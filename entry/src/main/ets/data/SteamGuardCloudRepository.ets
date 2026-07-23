import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { cloudData, relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  createSdaMaFile,
  emptySteamGuardData,
  parseSteamGuardData,
  serializeSteamGuardData,
  SteamGuardData
} from '../model/SteamGuardData';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';
import { CloudStageResult, CloudSyncState, TokenRepository } from './TokenRepository';
import { STEAM_GUARD_CLOUD_TABLE_NAME } from './SteamGuardCloudSchema';

const STORE_NAME = 'tool_2fa_tokens.db';
const CLOUD_TABLE_NAME = STEAM_GUARD_CLOUD_TABLE_NAME;
const DATA_VERSION = 1;
const TOKEN_PART_BYTES = 700;
const TOKEN_PART_LIMIT = 3;
const CLOUD_SYNC_TIMEOUT_MS = 120000;

export interface SteamGuardCloudRecord {
  id: string;
  dataVersion: number;
  accountName: string;
  steamId: string;
  sharedSecret: string;
  identitySecret: string;
  deviceId: string;
  accessTokenPartCount: number;
  accessTokenPart1: string;
  accessTokenPart2: string;
  accessTokenPart3: string;
  refreshTokenPartCount: number;
  refreshTokenPart1: string;
  refreshTokenPart2: string;
  refreshTokenPart3: string;
  sessionId: string;
  revocationCode: string;
  serialNumber: string;
  uri: string;
  serverTime: number;
  tokenGid: string;
  secret1: string;
  status: number;
  fullyEnrolled: number;
  updatedAt: number;
}

let autoSyncProgress: ((details: relationalStore.ProgressDetails) => void) | null = null;
let cloudDataChange: ((accounts: Array<string>) => void) | null = null;
let configuredAutoSync: boolean | null = null;
let activeStore: relationalStore.RdbStore | null = null;
let lastFailureStatus = '';
let lastSyncNeedsMetadataRepair = false;

function businessErrorText(error: BusinessError): string {
  const code = error.code ? error.code.toString() : 'unknown';
  const message = error.message && error.message.length > 0 ? error.message : 'Unknown error';
  return code + ': ' + message;
}

async function getStore(context: common.Context): Promise<relationalStore.RdbStore> {
  const store = await TokenRepository.getSharedCloudStore(context);
  if (activeStore !== store) {
    activeStore = store;
    configuredAutoSync = null;
    autoSyncProgress = null;
    cloudDataChange = null;
  }
  return store;
}

async function resetCloudSyncMetadataAfterDelete(
  context: common.UIAbilityContext,
  reason: string
): Promise<boolean> {
  return await TokenRepository.repairCloudSyncMetadata(context, reason);
}

function needsMetadataRepair(
  mode: relationalStore.SyncMode,
  details: relationalStore.ProgressDetails
): boolean {
  if (mode !== relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST ||
    details.schedule !== relationalStore.Progress.SYNC_FINISH ||
    details.code !== relationalStore.ProgressCode.UNKNOWN_ERROR) {
    return false;
  }
  const tableDetails = details.details[CLOUD_TABLE_NAME];
  return !!tableDetails && tableDetails.upload.failed > 0 && tableDetails.download.failed === 0;
}

async function configureNetworkStrategy(): Promise<void> {
  try {
    await cloudData.setCloudStrategy(cloudData.StrategyType.NETWORK, [
      cloudData.NetWorkStrategy.WIFI,
      cloudData.NetWorkStrategy.CELLULAR
    ]);
  } catch (error) {
    console.error('Failed to configure Steam Guard cloud network strategy: ' + JSON.stringify(error));
  }
}

function emptyCloudRecord(): SteamGuardCloudRecord {
  return {
    id: '',
    dataVersion: DATA_VERSION,
    accountName: '',
    steamId: '',
    sharedSecret: '',
    identitySecret: '',
    deviceId: '',
    accessTokenPartCount: 0,
    accessTokenPart1: '',
    accessTokenPart2: '',
    accessTokenPart3: '',
    refreshTokenPartCount: 0,
    refreshTokenPart1: '',
    refreshTokenPart2: '',
    refreshTokenPart3: '',
    sessionId: '',
    revocationCode: '',
    serialNumber: '',
    uri: '',
    serverTime: 0,
    tokenGid: '',
    secret1: '',
    status: 0,
    fullyEnrolled: 0,
    updatedAt: 0
  };
}

function splitEncryptedValue(value: string): string[] {
  if (value.length === 0) {
    return [];
  }
  const parts: string[] = [];
  let current = '';
  for (let index = 0; index < value.length; index++) {
    const candidate = current + value.charAt(index);
    const candidateBytes = new util.TextEncoder().encodeInto(candidate).length;
    if (candidateBytes > TOKEN_PART_BYTES) {
      if (current.length === 0) {
        throw new Error('Steam 令牌包含无法分片的字符');
      }
      parts.push(current);
      current = value.charAt(index);
    } else {
      current = candidate;
    }
  }
  if (current.length > 0) {
    parts.push(current);
  }
  if (parts.length > TOKEN_PART_LIMIT) {
    throw new Error('Steam 会话令牌超过云端分片容量');
  }
  return parts;
}

function tokenPart(parts: string[], index: number): string {
  return index < parts.length ? parts[index] : '';
}

function joinTokenParts(count: number, first: string, second: string, third: string): string | null {
  if (count < 0 || count > TOKEN_PART_LIMIT) {
    return null;
  }
  if (count === 0) {
    return '';
  }
  const parts: string[] = [first, second, third];
  let value = '';
  for (let index = 0; index < count; index++) {
    if (parts[index].length === 0) {
      return null;
    }
    value += parts[index];
  }
  return value;
}

function cloudRecordFromToken(record: TokenRecord): SteamGuardCloudRecord | null {
  const token = sanitizeTokenRecord(record);
  if (token.type !== 'Steam' || !token.steamData || token.steamData.length === 0) {
    return null;
  }
  const data = parseSteamGuardData(token.steamData);
  if (data.sharedSecret.length === 0) {
    data.sharedSecret = token.secret;
  }
  if (data.sharedSecret.length === 0) {
    return null;
  }
  const accessTokenParts = splitEncryptedValue(data.accessToken);
  const refreshTokenParts = splitEncryptedValue(data.refreshToken);
  return {
    id: token.id,
    dataVersion: DATA_VERSION,
    accountName: data.accountName,
    steamId: data.steamId,
    sharedSecret: data.sharedSecret,
    identitySecret: data.identitySecret,
    deviceId: data.deviceId,
    accessTokenPartCount: accessTokenParts.length,
    accessTokenPart1: tokenPart(accessTokenParts, 0),
    accessTokenPart2: tokenPart(accessTokenParts, 1),
    accessTokenPart3: tokenPart(accessTokenParts, 2),
    refreshTokenPartCount: refreshTokenParts.length,
    refreshTokenPart1: tokenPart(refreshTokenParts, 0),
    refreshTokenPart2: tokenPart(refreshTokenParts, 1),
    refreshTokenPart3: tokenPart(refreshTokenParts, 2),
    sessionId: data.sessionId,
    revocationCode: data.revocationCode,
    serialNumber: data.serialNumber,
    uri: data.uri,
    serverTime: data.serverTime,
    tokenGid: data.tokenGid,
    secret1: data.secret1,
    status: data.status,
    fullyEnrolled: data.fullyEnrolled ? 1 : 0,
    updatedAt: token.modifiedTime || token.createdAt || Date.now()
  };
}

function steamDataFromCloudRecord(record: SteamGuardCloudRecord): SteamGuardData | null {
  if (record.dataVersion !== DATA_VERSION) {
    return null;
  }
  const accessToken = joinTokenParts(
    record.accessTokenPartCount,
    record.accessTokenPart1,
    record.accessTokenPart2,
    record.accessTokenPart3
  );
  const refreshToken = joinTokenParts(
    record.refreshTokenPartCount,
    record.refreshTokenPart1,
    record.refreshTokenPart2,
    record.refreshTokenPart3
  );
  if (accessToken === null || refreshToken === null) {
    return null;
  }
  const data = emptySteamGuardData();
  data.accountName = record.accountName;
  data.steamId = record.steamId;
  data.sharedSecret = record.sharedSecret;
  data.identitySecret = record.identitySecret;
  data.deviceId = record.deviceId;
  data.accessToken = accessToken;
  data.refreshToken = refreshToken;
  data.sessionId = record.sessionId;
  data.revocationCode = record.revocationCode;
  data.serialNumber = record.serialNumber;
  data.uri = record.uri;
  data.serverTime = record.serverTime;
  data.tokenGid = record.tokenGid;
  data.secret1 = record.secret1;
  data.status = record.status;
  data.fullyEnrolled = record.fullyEnrolled === 1;
  data.maFile = createSdaMaFile(data);
  return data;
}

function cloudRecordFromRow(resultSet: relationalStore.ResultSet): SteamGuardCloudRecord {
  const record = emptyCloudRecord();
  record.id = rowString(resultSet, 'id');
  record.dataVersion = rowLong(resultSet, 'dataVersion');
  record.accountName = rowString(resultSet, 'accountName');
  record.steamId = rowString(resultSet, 'steamId');
  record.sharedSecret = rowString(resultSet, 'sharedSecret');
  record.identitySecret = rowString(resultSet, 'identitySecret');
  record.deviceId = rowString(resultSet, 'deviceId');
  record.accessTokenPartCount = rowLong(resultSet, 'accessTokenPartCount');
  record.accessTokenPart1 = rowString(resultSet, 'accessTokenPart1');
  record.accessTokenPart2 = rowString(resultSet, 'accessTokenPart2');
  record.accessTokenPart3 = rowString(resultSet, 'accessTokenPart3');
  record.refreshTokenPartCount = rowLong(resultSet, 'refreshTokenPartCount');
  record.refreshTokenPart1 = rowString(resultSet, 'refreshTokenPart1');
  record.refreshTokenPart2 = rowString(resultSet, 'refreshTokenPart2');
  record.refreshTokenPart3 = rowString(resultSet, 'refreshTokenPart3');
  record.sessionId = rowString(resultSet, 'sessionId');
  record.revocationCode = rowString(resultSet, 'revocationCode');
  record.serialNumber = rowString(resultSet, 'serialNumber');
  record.uri = rowString(resultSet, 'uri');
  record.serverTime = rowDouble(resultSet, 'serverTime');
  record.tokenGid = rowString(resultSet, 'tokenGid');
  record.secret1 = rowString(resultSet, 'secret1');
  record.status = rowLong(resultSet, 'status');
  record.fullyEnrolled = rowLong(resultSet, 'fullyEnrolled');
  record.updatedAt = rowDouble(resultSet, 'updatedAt');
  return record;
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

function rowDouble(resultSet: relationalStore.ResultSet, column: string): number {
  try {
    const index = resultSet.getColumnIndex(column);
    if (index < 0 || resultSet.isColumnNull(index)) {
      return 0;
    }
    return resultSet.getDouble(index);
  } catch (error) {
    return 0;
  }
}

function cloudRecordToBucket(record: SteamGuardCloudRecord): relationalStore.ValuesBucket {
  const bucket: relationalStore.ValuesBucket = {};
  bucket['id'] = record.id;
  bucket['dataVersion'] = record.dataVersion;
  bucket['accountName'] = record.accountName.length > 0 ? record.accountName : null;
  bucket['steamId'] = record.steamId.length > 0 ? record.steamId : null;
  bucket['sharedSecret'] = record.sharedSecret.length > 0 ? record.sharedSecret : null;
  bucket['identitySecret'] = record.identitySecret.length > 0 ? record.identitySecret : null;
  bucket['deviceId'] = record.deviceId.length > 0 ? record.deviceId : null;
  bucket['accessTokenPartCount'] = record.accessTokenPartCount;
  bucket['accessTokenPart1'] = record.accessTokenPart1.length > 0 ? record.accessTokenPart1 : null;
  bucket['accessTokenPart2'] = record.accessTokenPart2.length > 0 ? record.accessTokenPart2 : null;
  bucket['accessTokenPart3'] = record.accessTokenPart3.length > 0 ? record.accessTokenPart3 : null;
  bucket['refreshTokenPartCount'] = record.refreshTokenPartCount;
  bucket['refreshTokenPart1'] = record.refreshTokenPart1.length > 0 ? record.refreshTokenPart1 : null;
  bucket['refreshTokenPart2'] = record.refreshTokenPart2.length > 0 ? record.refreshTokenPart2 : null;
  bucket['refreshTokenPart3'] = record.refreshTokenPart3.length > 0 ? record.refreshTokenPart3 : null;
  bucket['sessionId'] = record.sessionId.length > 0 ? record.sessionId : null;
  bucket['revocationCode'] = record.revocationCode.length > 0 ? record.revocationCode : null;
  bucket['serialNumber'] = record.serialNumber.length > 0 ? record.serialNumber : null;
  bucket['uri'] = record.uri.length > 0 ? record.uri : null;
  bucket['serverTime'] = record.serverTime;
  bucket['tokenGid'] = record.tokenGid.length > 0 ? record.tokenGid : null;
  bucket['secret1'] = record.secret1.length > 0 ? record.secret1 : null;
  bucket['status'] = record.status;
  bucket['fullyEnrolled'] = record.fullyEnrolled;
  bucket['updatedAt'] = record.updatedAt;
  return bucket;
}

function sameCloudRecord(first: SteamGuardCloudRecord, second: SteamGuardCloudRecord): boolean {
  return first.id === second.id &&
    first.dataVersion === second.dataVersion &&
    first.accountName === second.accountName &&
    first.steamId === second.steamId &&
    first.sharedSecret === second.sharedSecret &&
    first.identitySecret === second.identitySecret &&
    first.deviceId === second.deviceId &&
    first.accessTokenPartCount === second.accessTokenPartCount &&
    first.accessTokenPart1 === second.accessTokenPart1 &&
    first.accessTokenPart2 === second.accessTokenPart2 &&
    first.accessTokenPart3 === second.accessTokenPart3 &&
    first.refreshTokenPartCount === second.refreshTokenPartCount &&
    first.refreshTokenPart1 === second.refreshTokenPart1 &&
    first.refreshTokenPart2 === second.refreshTokenPart2 &&
    first.refreshTokenPart3 === second.refreshTokenPart3 &&
    first.sessionId === second.sessionId &&
    first.revocationCode === second.revocationCode &&
    first.serialNumber === second.serialNumber &&
    first.uri === second.uri &&
    first.serverTime === second.serverTime &&
    first.tokenGid === second.tokenGid &&
    first.secret1 === second.secret1 &&
    first.status === second.status &&
    first.fullyEnrolled === second.fullyEnrolled &&
    first.updatedAt === second.updatedAt;
}

async function readCloudRows(store: relationalStore.RdbStore): Promise<SteamGuardCloudRecord[]> {
  const records: SteamGuardCloudRecord[] = [];
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.querySql('SELECT * FROM ' + CLOUD_TABLE_NAME);
    while (resultSet.goToNextRow()) {
      records.push(cloudRecordFromRow(resultSet));
    }
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
  return records;
}

async function upsertCloudRows(store: relationalStore.RdbStore, tokens: TokenRecord[]): Promise<number> {
  const existingRecords = await readCloudRows(store);
  const existingMap = new Map<string, SteamGuardCloudRecord>();
  for (let index = 0; index < existingRecords.length; index++) {
    existingMap.set(existingRecords[index].id, existingRecords[index]);
  }
  let changed = 0;
  for (let index = 0; index < tokens.length; index++) {
    const record = cloudRecordFromToken(tokens[index]);
    if (!record) {
      continue;
    }
    const existing = existingMap.get(record.id);
    const bucket = cloudRecordToBucket(record);
    if (!existing) {
      await store.insert(CLOUD_TABLE_NAME, bucket);
      changed += 1;
    } else if (!sameCloudRecord(record, existing)) {
      const predicates = new relationalStore.RdbPredicates(CLOUD_TABLE_NAME).equalTo('id', record.id);
      const updated = await store.update(bucket, predicates);
      if (updated > 0) {
        changed += updated;
      } else {
        await store.insert(CLOUD_TABLE_NAME, bucket);
        changed += 1;
      }
    }
  }
  console.info('Staged Steam Guard cloud rows: changed=' + changed.toString());
  return changed;
}

async function cleanCloudDeletedData(store: relationalStore.RdbStore): Promise<boolean> {
  try {
    await store.cleanDirtyData(CLOUD_TABLE_NAME);
    return true;
  } catch (error) {
    console.error('Failed to clean Steam Guard cloud deleted data: ' + JSON.stringify(error));
    return false;
  }
}

async function hasCloudRecord(store: relationalStore.RdbStore, tokenId: string): Promise<boolean> {
  let resultSet: relationalStore.ResultSet | null = null;
  try {
    resultSet = await store.query(
      new relationalStore.RdbPredicates(CLOUD_TABLE_NAME).equalTo('id', tokenId),
      ['id']
    );
    return resultSet.goToFirstRow();
  } finally {
    if (resultSet) {
      resultSet.close();
    }
  }
}

export class SteamGuardCloudRepository {
  static async configureCloudSync(
    context: common.UIAbilityContext,
    enabled: boolean,
    listener?: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      console.info('Configure Steam Guard cloud sync: db=' + STORE_NAME + ', table=' + CLOUD_TABLE_NAME +
        ', autoSync=' + enabled.toString());
      const store = await getStore(context);
      await configureNetworkStrategy();
      if (configuredAutoSync !== enabled) {
        await store.setDistributedTables(
          [CLOUD_TABLE_NAME],
          relationalStore.DistributedType.DISTRIBUTED_CLOUD,
          { autoSync: enabled }
        );
        configuredAutoSync = enabled;
      }
      console.info('Steam Guard cloud table configured: table=' + CLOUD_TABLE_NAME +
        ', autoSync=' + enabled.toString());
      lastFailureStatus = '';
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
            if (details.details[CLOUD_TABLE_NAME]) {
              listener(SteamGuardCloudRepository.cloudSyncState(details));
            }
          };
          store.on('autoSyncProgress', autoSyncProgress);
          cloudDataChange = (): void => {
            listener({ status: 'Steam 云端数据已更新', finished: true, success: true });
          };
          store.on('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD, cloudDataChange);
        }
      }
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      lastFailureStatus = 'Steam 云表配置失败（' + businessErrorText(businessError) + '）';
      console.error('Failed to configure Steam Guard cloud sync: ' + businessErrorText(businessError));
      return false;
    }
  }

  static getLastFailureStatus(): string {
    return lastFailureStatus;
  }

  static async pushToCloud(
    context: common.UIAbilityContext,
    records: TokenRecord[],
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      if (!await SteamGuardCloudRepository.refreshCloudVersionBaseline(context, listener)) {
        return false;
      }
      if (!await cleanCloudDeletedData(store)) {
        listener({ status: 'Steam 云端状态清理失败', finished: true, success: false });
        return false;
      }
      await upsertCloudRows(store, records);
    } catch (error) {
      const businessError = error as BusinessError;
      lastFailureStatus = 'Steam 完整数据推送准备失败（' + businessErrorText(businessError) + '）';
      console.error('Failed to stage Steam Guard cloud records: ' + businessErrorText(businessError));
      listener({ status: lastFailureStatus, message: lastFailureStatus, finished: true, success: false });
      return false;
    }
    const initialSuccess = await SteamGuardCloudRepository.sync(
      context,
      relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST,
      (state: CloudSyncState): void => {
        if (state.finished && !state.success && lastSyncNeedsMetadataRepair) {
          listener({ status: '正在修复 Steam 云端同步状态', finished: false, success: false });
        } else {
          listener(state);
        }
      }
    );
    if (initialSuccess || !lastSyncNeedsMetadataRepair) {
      return initialSuccess;
    }
    listener({ status: '正在修复 Steam 云端同步状态', finished: false, success: false });
    if (!await TokenRepository.repairCloudSyncMetadata(context, 'steamGuardData native-first upload failed')) {
      listener({ status: 'Steam 云端同步状态修复失败', finished: true, success: false });
      return false;
    }
    if (!await SteamGuardCloudRepository.configureCloudSync(context, false)) {
      listener({ status: 'Steam 云表配置失败', finished: true, success: false });
      return false;
    }
    if (!await SteamGuardCloudRepository.refreshCloudVersionBaseline(context, listener)) {
      return false;
    }
    try {
      const repairedStore = await getStore(context);
      if (!await cleanCloudDeletedData(repairedStore)) {
        listener({ status: 'Steam 云端状态清理失败', finished: true, success: false });
        return false;
      }
      await upsertCloudRows(repairedStore, records);
    } catch (error) {
      console.error('Failed to restage Steam Guard records after metadata repair: ' + JSON.stringify(error));
      listener({ status: 'Steam 完整数据推送重试准备失败', finished: true, success: false });
      return false;
    }
    console.info('Retry Steam Guard cloud push after metadata repair');
    return await SteamGuardCloudRepository.sync(
      context,
      relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST,
      listener
    );
  }

  static async stageAutoPush(
    context: common.UIAbilityContext,
    records: TokenRecord[]
  ): Promise<CloudStageResult> {
    if (configuredAutoSync !== true) {
      return { success: false, changed: false };
    }
    try {
      const store = await getStore(context);
      const changed = await upsertCloudRows(store, records);
      return { success: true, changed: changed > 0 };
    } catch (error) {
      console.error('Failed to stage automatic Steam Guard cloud sync: ' + JSON.stringify(error));
      return { success: false, changed: false };
    }
  }

  static async pullFromCloud(
    context: common.UIAbilityContext,
    listener: (state: CloudSyncState) => void
  ): Promise<SteamGuardCloudRecord[] | null> {
    if (!await SteamGuardCloudRepository.sync(
      context,
      relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
      listener
    )) {
      return null;
    }
    return await SteamGuardCloudRepository.loadCloudRecords(context);
  }

  static async loadCloudRecords(context: common.Context): Promise<SteamGuardCloudRecord[]> {
    try {
      return await readCloudRows(await getStore(context));
    } catch (error) {
      console.error('Failed to load Steam Guard cloud mirror: ' + JSON.stringify(error));
      return [];
    }
  }

  static mergeIntoTokens(tokens: TokenRecord[], records: SteamGuardCloudRecord[]): TokenRecord[] {
    const recordMap = new Map<string, SteamGuardCloudRecord>();
    for (let index = 0; index < records.length; index++) {
      if (records[index].id.length > 0) {
        recordMap.set(records[index].id, records[index]);
      }
    }
    const merged: TokenRecord[] = [];
    for (let index = 0; index < tokens.length; index++) {
      const token = sanitizeTokenRecord(tokens[index]);
      const cloudRecord = recordMap.get(token.id);
      if (token.type !== 'Steam' || !cloudRecord) {
        merged.push(token);
        continue;
      }
      const data = steamDataFromCloudRecord(cloudRecord);
      if (!data) {
        console.error('Ignored invalid Steam Guard cloud record: id=' + token.id);
        merged.push(token);
        continue;
      }
      merged.push({
        id: token.id,
        name: token.name,
        remark: token.remark,
        type: token.type,
        algorithm: token.algorithm,
        secret: token.secret.length > 0 ? token.secret : data.sharedSecret,
        logoUri: token.logoUri,
        logoLightUri: token.logoLightUri,
        logoDarkUri: token.logoDarkUri,
        logoSource: token.logoSource,
        digits: token.digits,
        period: token.period,
        counter: token.counter,
        steamData: serializeSteamGuardData(data),
        createdAt: token.createdAt,
        modifiedTime: Math.max(token.modifiedTime || 0, cloudRecord.updatedAt)
      });
    }
    return merged;
  }

  static async deleteFromCloud(
    context: common.UIAbilityContext,
    tokenId: string,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    try {
      const store = await getStore(context);
      if (!await SteamGuardCloudRepository.refreshCloudVersionBaseline(context, listener)) {
        return false;
      }
      if (!await cleanCloudDeletedData(store)) {
        listener({ status: 'Steam 云端删除状态清理失败', finished: true, success: false });
        return false;
      }
      if (!await hasCloudRecord(store, tokenId)) {
        const resetSuccess = await resetCloudSyncMetadataAfterDelete(
          context,
          'steamGuardData delete target is already absent: ' + tokenId
        );
        listener({
          status: resetSuccess ? '同步成功（上传0条，下载0条）' : 'Steam 云端删除状态清理失败',
          finished: true,
          success: resetSuccess,
          uploadTotal: 0,
          uploadSuccess: 0,
          uploadFailed: 0,
          downloadTotal: 0,
          downloadSuccess: 0,
          downloadFailed: 0
        });
        if (!resetSuccess) {
          return false;
        }
        return true;
      }
      await store.delete(new relationalStore.RdbPredicates(CLOUD_TABLE_NAME).equalTo('id', tokenId));
      const success = await SteamGuardCloudRepository.sync(
        context,
        relationalStore.SyncMode.SYNC_MODE_NATIVE_FIRST,
        listener
      );
      if (success) {
        if (!await cleanCloudDeletedData(store)) {
          listener({ status: 'Steam 云端删除状态清理失败', finished: true, success: false });
          return false;
        }
        return true;
      }
      listener({ status: '正在确认 Steam 云端删除结果', finished: false, success: false });
      const verified = await SteamGuardCloudRepository.sync(
        context,
        relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
        (state: CloudSyncState): void => {
          if (!state.finished) {
            listener({ status: '正在确认 Steam 云端删除结果', finished: false, success: false });
          }
        }
      );
      if (verified && await cleanCloudDeletedData(store) && !await hasCloudRecord(store, tokenId) &&
        await resetCloudSyncMetadataAfterDelete(
          context,
          'steamGuardData delete verified absent after failed upload: ' + tokenId
        )) {
        listener({
          status: '同步成功（上传0条，下载0条）',
          finished: true,
          success: true,
          uploadTotal: 0,
          uploadSuccess: 0,
          uploadFailed: 0,
          downloadTotal: 0,
          downloadSuccess: 0,
          downloadFailed: 0
        });
        return true;
      }
      await resetCloudSyncMetadataAfterDelete(context, 'steamGuardData delete failed: ' + tokenId);
      listener({ status: 'Steam 完整数据删除失败', finished: true, success: false });
      return false;
    } catch (error) {
      console.error('Failed to delete Steam Guard cloud record: ' + JSON.stringify(error));
      listener({ status: 'Steam 完整数据删除失败', finished: true, success: false });
      return false;
    }
  }

  private static async refreshCloudVersionBaseline(
    context: common.UIAbilityContext,
    listener: (state: CloudSyncState) => void
  ): Promise<boolean> {
    listener({ status: '正在检查 Steam 云端版本', finished: false, success: false });
    return await SteamGuardCloudRepository.sync(
      context,
      relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
      (state: CloudSyncState): void => {
        if (!state.finished) {
          listener({ status: '正在检查 Steam 云端版本', finished: false, success: false });
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
    lastSyncNeedsMetadataRepair = false;
    try {
      const store = await getStore(context);
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
            listener({ status: 'Steam 完整数据同步超时', finished: true, success: false });
            finish(false);
          }
        }, CLOUD_SYNC_TIMEOUT_MS);
        const syncTask = store.cloudSync(
          mode,
          [CLOUD_TABLE_NAME],
          (details: relationalStore.ProgressDetails): void => {
            lastSyncNeedsMetadataRepair = needsMetadataRepair(mode, details);
            const state = SteamGuardCloudRepository.cloudSyncState(details);
            console.info('Steam Guard cloud sync progress: table=' + CLOUD_TABLE_NAME +
              ', schedule=' + details.schedule.toString() + ', code=' + details.code.toString());
            const tableDetails = details.details[CLOUD_TABLE_NAME];
            if (tableDetails) {
              console.info('Steam Guard cloud sync statistics: upload=' + JSON.stringify(tableDetails.upload) +
                ', download=' + JSON.stringify(tableDetails.download));
            }
            listener(state);
            if (state.finished) {
              finish(state.success);
            }
          }
        );
        syncTask.catch((error: BusinessError): void => {
          if (!settled) {
            lastFailureStatus = 'Steam 完整数据同步失败（' + businessErrorText(error) + '）';
            console.error('Steam Guard cloud sync failed: ' + businessErrorText(error));
            listener({
              status: lastFailureStatus,
              message: lastFailureStatus,
              finished: true,
              success: false
            });
            finish(false);
          }
        });
      });
    } catch (error) {
      console.error('Failed to sync Steam Guard cloud data: ' + JSON.stringify(error));
      listener({ status: 'Steam 完整数据同步失败', finished: true, success: false });
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
    const progressText = '（上传' + uploadSuccess.toString() + '/' + uploadTotal.toString() +
      '，下载' + downloadSuccess.toString() + '/' + downloadTotal.toString() + '）';
    const failedCount = uploadFailed + downloadFailed;
    const resultText = failedCount > 0 ?
      '（上传' + uploadSuccess.toString() + '条，下载' + downloadSuccess.toString() +
        '条，失败' + failedCount.toString() + '条）' :
      '（上传' + uploadSuccess.toString() + '条，下载' + downloadSuccess.toString() + '条）';
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
        status: 'Steam 完整数据同步失败（' + details.code.toString() + '）',
        message: 'Steam 完整数据云表返回错误码 ' + details.code.toString(),
        finished: true,
        success: false
      };
    }
    if (details.schedule === relationalStore.Progress.SYNC_BEGIN ||
      details.schedule === relationalStore.Progress.SYNC_IN_PROGRESS) {
      return {
        status: '同步中' + progressText,
        finished: false,
        success: false,
        uploadTotal: uploadTotal,
        uploadSuccess: uploadSuccess,
        uploadFailed: uploadFailed,
        downloadTotal: downloadTotal,
        downloadSuccess: downloadSuccess,
        downloadFailed: downloadFailed
      };
    }
    if (details.schedule === relationalStore.Progress.SYNC_FINISH) {
      const success = uploadFailed === 0 && downloadFailed === 0;
      return {
        status: success ? '同步成功' + resultText : '同步部分失败' + resultText,
        message: success ? '' : '部分数据同步失败' + resultText,
        finished: true,
        success: success,
        uploadTotal: uploadTotal,
        uploadSuccess: uploadSuccess,
        uploadFailed: uploadFailed,
        downloadTotal: downloadTotal,
        downloadSuccess: downloadSuccess,
        downloadFailed: downloadFailed
      };
    }
    return { status: 'Steam 完整数据同步状态未知', finished: true, success: false };
  }
}
