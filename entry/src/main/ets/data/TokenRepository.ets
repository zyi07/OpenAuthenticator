import { common } from '@kit.AbilityKit';
import { cloudData, preferences, relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';

const STORE_NAME = 'tool_2fa_tokens.db';
const LOCAL_TABLE_NAME = 'local_tokens';
const LOCAL_EXCLUSIONS_TABLE_NAME = 'local_cloud_exclusions';
const CLOUD_TABLE_NAME = 'tokens';
const OLD_JSON_COLUMN = 'tokens';
const OLD_PREFS_NAME = 'tool_2fa_tokens';
const OLD_EXCLUSIONS_KEY = 'localCloudExclusions';
const STORE_FORMAT_VERSION = 4;
const CLOUD_SYNC_TIMEOUT_MS = 120000;

const SQL_CREATE_LOCAL_TABLE = `
  CREATE TABLE IF NOT EXISTS ${LOCAL_TABLE_NAME} (
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

const SQL_CREATE_CLOUD_TABLE = `
  CREATE TABLE IF NOT EXISTS ${CLOUD_TABLE_NAME} (
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
    createdAt INTEGER,
    sortIndex INTEGER
  )
`;

const SQL_CREATE_LOCAL_EXCLUSIONS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${LOCAL_EXCLUSIONS_TABLE_NAME} (
    id TEXT PRIMARY KEY
  )
`;

const LOCAL_REQUIRED_COLUMNS: string[] = [
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

const CLOUD_REQUIRED_COLUMNS: string[] = [
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
  'createdAt',
  'sortIndex'
];

let rdbStore: relationalStore.RdbStore | null = null;
let rdbStoreInitialization: Promise<relationalStore.RdbStore> | null = null;
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

export interface CloudStageResult {
  success: boolean;
  changed: boolean;
}

async function getStore(context: common.Context): Promise<relationalStore.RdbStore> {
  if (rdbStore) {
    return rdbStore;
  }
  if (!rdbStoreInitialization) {
    rdbStoreInitialization = initializeStore(context);
  }
  try {
    return await rdbStoreInitialization;
  } finally {
    if (!rdbStore) {
      rdbStoreInitialization = null;
    }
  }
}

async function initializeStore(context: common.Context): Promise<relationalStore.RdbStore> {
  const config = createStoreConfig();
  let store = await relationalStore.getRdbStore(context, config);
  await ensureTableSchemas(context, store);
  store = await rebuildCloudSyncMetadataIfNeeded(context, config, store);
  rdbStore = store;
  return store;
}

function createStoreConfig(): relationalStore.StoreConfig {
  const config: relationalStore.StoreConfig = {
    name: STORE_NAME,
    securityLevel: relationalStore.SecurityLevel.S3,
    autoCleanDirtyData: true
  };
  return config;
}

async function ensureTableSchemas(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
  const cloudInfo = await getTableInfo(store, CLOUD_TABLE_NAME);
  const cloudColumns = Object.keys(cloudInfo);
  let migrationRecords: TokenRecord[] = [];
  if (cloudColumns.length === 0) {
    migrationRecords = await readRecordsFromPreferences(context);
  } else if (cloudColumns.includes(OLD_JSON_COLUMN)) {
    migrationRecords = await readLegacyJsonRows(store);
  } else {
    migrationRecords = await readStructuredRows(store, CLOUD_TABLE_NAME);
  }

  const localInfo = await getTableInfo(store, LOCAL_TABLE_NAME);
  const localColumns = Object.keys(localInfo);
  if (localColumns.length === 0) {
    await store.executeSql(SQL_CREATE_LOCAL_TABLE);
    if (migrationRecords.length > 0) {
      await replaceLocalRows(store, migrationRecords);
    }
  } else {
    await addMissingColumns(store, LOCAL_TABLE_NAME, localColumns, LOCAL_REQUIRED_COLUMNS);
  }

  if (cloudColumns.length === 0) {
    await store.executeSql(SQL_CREATE_CLOUD_TABLE);
  } else if (!cloudColumns.includes(OLD_JSON_COLUMN)) {
    await addMissingColumns(store, CLOUD_TABLE_NAME, cloudColumns, CLOUD_REQUIRED_COLUMNS);
  }
  await store.executeSql(SQL_CREATE_LOCAL_EXCLUSIONS_TABLE);
}

async function rebuildCloudSyncMetadataIfNeeded(
  context: common.Context,
  config: relationalStore.StoreConfig,
  store: relationalStore.RdbStore
): Promise<relationalStore.RdbStore> {
  if (store.version >= STORE_FORMAT_VERSION) {
    return store;
  }
  return await rebuildCloudSyncMetadata(context, config, store);
}

async function rebuildCloudSyncMetadata(
  context: common.Context,
  config: relationalStore.StoreConfig,
  store: relationalStore.RdbStore
): Promise<relationalStore.RdbStore> {
  let records = await readStructuredRows(store, LOCAL_TABLE_NAME);
  if (records.length === 0) {
    records = await readRecordsFromPreferences(context);
  }
  let exclusions = await readLocalExclusions(store);
  if (exclusions.length === 0) {
    exclusions = await readMigrationExclusions(context);
  }
  await saveMigrationSnapshot(context, records, exclusions);
  console.info('Rebuild cloud sync metadata while preserving local records: records=' + records.length.toString());
  await store.close();
  await relationalStore.deleteRdbStore(context, config);
  const rebuiltStore = await relationalStore.getRdbStore(context, config);
  await rebuiltStore.executeSql(SQL_CREATE_LOCAL_TABLE);
  await rebuiltStore.executeSql(SQL_CREATE_CLOUD_TABLE);
  await rebuiltStore.executeSql(SQL_CREATE_LOCAL_EXCLUSIONS_TABLE);
  await replaceLocalRows(rebuiltStore, records);
  await restoreLocalExclusions(rebuiltStore, exclusions);
  rebuiltStore.version = STORE_FORMAT_VERSION;
  await clearMigrationSnapshot(context);
  console.info('Cloud sync metadata rebuild completed');
  return rebuiltStore;
}

async function resetCloudSyncMetadataAfterDelete(
  context: common.UIAbilityContext,
  store: relationalStore.RdbStore
): Promise<boolean> {
  const config = createStoreConfig();
  rdbStore = null;
  rdbStoreInitialization = null;
  configuredAutoSync = null;
  autoSyncProgress = null;
  cloudDataChange = null;
  try {
    console.info('Reset cloud sync metadata after physical cloud delete');
    const rebuiltStore = await rebuildCloudSyncMetadata(context, config, store);
    rdbStore = rebuiltStore;
    console.info('Cloud sync metadata reset after delete completed');
    return true;
  } catch (error) {
    console.error('Failed to reset cloud sync metadata after delete: ' + JSON.stringify(error));
    return false;
  }
}

async function addMissingColumns(
  store: relationalStore.RdbStore,
  tableName: string,
  tableColumns: string[],
  requiredColumns: string[]
): Promise<void> {
  for (let i = 0; i < requiredColumns.length; i++) {
    const column = requiredColumns[i];
    if (!tableColumns.includes(column)) {
      await store.executeSql('ALTER TABLE ' + tableName + ' ADD COLUMN ' + column + ' ' + columnType(column));
    }
  }
}

async function getTableInfo(
  store: relationalStore.RdbStore,
  tableName: string
): Promise<Record<string, string>> {
  const columns: Record<string, string> = {};
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql('PRAGMA table_info(' + tableName + ')');
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

async function readMigrationExclusions(context: common.Context): Promise<string[]> {
  try {
    const store = await preferences.getPreferences(context, { name: OLD_PREFS_NAME });
    const value = await store.get(OLD_EXCLUSIONS_KEY, '');
    if (typeof value !== 'string' || value.length === 0) {
      return [];
    }
    const values = value.split('\n');
    const exclusions: string[] = [];
    for (let i = 0; i < values.length; i++) {
      if (values[i].length > 0) {
        exclusions.push(values[i]);
      }
    }
    return exclusions;
  } catch (error) {
    return [];
  }
}

async function saveMigrationSnapshot(
  context: common.Context,
  records: TokenRecord[],
  exclusions: string[]
): Promise<void> {
  const store = await preferences.getPreferences(context, { name: OLD_PREFS_NAME });
  await store.put(OLD_JSON_COLUMN, JSON.stringify(records));
  await store.put(OLD_EXCLUSIONS_KEY, exclusions.join('\n'));
  await store.flush();
}

async function clearMigrationSnapshot(context: common.Context): Promise<void> {
  const store = await preferences.getPreferences(context, { name: OLD_PREFS_NAME });
  await store.delete(OLD_JSON_COLUMN);
  await store.delete(OLD_EXCLUSIONS_KEY);
  await store.flush();
}

async function readLocalExclusions(store: relationalStore.RdbStore): Promise<string[]> {
  const exclusions: string[] = [];
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql('SELECT id FROM ' + LOCAL_EXCLUSIONS_TABLE_NAME);
    while (resultSet.goToNextRow()) {
      exclusions.push(resultSet.getString(resultSet.getColumnIndex('id')));
    }
  } catch (error) {
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
  return exclusions;
}

async function restoreLocalExclusions(store: relationalStore.RdbStore, exclusions: string[]): Promise<void> {
  const buckets: relationalStore.ValuesBucket[] = [];
  for (let i = 0; i < exclusions.length; i++) {
    const bucket: relationalStore.ValuesBucket = {};
    bucket['id'] = exclusions[i];
    buckets.push(bucket);
  }
  if (buckets.length > 0) {
    await store.batchInsertWithConflictResolution(
      LOCAL_EXCLUSIONS_TABLE_NAME,
      buckets,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
  }
}

async function readLegacyJsonRows(store: relationalStore.RdbStore): Promise<TokenRecord[]> {
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql(
      'SELECT ' + OLD_JSON_COLUMN + ' FROM ' + CLOUD_TABLE_NAME + ' ORDER BY id ASC LIMIT 1'
    );
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

async function readStructuredRows(
  store: relationalStore.RdbStore,
  tableName: string
): Promise<TokenRecord[]> {
  let resultSet: relationalStore.ResultSet | null = null;
  const records: TokenRecord[] = [];
  try {
    resultSet = await store.querySql('SELECT * FROM ' + tableName + ' ORDER BY sortIndex ASC, createdAt DESC');
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

async function replaceLocalRows(store: relationalStore.RdbStore, records: TokenRecord[]): Promise<void> {
  const ids = records.map((record: TokenRecord, index: number): string => {
    return sanitizeTokenRecord(record).id || Date.now().toString() + '_' + index.toString();
  });
  if (ids.length === 0) {
    await store.delete(new relationalStore.RdbPredicates(LOCAL_TABLE_NAME));
    return;
  }
  await store.delete(new relationalStore.RdbPredicates(LOCAL_TABLE_NAME).notIn('id', ids));
  const buckets: relationalStore.ValuesBucket[] = [];
  for (let i = 0; i < records.length; i++) {
    buckets.push(tokenToLocalBucket(records[i], i));
  }
  if (buckets.length > 0) {
    await store.batchInsertWithConflictResolution(
      LOCAL_TABLE_NAME,
      buckets,
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
    );
    await store.delete(new relationalStore.RdbPredicates(LOCAL_EXCLUSIONS_TABLE_NAME).in('id', ids));
  }
}

async function upsertCloudRows(store: relationalStore.RdbStore, records: TokenRecord[]): Promise<number> {
  const cloudRecords = await readStructuredRows(store, CLOUD_TABLE_NAME);
  const cloudSortIndexes = await readCloudSortIndexes(store);
  let insertedCount = 0;
  let updatedCount = 0;
  for (let i = 0; i < records.length; i++) {
    const localRecord = sanitizeTokenRecord(records[i]);
    const cloudRecord = cloudRecords.find((record: TokenRecord): boolean => record.id === localRecord.id);
    const cloudSortIndex = cloudSortIndexes.get(localRecord.id);
    const bucket = tokenToCloudBucket(localRecord, i);
    if (!cloudRecord) {
      await store.insert(CLOUD_TABLE_NAME, bucket);
      insertedCount += 1;
    } else if (cloudSortIndex !== i || !sameCloudRecord(localRecord, cloudRecord)) {
      const predicates = new relationalStore.RdbPredicates(CLOUD_TABLE_NAME).equalTo('id', localRecord.id);
      const changedRows = await store.update(bucket, predicates);
      if (changedRows > 0) {
        updatedCount += changedRows;
      } else {
        await store.insert(CLOUD_TABLE_NAME, bucket);
        insertedCount += 1;
      }
    }
  }
  console.info('Staged cloud rows without replace: inserted=' + insertedCount.toString() +
    ', updated=' + updatedCount.toString());
  return insertedCount + updatedCount;
}

async function cleanCloudDeletedData(store: relationalStore.RdbStore): Promise<boolean> {
  try {
    await store.cleanDirtyData(CLOUD_TABLE_NAME);
    console.info(`Cleaned cloud deleted data: table=${CLOUD_TABLE_NAME}`);
    return true;
  } catch (error) {
    console.error(`Failed to clean cloud deleted data: ${JSON.stringify(error)}`);
    return false;
  }
}

async function hasCloudRecord(store: relationalStore.RdbStore, tokenId: string): Promise<boolean> {
  const records = await readStructuredRows(store, CLOUD_TABLE_NAME);
  return records.find((record: TokenRecord): boolean => record.id === tokenId) !== undefined;
}

async function readCloudSortIndexes(store: relationalStore.RdbStore): Promise<Map<string, number>> {
  const indexes = new Map<string, number>();
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql('SELECT id, sortIndex FROM ' + CLOUD_TABLE_NAME);
    while (resultSet.goToNextRow()) {
      indexes.set(
        resultSet.getString(resultSet.getColumnIndex('id')),
        resultSet.getLong(resultSet.getColumnIndex('sortIndex'))
      );
    }
  } catch (error) {
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
  return indexes;
}

function sameCloudRecord(first: TokenRecord, second: TokenRecord): boolean {
  return first.id === second.id &&
    first.name === second.name &&
    first.remark === second.remark &&
    first.type === second.type &&
    first.algorithm === second.algorithm &&
    first.secret === second.secret &&
    (first.logoUri || '') === (second.logoUri || '') &&
    (first.logoLightUri || '') === (second.logoLightUri || '') &&
    (first.logoDarkUri || '') === (second.logoDarkUri || '') &&
    (first.logoSource || '') === (second.logoSource || '') &&
    (first.digits || 6) === (second.digits || 6) &&
    (first.period || 30) === (second.period || 30) &&
    (first.counter || 0) === (second.counter || 0) &&
    first.createdAt === second.createdAt;
}

function tokenToLocalBucket(record: TokenRecord, index: number): relationalStore.ValuesBucket {
  const bucket = tokenToCloudBucket(record, index);
  bucket['steamData'] = record.steamData || '';
  bucket['modifiedTime'] = record.modifiedTime || Date.now();
  return bucket;
}

function tokenToCloudBucket(record: TokenRecord, index: number): relationalStore.ValuesBucket {
  const token = sanitizeTokenRecord(record);
  const bucket: relationalStore.ValuesBucket = {};
  bucket['id'] = token.id.length > 0 ? token.id : Date.now().toString() + '_' + index.toString();
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
  bucket['createdAt'] = token.createdAt || Date.now();
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
      return await readStructuredRows(store, LOCAL_TABLE_NAME);
    } catch (error) {
      console.error(`Failed to load token store: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async save(context: common.UIAbilityContext, records: TokenRecord[]): Promise<boolean> {
    try {
      const store = await getStore(context);
      await replaceLocalRows(store, records);
      return true;
    } catch (error) {
      console.error(`Failed to save token store: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async excludeCloudTokenFromLocal(context: common.UIAbilityContext, tokenId: string): Promise<boolean> {
    try {
      const store = await getStore(context);
      const bucket: relationalStore.ValuesBucket = {};
      bucket['id'] = tokenId;
      await store.insert(
        LOCAL_EXCLUSIONS_TABLE_NAME,
        bucket,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
      );
      return true;
    } catch (error) {
      console.error(`Failed to save local cloud exclusion: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async loadLocalCloudExclusions(context: common.Context): Promise<string[]> {
    const exclusions: string[] = [];
    let resultSet: relationalStore.ResultSet | null = null;
    try {
      const store = await getStore(context);
      resultSet = await store.querySql('SELECT id FROM ' + LOCAL_EXCLUSIONS_TABLE_NAME);
      while (resultSet.goToNextRow()) {
        exclusions.push(resultSet.getString(resultSet.getColumnIndex('id')));
      }
    } catch (error) {
      console.error(`Failed to load local cloud exclusions: ${JSON.stringify(error)}`);
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return exclusions;
  }

  static async configureCloudSync(
    context: common.UIAbilityContext,
    enabled: boolean,
    listener?: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      let store = await getStore(context);
      console.info(`Configure cloud sync: db=${STORE_NAME}, table=${CLOUD_TABLE_NAME}, autoSync=${enabled}`);
      await configureNetworkStrategy();
      if (configuredAutoSync !== enabled) {
        await store.setDistributedTables(
          [CLOUD_TABLE_NAME],
          relationalStore.DistributedType.DISTRIBUTED_CLOUD,
          { autoSync: enabled }
        );
        configuredAutoSync = enabled;
        console.info(`Cloud table configured: table=${CLOUD_TABLE_NAME}, autoSync=${enabled}`);
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
    try {
      const store = await getStore(context);
      console.info(`Refresh cloud version baseline before push: records=${records.length}`);
      if (!await TokenRepository.refreshCloudVersionBaseline(context, listener)) {
        return false;
      }
      if (!await cleanCloudDeletedData(store)) {
        listener({ status: '云端删除状态清理失败', finished: true, success: false });
        return false;
      }
      console.info(`Start native-first cloud sync: records=${records.length}`);
      await upsertCloudRows(store, records);
    } catch (error) {
      console.error(`Failed to stage cloud records: ${JSON.stringify(error)}`);
      listener({ status: '推送准备失败', finished: true, success: false });
      return false;
    }
    return await TokenRepository.sync(context, relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST, listener);
  }

  static async stageAutoPush(
    context: common.UIAbilityContext,
    records: TokenRecord[]
  ): Promise<CloudStageResult> {
    try {
      const store = await getStore(context);
      const changed = await upsertCloudRows(store, records);
      return { success: true, changed: changed > 0 };
    } catch (error) {
      console.error(`Failed to stage automatic cloud sync: ${JSON.stringify(error)}`);
      return { success: false, changed: false };
    }
  }

  static async pullFromCloud(
    context: common.UIAbilityContext,
    listener: (state: CloudSyncState) => void
  ): Promise<TokenRecord[] | null> {
    if (!await TokenRepository.sync(context, relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST, listener)) {
      return null;
    }
    return await TokenRepository.loadCloudRecords(context);
  }

  static async loadCloudRecords(context: common.Context): Promise<TokenRecord[]> {
    try {
      const store = await getStore(context);
      return await readStructuredRows(store, CLOUD_TABLE_NAME);
    } catch (error) {
      console.error(`Failed to load cloud token mirror: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async deleteFromCloud(
    context: common.UIAbilityContext,
    token: TokenRecord,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      console.info(`Refresh cloud version baseline before delete: id=${token.id}`);
      if (!await TokenRepository.refreshCloudVersionBaseline(context, listener)) {
        return false;
      }
      if (!await cleanCloudDeletedData(store)) {
        listener({ status: '云端删除状态清理失败', finished: true, success: false });
        return false;
      }
      if (!await hasCloudRecord(store, token.id)) {
        await resetCloudSyncMetadataAfterDelete(context, store);
        listener({ status: '删除成功', finished: true, success: true });
        return true;
      }
      await store.delete(new relationalStore.RdbPredicates(CLOUD_TABLE_NAME).equalTo('id', token.id));
      const success = await TokenRepository.sync(
        context,
        relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST,
        listener
      );
      if (success) {
        await resetCloudSyncMetadataAfterDelete(context, store);
        return true;
      }
      listener({ status: '正在确认云端删除结果', finished: false, success: false });
      const verified = await TokenRepository.sync(
        context,
        relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
        (state: CloudSyncState): void => {
          if (!state.finished) {
            listener({ status: '正在确认云端删除结果', finished: false, success: false });
          }
        }
      );
      if (verified && await cleanCloudDeletedData(store)) {
        if (!await hasCloudRecord(store, token.id)) {
          await resetCloudSyncMetadataAfterDelete(context, store);
          listener({ status: '删除成功', finished: true, success: true });
          return true;
        }
      }
      await resetCloudSyncMetadataAfterDelete(context, store);
      listener({ status: '云端删除失败', finished: true, success: false });
      return false;
    } catch (error) {
      console.error(`Failed to delete cloud token: ${JSON.stringify(error)}`);
      listener({ status: '云端删除失败', finished: true, success: false });
      return false;
    }
  }

  private static async refreshCloudVersionBaseline(
    context: common.UIAbilityContext,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    listener({ status: '正在检查云端版本', finished: false, success: false });
    return await TokenRepository.sync(
      context,
      relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
      (state: CloudSyncState): void => {
        if (!state.finished) {
          listener({ status: '正在检查云端版本', finished: false, success: false });
        } else if (!state.success) {
          listener(state);
        }
      }
    );
  }

  private static async sync(
    context: common.UIAbilityContext,
    mode: relationalStore.SyncMode,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      console.info(`Request cloud sync: table=${CLOUD_TABLE_NAME}, mode=${mode}`);
      return await new Promise<boolean>((resolve): void => {
        let settled = false;
        let timeoutId = -1;
        const finish = (success: boolean): void => {
          if (!settled) {
            settled = true;
            if (timeoutId >= 0) {
              clearTimeout(timeoutId);
            }
            resolve(success);
          }
        };
        timeoutId = setTimeout((): void => {
          if (!settled) {
            listener({ status: '同步超时', finished: true, success: false });
            console.error(`Cloud sync timed out: table=${CLOUD_TABLE_NAME}, mode=${mode}`);
            finish(false);
          }
        }, CLOUD_SYNC_TIMEOUT_MS);
        const syncTask = store.cloudSync(
          mode,
          [CLOUD_TABLE_NAME],
          (details: relationalStore.ProgressDetails): void => {
            const state = TokenRepository.cloudSyncState(details);
            console.info(`Cloud sync progress, schedule=${details.schedule}, code=${details.code}`);
            const tableDetails = details.details[CLOUD_TABLE_NAME];
            if (tableDetails) {
              console.info(`Cloud sync ${CLOUD_TABLE_NAME}, upload=${JSON.stringify(tableDetails.upload)}, ` +
                `download=${JSON.stringify(tableDetails.download)}`);
            }
            listener(state);
            if (state.finished) {
              finish(state.success);
            }
          }
        );
        syncTask.then((): void => {
          console.info(`Cloud sync request completed: table=${CLOUD_TABLE_NAME}, mode=${mode}`);
        }).catch((error: BusinessError): void => {
          if (!settled) {
            console.error(`Cloud sync failed, code is ${error.code}, message is ${error.message}`);
            listener({ status: `同步失败 (${error.code})`, finished: true, success: false });
            finish(false);
          }
        });
      });
    } catch (error) {
      const businessError = error as BusinessError;
      console.error(`Failed to sync cloud data: ${businessError.code}, ${businessError.message}`);
      listener({ status: '同步失败', finished: true, success: false });
      return false;
    }
  }

  private static cloudSyncState(details: relationalStore.ProgressDetails): CloudSyncState {
    const tableDetails = details.details[CLOUD_TABLE_NAME];
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
