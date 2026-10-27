import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const SETTINGS_NAME = 'tool_2fa_settings';
const BACKGROUND_SETTINGS_VERSION = 2;
const WATCH_PRIVACY_ACCEPTED_KEY = 'watchPrivacyAccepted';
const TOKEN_CREATION_COMMENT_PROMPTED_KEY = 'tokenCreationCommentPrompted';

export interface Settings {
  cloudBackup: boolean;
  smartGrip: boolean;
  antiPeep: boolean;
  appLock: boolean;
  showNextToken: boolean;
  showSteamFeaturePage: boolean;
  launchHomePage: string;
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
  backgroundBrightnessPercent: number;
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
  selectedSteamTokenId: string;
}

const DEFAULTS: Settings = {
  cloudBackup: false,
  smartGrip: false,
  antiPeep: false,
  appLock: false,
  showNextToken: false,
  showSteamFeaturePage: true,
  launchHomePage: '令牌',
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
  backgroundBrightnessPercent: 50,
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
  steamGatewayToken: '',
  selectedSteamTokenId: ''
};

let prefs: preferences.Preferences | null = null;
let pendingSaveSettings: Settings | undefined = undefined;
let settingsSavePromise: Promise<void> | undefined = undefined;

async function getPrefs(context: common.UIAbilityContext): Promise<preferences.Preferences> {
  if (prefs) {
    return prefs;
  }
  prefs = await preferences.getPreferences(context, { name: SETTINGS_NAME });
  return prefs;
}

export class SettingsRepository {
  static async claimTokenCreationCommentPrompt(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await getPrefs(context);
      const prompted = store.getSync(TOKEN_CREATION_COMMENT_PROMPTED_KEY, false);
      if (typeof prompted === 'boolean' && prompted) {
        return false;
      }
      await store.put(TOKEN_CREATION_COMMENT_PROMPTED_KEY, true);
      await store.flush();
      return true;
    } catch (error) {
      console.error(`Failed to claim token creation comment prompt: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async loadWatchPrivacyAccepted(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await getPrefs(context);
      const value = store.getSync(WATCH_PRIVACY_ACCEPTED_KEY, false);
      return typeof value === 'boolean' ? value : false;
    } catch (error) {
      console.error(`Failed to load watch privacy acceptance: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async saveWatchPrivacyAccepted(context: common.UIAbilityContext): Promise<void> {
    const store = await getPrefs(context);
    await store.put(WATCH_PRIVACY_ACCEPTED_KEY, true);
    await store.flush();
  }

  static async load(context: common.UIAbilityContext): Promise<Settings> {
    try {
      while (settingsSavePromise !== undefined) {
        const activeSavePromise: Promise<void> = settingsSavePromise;
        await activeSavePromise;
      }
      const store = await getPrefs(context);
      const json = store.getSync('settings', '{}');
      const parsed: Record<string, Object> = typeof json === 'string' ? JSON.parse(json) : {};
      const showSteamFeaturePageValue = parsed['showSteamFeaturePage'];
      const launchHomePageValue = parsed['launchHomePage'];
      const selectedSteamTokenIdValue = parsed['selectedSteamTokenId'];
      const globalImmersionValue = store.getSync('globalImmersionEnabled', DEFAULTS.globalImmersionEnabled);
      const backgroundSelectionValue = store.getSync('backgroundSelection', DEFAULTS.backgroundSelection);
      const backgroundSettingsVersionValue = store.getSync('backgroundSettingsVersion', 0);
      const customBackgroundUriValue = store.getSync('customBackgroundUri', DEFAULTS.customBackgroundUri);
      const backgroundBlurValue = store.getSync('backgroundBlurPercent', DEFAULTS.backgroundBlurPercent);
      const backgroundBrightnessValue =
        store.getSync('backgroundBrightnessPercent', DEFAULTS.backgroundBrightnessPercent);
      const globalBackgroundValue = store.getSync('globalBackgroundEnabled', DEFAULTS.globalBackgroundEnabled);
      const updateNoticeVersionValue = store.getSync('updateNoticeVersion', DEFAULTS.updateNoticeVersion);
      return {
        cloudBackup: parsed['cloudBackup'] as boolean ?? DEFAULTS.cloudBackup,
        smartGrip: parsed['smartGrip'] as boolean ?? DEFAULTS.smartGrip,
        antiPeep: parsed['antiPeep'] as boolean ?? DEFAULTS.antiPeep,
        appLock: parsed['appLock'] as boolean ?? DEFAULTS.appLock,
        showNextToken: parsed['showNextToken'] as boolean ?? DEFAULTS.showNextToken,
        showSteamFeaturePage: typeof showSteamFeaturePageValue === 'boolean' ? showSteamFeaturePageValue :
          DEFAULTS.showSteamFeaturePage,
        launchHomePage: launchHomePageValue === 'Steam' ? 'Steam' : DEFAULTS.launchHomePage,
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
        backgroundBrightnessPercent: typeof backgroundBrightnessValue === 'number' ? backgroundBrightnessValue :
          DEFAULTS.backgroundBrightnessPercent,
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
        steamGatewayToken: parsed['steamGatewayToken'] as string ?? DEFAULTS.steamGatewayToken,
        selectedSteamTokenId: typeof selectedSteamTokenIdValue === 'string' ? selectedSteamTokenIdValue :
          DEFAULTS.selectedSteamTokenId
      };
    } catch (error) {
      console.error(`Failed to load settings: ${JSON.stringify(error)}`);
      return DEFAULTS;
    }
  }

  static async save(context: common.UIAbilityContext, settings: Settings): Promise<void> {
    pendingSaveSettings = settings;
    if (settingsSavePromise === undefined) {
      settingsSavePromise = SettingsRepository.drainSaveQueue(context);
    }
    const activeSavePromise: Promise<void> = settingsSavePromise;
    await activeSavePromise;
  }

  private static async drainSaveQueue(context: common.UIAbilityContext): Promise<void> {
    while (pendingSaveSettings !== undefined) {
      const settings: Settings = pendingSaveSettings;
      pendingSaveSettings = undefined;
      await SettingsRepository.persist(context, settings);
    }
    settingsSavePromise = undefined;
  }

  private static async persist(context: common.UIAbilityContext, settings: Settings): Promise<void> {
    try {
      const store = await getPrefs(context);
      await store.put('settings', JSON.stringify(settings));
      await store.put('globalImmersionEnabled', settings.globalImmersionEnabled);
      await store.put('backgroundSelection', settings.backgroundSelection);
      await store.put('backgroundSettingsVersion', BACKGROUND_SETTINGS_VERSION);
      await store.put('customBackgroundUri', settings.customBackgroundUri);
      await store.put('backgroundBlurPercent', settings.backgroundBlurPercent);
      await store.put('backgroundBrightnessPercent', settings.backgroundBrightnessPercent);
      await store.put('globalBackgroundEnabled', settings.globalBackgroundEnabled);
      await store.put('updateNoticeVersion', settings.updateNoticeVersion);
      await store.flush();
    } catch (error) {
      console.error(`Failed to save settings: ${JSON.stringify(error)}`);
    }
  }
}
