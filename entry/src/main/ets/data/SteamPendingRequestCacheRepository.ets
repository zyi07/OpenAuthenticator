import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { SteamConfirmation, SteamPendingLogin } from '../model/SteamGuardData';

const STEAM_PENDING_REQUEST_CACHE_VERSION: number = 1;
const STEAM_PENDING_REQUEST_CACHE_FILE: string = 'steam_pending_requests.json';

export interface SteamPendingConfirmationCacheRecord {
  tokenId: string;
  tokenName: string;
  confirmation: SteamConfirmation;
}

export interface SteamPendingLoginCacheRecord {
  tokenId: string;
  tokenName: string;
  pending: SteamPendingLogin;
}

export class SteamPendingRequestCache {
  version: number = STEAM_PENDING_REQUEST_CACHE_VERSION;
  updatedAt: number = 0;
  confirmations: SteamPendingConfirmationCacheRecord[] = [];
  pendingLogins: SteamPendingLoginCacheRecord[] = [];
}

export class SteamPendingRequestCacheRepository {
  static load(context: common.UIAbilityContext): SteamPendingRequestCache {
    const emptyCache = new SteamPendingRequestCache();
    try {
      const path = context.filesDir + '/' + STEAM_PENDING_REQUEST_CACHE_FILE;
      if (!fileIo.accessSync(path)) {
        return emptyCache;
      }
      const parsed: SteamPendingRequestCache = JSON.parse(fileIo.readTextSync(path));
      if (parsed.version !== STEAM_PENDING_REQUEST_CACHE_VERSION) {
        return emptyCache;
      }
      const cache = new SteamPendingRequestCache();
      cache.updatedAt = parsed.updatedAt || 0;
      cache.confirmations = Array.isArray(parsed.confirmations) ? parsed.confirmations.filter(
        (record: SteamPendingConfirmationCacheRecord): boolean => record.tokenId.length > 0 &&
          record.confirmation.id.length > 0
      ) : [];
      cache.pendingLogins = Array.isArray(parsed.pendingLogins) ? parsed.pendingLogins.filter(
        (record: SteamPendingLoginCacheRecord): boolean => record.tokenId.length > 0 &&
          record.pending.clientId.length > 0
      ) : [];
      return cache;
    } catch (error) {
      console.error('Failed to load Steam pending request cache: ' + JSON.stringify(error));
      return emptyCache;
    }
  }

  static save(context: common.UIAbilityContext, cache: SteamPendingRequestCache): void {
    try {
      cache.version = STEAM_PENDING_REQUEST_CACHE_VERSION;
      cache.updatedAt = Date.now();
      const path = context.filesDir + '/' + STEAM_PENDING_REQUEST_CACHE_FILE;
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, JSON.stringify(cache));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
      console.error('Failed to save Steam pending request cache: ' + JSON.stringify(error));
    }
  }
}
