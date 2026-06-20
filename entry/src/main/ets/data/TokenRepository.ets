import { common } from '@kit.AbilityKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';

const STORE_NAME = 'tool_2fa_tokens.db';
const TABLE_NAME = 'tokens';
const TOKENS_KEY = 'tokens';
const OLD_PREFS_NAME = 'tool_2fa_tokens';
const CLOUD_SYNC_TIMEOUT_MS = 30000;

const SQL_CREATE_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
    id INTEGER PRIMARY KEY,
    ${TOKENS_KEY} TEXT
  )
`;

let rdbStore: relationalStore.RdbStore | null = null;
let autoSyncProgress: ((details: relationalStore.ProgressDetails) => void) | null = null;

export interface CloudSyncState {
  status: string;
  finished: boolean;
  success: boolean;
}

async function getStore(context: common.Context): Promise<relationalStore.RdbStore> {
  if (rdbStore) {
    return rdbStore;
  }
  const config: relationalStore.StoreConfig = {
    name: STORE_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  };
  rdbStore = await relationalStore.getRdbStore(context, config);
  await rdbStore.executeSql(SQL_CREATE_TABLE);
  await migrateTableSchema(rdbStore);
  await migrateFromPreferences(context);
  return rdbStore;
}

async function migrateTableSchema(store: relationalStore.RdbStore): Promise<void> {
  try {
    const resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
    while (resultSet.goToNextRow()) {
      const name = resultSet.getString(resultSet.getColumnIndex('name'));
      const notNull = resultSet.getLong(resultSet.getColumnIndex('notnull'));
      if (name === TOKENS_KEY && notNull === 1) {
        await store.executeSql(`CREATE TABLE IF NOT EXISTS ${TABLE_NAME}_tmp (id INTEGER PRIMARY KEY, ${TOKENS_KEY} TEXT)`);
        await store.executeSql(`INSERT INTO ${TABLE_NAME}_tmp SELECT * FROM ${TABLE_NAME}`);
        await store.executeSql(`DROP TABLE ${TABLE_NAME}`);
        await store.executeSql(`ALTER TABLE ${TABLE_NAME}_tmp RENAME TO ${TABLE_NAME}`);
        break;
      }
    }
    resultSet.close();
  } catch (error) {
  }
}

async function migrateFromPreferences(context: common.Context): Promise<void> {
  try {
    const resultSet = await rdbStore!.querySql(`SELECT COUNT(*) as cnt FROM ${TABLE_NAME}`);
    resultSet.goToFirstRow();
    const count = resultSet.getLong(resultSet.getColumnIndex('cnt'));
    resultSet.close();
    if (count > 0) {
      return;
    }
    const store = await preferences.getPreferences(context, { name: OLD_PREFS_NAME });
    const value = await store.get(TOKENS_KEY, '');
    const json = typeof value === 'string' ? value : '[]';
    if (json !== '[]') {
      const valueBucket: relationalStore.ValuesBucket = {};
      valueBucket['id'] = 1;
      valueBucket[TOKENS_KEY] = json;
      await rdbStore!.insert(TABLE_NAME, valueBucket);
    }
  } catch (error) {
    // ignore migration failure
  }
}

export class TokenRepository {
  static async load(context: common.Context): Promise<TokenRecord[]> {
    try {
      const store = await getStore(context);
      const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
      const resultSet = await store.query(predicates);
      if (resultSet.rowCount === 0) {
        resultSet.close();
        return [];
      }
      resultSet.goToFirstRow();
      const value = resultSet.getString(resultSet.getColumnIndex(TOKENS_KEY));
      resultSet.close();
      if (!value || value.length === 0) {
        return [];
      }
      const parsedRecords = JSON.parse(value) as TokenRecord[];
      return parsedRecords.map((record: TokenRecord) => sanitizeTokenRecord(record));
    } catch (error) {
      console.error(`Failed to load token store: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async save(context: common.UIAbilityContext, records: TokenRecord[]): Promise<boolean> {
    try {
      const store = await getStore(context);
      const json = JSON.stringify(records);
      await store.executeSql(`DELETE FROM ${TABLE_NAME}`);
      const valueBucket: relationalStore.ValuesBucket = {};
      valueBucket['id'] = 1;
      valueBucket[TOKENS_KEY] = json;
      await store.insert(TABLE_NAME, valueBucket);
      return true;
    } catch (error) {
      console.error(`Failed to save token store: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async configureCloudSync(
    context: common.UIAbilityContext,
    enabled: boolean,
    listener?: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      const config: relationalStore.DistributedConfig = {
        autoSync: enabled,
        enableCloud: true
      };
      await store.setDistributedTables(
        [TABLE_NAME],
        relationalStore.DistributedType.DISTRIBUTED_CLOUD,
        config
      );
      if (!enabled || listener) {
        if (autoSyncProgress) {
          store.off('autoSyncProgress', autoSyncProgress);
          autoSyncProgress = null;
        }
        if (enabled && listener) {
          autoSyncProgress = (details: relationalStore.ProgressDetails): void => {
            listener(TokenRepository.cloudSyncState(details));
          };
          store.on('autoSyncProgress', autoSyncProgress);
        }
      }
      return true;
    } catch (error) {
      console.error(`Failed to configure cloud sync: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async pushToCloud(
    context: common.UIAbilityContext,
    records: TokenRecord[],
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    if (!await TokenRepository.save(context, records)) {
      return false;
    }
    return await TokenRepository.sync(context, relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST, listener);
  }

  static async pullFromCloud(
    context: common.UIAbilityContext,
    listener: (state: CloudSyncState) => void
  ): Promise<TokenRecord[] | null> {
    if (!await TokenRepository.sync(context, relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST, listener)) {
      return null;
    }
    return await TokenRepository.load(context);
  }

  private static async sync(
    context: common.UIAbilityContext,
    mode: relationalStore.SyncMode,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      return await new Promise<boolean>((resolve): void => {
        let callbackFinished = false;
        let progressFinished = false;
        let progressSucceeded = false;
        let settled = false;
        let timeoutId = -1;
        const settle = (success: boolean): void => {
          if (settled) {
            return;
          }
          settled = true;
          if (timeoutId >= 0) {
            clearTimeout(timeoutId);
          }
          resolve(success);
        };
        timeoutId = setTimeout((): void => {
          listener({ status: '同步超时', finished: true, success: false });
          settle(false);
        }, CLOUD_SYNC_TIMEOUT_MS);
        store.cloudSync(mode, [TABLE_NAME], (details: relationalStore.ProgressDetails): void => {
          const state = TokenRepository.cloudSyncState(details);
          console.info(`Cloud sync progress, schedule=${details.schedule}, code=${details.code}`);
          const tableDetails = details.details[TABLE_NAME];
          if (tableDetails) {
            console.info(`Cloud sync upload, total=${tableDetails.upload.total}, ` +
              `successful=${tableDetails.upload.successful}, failed=${tableDetails.upload.failed}, ` +
              `remained=${tableDetails.upload.remained}`);
          }
          listener(state);
          if (state.finished) {
            progressFinished = true;
            progressSucceeded = state.success;
            if (callbackFinished) {
              settle(progressSucceeded);
            }
          }
        }, (err: BusinessError): void => {
          if (err) {
            console.error(`Cloud sync failed, code is ${err.code}, message is ${err.message}`);
            listener({ status: `同步失败 (${err.code})`, finished: true, success: false });
            settle(false);
            return;
          }
          callbackFinished = true;
          if (progressFinished) {
            settle(progressSucceeded);
          }
        });
      });
    } catch (error) {
      console.error(`Failed to sync cloud data: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private static cloudSyncState(details: relationalStore.ProgressDetails): CloudSyncState {
    if (details.schedule === relationalStore.Progress.SYNC_BEGIN) {
      return { status: '正在准备', finished: false, success: false };
    }
    if (details.schedule === relationalStore.Progress.SYNC_IN_PROGRESS) {
      return { status: '正在同步', finished: false, success: false };
    }
    if (details.code === relationalStore.ProgressCode.SUCCESS) {
      return { status: '同步成功', finished: true, success: true };
    }
    if (details.code === relationalStore.ProgressCode.NETWORK_ERROR) {
      return { status: '网络异常', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.CLOUD_DISABLED) {
      return { status: '云服务未启用（3）', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.NO_SPACE_FOR_ASSET) {
      return { status: '云空间不足', finished: true, success: false };
    }
    return { status: `同步失败 (${details.code})`, finished: true, success: false };
  }
}
