import { common } from '@kit.AbilityKit';
import { cloudData, preferences, relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';

const STORE_NAME = 'tool_2fa_tokens.db';
const TABLE_NAME = 'tokens';
const OLD_JSON_COLUMN = 'tokens';
const OLD_PREFS_NAME = 'tool_2fa_tokens';
const CLOUD_SYNC_TIMEOUT_MS = 30000;

const SQL_CREATE_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
    id TEXT PRIMARY KEY,
    name TEXT,
    remark TEXT,
    type TEXT,
    algorithm TEXT,
    secret TEXT,
    logoUri TEXT,
    logoLightUri TEXT,
    logoDarkUri TEXT,
    logoSource TEXT,
    digits INTEGER,
    period INTEGER,
    counter INTEGER,
    steamData TEXT,
    createdAt INTEGER,
    modifiedTime INTEGER,
    sortIndex INTEGER
  )
`;

const REQUIRED_COLUMNS: string[] = [
  'id',
  'name',
  'remark',
  'type',
  'algorithm',
  'secret',
  'logoUri',
  'logoLightUri',
  'logoDarkUri',
  'logoSource',
  'digits',
  'period',
  'counter',
  'steamData',
  'createdAt',
  'modifiedTime',
  'sortIndex'
];

let rdbStore: relationalStore.RdbStore | null = null;
let autoSyncProgress: ((details: relationalStore.ProgressDetails) => void) | null = null;
let cloudDataChange: ((accounts: Array<string>) => void) | null = null;
let configuredAutoSync: boolean | null = null;

export interface CloudSyncState {
  status: string;
  finished: boolean;
  success: boolean;
  message?: string;
  uploadTotal?: number;
  uploadSuccess?: number;
  uploadFailed?: number;
  downloadTotal?: number;
  downloadSuccess?: number;
  downloadFailed?: number;
}

async function getStore(context: common.Context): Promise<relationalStore.RdbStore> {
  if (rdbStore) {
    return rdbStore;
  }
  const config: relationalStore.StoreConfig = {
    name: STORE_NAME,
    securityLevel: relationalStore.SecurityLevel.S3
  };
  rdbStore = await relationalStore.getRdbStore(context, config);
  await ensureTableSchema(context, rdbStore);
  return rdbStore;
}

async function ensureTableSchema(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
  const tableInfo = await getTableInfo(store);
  const tableColumns = Object.keys(tableInfo);
  if (tableColumns.length === 0) {
    await store.executeSql(SQL_CREATE_TABLE);
    const records = await readRecordsFromPreferences(context);
    if (records.length > 0) {
      await replaceRows(store, records);
    }
    return;
  }
  const shouldRebuild = tableColumns.includes(OLD_JSON_COLUMN) ||
    !tableColumns.includes('name') ||
    !tableColumns.includes('sortIndex') ||
    (tableInfo['id'] || '').toUpperCase() !== 'TEXT';
  if (shouldRebuild) {
    const records = tableColumns.includes(OLD_JSON_COLUMN) ?
      await readLegacyJsonRows(store) :
      await readStructuredRows(store);
    await store.executeSql(`DROP TABLE ${TABLE_NAME}`);
    await store.executeSql(SQL_CREATE_TABLE);
    if (records.length > 0) {
      await replaceRows(store, records);
    }
    return;
  }
  for (let i = 0; i < REQUIRED_COLUMNS.length; i++) {
    const column = REQUIRED_COLUMNS[i];
    if (!tableColumns.includes(column)) {
      await store.executeSql(`ALTER TABLE ${TABLE_NAME} ADD COLUMN ${column} ${columnType(column)}`);
    }
  }
}

async function getTableInfo(store: relationalStore.RdbStore): Promise<Record<string, string>> {
  const columns: Record<string, string> = {};
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql(`PRAGMA table_info(${TABLE_NAME})`);
    while (resultSet.goToNextRow()) {
      const name = resultSet.getString(resultSet.getColumnIndex('name'));
      const type = resultSet.getString(resultSet.getColumnIndex('type'));
      columns[name] = type;
    }
  } catch (error) {
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
  return columns;
}

function columnType(column: string): string {
  if (column === 'digits' || column === 'period' || column === 'counter' ||
    column === 'createdAt' || column === 'modifiedTime' || column === 'sortIndex') {
    return 'INTEGER';
  }
  return 'TEXT';
}

async function readRecordsFromPreferences(context: common.Context): Promise<TokenRecord[]> {
  try {
    const store = await preferences.getPreferences(context, { name: OLD_PREFS_NAME });
    const value = await store.get(OLD_JSON_COLUMN, '');
    return recordsFromJson(typeof value === 'string' ? value : '[]');
  } catch (error) {
    return [];
  }
}

async function readLegacyJsonRows(store: relationalStore.RdbStore): Promise<TokenRecord[]> {
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql(`SELECT ${OLD_JSON_COLUMN} FROM ${TABLE_NAME} ORDER BY id ASC LIMIT 1`);
    if (!resultSet.goToFirstRow()) {
      return [];
    }
    return recordsFromJson(resultSet.getString(resultSet.getColumnIndex(OLD_JSON_COLUMN)));
  } catch (error) {
    return [];
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
}

function recordsFromJson(json: string): TokenRecord[] {
  try {
    const parsedRecords = JSON.parse(json) as TokenRecord[];
    if (!Array.isArray(parsedRecords)) {
      return [];
    }
    return parsedRecords.map((record: TokenRecord) => sanitizeTokenRecord(record));
  } catch (error) {
    return [];
  }
}

async function readStructuredRows(store: relationalStore.RdbStore): Promise<TokenRecord[]> {
  let resultSet: relationalStore.ResultSet | null = null;
  const records: TokenRecord[] = [];
  try {
    resultSet = await store.querySql(`SELECT * FROM ${TABLE_NAME} ORDER BY sortIndex ASC, createdAt DESC`);
    while (resultSet.goToNextRow()) {
      records.push(tokenFromRow(resultSet));
    }
  } catch (error) {
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
  return records;
}

function tokenFromRow(resultSet: relationalStore.ResultSet): TokenRecord {
  return sanitizeTokenRecord({
    id: rowString(resultSet, 'id'),
    name: rowString(resultSet, 'name'),
    remark: rowString(resultSet, 'remark'),
    type: rowString(resultSet, 'type') || 'TOTP',
    algorithm: rowString(resultSet, 'algorithm') || 'SHA1',
    secret: rowString(resultSet, 'secret'),
    logoUri: rowString(resultSet, 'logoUri'),
    logoLightUri: rowString(resultSet, 'logoLightUri'),
    logoDarkUri: rowString(resultSet, 'logoDarkUri'),
    logoSource: rowString(resultSet, 'logoSource'),
    digits: rowLong(resultSet, 'digits'),
    period: rowLong(resultSet, 'period'),
    counter: rowLong(resultSet, 'counter'),
    steamData: rowString(resultSet, 'steamData'),
    createdAt: rowLong(resultSet, 'createdAt') || Date.now(),
    modifiedTime: rowLong(resultSet, 'modifiedTime') || rowLong(resultSet, 'createdAt') || Date.now()
  });
}

function rowString(resultSet: relationalStore.ResultSet, column: string): string {
  try {
    const index = resultSet.getColumnIndex(column);
    if (index < 0 || resultSet.isColumnNull(index)) {
      return '';
    }
    return resultSet.getString(index);
  } catch (error) {
    return '';
  }
}

function rowLong(resultSet: relationalStore.ResultSet, column: string): number {
  try {
    const index = resultSet.getColumnIndex(column);
    if (index < 0 || resultSet.isColumnNull(index)) {
      return 0;
    }
    return resultSet.getLong(index);
  } catch (error) {
    return 0;
  }
}

async function replaceRows(store: relationalStore.RdbStore, records: TokenRecord[]): Promise<void> {
  const ids = records.map((record: TokenRecord, index: number): string => {
    return sanitizeTokenRecord(record).id || `${Date.now()}_${index}`;
  });
  if (ids.length === 0) {
    await store.delete(new relationalStore.RdbPredicates(TABLE_NAME));
    return;
  }
  await store.delete(new relationalStore.RdbPredicates(TABLE_NAME).notIn('id', ids));
  const buckets: relationalStore.ValuesBucket[] = [];
  for (let i = 0; i < records.length; i++) {
    buckets.push(tokenToBucket(records[i], i));
  }
  if (buckets.length > 0) {
    await store.batchInsertWithConflictResolution(
      TABLE_NAME,
      buckets,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }
}

function tokenToBucket(record: TokenRecord, index: number): relationalStore.ValuesBucket {
  const token = sanitizeTokenRecord(record);
  const bucket: relationalStore.ValuesBucket = {};
  bucket['id'] = token.id.length > 0 ? token.id : `${Date.now()}_${index}`;
  bucket['name'] = token.name;
  bucket['remark'] = token.remark;
  bucket['type'] = token.type;
  bucket['algorithm'] = token.algorithm;
  bucket['secret'] = token.secret;
  bucket['logoUri'] = token.logoUri || '';
  bucket['logoLightUri'] = token.logoLightUri || '';
  bucket['logoDarkUri'] = token.logoDarkUri || '';
  bucket['logoSource'] = token.logoSource || '';
  bucket['digits'] = token.digits || 6;
  bucket['period'] = token.period || 30;
  bucket['counter'] = token.counter || 0;
  bucket['steamData'] = token.steamData || '';
  bucket['createdAt'] = token.createdAt || Date.now();
  bucket['modifiedTime'] = Date.now();
  bucket['sortIndex'] = index;
  return bucket;
}

async function configureNetworkStrategy(): Promise<void> {
  try {
    await cloudData.setCloudStrategy(cloudData.StrategyType.NETWORK, [
      cloudData.NetWorkStrategy.WIFI,
      cloudData.NetWorkStrategy.CELLULAR
    ]);
  } catch (error) {
    const businessError = error as BusinessError;
    console.error(`Failed to configure cloud network strategy: ${businessError.code}, ${businessError.message}`);
  }
}

export class TokenRepository {
  static async load(context: common.Context): Promise<TokenRecord[]> {
    try {
      const store = await getStore(context);
      return await readStructuredRows(store);
    } catch (error) {
      console.error(`Failed to load token store: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async save(context: common.UIAbilityContext, records: TokenRecord[]): Promise<boolean> {
    try {
      const store = await getStore(context);
      await replaceRows(store, records);
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
      let store = await getStore(context);
      console.info(`Configure cloud sync: db=${STORE_NAME}, table=${TABLE_NAME}, autoSync=${enabled}`);
      await configureNetworkStrategy();
      if (configuredAutoSync !== enabled) {
        await store.setDistributedTables(
          [TABLE_NAME],
          relationalStore.DistributedType.DISTRIBUTED_CLOUD,
          { autoSync: enabled }
        );
        configuredAutoSync = enabled;
        console.info(`Cloud table configured: table=${TABLE_NAME}, autoSync=${enabled}`);
        await store.close();
        rdbStore = null;
        store = await getStore(context);
      }
      if (!enabled || listener) {
        if (autoSyncProgress) {
          store.off('autoSyncProgress', autoSyncProgress);
          autoSyncProgress = null;
        }
        if (cloudDataChange) {
          store.off('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD, cloudDataChange);
          cloudDataChange = null;
        }
        if (enabled && listener) {
          autoSyncProgress = (details: relationalStore.ProgressDetails): void => {
            listener(TokenRepository.cloudSyncState(details));
          };
          store.on('autoSyncProgress', autoSyncProgress);
          cloudDataChange = (): void => {
            listener({ status: '云端数据已更新', finished: true, success: true });
          };
          store.on('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD, cloudDataChange);
        }
      }
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed to configure cloud sync: ${businessError.code}, ${businessError.message}`);
      return false;
    }
  }

  static async pushToCloud(
    context: common.UIAbilityContext,
    records: TokenRecord[],
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    console.info(`Start native-first cloud sync: records=${records.length}`);
    if (!await TokenRepository.save(context, records)) {
      listener({ status: '本地保存失败', finished: true, success: false });
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
      console.info(`Request cloud sync: table=${TABLE_NAME}, mode=${mode}`);
      let progressSeen = false;
      let lastState: CloudSyncState = { status: '正在同步', finished: false, success: false };
      const syncTask = store.cloudSync(mode, [TABLE_NAME], (details: relationalStore.ProgressDetails): void => {
        progressSeen = true;
        lastState = TokenRepository.cloudSyncState(details);
        console.info(`Cloud sync progress, schedule=${details.schedule}, code=${details.code}`);
        const tableDetails = details.details[TABLE_NAME];
        if (tableDetails) {
          console.info(`Cloud sync ${TABLE_NAME}, upload=${JSON.stringify(tableDetails.upload)}, ` +
            `download=${JSON.stringify(tableDetails.download)}`);
        }
        listener(lastState);
      });
      const timedOut = await new Promise<boolean>((resolve): void => {
        let settled = false;
        const timeoutId = setTimeout((): void => {
          if (!settled) {
            settled = true;
            resolve(true);
          }
        }, CLOUD_SYNC_TIMEOUT_MS);
        syncTask.then((): void => {
          if (!settled) {
            settled = true;
            clearTimeout(timeoutId);
            resolve(false);
          }
        }).catch((error: BusinessError): void => {
          if (!settled) {
            settled = true;
            clearTimeout(timeoutId);
            console.error(`Cloud sync failed, code is ${error.code}, message is ${error.message}`);
            listener({ status: `同步失败 (${error.code})`, finished: true, success: false });
            resolve(true);
          }
        });
      });
      if (timedOut) {
        if (!lastState.finished) {
          listener({ status: '同步超时', finished: true, success: false });
        }
        console.error(`Cloud sync timed out: table=${TABLE_NAME}, mode=${mode}`);
        return false;
      }
      if (!progressSeen) {
        listener({ status: '同步中', finished: true, success: true });
        return true;
      }
      if (!lastState.finished) {
        listener({ status: '同步未完成', finished: true, success: false });
        return false;
      }
      return lastState.success;
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed to sync cloud data: ${businessError.code}, ${businessError.message}`);
      listener({ status: '同步失败', finished: true, success: false });
      return false;
    }
  }

  private static cloudSyncState(details: relationalStore.ProgressDetails): CloudSyncState {
    const tableDetails = details.details[TABLE_NAME];
    const uploadTotal = tableDetails ? tableDetails.upload.total : 0;
    const uploadSuccess = tableDetails ? tableDetails.upload.successful : 0;
    const uploadFailed = tableDetails ? tableDetails.upload.failed : 0;
    const downloadTotal = tableDetails ? tableDetails.download.total : 0;
    const downloadSuccess = tableDetails ? tableDetails.download.successful : 0;
    const downloadFailed = tableDetails ? tableDetails.download.failed : 0;
    const progressText = `（上传${uploadSuccess}/${uploadTotal}，下载${downloadSuccess}/${downloadTotal}）`;
    const resultText = uploadFailed > 0 || downloadFailed > 0 ?
      `（上传${uploadSuccess}条，下载${downloadSuccess}条，失败${uploadFailed + downloadFailed}条）` :
      `（上传${uploadSuccess}条，下载${downloadSuccess}条）`;
    if (details.code === relationalStore.ProgressCode.NETWORK_ERROR) {
      return { status: '网络异常', message: '网络异常', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.CLOUD_DISABLED) {
      return { status: '云服务未启用（3）', message: '云服务未启用', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.LOCKED_BY_OTHERS) {
      return { status: '云同步被占用（4）', message: '云同步被其他任务占用', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.RECORD_LIMIT_EXCEEDED) {
      return { status: '云端记录超限（5）', message: '云端记录超出限制', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.NO_SPACE_FOR_ASSET) {
      return { status: '云空间不足', message: '云空间容量不足', finished: true, success: false };
    }
    if (details.code === relationalStore.ProgressCode.BLOCKED_BY_NETWORK_STRATEGY) {
      return { status: '当前网络不允许同步（7）', message: '当前网络不允许同步', finished: true, success: false };
    }
    if (details.code !== relationalStore.ProgressCode.SUCCESS) {
      return {
        status: `同步失败（${details.code}）`,
        message: `云空间返回错误码 ${details.code}`,
        finished: true,
        success: false
      };
    }
    if (details.schedule === relationalStore.Progress.SYNC_BEGIN) {
      return { status: '同步中', finished: false, success: false };
    }
    if (details.schedule === relationalStore.Progress.SYNC_IN_PROGRESS) {
      return {
        status: `同步中${progressText}`,
        finished: false,
        success: false,
        uploadTotal,
        uploadSuccess,
        uploadFailed,
        downloadTotal,
        downloadSuccess,
        downloadFailed
      };
    }
    if (details.schedule === relationalStore.Progress.SYNC_FINISH && (uploadFailed > 0 || downloadFailed > 0)) {
      return {
        status: `同步部分失败${resultText}`,
        message: `部分数据同步失败${resultText}`,
        finished: true,
        success: false,
        uploadTotal,
        uploadSuccess,
        uploadFailed,
        downloadTotal,
        downloadSuccess,
        downloadFailed
      };
    }
    if (details.schedule === relationalStore.Progress.SYNC_FINISH) {
      return {
        status: `同步成功${resultText}`,
        finished: true,
        success: true,
        uploadTotal,
        uploadSuccess,
        uploadFailed,
        downloadTotal,
        downloadSuccess,
        downloadFailed
      };
    }
    return { status: '同步状态未知', finished: true, success: false };
  }
}
