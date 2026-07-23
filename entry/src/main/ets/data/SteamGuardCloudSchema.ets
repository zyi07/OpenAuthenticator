export const STEAM_GUARD_CLOUD_TABLE_NAME = 'steamGuardData';

export const SQL_CREATE_STEAM_GUARD_CLOUD_TABLE = 'CREATE TABLE IF NOT EXISTS ' +
  STEAM_GUARD_CLOUD_TABLE_NAME + ' (' +
  'id TEXT PRIMARY KEY,' +
  'dataVersion INTEGER,' +
  'accountName TEXT,' +
  'steamId TEXT,' +
  'sharedSecret TEXT,' +
  'identitySecret TEXT,' +
  'deviceId TEXT,' +
  'accessTokenPartCount INTEGER,' +
  'accessTokenPart1 TEXT,' +
  'accessTokenPart2 TEXT,' +
  'accessTokenPart3 TEXT,' +
  'refreshTokenPartCount INTEGER,' +
  'refreshTokenPart1 TEXT,' +
  'refreshTokenPart2 TEXT,' +
  'refreshTokenPart3 TEXT,' +
  'sessionId TEXT,' +
  'revocationCode TEXT,' +
  'serialNumber TEXT,' +
  'uri TEXT,' +
  'serverTime REAL,' +
  'tokenGid TEXT,' +
  'secret1 TEXT,' +
  'status INTEGER,' +
  'fullyEnrolled INTEGER,' +
  'updatedAt REAL)';

export const SQL_NORMALIZE_STEAM_GUARD_CLOUD_STRINGS = 'UPDATE ' + STEAM_GUARD_CLOUD_TABLE_NAME +
  ' SET ' +
  "accountName=NULLIF(accountName,'')," +
  "steamId=NULLIF(steamId,'')," +
  "sharedSecret=NULLIF(sharedSecret,'')," +
  "identitySecret=NULLIF(identitySecret,'')," +
  "deviceId=NULLIF(deviceId,'')," +
  "accessTokenPart1=NULLIF(accessTokenPart1,'')," +
  "accessTokenPart2=NULLIF(accessTokenPart2,'')," +
  "accessTokenPart3=NULLIF(accessTokenPart3,'')," +
  "refreshTokenPart1=NULLIF(refreshTokenPart1,'')," +
  "refreshTokenPart2=NULLIF(refreshTokenPart2,'')," +
  "refreshTokenPart3=NULLIF(refreshTokenPart3,'')," +
  "sessionId=NULLIF(sessionId,'')," +
  "revocationCode=NULLIF(revocationCode,'')," +
  "serialNumber=NULLIF(serialNumber,'')," +
  "uri=NULLIF(uri,'')," +
  "tokenGid=NULLIF(tokenGid,'')," +
  "secret1=NULLIF(secret1,'') WHERE " +
  "accountName='' OR steamId='' OR sharedSecret='' OR identitySecret='' OR deviceId='' OR " +
  "accessTokenPart1='' OR accessTokenPart2='' OR accessTokenPart3='' OR " +
  "refreshTokenPart1='' OR refreshTokenPart2='' OR refreshTokenPart3='' OR " +
  "sessionId='' OR revocationCode='' OR serialNumber='' OR uri='' OR tokenGid='' OR secret1=''";
