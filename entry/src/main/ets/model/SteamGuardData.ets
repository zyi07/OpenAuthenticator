interface SdaSessionData {
  SteamID?: number | string;
  AccessToken?: string;
  RefreshToken?: string;
  SessionID?: string;
}

interface SdaMaFileData {
  shared_secret?: string;
  serial_number?: string;
  revocation_code?: string;
  uri?: string;
  server_time?: number;
  account_name?: string;
  token_gid?: string;
  identity_secret?: string;
  secret_1?: string;
  status?: number;
  device_id?: string;
  fully_enrolled?: boolean;
  Session?: SdaSessionData;
}

export interface SteamGuardData {
  accountName: string;
  steamId: string;
  sharedSecret: string;
  identitySecret: string;
  deviceId: string;
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  revocationCode: string;
  serialNumber: string;
  uri: string;
  serverTime: number;
  tokenGid: string;
  secret1: string;
  status: number;
  fullyEnrolled: boolean;
  maFile: string;
}

export interface SteamConfirmation {
  type: number;
  type_name: string;
  id: string;
  creator_id: string;
  nonce: string;
  creation_time: number;
  headline: string;
  summary: string[];
  icon?: string;
}

export interface SteamPendingLogin {
  clientId: string;
  version: number;
  ip: string;
  location: string;
  deviceName: string;
  creationTime: number;
}

export interface SteamProfile {
  displayName: string;
  avatarUrl: string;
}

export interface SteamInventoryGame {
  appId: number;
  contextId: string;
  name: string;
  contextName: string;
  iconUrl: string;
  itemCount: number;
}

export interface SteamInventoryItem {
  appId: number;
  contextId: string;
  assetId: string;
  classId: string;
  instanceId: string;
  amount: number;
  marketHashName: string;
  name: string;
  type: string;
  iconUrl: string;
  marketable: boolean;
  tradable: boolean;
  marketFee: number;
}

export interface SteamMarketPricePoint {
  label: string;
  price: number;
  volume: number;
}

export interface SteamMarketPriceHistory {
  prefix: string;
  suffix: string;
  points: SteamMarketPricePoint[];
}

export interface SteamMarketSellResult {
  requiresConfirmation: boolean;
  mobileConfirmation: boolean;
  emailConfirmation: boolean;
}

export interface SteamMarketListing {
  listingId: string;
  appId: number;
  contextId: string;
  assetId: string;
  name: string;
  type: string;
  iconUrl: string;
  priceText: string;
  listedDateText: string;
}

export interface SteamMarketListingPage {
  items: SteamMarketListing[];
  nextStart: number;
  hasMore: boolean;
  totalCount: number;
}

export interface SteamMarketSaleHistoryItem {
  id: string;
  name: string;
  type: string;
  iconUrl: string;
  priceText: string;
  dateText: string;
}

export interface SteamMarketSaleHistoryPage {
  items: SteamMarketSaleHistoryItem[];
  nextStart: number;
  hasMore: boolean;
  totalCount: number;
}

export interface SteamInventoryOverview {
  games: SteamInventoryGame[];
}

export interface SteamInventoryPage {
  items: SteamInventoryItem[];
  lastAssetId: string;
  hasMore: boolean;
  totalCount: number;
}

export interface SteamConfirmationHistoryRecord {
  id: string;
  tokenId: string;
  steamId: string;
  requestId: string;
  requestType: string;
  headline: string;
  summary: string;
  iconUrl: string;
  creationTime: number;
  handledTime: number;
  allowed: boolean;
}

export function emptySteamGuardData(): SteamGuardData {
  return {
    accountName: '',
    steamId: '',
    sharedSecret: '',
    identitySecret: '',
    deviceId: '',
    accessToken: '',
    refreshToken: '',
    sessionId: '',
    revocationCode: '',
    serialNumber: '',
    uri: '',
    serverTime: 0,
    tokenGid: '',
    secret1: '',
    status: 0,
    fullyEnrolled: false,
    maFile: ''
  };
}

export function parseSteamGuardData(value: string): SteamGuardData {
  if (value.trim().length === 0) {
    return emptySteamGuardData();
  }
  try {
    const parsed: SteamGuardData = JSON.parse(value);
    return {
      accountName: parsed.accountName || '',
      steamId: parsed.steamId || '',
      sharedSecret: parsed.sharedSecret || '',
      identitySecret: parsed.identitySecret || '',
      deviceId: parsed.deviceId || '',
      accessToken: parsed.accessToken || '',
      refreshToken: parsed.refreshToken || '',
      sessionId: parsed.sessionId || '',
      revocationCode: parsed.revocationCode || '',
      serialNumber: parsed.serialNumber || '',
      uri: parsed.uri || '',
      serverTime: parsed.serverTime || 0,
      tokenGid: parsed.tokenGid || '',
      secret1: parsed.secret1 || '',
      status: parsed.status || 0,
      fullyEnrolled: parsed.fullyEnrolled || false,
      maFile: parsed.maFile || ''
    };
  } catch (error) {
    return emptySteamGuardData();
  }
}

export function parseSdaMaFile(value: string): SteamGuardData {
  const trimmed = value.trim();
  if (trimmed.length === 0 || !trimmed.startsWith('{')) {
    return emptySteamGuardData();
  }
  try {
    const parsed: SdaMaFileData = JSON.parse(trimmed);
    if (!parsed.shared_secret || parsed.shared_secret.length === 0) {
      return emptySteamGuardData();
    }
    const session = parsed.Session;
    const extractedSteamId = extractJsonInteger(trimmed, 'SteamID');
    return {
      accountName: parsed.account_name || '',
      steamId: extractedSteamId || sessionSteamId(session),
      sharedSecret: parsed.shared_secret,
      identitySecret: parsed.identity_secret || '',
      deviceId: parsed.device_id || '',
      accessToken: session && session.AccessToken ? session.AccessToken : '',
      refreshToken: session && session.RefreshToken ? session.RefreshToken : '',
      sessionId: session && session.SessionID ? session.SessionID : '',
      revocationCode: parsed.revocation_code || '',
      serialNumber: parsed.serial_number || '',
      uri: parsed.uri || '',
      serverTime: parsed.server_time || 0,
      tokenGid: parsed.token_gid || '',
      secret1: parsed.secret_1 || '',
      status: parsed.status || 0,
      fullyEnrolled: parsed.fully_enrolled || false,
      maFile: trimmed
    };
  } catch (error) {
    return emptySteamGuardData();
  }
}

export function serializeSteamGuardData(data: SteamGuardData): string {
  return JSON.stringify(data);
}

export function createSdaMaFile(data: SteamGuardData): string {
  const steamIdValue = /^\d+$/.test(data.steamId) ? data.steamId : jsonString(data.steamId);
  return '{' +
    '"shared_secret":' + jsonString(data.sharedSecret) + ',' +
    '"serial_number":' + jsonString(data.serialNumber) + ',' +
    '"revocation_code":' + jsonString(data.revocationCode) + ',' +
    '"uri":' + jsonString(data.uri) + ',' +
    '"server_time":' + Math.max(0, Math.floor(data.serverTime)).toString() + ',' +
    '"account_name":' + jsonString(data.accountName) + ',' +
    '"token_gid":' + jsonString(data.tokenGid) + ',' +
    '"identity_secret":' + jsonString(data.identitySecret) + ',' +
    '"secret_1":' + jsonString(data.secret1) + ',' +
    '"status":' + Math.floor(data.status).toString() + ',' +
    '"device_id":' + jsonString(data.deviceId) + ',' +
    '"fully_enrolled":' + (data.fullyEnrolled ? 'true' : 'false') + ',' +
    '"Session":{' +
    '"SteamID":' + steamIdValue + ',' +
    '"AccessToken":' + jsonString(data.accessToken) + ',' +
    '"RefreshToken":' + jsonString(data.refreshToken) + ',' +
    '"SessionID":' + jsonString(data.sessionId) +
    '}}';
}

export function canUseSteamRemoteFeatures(data: SteamGuardData): boolean {
  return data.steamId.length > 0 && data.sharedSecret.length > 0 &&
    (data.accessToken.length > 0 || data.refreshToken.length > 0);
}

function sessionSteamId(session?: SdaSessionData): string {
  if (!session || session.SteamID === undefined || session.SteamID === null) {
    return '';
  }
  return session.SteamID.toString();
}

function extractJsonInteger(value: string, key: string): string {
  const expression = new RegExp('"' + key + '"\\s*:\\s*"?(\\d+)"?', 'i');
  const match = expression.exec(value);
  return match && match.length > 1 ? match[1] : '';
}

function jsonString(value: string): string {
  return JSON.stringify(value || '');
}
