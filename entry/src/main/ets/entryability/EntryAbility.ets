import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import deviceInfo from '@ohos.deviceInfo';

const DOMAIN = 0x0000;
const TRANSPARENT_SYSTEM_BAR = '#00000000';
const STATUS_BAR_HEIGHT_KEY = 'tool2fa_statusBarHeight';
const NAVI_INDICATOR_HEIGHT_KEY = 'tool2fa_naviIndicatorHeight';
const FORCE_DARK_SYSTEM_BARS_KEY = 'tool2fa_forceDarkSystemBars';
const PHONE_PAGE = 'pages/Index';
const WATCH_PAGE = 'pages/WatchIndex';

export default class EntryAbility extends UIAbility {
  private hasSafeAreaListener: boolean = false;
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.publishColorMode(this.context.config.colorMode);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.configureWindow(windowStage).finally(() => {
      const contentPage = this.resolveContentPage();
      windowStage.loadContent(contentPage, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        this.configureWindow(windowStage);
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading %{public}s.', contentPage);
      });
    });
  }

  private resolveContentPage(): string {
    const currentDeviceType = deviceInfo.deviceType.toLowerCase();
    if (currentDeviceType.indexOf('wear') >= 0 || currentDeviceType.indexOf('watch') >= 0) {
      return WATCH_PAGE;
    }
    return PHONE_PAGE;
  }

  private async configureWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      const isDark = this.isDarkMode(this.context.config.colorMode);
      await mainWindow.setWindowLayoutFullScreen(true);
      await this.configureWindowAppearance(mainWindow, isDark);
      this.publishColorMode(this.context.config.colorMode);
      this.syncSafeArea(mainWindow);
      if (!this.hasSafeAreaListener) {
        mainWindow.on('avoidAreaChange', (avoidAreaOption) => {
          if (avoidAreaOption.type === window.AvoidAreaType.TYPE_SYSTEM ||
            avoidAreaOption.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            this.syncSafeArea(mainWindow);
          }
        });
        this.hasSafeAreaListener = true;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to configure system bars. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private syncSafeArea(mainWindow: window.Window): void {
    try {
      const uiContext = mainWindow.getUIContext();
      const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const naviAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>(
        STATUS_BAR_HEIGHT_KEY,
        uiContext.px2vp(systemAvoidArea?.topRect?.height ?? 0)
      );
      AppStorage.setOrCreate<number>(
        NAVI_INDICATOR_HEIGHT_KEY,
        uiContext.px2vp(naviAvoidArea?.bottomRect?.height ?? 0)
      );
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to sync safe area. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    this.mainWindow = null;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark = this.isDarkMode(newConfig.colorMode);
    this.publishColorMode(newConfig.colorMode);
    if (this.mainWindow) {
      this.configureWindowAppearance(this.mainWindow, isDark);
    }
  }

  private publishColorMode(colorMode?: ConfigurationConstant.ColorMode): void {
    const isDark = this.isDarkMode(colorMode);
    AppStorage.setOrCreate<boolean>('tool2fa_systemDark', isDark);
    AppStorage.set<boolean>('tool2fa_systemDark', isDark);
  }

  private isDarkMode(colorMode?: ConfigurationConstant.ColorMode): boolean {
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private async configureWindowAppearance(mainWindow: window.Window, isDark: boolean): Promise<void> {
    try {
      const forceDarkSystemBars = AppStorage.get<boolean>(FORCE_DARK_SYSTEM_BARS_KEY) === true;
      const useDark = forceDarkSystemBars || isDark;
      mainWindow.setWindowBackgroundColor(useDark ? '#FF000000' : '#FFF2F3F5');
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_SYSTEM_BAR,
        navigationBarColor: TRANSPARENT_SYSTEM_BAR,
        isStatusBarLightIcon: useDark,
        isNavigationBarLightIcon: useDark,
        navigationBarContentColor: useDark ? '#FFEEEEEE' : '#FF1A1A1A',
        statusBarContentColor: useDark ? '#FFEEEEEE' : '#FF1A1A1A'
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to update window colors. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    AppStorage.setOrCreate<boolean>('tool2fa_requireAuth', true);
    AppStorage.setOrCreate<boolean>('tool2fa_isLocked', true);
    hilog.info(DOMAIN, 'testTag', 'Set tool2fa_isLocked=true in onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
