import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SteamConfirmationHistoryRecord } from '../model/SteamGuardData';

const STEAM_HISTORY_SETTINGS_NAME: string = 'tool_2fa_steam_confirmation_history';
const STEAM_HISTORY_KEY: string = 'records';
const STEAM_HISTORY_MAX_COUNT: number = 200;
const STEAM_HISTORY_RETENTION_MS: number = 30 * 24 * 60 * 60 * 1000;

let steamHistoryPrefs: preferences.Preferences | undefined = undefined;

async function getSteamHistoryPrefs(context: common.UIAbilityContext): Promise<preferences.Preferences> {
  if (steamHistoryPrefs !== undefined) {
    return steamHistoryPrefs;
  }
  steamHistoryPrefs = await preferences.getPreferences(context, { name: STEAM_HISTORY_SETTINGS_NAME });
  return steamHistoryPrefs;
}

export class SteamConfirmationHistoryRepository {
  static async load(context: common.UIAbilityContext): Promise<SteamConfirmationHistoryRecord[]> {
    try {
      const store = await getSteamHistoryPrefs(context);
      const value = store.getSync(STEAM_HISTORY_KEY, '[]');
      if (typeof value !== 'string') {
        return [];
      }
      const parsed: SteamConfirmationHistoryRecord[] = JSON.parse(value);
      const oldestTime = Date.now() - STEAM_HISTORY_RETENTION_MS;
      return parsed.filter((record: SteamConfirmationHistoryRecord): boolean => {
        return record.id.length > 0 && record.handledTime >= oldestTime;
      }).slice(0, STEAM_HISTORY_MAX_COUNT);
    } catch (error) {
      console.error('Failed to load Steam confirmation history: ' + JSON.stringify(error));
      return [];
    }
  }

  static async save(
    context: common.UIAbilityContext,
    records: SteamConfirmationHistoryRecord[]
  ): Promise<void> {
    const store = await getSteamHistoryPrefs(context);
    const oldestTime = Date.now() - STEAM_HISTORY_RETENTION_MS;
    const retained = records.filter((record: SteamConfirmationHistoryRecord): boolean => {
      return record.handledTime >= oldestTime;
    }).slice(0, STEAM_HISTORY_MAX_COUNT);
    await store.put(STEAM_HISTORY_KEY, JSON.stringify(retained));
    await store.flush();
  }
}
