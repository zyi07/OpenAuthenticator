import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { SteamInventoryGame, SteamInventoryItem } from '../model/SteamGuardData';

const STEAM_INVENTORY_CACHE_VERSION: number = 1;

export class SteamInventoryCategoryCache {
  gameKey: string = '';
  items: SteamInventoryItem[] = [];
  lastAssetId: string = '';
  hasMore: boolean = false;
  totalCount: number = 0;
  updatedAt: number = 0;
}

export class SteamInventoryCache {
  version: number = STEAM_INVENTORY_CACHE_VERSION;
  tokenId: string = '';
  updatedAt: number = 0;
  selectedGameKey: string = '';
  games: SteamInventoryGame[] = [];
  categories: SteamInventoryCategoryCache[] = [];
}

export class SteamInventoryCacheRepository {
  static load(context: common.UIAbilityContext, tokenId: string): SteamInventoryCache {
    const emptyCache = SteamInventoryCacheRepository.emptyCache(tokenId);
    try {
      const path = SteamInventoryCacheRepository.cachePath(context, tokenId);
      if (!fileIo.accessSync(path)) {
        return emptyCache;
      }
      const parsed: SteamInventoryCache = JSON.parse(fileIo.readTextSync(path));
      if (parsed.version !== STEAM_INVENTORY_CACHE_VERSION || parsed.tokenId !== tokenId) {
        return emptyCache;
      }
      const cache = SteamInventoryCacheRepository.emptyCache(tokenId);
      cache.updatedAt = parsed.updatedAt || 0;
      cache.selectedGameKey = parsed.selectedGameKey || '';
      cache.games = Array.isArray(parsed.games) ? parsed.games : [];
      cache.categories = Array.isArray(parsed.categories) ? parsed.categories.filter(
        (category: SteamInventoryCategoryCache): boolean => category.gameKey.length > 0 &&
          Array.isArray(category.items)
      ) : [];
      return cache;
    } catch (error) {
      console.error('Failed to load Steam inventory cache: ' + JSON.stringify(error));
      return emptyCache;
    }
  }

  static save(context: common.UIAbilityContext, cache: SteamInventoryCache): void {
    try {
      cache.version = STEAM_INVENTORY_CACHE_VERSION;
      cache.updatedAt = Date.now();
      const path = SteamInventoryCacheRepository.cachePath(context, cache.tokenId);
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, JSON.stringify(cache));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
      console.error('Failed to save Steam inventory cache: ' + JSON.stringify(error));
    }
  }

  private static emptyCache(tokenId: string): SteamInventoryCache {
    const cache = new SteamInventoryCache();
    cache.tokenId = tokenId;
    return cache;
  }

  private static cachePath(context: common.UIAbilityContext, tokenId: string): string {
    return context.filesDir + '/steam_inventory_' + SteamInventoryCacheRepository.safeFilePart(tokenId) + '.json';
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
