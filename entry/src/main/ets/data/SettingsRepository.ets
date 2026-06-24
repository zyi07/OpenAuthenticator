import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const SETTINGS_NAME = 'tool_2fa_settings';

interface Settings {
  cloudBackup: boolean;
  smartGrip: boolean;
  antiPeep: boolean;
  appLock: boolean;
  showNextToken: boolean;
  huaweiLoggedIn: boolean;
  huaweiNickname: string;
  huaweiAvatarUri: string;
  huaweiUserId: string;
  themeMode: string;
  themeColor: string;
  language: string;
  cloudSyncStatus: string;
  cloudLastSyncTime: number;
  onboardingCompleted: boolean;
}

const DEFAULTS: Settings = {
  cloudBackup: false,
  smartGrip: false,
  antiPeep: false,
  appLock: false,
  showNextToken: false,
  huaweiLoggedIn: false,
  huaweiNickname: '',
  huaweiAvatarUri: '',
  huaweiUserId: '',
  themeMode: '跟随系统',
  themeColor: '柠檬黄',
  language: '跟随系统',
  cloudSyncStatus: '尚未同步',
  cloudLastSyncTime: 0,
  onboardingCompleted: false
};

let prefs: preferences.Preferences | null = null;

async function getPrefs(context: common.UIAbilityContext): Promise<preferences.Preferences> {
  if (prefs) {
    return prefs;
  }
  prefs = await preferences.getPreferences(context, { name: SETTINGS_NAME });
  return prefs;
}

export class SettingsRepository {
  static async load(context: common.UIAbilityContext): Promise<Settings> {
    try {
      const store = await getPrefs(context);
      const json = await store.get('settings', '{}');
      const parsed: Record<string, Object> = typeof json === 'string' ? JSON.parse(json) : {};
      return {
        cloudBackup: parsed['cloudBackup'] as boolean ?? DEFAULTS.cloudBackup,
        smartGrip: parsed['smartGrip'] as boolean ?? DEFAULTS.smartGrip,
        antiPeep: parsed['antiPeep'] as boolean ?? DEFAULTS.antiPeep,
        appLock: parsed['appLock'] as boolean ?? DEFAULTS.appLock,
        showNextToken: parsed['showNextToken'] as boolean ?? DEFAULTS.showNextToken,
        huaweiLoggedIn: parsed['huaweiLoggedIn'] as boolean ?? DEFAULTS.huaweiLoggedIn,
        huaweiNickname: parsed['huaweiNickname'] as string ?? DEFAULTS.huaweiNickname,
        huaweiAvatarUri: parsed['huaweiAvatarUri'] as string ?? DEFAULTS.huaweiAvatarUri,
        huaweiUserId: parsed['huaweiUserId'] as string ?? DEFAULTS.huaweiUserId,
        themeMode: parsed['themeMode'] as string ?? DEFAULTS.themeMode,
        themeColor: parsed['themeColor'] as string ?? DEFAULTS.themeColor,
        language: parsed['language'] as string ?? DEFAULTS.language,
        cloudSyncStatus: parsed['cloudSyncStatus'] as string ?? DEFAULTS.cloudSyncStatus,
        cloudLastSyncTime: parsed['cloudLastSyncTime'] as number ?? DEFAULTS.cloudLastSyncTime,
        onboardingCompleted: parsed['onboardingCompleted'] as boolean ?? DEFAULTS.onboardingCompleted
      };
    } catch (error) {
      return DEFAULTS;
    }
  }

  static async save(context: common.UIAbilityContext, settings: Settings): Promise<void> {
    try {
      const store = await getPrefs(context);
      await store.put('settings', JSON.stringify(settings));
      await store.flush();
    } catch (error) {
      console.error(`Failed to save settings: ${JSON.stringify(error)}`);
    }
  }
}
