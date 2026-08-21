import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { SteamProfile } from '../model/SteamGuardData';

const STEAM_PROFILE_SETTINGS_NAME: string = 'tool_2fa_steam_profiles';
const STEAM_PROFILE_KEY: string = 'profiles';
const STEAM_AVATAR_MAX_BYTES: number = 5 * 1024 * 1024;

class SteamProfileCacheRecord {
  tokenId: string = '';
  displayName: string = '';
  avatarRemoteUrl: string = '';
  avatarPath: string = '';
}

let steamProfilePrefs: preferences.Preferences | undefined = undefined;

async function getSteamProfilePrefs(context: common.UIAbilityContext): Promise<preferences.Preferences> {
  if (steamProfilePrefs !== undefined) {
    return steamProfilePrefs;
  }
  steamProfilePrefs = await preferences.getPreferences(context, { name: STEAM_PROFILE_SETTINGS_NAME });
  return steamProfilePrefs;
}

export class SteamProfileRepository {
  static async load(context: common.UIAbilityContext, tokenId: string): Promise<SteamProfile> {
    const records = await SteamProfileRepository.loadRecords(context);
    const record = records.find((item: SteamProfileCacheRecord): boolean => item.tokenId === tokenId);
    if (record === undefined) {
      return { displayName: '', avatarUrl: '' };
    }
    return SteamProfileRepository.profileFromRecord(record);
  }

  static async save(
    context: common.UIAbilityContext,
    tokenId: string,
    profile: SteamProfile
  ): Promise<SteamProfile> {
    const records = await SteamProfileRepository.loadRecords(context);
    let record = records.find((item: SteamProfileCacheRecord): boolean => item.tokenId === tokenId);
    if (record === undefined) {
      record = new SteamProfileCacheRecord();
      record.tokenId = tokenId;
      records.push(record);
    }
    const currentPath = record.avatarPath;
    const hasCachedAvatar = SteamProfileRepository.isCachedFile(currentPath);
    const canReuseAvatar = profile.avatarUrl.length > 0 && profile.avatarUrl === record.avatarRemoteUrl &&
      hasCachedAvatar;
    let nextPath = hasCachedAvatar ? currentPath : '';
    if (!canReuseAvatar && SteamProfileRepository.isRemoteUrl(profile.avatarUrl)) {
      try {
        nextPath = await SteamProfileRepository.downloadAvatar(context, tokenId, profile.avatarUrl);
      } catch (error) {
        nextPath = SteamProfileRepository.isCachedFile(currentPath) ? currentPath : '';
        console.error('Failed to cache Steam avatar: ' + JSON.stringify(error));
      }
    }
    record.displayName = profile.displayName.length > 0 ? profile.displayName : record.displayName;
    record.avatarRemoteUrl = profile.avatarUrl.length > 0 ? profile.avatarUrl : record.avatarRemoteUrl;
    record.avatarPath = nextPath;
    await SteamProfileRepository.saveRecords(context, records);
    return SteamProfileRepository.profileFromRecord(record);
  }

  private static async loadRecords(context: common.UIAbilityContext): Promise<SteamProfileCacheRecord[]> {
    try {
      const store = await getSteamProfilePrefs(context);
      const value = store.getSync(STEAM_PROFILE_KEY, '[]');
      if (typeof value !== 'string') {
        return [];
      }
      const parsed: SteamProfileCacheRecord[] = JSON.parse(value);
      return parsed.filter((record: SteamProfileCacheRecord): boolean => record.tokenId.length > 0);
    } catch (error) {
      console.error('Failed to load Steam profiles: ' + JSON.stringify(error));
      return [];
    }
  }

  private static async saveRecords(
    context: common.UIAbilityContext,
    records: SteamProfileCacheRecord[]
  ): Promise<void> {
    const store = await getSteamProfilePrefs(context);
    await store.put(STEAM_PROFILE_KEY, JSON.stringify(records));
    await store.flush();
  }

  private static profileFromRecord(record: SteamProfileCacheRecord): SteamProfile {
    let avatarUrl = record.avatarRemoteUrl;
    if (SteamProfileRepository.isCachedFile(record.avatarPath)) {
      avatarUrl = fileUri.getUriFromPath(record.avatarPath);
    }
    return {
      displayName: record.displayName,
      avatarUrl: avatarUrl
    };
  }

  private static async downloadAvatar(
    context: common.UIAbilityContext,
    tokenId: string,
    remoteUrl: string
  ): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(remoteUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode < 200 || response.responseCode >= 300 ||
        !(response.result instanceof ArrayBuffer)) {
        throw new Error('Steam avatar request failed');
      }
      if (response.result.byteLength <= 0 || response.result.byteLength > STEAM_AVATAR_MAX_BYTES) {
        throw new Error('Steam avatar size is invalid');
      }
      const path = context.filesDir + '/steam_avatar_' + SteamProfileRepository.safeFilePart(tokenId) + '.img';
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, response.result);
      } finally {
        fileIo.closeSync(file);
      }
      return path;
    } finally {
      client.destroy();
    }
  }

  private static isRemoteUrl(value: string): boolean {
    return value.startsWith('https://') || value.startsWith('http://');
  }

  private static isCachedFile(path: string): boolean {
    try {
      return path.length > 0 && fileIo.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private static safeFilePart(value: string): string {
    let result = '';
    let hash = 0;
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index);
      const isNumber = code >= 48 && code <= 57;
      const isUpper = code >= 65 && code <= 90;
      const isLower = code >= 97 && code <= 122;
      result += isNumber || isUpper || isLower ? value[index] : '_';
      hash = (hash * 31 + code) >>> 0;
    }
    const prefix = result.length > 48 ? result.substring(0, 48) : result;
    return prefix + '_' + hash.toString(16);
  }
}
