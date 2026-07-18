export interface SteamGuardData {
  accountName: string;
  steamId: string;
  sharedSecret: string;
  identitySecret: string;
  deviceId: string;
  accessToken: string;
  refreshToken: string;
  revocationCode: string;
  serialNumber: string;
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

export function emptySteamGuardData(): SteamGuardData {
  return {
    accountName: '',
    steamId: '',
    sharedSecret: '',
    identitySecret: '',
    deviceId: '',
    accessToken: '',
    refreshToken: '',
    revocationCode: '',
    serialNumber: ''
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
      revocationCode: parsed.revocationCode || '',
      serialNumber: parsed.serialNumber || ''
    };
  } catch (error) {
    return emptySteamGuardData();
  }
}

export function canUseSteamRemoteFeatures(data: SteamGuardData): boolean {
  return data.steamId.length > 0 && data.sharedSecret.length > 0 &&
    (data.accessToken.length > 0 || data.refreshToken.length > 0);
}
