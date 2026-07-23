import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const SETTINGS_NAME = 'tool_2fa_settings';
const BACKGROUND_SETTINGS_VERSION = 2;

interface Settings {
  cloudBackup: boolean;
  smartGrip: boolean;
  antiPeep: boolean;
  appLock: boolean;
  showNextToken: boolean;
  issuerLogoColorMode: string;
  tokenLayoutMode: string;
  huaweiLoggedIn: boolean;
  huaweiNickname: string;
  huaweiAvatarUri: string;
  huaweiUserId: string;
  themeMode: string;
  themeColor: string;
  materialType: string;
  materialLevel: string;
  globalImmersionEnabled: boolean;
  backgroundSelection: string;
  customBackgroundUri: string;
  backgroundBlurPercent: number;
  globalBackgroundEnabled: boolean;
  updateNoticeVersion: string;
  language: string;
  cloudSyncStatus: string;
  steamCloudSyncStatus: string;
  cloudLastSyncTime: number;
  onboardingCompleted: boolean;
  watchSelectedTokenIds: string[];
  watchPushStatus: string;
  watchLastPushTime: number;
  steamEnhancedAccess: boolean;
  steamGatewayUrl: string;
  steamGatewayToken: string;
}

const DEFAULTS: Settings = {
  cloudBackup: false,
  smartGrip: false,
  antiPeep: false,
  appLock: false,
  showNextToken: false,
  issuerLogoColorMode: '纯色',
  tokenLayoutMode: 'single',
  huaweiLoggedIn: false,
  huaweiNickname: '',
  huaweiAvatarUri: '',
  huaweiUserId: '',
  themeMode: '跟随系统',
  themeColor: '灰豆沙粉',
  materialType: '自适应',
  materialLevel: '自适应',
  globalImmersionEnabled: false,
  backgroundSelection: 'none',
  customBackgroundUri: '',
  backgroundBlurPercent: 0,
  globalBackgroundEnabled: true,
  updateNoticeVersion: '',
  language: '跟随系统',
  cloudSyncStatus: '尚未同步',
  steamCloudSyncStatus: '尚未同步',
  cloudLastSyncTime: 0,
  onboardingCompleted: false,
  watchSelectedTokenIds: [],
  watchPushStatus: '尚未同步',
  watchLastPushTime: 0,
  steamEnhancedAccess: false,
  steamGatewayUrl: '',
  steamGatewayToken: ''
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
      const globalImmersionValue = await store.get('globalImmersionEnabled', DEFAULTS.globalImmersionEnabled);
      const backgroundSelectionValue = await store.get('backgroundSelection', DEFAULTS.backgroundSelection);
      const backgroundSettingsVersionValue = await store.get('backgroundSettingsVersion', 0);
      const customBackgroundUriValue = await store.get('customBackgroundUri', DEFAULTS.customBackgroundUri);
      const backgroundBlurValue = await store.get('backgroundBlurPercent', DEFAULTS.backgroundBlurPercent);
      const globalBackgroundValue = await store.get('globalBackgroundEnabled', DEFAULTS.globalBackgroundEnabled);
      const updateNoticeVersionValue = await store.get('updateNoticeVersion', DEFAULTS.updateNoticeVersion);
      return {
        cloudBackup: parsed['cloudBackup'] as boolean ?? DEFAULTS.cloudBackup,
        smartGrip: parsed['smartGrip'] as boolean ?? DEFAULTS.smartGrip,
        antiPeep: parsed['antiPeep'] as boolean ?? DEFAULTS.antiPeep,
        appLock: parsed['appLock'] as boolean ?? DEFAULTS.appLock,
        showNextToken: parsed['showNextToken'] as boolean ?? DEFAULTS.showNextToken,
        issuerLogoColorMode: parsed['issuerLogoColorMode'] as string ?? DEFAULTS.issuerLogoColorMode,
        tokenLayoutMode: parsed['tokenLayoutMode'] as string ?? DEFAULTS.tokenLayoutMode,
        huaweiLoggedIn: parsed['huaweiLoggedIn'] as boolean ?? DEFAULTS.huaweiLoggedIn,
        huaweiNickname: parsed['huaweiNickname'] as string ?? DEFAULTS.huaweiNickname,
        huaweiAvatarUri: parsed['huaweiAvatarUri'] as string ?? DEFAULTS.huaweiAvatarUri,
        huaweiUserId: parsed['huaweiUserId'] as string ?? DEFAULTS.huaweiUserId,
        themeMode: parsed['themeMode'] as string ?? DEFAULTS.themeMode,
        themeColor: parsed['themeColor'] as string ?? DEFAULTS.themeColor,
        materialType: parsed['materialType'] as string ?? DEFAULTS.materialType,
        materialLevel: parsed['materialLevel'] as string ?? DEFAULTS.materialLevel,
        globalImmersionEnabled: typeof globalImmersionValue === 'boolean' ? globalImmersionValue :
          DEFAULTS.globalImmersionEnabled,
        backgroundSelection: typeof backgroundSettingsVersionValue === 'number' &&
          backgroundSettingsVersionValue >= BACKGROUND_SETTINGS_VERSION &&
          typeof backgroundSelectionValue === 'string' ? backgroundSelectionValue : DEFAULTS.backgroundSelection,
        customBackgroundUri: typeof customBackgroundUriValue === 'string' ? customBackgroundUriValue :
          DEFAULTS.customBackgroundUri,
        backgroundBlurPercent: typeof backgroundBlurValue === 'number' ? backgroundBlurValue :
          DEFAULTS.backgroundBlurPercent,
        globalBackgroundEnabled: typeof globalBackgroundValue === 'boolean' ? globalBackgroundValue :
          DEFAULTS.globalBackgroundEnabled,
        updateNoticeVersion: typeof updateNoticeVersionValue === 'string' ? updateNoticeVersionValue :
          DEFAULTS.updateNoticeVersion,
        language: parsed['language'] as string ?? DEFAULTS.language,
        cloudSyncStatus: parsed['cloudSyncStatus'] as string ?? DEFAULTS.cloudSyncStatus,
        steamCloudSyncStatus: parsed['steamCloudSyncStatus'] as string ?? DEFAULTS.steamCloudSyncStatus,
        cloudLastSyncTime: parsed['cloudLastSyncTime'] as number ?? DEFAULTS.cloudLastSyncTime,
        onboardingCompleted: parsed['onboardingCompleted'] as boolean ?? DEFAULTS.onboardingCompleted,
        watchSelectedTokenIds: (parsed['watchSelectedTokenIds'] as string[]) ?? DEFAULTS.watchSelectedTokenIds,
        watchPushStatus: parsed['watchPushStatus'] as string ?? DEFAULTS.watchPushStatus,
        watchLastPushTime: parsed['watchLastPushTime'] as number ?? DEFAULTS.watchLastPushTime,
        steamEnhancedAccess: parsed['steamEnhancedAccess'] as boolean ?? DEFAULTS.steamEnhancedAccess,
        steamGatewayUrl: parsed['steamGatewayUrl'] as string ?? DEFAULTS.steamGatewayUrl,
        steamGatewayToken: parsed['steamGatewayToken'] as string ?? DEFAULTS.steamGatewayToken
      };
    } catch (error) {
      return DEFAULTS;
    }
  }

  static async save(context: common.UIAbilityContext, settings: Settings): Promise<void> {
    try {
      const store = await getPrefs(context);
      await store.put('settings', JSON.stringify(settings));
      await store.put('globalImmersionEnabled', settings.globalImmersionEnabled);
      await store.put('backgroundSelection', settings.backgroundSelection);
      await store.put('backgroundSettingsVersion', BACKGROUND_SETTINGS_VERSION);
      await store.put('customBackgroundUri', settings.customBackgroundUri);
      await store.put('backgroundBlurPercent', settings.backgroundBlurPercent);
      await store.put('globalBackgroundEnabled', settings.globalBackgroundEnabled);
      await store.put('updateNoticeVersion', settings.updateNoticeVersion);
      await store.flush();
    } catch (error) {
      console.error(`Failed to save settings: ${JSON.stringify(error)}`);
    }
  }
}
