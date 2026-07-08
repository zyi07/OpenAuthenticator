import { abilityAccessCtrl, common, ConfigurationConstant, Permissions, Want } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { privacyManager } from '@kit.AppGalleryKit';
import { util } from '@kit.ArkTS';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import deviceInfo from '@ohos.deviceInfo';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { image } from '@kit.ImageKit';
import { i18n } from '@kit.LocalizationKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { formInfo, formProvider } from '@kit.FormKit';
import {
  BlurStrategy,
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsAttribute,
  ScrollEffectType,
  hdsEffect,
  hdsMaterial
} from '@kit.UIDesignKit';
import { CloudSyncState, TokenRepository } from '../data/TokenRepository';
import { TokenRecord } from '../model/TokenRecord';
import { Totp } from '../utils/Totp';
import { SettingsRepository } from '../data/SettingsRepository';
import { FormManager } from '../form/FormManager';
import { GoogleAuthenticatorMigration, GoogleOtpParameter } from '../utils/GoogleAuthenticatorMigration';
import { LogoResolver, LogoResolveResult } from '../utils/LogoResolver';
import {
  LANGUAGE_EN_GB,
  LANGUAGE_EN_US,
  LANGUAGE_SYSTEM,
  LANGUAGE_ZH_CN,
  LANGUAGE_ZH_TW,
  normalizeSelectedLanguage,
  systemLanguageTag,
  translate
} from '../utils/LocaleText';

const APPLOCK_DOMAIN = 0x0001;
const APPLOCK_TAG = 'AppLock';
const DATA_SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const DETECT_GESTURE_PERMISSION: Permissions = 'ohos.permission.DETECT_GESTURE';
const DLP_ANTI_PEEP_PERMISSION: Permissions = 'ohos.permission.DLP_GET_HIDE_STATUS';
const ERROR_RED: string = '#D93025';
const LOGO_SOURCE_MANUAL: string = 'manual';
const TYPE_OPTIONS: SelectOption[] = [{ value: 'TOTP' }, { value: 'Steam' }, { value: 'HOTP' }];
const SHA1_OPTIONS: SelectOption[] = [{ value: 'SHA1' }];
const ALGORITHM_OPTIONS: SelectOption[] = [
  { value: 'SHA1' },
  { value: 'SHA3' },
  { value: 'SHA224' },
  { value: 'SHA256' },
  { value: 'SHA384' },
  { value: 'SHA512' }
];
const TOKEN_LENGTH_OPTIONS: SelectOption[] = [{ value: '4位' }, { value: '6位' }, { value: '8位' }];
const STEAM_TOKEN_LENGTH_OPTIONS: SelectOption[] = [{ value: '5位' }];
const HOTP_TOKEN_LENGTH_OPTIONS: SelectOption[] = [{ value: '6位' }, { value: '8位' }];
const REFRESH_TIME_OPTIONS: SelectOption[] = [{ value: '30秒' }, { value: '60秒' }];
const STEAM_REFRESH_TIME_OPTIONS: SelectOption[] = [{ value: '30秒' }];
const NO_REFRESH_TIME_OPTIONS: SelectOption[] = [{ value: '不刷新' }];
const THEME_MODE_OPTIONS: SelectOption[] = [
  { value: '跟随系统' },
  { value: '深色' },
  { value: '浅色' }
];
const THEME_COLOR_OPTIONS: SelectOption[] = [
  { value: '柠檬黄' },
  { value: '奶油黄' },
  { value: '鼠尾草绿' },
  { value: '雾霾蓝' },
  { value: '灰豆沙粉' },
  { value: '清透炭黑' }
];
const LANGUAGE_OPTIONS: SelectOption[] = [
  { value: LANGUAGE_SYSTEM },
  { value: LANGUAGE_ZH_CN },
  { value: LANGUAGE_ZH_TW },
  { value: LANGUAGE_EN_US },
  { value: LANGUAGE_EN_GB }
];
const ISSUER_LOGO_COLOR_OPTIONS: SelectOption[] = [{ value: '品牌色' }, { value: '纯色' }];
const TOKEN_LAYOUT_SINGLE: string = 'single';
const TOKEN_LAYOUT_DOUBLE: string = 'double';
const DEFAULT_TOKEN_DIGITS: number = 6;
const DEFAULT_TOKEN_PERIOD: number = 30;
const USER_AGREEMENT_URL: string = 'https://gitcode.com/mroble/Tool_2FA/raw/main/cloud-hosting/public/user-agreement.html';
const FORM_TEXT_SIZE: number = 16;
const PAGE_CARD_GAP: number = 10;
const FORM_ROW_HEIGHT: number = 60;
const FORM_LOGO_SIZE: number = 120;
const FORM_BASIC_CARD_HEIGHT: number = FORM_ROW_HEIGHT * 3 + 2;
const FORM_DETAIL_CARD_HEIGHT: number = FORM_ROW_HEIGHT * 4 + 3;
const HOME_HORIZONTAL_PADDING: number = 20;
const HOME_LAYOUT_GAP: number = 8;
const HOME_TITLE_HEIGHT: number = 56;
const HOME_SEARCH_HEIGHT: number = 40;
const HOME_SEARCH_HEADER_HEIGHT: number = HOME_SEARCH_HEIGHT;
const HOME_SEARCH_COLLAPSE_DISTANCE: number = HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP;
const HOME_SEARCH_COLLAPSE_SHOW_THRESHOLD: number = 0.25;
const HOME_SEARCH_COLLAPSE_HIDE_THRESHOLD: number = 0.75;
const HOME_SEARCH_FADE_DURATION: number = 180;
const HOME_LIST_CACHE_COUNT: number = 4;
const HOME_NAV_WIDTH: number = 120;
const HOME_NAV_HEIGHT: number = 52;
const HOME_NAV_TEXT_SIZE: number = 10;
const HOME_SEARCH_ICON_SIZE: number = 14;
const HOME_SEARCH_TEXT_SIZE: number = 14;
const RESPONSIVE_CARD_MIN_WIDTH: number = 320;
const RESPONSIVE_DOUBLE_CARD_MIN_WIDTH: number = (RESPONSIVE_CARD_MIN_WIDTH - PAGE_CARD_GAP) / 2;
const RESPONSIVE_CARD_MAX_WIDTH: number = 480;
const CARD_TOKEN_LIMIT: number = 8;
const TOKEN_CARD_HEIGHT: number = 75;
const TOKEN_CARD_RADIUS: number = 15;
const TOKEN_NAME_TEXT_SIZE: number = 14;
const TOKEN_CODE_TEXT_SIZE: number = 24;
const TOKEN_TIME_TEXT_SIZE: number = 14;
const TOKEN_NEXT_CODE_TEXT_SIZE: number = 24;
const TOKEN_COUNTDOWN_SIZE: number = 40;
const TOKEN_COUNTDOWN_STROKE: number = 4;
const TOKEN_LOGO_SIZE: number = 40;
const ME_CARD_RADIUS: number = 15;
const ME_LOGIN_CARD_HEIGHT: number = 75;
const ME_ROW_HEIGHT: number = 60;
const ME_AVATAR_SIZE: number = 48;
const ME_TEXT_SIZE: number = 18;
const ME_ACTION_TEXT_SIZE: number = 15;
const ME_ACTION_ICON_SIZE: number = 20;
const ME_ARROW_WIDTH: number = 8;
const ME_ARROW_HEIGHT: number = 15;
const ADD_BUTTON_SIZE: number = 50;
const ADD_BUTTON_RIGHT: number = 36;
const ADD_BUTTON_BOTTOM: number = 142;
const ADD_BUTTON_ICON_SIZE: number = 24;
const LOGO_SAVE_LOOKUP_TIMEOUT_MS: number = 1500;
const SWIPE_ACTION_SIZE: number = 40;
const SWIPE_ACTION_ICON_SIZE: number = 32;
const SWIPE_ACTION_GAP: number = 10;
const SWIPE_ACTION_AREA_WIDTH: number = SWIPE_ACTION_SIZE * 2 + SWIPE_ACTION_GAP * 3;
const WATCH_LAYOUT_MAX_WIDTH: number = 320;
const WATCH_LAYOUT_MAX_HEIGHT: number = 360;
const WATCH_HORIZONTAL_PADDING: number = 18;
const WATCH_TOKEN_CARD_HEIGHT: number = 108;
const WATCH_TOKEN_CODE_SIZE: number = 28;

enum PageMode {
  Home,
  AddToken
}

enum HomeTab {
  Token,
  Me
}

enum HoldingHandStatus {
  NOT_HELD = 0,
  LEFT_HAND_HELD = 1
}

@Entry
@Component
struct Index {
  @State private pageMode: PageMode = PageMode.Home;
  @State private tokens: TokenRecord[] = [];
  @State private searchText: string = '';
  @State private nameInput: string = '';
  @State private remarkInput: string = '';
  @State private typeInput: string = 'TOTP';
  @State private algorithmInput: string = 'SHA1';
  @State private secretInput: string = '';
  @State private editingOriginalSecret: string = '';
  @State private logoUriInput: string = '';
  @State private logoLightUriInput: string = '';
  @State private logoDarkUriInput: string = '';
  @State private logoSourceInput: string = '';
  @State private tokenLengthInput: string = '6位';
  @State private refreshTimeInput: string = '30秒';
  @State private currentTimeMs: number = Date.now();
  @State private isSaving: boolean = false;
  @State private isAddMenuOpen: boolean = false;
  @State private addButtonOffsetX: number = 0;
  @State private addButtonOffsetY: number = 0;
  @State private addButtonDragging: boolean = false;
  @State private isScanning: boolean = false;
  @State private validationMessage: string = '';
  @State private pageWidth: number = 390;
  @State private pageHeight: number = 844;
  @State private editingTokenId: string = '';
  @State private selectedHomeTab: HomeTab = HomeTab.Token;
  @State private homeScrollY: number = 0;
  @State private isHomeSearchCollapsed: boolean = false;
  @State private isHuaweiLoggedIn: boolean = false;
  @State private huaweiNickname: string = '';
  @State private huaweiAvatarUri: string = '';
  @State private huaweiUserId: string = '';
  @State private huaweiLoginInProgress: boolean = false;
  @State private cloudBackupEnabled: boolean = false;
  @State private smartGripEnabled: boolean = false;
  @State private holdingHandStatus: HoldingHandStatus = HoldingHandStatus.NOT_HELD;
  @State private antiPeepEnabled: boolean = false;
  @State private appLockEnabled: boolean = false;
  @State private showNextToken: boolean = false;
  @State private issuerLogoColorMode: string = '纯色';
  @State private tokenLayoutMode: string = TOKEN_LAYOUT_SINGLE;
  @State private logoRenderVersion: number = 0;
  @State private formLogoRenderVersion: number = 0;
  @State private themeModeInput: string = '跟随系统';
  @State private themeColorInput: string = '灰豆沙粉';
  @State private languageInput: string = LANGUAGE_SYSTEM;
  @State private systemLanguage: string = 'zh-Hans';
  @State private cloudSyncStatus: string = '尚未同步';
  @State private cloudLastSyncTime: number = 0;
  @State private cloudSyncing: boolean = false;
  @State private cloudSyncRefreshKey: number = 0;
  @State private onboardingCompleted: boolean = false;
  @State private showOnboarding: boolean = false;
  @State private onboardingPage: number = 0;
  @StorageLink('tool2fa_systemDark') private systemDark: boolean = false;
  @StorageLink('tool2fa_requireAuth') private requireAuth: boolean = false;
  @StorageLink('tool2fa_isLocked') private isLocked: boolean = false;

  aboutToAppear(): void {
    this.refreshSystemLanguage();
    this.loadTokens();
    this.loadSettings();
    this.loadCardTokenIds();
    this.timerId = setInterval(() => {
      this.currentTimeMs = Date.now();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.stopSmartGrip();
    this.stopAntiPeep();
    this.clearLogoLookupTimer();
  }
  @StorageProp('tool2fa_statusBarHeight') private statusBarHeight: number = 0;
  @StorageProp('tool2fa_naviIndicatorHeight') private naviIndicatorHeight: number = 0;
  private homeScroller: Scroller = new Scroller();
  private meScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private cloudSpaceScroller: Scroller = new Scroller();
  private watchScroller: Scroller = new Scroller();
  private homePathStack: NavPathStack = new NavPathStack();
  private addPageScroller: Scroller = new Scroller();
  private onboardingSwiperController: SwiperController = new SwiperController();
  private timerId: number = -1;
  private authInstance: userAuth.UserAuthInstance | null = null;
  private holdingHandCallback: ((status: motion.HoldingHandStatus) => void) | null = null;
  private antiPeepCallback: ((status: dlpAntiPeep.DlpAntiPeepStatus) => void) | null = null;
  private importRejectedCount: number = 0;
  private logoLookupTimer: number = 0;
  private logoLookupSerial: number = 0;
  private deviceType: string = deviceInfo.deviceType;
  private addButtonDragStartX: number = 0;
  private addButtonDragStartY: number = 0;
  @State private cardSelectedTokenIds: string[] = [];
  @State private pendingCardTokenIds: string[] = [];
  @State private showCardTokenPicker: boolean = false;
  @State private showExportPicker: boolean = false;
  @State private exportSelectedIds: string[] = [];
  @State private openSwipeTokenId: string = '';
  @State private activeSwipeTokenId: string = '';
  @State private activeSwipeOffset: number = 0;
  @State private draggingTokenId: string = '';
  @State private showExportFormat: boolean = false;
  @State private showExportQR: boolean = false;
  @State private exportQRIndex: number = 0;
  @State private isSavingQRCode: boolean = false;
  @State private importProgressVisible: boolean = false;
  @State private importProgressTotal: number = 0;
  @State private importProgressProcessed: number = 0;
  @State private importProgressSuccess: number = 0;
  @State private importProgressFailed: number = 0;
  @State private importProgressMessage: string = '';
  private tokenDragReordered: boolean = false;
  private async loadSettings(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    const settings = await SettingsRepository.load(context);
    this.cloudBackupEnabled = settings.cloudBackup;
    this.smartGripEnabled = settings.smartGrip;
    this.antiPeepEnabled = settings.antiPeep;
    this.appLockEnabled = settings.appLock;
    this.showNextToken = settings.showNextToken;
    this.issuerLogoColorMode = settings.issuerLogoColorMode;
    this.tokenLayoutMode = settings.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? TOKEN_LAYOUT_DOUBLE : TOKEN_LAYOUT_SINGLE;
    this.isHuaweiLoggedIn = settings.huaweiLoggedIn;
    this.huaweiNickname = settings.huaweiNickname;
    this.huaweiAvatarUri = settings.huaweiAvatarUri;
    this.huaweiUserId = settings.huaweiUserId;
    this.themeModeInput = settings.themeMode;
    this.themeColorInput = settings.themeColor;
    this.languageInput = normalizeSelectedLanguage(settings.language);
    this.refreshSystemLanguage();
    this.cloudSyncStatus = settings.cloudSyncStatus;
    this.cloudLastSyncTime = settings.cloudLastSyncTime;
    this.onboardingCompleted = settings.onboardingCompleted;
    this.showOnboarding = !settings.onboardingCompleted;
    this.applyColorMode();
    if (this.cloudBackupEnabled && this.isHuaweiLoggedIn) {
      this.configureCloudAutoSync(true);
    }
    const shouldStartSmartGrip = this.smartGripEnabled;
    const shouldStartAntiPeep = this.antiPeepEnabled;
    if (shouldStartSmartGrip) {
      this.smartGripEnabled = this.startSmartGrip();
    }
    if (shouldStartAntiPeep) {
      this.startAntiPeep().then((started: boolean): void => {
        this.antiPeepEnabled = started;
      });
    }
    hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'loadSettings: appLock=%{public}d, isLocked=%{public}d, huaweiLoggedIn=%{public}d', this.appLockEnabled ? 1 : 0, this.isLocked ? 1 : 0, this.isHuaweiLoggedIn ? 1 : 0);
  }

  private async saveSettings(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    await SettingsRepository.save(context, {
      cloudBackup: this.cloudBackupEnabled,
      smartGrip: this.smartGripEnabled,
      antiPeep: this.antiPeepEnabled,
      appLock: this.appLockEnabled,
      showNextToken: this.showNextToken,
      issuerLogoColorMode: this.issuerLogoColorMode,
      tokenLayoutMode: this.tokenLayoutMode,
      huaweiLoggedIn: this.isHuaweiLoggedIn,
      huaweiNickname: this.huaweiNickname,
      huaweiAvatarUri: this.huaweiAvatarUri,
      huaweiUserId: this.huaweiUserId,
      themeMode: this.themeModeInput,
      themeColor: this.themeColorInput,
      language: normalizeSelectedLanguage(this.languageInput),
      cloudSyncStatus: this.cloudSyncStatus,
      cloudLastSyncTime: this.cloudLastSyncTime,
      onboardingCompleted: this.onboardingCompleted
    });
  }

  private startAppLockAuth(): void {
    hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'startAppLockAuth called, appLockEnabled=%{public}d, isLocked=%{public}d', this.appLockEnabled ? 1 : 0, this.isLocked ? 1 : 0);
    if (this.authInstance) {
      try {
        this.authInstance.off('result');
        this.authInstance.cancel();
      } catch (e) {
      }
      this.authInstance = null;
    }
    const authParam: userAuth.AuthParam = {
      challenge: new Uint8Array([49, 49, 49, 49, 49, 49]),
      authType: [userAuth.UserAuthType.PIN, userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
      authTrustLevel: userAuth.AuthTrustLevel.ATL1,
    };
    const widgetParam: userAuth.WidgetParam = {
      title: this.t('请进行身份验证'),
    };
    try {
      this.authInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'getUserAuthInstance success');
      this.authInstance.on('result', {
        onResult: (result: userAuth.UserAuthResult): void => {
          hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'onResult: result=%{public}d', result.result);
          if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
            this.authInstance = null;
            this.isLocked = false;
          } else {
            this.authInstance = null;
          }
        }
      });
      this.authInstance.start();
      hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'authInstance.start() called');
    } catch (error) {
      hilog.error(APPLOCK_DOMAIN, APPLOCK_TAG, 'auth error: %{public}s', JSON.stringify(error));
      this.authInstance = null;
      this.isLocked = false;
    }
  }

  build() {
    if (this.isWatchLayout()) {
      this.WatchAppRoot()
    } else {
      this.PhoneAppRoot()
    }
  }

  @Builder
  private PhoneAppRoot() {
    Stack({ alignContent: this.isLeftHanded() ? Alignment.BottomStart : Alignment.BottomEnd }) {
      if (this.appLockEnabled && this.isLocked) {
        Column() {
          Text(this.t('应用已锁定'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Text(this.t('请完成身份验证后使用'))
            .fontSize(14)
            .fontColor(this.secondaryTextColor())
            .margin({ top: 8 })
          Button(this.t('验证身份'))
            .margin({ top: 24 })
            .width(160)
            .height(44)
            .fontSize(16)
            .backgroundColor(this.accentColor())
            .borderRadius(22)
            .onClick(() => {
              this.startAppLockAuth();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.pageBackgroundColor())
        .zIndex(100)
        .onAppear(() => {
          this.startAppLockAuth();
        })
      }

      this.PageBackground()

      HdsNavigation(this.homePathStack) {
        this.HomePageContent()
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: {
            mainTitle: this.currentHomeTitle()
          },
          menu: this.homeSearchMenu()
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(this.statusBarHeight + HOME_TITLE_HEIGHT)
          },
          blurStrategy: BlurStrategy.ADAPTIVE,
          originalStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .navDestination(this.SettingsNavDestination)
      .bindToScrollable(this.homeNavigationScrollers())
      .hideBackButton(true)
      .titleMode(HdsNavigationTitleMode.MINI)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .width('100%')
      .height('100%')

      if (this.shouldShowAddFloatingButton()) {
        this.AddFloatingButton()
      }

      if (!this.isWatchLayout() && this.showOnboarding) {
        this.OnboardingOverlay()
      }

      if (this.importProgressVisible) {
        this.ImportProgressOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const nextWidth = this.lengthToNumber(newValue.width, this.pageWidth);
      const nextHeight = this.lengthToNumber(newValue.height, this.pageHeight);
      if (nextWidth > 0 && Math.abs(nextWidth - this.pageWidth) > 0.5) {
        this.pageWidth = nextWidth;
      }
      if (nextHeight > 0 && Math.abs(nextHeight - this.pageHeight) > 0.5) {
        this.pageHeight = nextHeight;
      }
    })
  }

  @Builder
  private WatchAppRoot() {
    Stack() {
      this.PageBackground()
      this.WatchHomePageContent()
      if (this.importProgressVisible) {
        this.ImportProgressOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackgroundColor())
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const nextWidth = this.lengthToNumber(newValue.width, this.pageWidth);
      const nextHeight = this.lengthToNumber(newValue.height, this.pageHeight);
      if (nextWidth > 0 && Math.abs(nextWidth - this.pageWidth) > 0.5) {
        this.pageWidth = nextWidth;
      }
      if (nextHeight > 0 && Math.abs(nextHeight - this.pageHeight) > 0.5) {
        this.pageHeight = nextHeight;
      }
    })
  }

  @Builder
  private PageBackground() {
    Column()
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private OnboardingOverlay() {
    Column() {
      Swiper(this.onboardingSwiperController) {
        this.OnboardingPage(0)
        this.OnboardingPage(1)
        this.OnboardingPage(2)
        this.OnboardingPage(3)
      }
      .index(this.onboardingPage)
      .loop(false)
      .indicator(true)
      .duration(360)
      .curve(Curve.EaseInOut)
      .onChange((index: number) => {
        this.onboardingPage = index;
      })
      .layoutWeight(1)
      .width('100%')

      Row({ space: 12 }) {
        Button(this.t('跳过'))
          .height(44)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.cardBackgroundColor())
          .onClick(() => {
            this.completeOnboarding();
          })

        Button(this.onboardingPage === 3 ? this.t('开始使用') : this.t('下一页'))
          .height(44)
          .layoutWeight(2)
          .fontSize(15)
          .fontColor(this.accentContrastColor())
          .backgroundColor(this.accentColor())
          .onClick(() => {
            if (this.onboardingPage < 3) {
              this.onboardingSwiperController.showNext();
            } else {
              this.completeOnboarding();
            }
          })
      }
      .width('100%')
      .constraintSize({ maxWidth: 560 })
      .padding({ left: 24, right: 24, bottom: this.naviIndicatorHeight + 20 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight + 16 })
    .backgroundColor(this.pageBackgroundColor())
    .zIndex(200)
  }

  @Builder
  private OnboardingPage(index: number) {
    Column({ space: 18 }) {
      if (index === 0) {
        Image($r('app.media.app_icon_black'))
          .width(112)
          .height(112)
          .borderRadius(28)
          .objectFit(ImageFit.Cover)
        Text(this.t('开源验证器'))
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text(this.t('专注、安全、随时可用的二次验证器'))
          .fontSize(16)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
        this.OnboardingFeatureList(['TOTP、HOTP 与 Steam 令牌', '秘钥仅保存在你掌控的设备中'])
      } else if (index === 1) {
        Row() {
          this.OnboardingRoundIcon($r('app.media.ic_sheet_manual_input'))
          this.OnboardingRoundIcon($r('app.media.ic_sheet_scan'))
          this.OnboardingRoundIcon($r('app.media.ic_sheet_import'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        Text(this.t('多种录入方式'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text(this.t('录入密钥、扫描二维码或导入备份，轻松迁移你的令牌。'))
          .fontSize(16)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
        this.OnboardingFeatureList(['兼容 Google Authenticator 迁移二维码', '支持 JSON 和 otpauth 数据'])
      } else if (index === 2) {
        Image($r('app.media.ic_tab_token_selected'))
          .width(80)
          .height(80)
          .objectFit(ImageFit.Contain)
        Text(this.t('一眼掌握所有令牌'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text(this.t('手机、折叠屏和平板自适应排版，桌面服务卡片让常用令牌抬眼即见。'))
          .fontSize(16)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
        this.OnboardingFeatureList(['多列响应式布局', '1×2 至 4×4 服务卡片', '浅色与深色外观'])
      } else {
        Row() {
          this.OnboardingRoundIcon($r('app.media.ic_me_cloud'))
          this.OnboardingRoundIcon($r('app.media.ic_me_contract'))
          this.OnboardingRoundIcon($r('app.media.ic_me_settings'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        Text(this.t('备份与隐私，都由你决定'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
        Text(this.t('可选华为云空间同步、JSON 或二维码备份，并提供应用锁与防窥保护。'))
          .fontSize(16)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
        this.OnboardingFeatureList(['备份与恢复由你主动控制', '支持应用锁、防窥和主题切换'])
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 620 })
    .padding({ left: 32, right: 32, bottom: 56 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private OnboardingRoundIcon(icon: Resource) {
    Stack() {
      Circle()
        .width(72)
        .height(72)
        .fill(this.accentColor())
      Image(icon)
        .width(28)
        .height(28)
        .objectFit(ImageFit.Contain)
    }
    .width(72)
    .height(72)
  }

  @Builder
  private OnboardingFeatureList(features: string[]) {
    Column({ space: 10 }) {
      ForEach(features, (feature: string) => {
        Row({ space: 10 }) {
          Circle()
            .width(7)
            .height(7)
            .fill(this.accentColor())
          Text(this.t(feature))
            .fontSize(14)
            .fontColor(this.primaryTextColor())
            .layoutWeight(1)
        }
        .width('100%')
      }, (feature: string) => feature)
    }
    .width('100%')
    .constraintSize({ maxWidth: 460 })
    .padding(18)
    .borderRadius(16)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private HomePageContent() {
    if (this.isWatchLayout()) {
      this.WatchHomePageContent()
    } else {
      HdsTabs() {
        TabContent() {
          this.TokenListContent()
        }
        .tabBar(this.tokenTabBarStyle())

        TabContent() {
          this.MePageContent()
        }
        .tabBar(this.meTabBarStyle())
      }
      .barOverlap(true)
      .vertical(false)
      .scrollable(false)
      .barPosition(BarPosition.End)
      .barWidth(HOME_NAV_WIDTH)
      .barHeight(HOME_NAV_HEIGHT)
      .barFloatingStyle({
        barBottomMargin: this.naviIndicatorHeight,
        barWidth: {
          smallWidth: HOME_NAV_WIDTH,
          mediumWidth: HOME_NAV_WIDTH,
          largeWidth: HOME_NAV_WIDTH
        },
        lightColor: this.accentColor(),
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onChange((index: number) => {
        this.selectedHomeTab = index === 0 ? HomeTab.Token : HomeTab.Me;
      })
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private WatchHomePageContent() {
    Scroll(this.watchScroller) {
      Column({ space: 10 }) {
        this.WatchCloudCard()

        if (this.tokens.length === 0) {
          Column({ space: 8 }) {
            Text(this.t('暂无令牌，请先添加令牌'))
              .fontSize(13)
              .fontColor(this.secondaryTextColor())
              .textAlign(TextAlign.Center)
              .width('100%')

            Text(this.t('登录华为账号'))
              .fontSize(12)
              .fontColor(this.secondaryTextColor())
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .width('100%')
          .padding({ top: 18, bottom: 18, left: 12, right: 12 })
          .borderRadius(18)
          .backgroundColor(this.cardBackgroundColor())
        } else {
          ForEach(this.tokens, (token: TokenRecord) => {
            this.WatchTokenCard(token)
          }, (token: TokenRecord) => `${token.id}-${this.currentTimeMs}`)
        }
      }
      .width('100%')
      .padding({
        left: WATCH_HORIZONTAL_PADDING,
        right: WATCH_HORIZONTAL_PADDING,
        top: this.statusBarHeight + HOME_TITLE_HEIGHT + 8,
        bottom: this.naviIndicatorHeight + 18
      })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
  }

  @Builder
  private WatchCloudCard() {
    Column({ space: 8 }) {
      Text(this.isHuaweiLoggedIn ? this.displayHuaweiNickname() : this.t('登录华为账号'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Button({ type: ButtonType.Capsule }) {
        if (this.cloudSyncing) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.accentContrastColor())
        } else {
          Text(this.isHuaweiLoggedIn ? this.t('手动获取') : this.t('登录华为账号'))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentContrastColor())
        }
      }
      .width('100%')
      .height(36)
      .backgroundColor(this.accentColor())
      .enabled(!this.cloudSyncing)
      .onClick(() => {
        if (this.isHuaweiLoggedIn) {
          this.pullTokensFromCloud();
        } else {
          this.loginHuaweiAccount();
        }
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(18)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private WatchTokenCard(token: TokenRecord) {
    Column({ space: 4 }) {
      Text(token.name)
        .fontSize(13)
        .fontColor(this.primaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(token.remark.trim().length > 0 ? token.remark.trim() : this.t('发行方'))
        .fontSize(11)
        .fontColor(this.secondaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(this.tokenCode(token))
          .fontSize(WATCH_TOKEN_CODE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tokenValueColor())
          .letterSpacing(0)
          .maxLines(1)
          .contentTransition(new NumericTextTransition({
            flipDirection: FlipDirection.UP,
            enableBlur: true
          }))
          .animation({ duration: 400, curve: Curve.Smooth })
          .layoutWeight(1)

        Text(this.tokenCountdownText(token))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(WATCH_TOKEN_CARD_HEIGHT)
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private SettingsNavDestination(name: string, pageInfos: Object) {
    NavDestination() {
      HdsNavigation() {
        if (name === 'addToken') {
          this.AddTokenContent()
        } else if (name === 'cloudSpace') {
          this.CloudSpacePageContent()
        } else {
          this.SettingsPageContent()
        }
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: {
            mainTitle: this.navigationDestinationTitle(name)
          },
          backIcon: {
            action: () => {
              if (name === 'addToken') {
                this.backHome();
              } else {
                this.homePathStack.pop(true);
              }
            }
          }
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(this.statusBarHeight + HOME_TITLE_HEIGHT)
          },
          blurStrategy: BlurStrategy.ADAPTIVE,
          originalStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        },
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: false
      })
      .bindToScrollable(this.navigationDestinationScrollers(name))
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavDestinationMode.STANDARD)
    .systemTransition(NavigationSystemTransitionType.DEFAULT)
    .onHidden((reason: VisibilityChangeReason) => {
      if (name === 'addToken' && reason === VisibilityChangeReason.TRANSITION) {
        this.clearAddPageNavigationState();
      }
    })
    .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private TokenListContent() {
    List({ scroller: this.homeScroller }) {
      ListItemGroup({
        header: this.HomeSearchGroupHeader,
        space: 0
      }) {
      }

      if (this.filteredTokens().length === 0) {
        ListItem() {
          this.EmptyTokenState()
        }
        .width('100%')
        .padding({ bottom: PAGE_CARD_GAP })
        .clip(false)
      } else {
        if (this.canMoveTokenList()) {
          this.MovableTokenListForEach()
        } else {
          this.TokenListForEach()
        }

        ListItemGroup({
          footer: this.TokenListFooter,
          space: 0
        }) {
        }
      }
    }
    .width('100%')
    .height('100%')
    .lanes(this.filteredTokens().length === 0 ? 1 : this.tokenListLaneCount(), PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      top: this.statusBarHeight + HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP
    })
    .contentEndOffset(this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP)
    .cachedCount(HOME_LIST_CACHE_COUNT, true)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
    .onReachStart(() => {
      this.homeScrollY = 0;
      this.setHomeSearchCollapsed(false);
    })
    .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
      this.updateHomeScroll(scrollOffset);
    })
  }

  @Builder
  private TokenListForEach() {
    ForEach(this.filteredTokens(), (token: TokenRecord) => {
      ListItem() {
        this.TokenListItem(token)
      }
      .width('100%')
      .padding({ bottom: PAGE_CARD_GAP })
      .clip(true)
      .borderRadius(TOKEN_CARD_RADIUS)
    }, (token: TokenRecord) => `${token.id}-${this.logoRenderVersion}`)
  }

  @Builder
  private MovableTokenListForEach() {
    ForEach(this.filteredTokens(), (token: TokenRecord) => {
      ListItem() {
        this.TokenListItem(token)
      }
      .width('100%')
      .padding({ bottom: PAGE_CARD_GAP })
      .clip(true)
      .borderRadius(TOKEN_CARD_RADIUS)
      .dragPreviewOptions({
        mode: [DragPreviewMode.DISABLE_SCALE, DragPreviewMode.ENABLE_DEFAULT_RADIUS],
        numberBadge: false,
        sizeChangeEffect: DraggingSizeChangeEffect.DEFAULT
      }, {
        enableHapticFeedback: true,
        enableEdgeAutoScroll: true
      })
    }, (token: TokenRecord) => `${token.id}-${this.logoRenderVersion}`)
          .onMove((from: number, to: number) => {
            this.handleTokenMove(from, to);
          }, {
            onLongPress: (index: number) => {
              this.handleTokenDragStart(index);
            },
            onDragStart: (index: number) => {
              this.handleTokenDragStart(index);
            },
            onDrop: (index: number) => {
              this.handleTokenDragDrop();
            }
          })
  }

  @Builder
  private EmptyTokenState() {
    Column({ space: 18 }) {
      Text(this.t('还没有令牌'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())

      Button(this.t('新增令牌'), { type: ButtonType.Capsule })
        .width(148)
        .height(44)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.accentColor())
        .onClick(() => {
          this.isAddMenuOpen = true;
        })

      Text(this.t('代码开源，本地存储'))
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
        .onClick(() => {
          this.openExternalUrl('https://gitcode.com/mroble/Tool_2FA');
        })
    }
    .width('100%')
    .height(this.emptyTokenStateHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ImportProgressOverlay() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isDarkTheme() ? '#99000000' : '#66FFFFFF')
        .backdropBlur(18)

      Column({ space: 14 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(this.accentColor())

        Text(this.importProgressMessage)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)

        Progress({
          value: this.importProgressProcessed,
          total: Math.max(this.importProgressTotal, 1),
          type: ProgressType.Linear
        })
          .width('100%')
          .height(4)
          .color(this.accentColor())
          .backgroundColor(this.dividerColor())

        Text(this.tf('已处理{0}/{1}，成功{2}，跳过{3}', [
          `${this.importProgressProcessed}`,
          `${this.importProgressTotal}`,
          `${this.importProgressSuccess}`,
          `${this.importProgressFailed}`
        ]))
          .fontSize(13)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
      }
      .width(Math.min(300, this.pageWidth - HOME_HORIZONTAL_PADDING * 2))
      .padding({ left: 22, right: 22, top: 22, bottom: 22 })
      .borderRadius(24)
      .backgroundColor(this.cardBackgroundColor())
      .shadow({
        radius: 24,
        color: this.isDarkTheme() ? '#66000000' : '#18000000',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    .zIndex(180)
    .hitTestBehavior(HitTestMode.Block)
  }

  @Builder
  private MePageContent() {
    List({ scroller: this.meScroller }) {
      ListItemGroup({ header: this.MeLoginGroupHeader, space: PAGE_CARD_GAP }) {
        ListItem() {
          this.MeActionCard([
            ['华为云空间', $r('app.media.ic_me_cloud')],
            ['备份导出', $r('app.media.ic_me_export')],
            ['设置', $r('app.media.ic_me_settings')]
          ], 0)
        }
        .width('100%')
        .bindSheet(this.showExportPicker, this.ExportTokenPickerSheet(), {
          height: SheetSize.MEDIUM,
          dragBar: true,
          showClose: false,
          backgroundColor: this.cardBackgroundColor(),
          blurStyle: BlurStyle.COMPONENT_THIN,
          radius: LengthMetrics.vp(28),
          onDisappear: () => {
            this.showExportPicker = false;
          }
        })

        ListItem() {
          this.MeActionCard([
            ['订阅会员服务', $r('app.media.ic_me_subscription')],
            ['更多作品', $r('app.media.ic_me_more')]
          ], 1)
        }
        .width('100%')
        .bindSheet(this.showExportQR, this.ExportQRCodeSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false,
          backgroundColor: this.cardBackgroundColor(),
          blurStyle: BlurStyle.COMPONENT_THIN,
          radius: LengthMetrics.vp(28),
          onDisappear: () => {
            this.showExportQR = false;
          }
        })
        ListItem() {
          this.MeActionCard([
            ['开源地址', $r('app.media.ic_me_gitcode')],
            ['用户协议', $r('app.media.ic_me_contract')],
            ['隐私声明', $r('app.media.ic_me_contract')],
            ['建议与反馈', $r('app.media.ic_me_feedback')]
          ], 2)
        }
        .width('100%')
        .bindSheet(this.showExportFormat, this.ExportFormatSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false,
          backgroundColor: this.cardBackgroundColor(),
          blurStyle: BlurStyle.COMPONENT_THIN,
          radius: LengthMetrics.vp(28),
          onDisappear: () => {
            this.showExportFormat = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .lanes({ minLength: RESPONSIVE_CARD_MIN_WIDTH, maxLength: RESPONSIVE_CARD_MAX_WIDTH }, PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      top: this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP
    })
    .contentEndOffset(this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP + 18)
    .cachedCount(HOME_LIST_CACHE_COUNT, true)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private MeLoginGroupHeader() {
    Column() {
      this.MeLoginCard()
    }
    .width('100%')
    .padding({ bottom: PAGE_CARD_GAP })
  }

  @Builder
  private MeLoginCard() {
    Row({ space: 16 }) {
      this.MeAvatar()

      Column({ space: 4 }) {
        Text(this.isHuaweiLoggedIn ? this.displayHuaweiNickname() : this.t('登录华为账号'))
          .fontSize(ME_TEXT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.isHuaweiLoggedIn ? this.t('已登录·点击退出') :
          (this.huaweiLoginInProgress ? this.t('正在登录') : this.t('点击登录')))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.secondaryTextColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(ME_LOGIN_CARD_HEIGHT)
    .padding({ left: 18, right: 20 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.isHuaweiLoggedIn) {
        this.logoutHuaweiAccount();
      } else if (!this.huaweiLoginInProgress) {
        this.loginHuaweiAccount();
      }
    })
  }

  @Builder
  private MeAvatar() {
    if (this.isHuaweiLoggedIn && this.huaweiAvatarUri.length > 0) {
      Image(this.huaweiAvatarUri)
        .width(ME_AVATAR_SIZE)
        .height(ME_AVATAR_SIZE)
        .borderRadius(ME_AVATAR_SIZE / 2)
        .objectFit(ImageFit.Cover)
    } else {
      Stack() {
        Circle()
          .width(ME_AVATAR_SIZE)
          .height(ME_AVATAR_SIZE)
          .fill(this.isDarkTheme() ? '#4A4A4A' : '#C7C7C7')

        Circle()
          .width(16)
          .height(16)
          .fill(this.isDarkTheme() ? '#777777' : '#9F9F9F')
          .position({ x: 16, y: 10 })

        Ellipse()
          .width(34)
          .height(20)
          .fill(this.isDarkTheme() ? '#777777' : '#9F9F9F')
          .position({ x: 7, y: 26 })
      }
      .width(ME_AVATAR_SIZE)
      .height(ME_AVATAR_SIZE)
    }
  }

  private displayHuaweiNickname(): string {
    return this.huaweiNickname === '华为账号' ? this.t('华为账号') : this.huaweiNickname;
  }

  @Builder
  private MeActionCard(items: Array<[string, Resource]>, group: number) {
    Column() {
      ForEach(items, (item: [string, Resource], index: number) => {
        this.MeActionRow(item[0], item[1], () => {
          this.handleMeAction(group, index);
        })
        if (index < items.length - 1) {
          this.MeCardDivider()
        }
      }, (item: [string, Resource]) => item[0])
    }
    .width('100%')
    .height(items.length * ME_ROW_HEIGHT + items.length - 1)
    .padding({ left: 20, right: 18 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private MeActionRow(label: string, icon: Resource, action: () => void) {
    Row({ space: 16 }) {
      Image(icon)
        .width(ME_ACTION_ICON_SIZE)
        .height(ME_ACTION_ICON_SIZE)
        .objectFit(ImageFit.Contain)

      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      Image($r('app.media.ic_me_right'))
        .width(ME_ARROW_WIDTH)
        .height(ME_ARROW_HEIGHT)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private SettingsPageContent() {
    Scroll(this.settingsScroller) {
      GridRow({
        columns: { xs: 1, sm: 2, md: 2, lg: 2, xl: 2, xxl: 2 },
        gutter: PAGE_CARD_GAP,
        breakpoints: {
          value: ['600vp'],
          reference: BreakpointsReference.ComponentSize
        }
      }) {
        GridCol({ span: { xs: 1, sm: 1, md: 1, lg: 1, xl: 1, xxl: 1 } }) {
          this.SettingsSecuritySection()
        }

        GridCol({ span: { xs: 1, sm: 1, md: 1, lg: 1, xl: 1, xxl: 1 } }) {
          this.SettingsAppearanceSection()
        }

        GridCol({ span: { xs: 1, sm: 1, md: 1, lg: 1, xl: 1, xxl: 1 } }) {
          this.SettingsWidgetSection()
        }
      }
      .width('100%')
      .padding({
        left: HOME_HORIZONTAL_PADDING,
        right: HOME_HORIZONTAL_PADDING,
        top: this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP,
        bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
  }

  @Builder
  private SettingsSecuritySection() {
    Column() {
      this.SettingsSectionTitle(this.t('功能与安全'))
      this.SettingsSecurityCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsAppearanceSection() {
    Column() {
      this.SettingsSectionTitle(this.t('界面外观'))
      this.SettingsAppearanceCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsWidgetSection() {
    Column() {
      this.SettingsSectionTitle(this.t('服务卡片'))
      this.SettingsCardWidgetCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsSectionTitle(title: string) {
    Text(title)
      .fontSize(ME_ACTION_TEXT_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.primaryTextColor())
      .width('100%')
      .padding({ left: 20, top: 10, bottom: 8 })
  }

  @Builder
  private CloudSpacePageContent() {
    Stack() {
      Scroll(this.cloudSpaceScroller) {
        Column({ space: PAGE_CARD_GAP }) {
          Text(this.t('同步设置'))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width('100%')
            .padding({ left: 20, top: 10, bottom: 8 })

          Column() {
            this.SettingsSwitchRow('云空间自动同步', this.cloudBackupEnabled, (isOn: boolean) => {
              this.toggleCloudBackup(isOn);
            })
          }
          .width('100%')
          .height(ME_ROW_HEIGHT)
          .padding({ left: 20, right: 18 })
          .borderRadius(ME_CARD_RADIUS)
          .backgroundColor(this.cardBackgroundColor())

          Text(this.t('同步操作'))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width('100%')
            .padding({ left: 20, top: 18, bottom: 8 })

          Column() {
            this.CloudSpaceActionRow('手动推送', () => {
              this.pushTokensToCloud();
            })
            this.MeCardDivider()
            this.CloudSpaceActionRow('手动获取', () => {
              this.pullTokensFromCloud();
            })
            this.MeCardDivider()
            this.CloudSpaceActionRow('云空间管理', () => {
              this.openCloudSpaceSettings();
            })
          }
          .width('100%')
          .height(ME_ROW_HEIGHT * 3 + 2)
          .padding({ left: 20, right: 18 })
          .borderRadius(ME_CARD_RADIUS)
          .backgroundColor(this.cardBackgroundColor())

          Text(this.t('同步记录'))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width('100%')
            .padding({ left: 20, top: 18, bottom: 8 })

          Column() {
            Row() {
              Text(this.t('同步状态'))
                .fontSize(ME_ACTION_TEXT_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.primaryTextColor())
                .layoutWeight(1)

              if (this.cloudSyncing) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color(this.accentColor())
                  .margin({ right: 6 })
              }

              Text(this.cloudSyncing ? this.t('同步中') : this.t(this.cloudSyncStatus))
                .fontSize(ME_ACTION_TEXT_SIZE)
                .fontColor(this.secondaryTextColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(ME_ROW_HEIGHT)
            .alignItems(VerticalAlign.Center)

            this.MeCardDivider()

            Row() {
              Text(this.t('最后同步时间'))
                .fontSize(ME_ACTION_TEXT_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.primaryTextColor())
                .layoutWeight(1)

              Text(this.cloudLastSyncTimeText())
                .fontSize(ME_ACTION_TEXT_SIZE)
                .fontColor(this.secondaryTextColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(ME_ROW_HEIGHT)
            .alignItems(VerticalAlign.Center)
            if (this.shouldShowCloudDisabledHint()) {
              Text('请点击「云空间管理」或前往「设置-云空间」，找到开源验证器应用，并开启云同步！')
                .fontSize(12)
                .fontColor(this.secondaryTextColor())
                .lineHeight(18)
                .width('100%')
                .padding({ top: 8, bottom: 10 })
            }
          }
          .width('100%')
          .height(this.shouldShowCloudDisabledHint() ? ME_ROW_HEIGHT * 2 + 57 : ME_ROW_HEIGHT * 2 + 1)
          .padding({ left: 20, right: 18 })
          .borderRadius(ME_CARD_RADIUS)
          .backgroundColor(this.cardBackgroundColor())
        }
        .width('100%')
        .padding({
          left: HOME_HORIZONTAL_PADDING,
          right: HOME_HORIZONTAL_PADDING,
          top: this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP,
          bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ExportTokenPickerSheet() {
    Column() {
      Row() {
        Text(this.t('选择要导出的令牌'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text(this.exportSelectedIds.length === this.tokens.length ? this.t('取消全选') : this.t('全选'))
          .fontSize(14)
          .fontColor(this.accentColor())
          .onClick(() => {
            this.exportSelectedIds = this.exportSelectedIds.length === this.tokens.length ? [] :
              this.tokens.map((token: TokenRecord) => token.id);
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })

      Text(this.tf('已选 {0} 个令牌', [`${this.exportSelectedIds.length}`]))
        .width('100%')
        .fontSize(12)
        .fontColor(this.secondaryTextColor())
        .padding({ left: 20, right: 20, bottom: 8 })

      List() {
        if (this.tokens.length === 0) {
          ListItem() {
            Text(this.t('暂无令牌，请先添加令牌'))
              .fontSize(14)
              .fontColor(this.secondaryTextColor())
              .width('100%')
              .height(100)
              .textAlign(TextAlign.Center)
          }
        } else {
          ForEach(this.tokens, (token: TokenRecord) => {
            ListItem() {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text(this.tokenDisplayName(token))
                    .fontSize(15)
                    .fontColor(this.primaryTextColor())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.normalizeTokenType(token.type))
                    .fontSize(12)
                    .fontColor(this.secondaryTextColor())
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Checkbox({ name: token.id, group: 'exportTokenPicker' })
                  .select(this.exportSelectedIds.includes(token.id))
                  .selectedColor(this.accentColor())
                  .hitTestBehavior(HitTestMode.None)
              }
              .width('100%')
              .height(58)
              .padding({ left: 20, right: 20 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.toggleExportToken(token.id);
              })
            }
          }, (token: TokenRecord) => token.id)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(HOME_LIST_CACHE_COUNT, true)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button(this.t('取消'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.searchBackgroundColor())
          .onClick(() => {
            this.showExportPicker = false;
          })

        Button(this.t('下一步'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.accentContrastColor())
          .backgroundColor(this.exportSelectedIds.length > 0 ? this.accentColor() : this.dividerColor())
          .enabled(this.exportSelectedIds.length > 0)
          .onClick(() => {
            this.showExportPicker = false;
            setTimeout(() => {
              this.showExportFormatMenu();
            }, 180);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: this.naviIndicatorHeight + 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ExportFormatSheet() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.t('选择导出格式'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())

        Text(this.t('请选择密钥备份的导出方式'))
          .fontSize(13)
          .fontColor(this.secondaryTextColor())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.ExportFormatOption(
          this.t('密钥 JSON 文件'),
          this.t('适合完整备份及跨设备导入'),
          () => {
            this.showExportFormat = false;
            setTimeout(() => {
              this.exportAsJSON();
            }, 180);
          }
        )

        this.MeCardDivider()

        this.ExportFormatOption(
          this.t('二维码图片'),
          this.t('适合通过其他认证器逐个扫描导入'),
          () => {
            this.exportQRIndex = 0;
            this.showExportFormat = false;
            setTimeout(() => {
              this.showExportQR = true;
            }, 180);
          }
        )
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .borderRadius(ME_CARD_RADIUS)
      .backgroundColor(this.searchBackgroundColor())

      Button(this.t('取消'))
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(this.primaryTextColor())
        .backgroundColor(this.searchBackgroundColor())
        .onClick(() => {
          this.showExportFormat = false;
        })
    }
    .width('100%')
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      top: 15,
      bottom: this.naviIndicatorHeight + 16
    })
  }

  @Builder
  private ExportFormatOption(title: string, description: string, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())

        Text(description)
          .fontSize(12)
          .fontColor(this.secondaryTextColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_me_right'))
        .width(ME_ARROW_WIDTH)
        .height(ME_ARROW_HEIGHT)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private ExportQRCodeSheet() {
    Column() {
      if (this.exportQRIndex < this.exportSelectedTokens().length) {
        Text(this.tokenDisplayName(this.exportSelectedTokens()[this.exportQRIndex]))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8, bottom: 14 })

        Row({ space: 10 }) {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_me_right'))
              .width(ME_ARROW_WIDTH)
              .height(ME_ARROW_HEIGHT)
              .objectFit(ImageFit.Contain)
              .rotate({ angle: 180 })
          }
          .width(40)
          .height(40)
          .backgroundColor(this.searchBackgroundColor())
          .enabled(this.exportQRIndex > 0 && !this.isSavingQRCode)
          .opacity(this.exportQRIndex > 0 ? 1 : 0.35)
          .onClick(() => {
            if (this.exportQRIndex > 0) {
              this.exportQRIndex--;
            }
          })

          Stack() {
            QRCode(this.buildOtpAuthUri(this.exportSelectedTokens()[this.exportQRIndex]))
              .width(this.exportQRCodeSize() - 24)
              .height(this.exportQRCodeSize() - 24)
              .color('#000000')
              .backgroundColor('#FFFFFF')
          }
          .id('exportCurrentQrCode')
          .width(this.exportQRCodeSize())
          .height(this.exportQRCodeSize())
          .padding(12)
          .borderRadius(8)
          .backgroundColor('#FFFFFF')

          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.ic_me_right'))
              .width(ME_ARROW_WIDTH)
              .height(ME_ARROW_HEIGHT)
              .objectFit(ImageFit.Contain)
          }
          .width(40)
          .height(40)
          .backgroundColor(this.searchBackgroundColor())
          .enabled(this.exportQRIndex < this.exportSelectedTokens().length - 1 && !this.isSavingQRCode)
          .opacity(this.exportQRIndex < this.exportSelectedTokens().length - 1 ? 1 : 0.35)
          .onClick(() => {
            if (this.exportQRIndex < this.exportSelectedTokens().length - 1) {
              this.exportQRIndex++;
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Text(`${this.exportQRIndex + 1}/${this.exportSelectedTokens().length}`)
          .fontSize(12)
          .fontColor(this.secondaryTextColor())
          .margin({ top: 10, bottom: 14 })

        Row({ space: 12 }) {
          Button(this.isSavingQRCode ? this.t('保存中') : this.t('保存当前图片'))
            .fontSize(14)
            .fontColor(this.primaryTextColor())
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.searchBackgroundColor())
            .enabled(!this.isSavingQRCode)
            .onClick(() => {
              if (!this.isSavingQRCode) {
                this.saveCurrentQRCode();
              }
            })

          Button(this.isSavingQRCode ? this.t('保存中') : this.t('保存所有图片'))
            .fontSize(14)
            .fontColor(this.accentContrastColor())
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.accentColor())
            .enabled(!this.isSavingQRCode)
            .onClick(() => {
              if (!this.isSavingQRCode) {
                this.saveAllQRCodes();
              }
            })
        }
        .width('100%')
        .opacity(this.isSavingQRCode ? 0.65 : 1)
      } else {
        Text(this.t('没有可导出的令牌'))
          .fontSize(14)
          .fontColor(this.secondaryTextColor())
          .height(120)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: this.naviIndicatorHeight + 20 })
    .alignItems(HorizontalAlign.Center)
  }

  private toggleExportToken(tokenId: string): void {
    if (this.exportSelectedIds.includes(tokenId)) {
      this.exportSelectedIds = this.exportSelectedIds.filter((id: string) => id !== tokenId);
    } else {
      this.exportSelectedIds = [...this.exportSelectedIds, tokenId];
    }
  }

  @Builder
  private CloudSpaceActionRow(label: string, action: () => void) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      if (this.cloudSyncing && (label === '手动推送' || label === '手动获取')) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.accentColor())
      } else {
        Image($r('app.media.ic_me_right'))
          .width(ME_ARROW_WIDTH)
          .height(ME_ARROW_HEIGHT)
          .objectFit(ImageFit.Contain)
      }
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .opacity(this.cloudSyncing && (label === '手动推送' || label === '手动获取') ? 0.6 : 1)
    .onClick(() => {
      if (!this.cloudSyncing) {
        action();
      }
    })
  }

  @Builder
  private CloudSpaceInfoRow(label: string, value: string) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      if (label === '同步状态' && this.cloudSyncing) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor())
          .margin({ right: 6 })
      }

      Text(value)
        .fontSize(HOME_SEARCH_TEXT_SIZE)
        .fontColor(this.secondaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SettingsSecurityCard() {
    Column() {
      this.SettingsSwitchRow('智感握姿', this.smartGripEnabled, (isOn: boolean) => {
        this.toggleSmartGrip(isOn);
      })
      this.MeCardDivider()
      this.SettingsSwitchRow('防窥保护', this.antiPeepEnabled, (isOn: boolean) => {
        this.toggleAntiPeep(isOn);
      })
      this.MeCardDivider()
      this.SettingsSwitchRow('应用锁定', this.appLockEnabled, (isOn: boolean) => {
        this.toggleAppLock(isOn);
      })
      this.MeCardDivider()
      this.SettingsSelectRow('语言', this.languageInput, LANGUAGE_OPTIONS, false, (value: string) => {
        this.languageInput = normalizeSelectedLanguage(value);
        this.refreshSystemLanguage();
        this.saveSettings();
      })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 4 + 3)
    .padding({ left: 20, right: 18 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private SettingsSwitchRow(label: string, isOn: boolean, onChanged: (isOn: boolean) => void) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.accentColor())
        .switchPointColor(this.cardBackgroundColor())
        .onChange((checked: boolean) => {
          onChanged(checked);
        })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SettingsAppearanceCard() {
    Column() {
      this.SettingsSelectRow('深色模式', this.themeModeInput, THEME_MODE_OPTIONS, false, (value: string) => {
        this.themeModeInput = value;
        this.applyColorMode();
        this.saveSettings();
      })
      this.MeCardDivider()
      this.SettingsSelectRow('主题色', this.themeColorInput, THEME_COLOR_OPTIONS, true, (value: string) => {
        this.themeColorInput = value;
        this.saveSettings();
      })
      this.MeCardDivider()
      this.SettingsSwitchRow('显示下一组令牌', this.showNextToken, (isOn: boolean) => {
        this.showNextToken = isOn;
        this.saveSettings();
      })
      this.MeCardDivider()
      this.SettingsSelectRow('发行方图标显示颜色', this.issuerLogoColorMode, ISSUER_LOGO_COLOR_OPTIONS, false,
        (value: string) => {
          this.issuerLogoColorMode = value;
          this.refreshTokenLogoDisplay();
          this.saveSettings();
        })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 4 + 3)
    .padding({ left: 20, right: 18 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private SettingsSelectRow(
    label: string,
    selectedValue: string,
    values: SelectOption[],
    showColorDot: boolean,
    onSelected: (value: string) => void
  ) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      if (showColorDot) {
        Row()
          .width(14)
          .height(14)
          .borderRadius(7)
          .backgroundColor(this.accentColor())
          .margin({ right: 8 })
      }

      Select(this.localizedOptions(values))
        .selected(this.optionIndex(values, selectedValue))
        .value(this.t(selectedValue))
        .font({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .fontColor(this.secondaryTextColor())
        .selectedOptionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .selectedOptionFontColor(this.accentContrastColor())
        .selectedOptionBgColor(this.accentColor())
        .optionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onSelect((index: number, value: string) => {
          onSelected(index >= 0 && index < values.length ? `${values[index].value}` : value);
        })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private MeCardDivider() {
    Divider()
      .strokeWidth(1)
      .color(this.dividerColor())
  }

  @Builder
  private SettingsCardWidgetCard() {
    Column() {
      this.CloudSpaceActionRow('选择卡片显示的令牌', () => {
        this.openCardTokenPicker();
      })
      this.MeCardDivider()
      this.CloudSpaceActionRow('选择服务卡片', () => {
        this.openSystemFormManager();
      })
      this.MeCardDivider()
      Row() {
        Column({ space: 4 }) {
          Text(this.cardSelectedTokenIds.length > 0 ?
            this.tf('已选择 {0} 个令牌', [`${this.cardSelectedTokenIds.length}`]) : this.t('按首页顺序显示'))
            .fontSize(13)
            .fontColor(this.secondaryTextColor())

          Text(this.cardTokenSelectionSummary())
            .fontSize(12)
            .fontColor(this.secondaryTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height(ME_ROW_HEIGHT)
      .padding({ left: 4 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .padding({ left: 20, right: 18 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
    .bindSheet(this.showCardTokenPicker, this.CardTokenPickerSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: this.cardBackgroundColor(),
      blurStyle: BlurStyle.COMPONENT_THIN,
      radius: LengthMetrics.vp(28),
      onDisappear: () => {
        this.showCardTokenPicker = false;
        this.pendingCardTokenIds = [];
      }
    })
  }

  @Builder
  private CardTokenPickerSheet() {
    Column() {
      Row() {
        Text(this.t('选择卡片显示的令牌'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text(`${this.pendingCardTokenIds.length}/${CARD_TOKEN_LIMIT}`)
          .fontSize(14)
          .fontColor(this.secondaryTextColor())
      }
      .width('100%')
      .height(52)
      .padding({ left: 20, right: 20 })

      Text(this.t('卡片按勾选顺序显示令牌'))
        .width('100%')
        .fontSize(12)
        .fontColor(this.secondaryTextColor())
        .padding({ left: 20, right: 20, bottom: 8 })

      List() {
        if (this.tokens.length === 0) {
          ListItem() {
            Text(this.t('暂无令牌，请先添加令牌'))
              .fontSize(14)
              .fontColor(this.secondaryTextColor())
              .width('100%')
              .height(100)
              .textAlign(TextAlign.Center)
          }
        } else {
          ForEach(this.tokens, (token: TokenRecord) => {
            ListItem() {
              Row({ space: 12 }) {
                Stack() {
                  if (this.pendingCardTokenIndex(token.id) >= 0) {
                    Circle()
                      .width(24)
                      .height(24)
                      .fill(this.accentColor())

                    Text(`${this.pendingCardTokenIndex(token.id) + 1}`)
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.accentContrastColor())
                  }
                }
                .width(24)
                .height(24)

                Column({ space: 2 }) {
                  Text(this.tokenDisplayName(token))
                    .fontSize(15)
                    .fontColor(this.primaryTextColor())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.normalizeTokenType(token.type))
                    .fontSize(12)
                    .fontColor(this.secondaryTextColor())
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Checkbox({ name: token.id, group: 'cardTokenPicker' })
                  .select(this.pendingCardTokenIndex(token.id) >= 0)
                  .selectedColor(this.accentColor())
                  .hitTestBehavior(HitTestMode.None)
              }
              .width('100%')
              .height(58)
              .padding({ left: 20, right: 20 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.togglePendingCardToken(token.id);
              })
            }
          }, (token: TokenRecord) => token.id)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(HOME_LIST_CACHE_COUNT, true)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button(this.t('取消'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.searchBackgroundColor())
          .onClick(() => {
            this.showCardTokenPicker = false;
          })

        Button(this.t('完成'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.accentContrastColor())
          .backgroundColor(this.accentColor())
          .onClick(() => {
            this.commitCardTokenSelection();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: this.naviIndicatorHeight + 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private HomeSearchGroupHeader() {
    Column() {
      this.HomeSearchListHeader()
    }
    .width('100%')
    .padding({ bottom: PAGE_CARD_GAP })
  }

  @Builder
  private TokenListFooter() {
    Text(this.tf('- 共{0}个 -', [`${this.filteredTokens().length}`]))
      .fontSize(12)
      .fontColor(this.secondaryTextColor())
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 50, bottom: 28 })
  }

  @Builder
  private HomeSearchListHeader() {
    Row() {
      Stack() {
        this.HomeSearchBar()
      }
      .width('100%')
      .height(HOME_SEARCH_HEIGHT)
      .opacity(1 - this.searchCollapseProgress())
      .hitTestBehavior(this.searchCollapseProgress() > 0.55 ? HitTestMode.None : HitTestMode.Default)
    }
    .width('100%')
    .height(HOME_SEARCH_HEADER_HEIGHT)
    .clip(false)
  }

  @Builder
  private HomeSearchBar() {
    Stack({ alignContent: Alignment.Center }) {
      Search({ value: this.searchText, placeholder: this.t('搜索令牌') })
        .height(HOME_SEARCH_HEIGHT)
        .width('100%')
        .borderRadius(HOME_SEARCH_HEIGHT / 2)
        .backgroundColor(Color.Transparent)
        .placeholderColor(this.secondaryTextColor())
        .fontColor(this.primaryTextColor())
        .searchIcon({ size: HOME_SEARCH_ICON_SIZE, color: this.secondaryTextColor() })
        .textFont({ size: HOME_SEARCH_TEXT_SIZE })
        .placeholderFont({ size: HOME_SEARCH_TEXT_SIZE })
        .onChange((value: string) => {
          this.searchText = value;
        })
    }
    .height(HOME_SEARCH_HEIGHT)
    .width('100%')
    .borderRadius(HOME_SEARCH_HEIGHT / 2)
    .clip(true)
    .backgroundColor(this.searchBackgroundColor())
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 1, color: this.searchBorderColor() })
  }

  private homeSearchMenu(): HdsNavigationMenuContentOptions {
    if (this.isWatchLayout() || this.selectedHomeTab !== HomeTab.Token) {
      return { value: [], maxCount: 0 };
    }

    if (!this.isHomeSearchCollapsed) {
      return {
        value: [
          {
            content: {
              icon: this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ?
              $r('app.media.ic_layout_single_black') : $r('app.media.ic_layout_double_black'),
              label: this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? this.t('单列') : this.t('双列'),
              action: () => {
                this.toggleTokenLayoutMode();
              }
            }
          }
        ],
        maxCount: 1
      };
    }

    return {
      value: [
        {
          content: {
            icon: $r('app.media.ic_home_search_black'),
            label: this.t('搜索'),
            action: () => {
              this.scrollHomeSearchIntoView();
            }
          }
        },
        {
          content: {
            icon: this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ?
            $r('app.media.ic_layout_single_black') : $r('app.media.ic_layout_double_black'),
            label: this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? this.t('单列') : this.t('双列'),
            action: () => {
              this.toggleTokenLayoutMode();
            }
          }
        }
      ],
      maxCount: 2
    };
  }

  private tokenListLaneCount(): number {
    const baseCount = this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? 2 : 1;
    const minWidth = this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? RESPONSIVE_DOUBLE_CARD_MIN_WIDTH :
    RESPONSIVE_CARD_MIN_WIDTH;
    const availableWidth = Math.max(1, this.pageWidth - HOME_HORIZONTAL_PADDING * 2);
    const responsiveCount = Math.max(1,
      Math.floor((availableWidth + PAGE_CARD_GAP) / (minWidth + PAGE_CARD_GAP)));
    return Math.max(baseCount, responsiveCount);
  }

  private emptyTokenStateHeight(): number {
    const topSpace = this.statusBarHeight + HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP + HOME_SEARCH_HEADER_HEIGHT +
    PAGE_CARD_GAP;
    const bottomSpace = this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP;
    return Math.max(260, this.pageHeight - topSpace - bottomSpace);
  }

  private toggleTokenLayoutMode(): void {
    this.tokenLayoutMode = this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? TOKEN_LAYOUT_SINGLE : TOKEN_LAYOUT_DOUBLE;
    this.resetTokenSwipe();
    this.saveSettings();
  }

  private tokenTabBarStyle(): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.key_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.primaryTextColor()]),
      selected: new SymbolGlyphModifier($r('sys.symbol.key_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.accentColor()])
    }, this.t('令牌'))
      .labelStyle({
        font: { size: HOME_NAV_TEXT_SIZE },
        unselectedColor: this.primaryTextColor(),
        selectedColor: this.accentColor()
      });
  }

  private meTabBarStyle(): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.primaryTextColor()]),
      selected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.accentColor()])
    }, this.t('我的'))
      .labelStyle({
        font: { size: HOME_NAV_TEXT_SIZE },
        unselectedColor: this.primaryTextColor(),
        selectedColor: this.accentColor()
      });
  }

  @Builder
  private AddFloatingButton() {
    Stack({ alignContent: Alignment.Center }) {
      this.AdaptiveAccentCircle($r('app.media.ic_add_page'), ADD_BUTTON_SIZE, ADD_BUTTON_ICON_SIZE, () => {
        if (!this.addButtonDragging) {
          this.isAddMenuOpen = true;
        }
      })
    }
    .width(ADD_BUTTON_SIZE)
    .height(ADD_BUTTON_SIZE)
    .clip(false)
    .margin({
      left: this.isLeftHanded() ? ADD_BUTTON_RIGHT : 0,
      right: this.isLeftHanded() ? 0 : ADD_BUTTON_RIGHT,
      bottom: ADD_BUTTON_BOTTOM
    })
    .translate({ x: this.addButtonOffsetX, y: this.addButtonOffsetY })
    .gesture(PanGesture({ direction: PanDirection.All, distance: 4 })
      .onActionStart(() => {
        this.addButtonDragging = false;
        this.addButtonDragStartX = this.addButtonOffsetX;
        this.addButtonDragStartY = this.addButtonOffsetY;
      })
      .onActionUpdate((event: GestureEvent) => {
        if (Math.abs(event.offsetX) > 3 || Math.abs(event.offsetY) > 3) {
          this.addButtonDragging = true;
        }
        this.addButtonOffsetX = this.clampAddButtonOffsetX(this.addButtonDragStartX + event.offsetX);
        this.addButtonOffsetY = this.clampAddButtonOffsetY(this.addButtonDragStartY + event.offsetY);
      })
      .onActionEnd(() => {
        this.addButtonOffsetX = this.snapAddButtonOffsetX(this.addButtonOffsetX);
        setTimeout(() => {
          this.addButtonDragging = false;
        }, 80);
      }))
    .bindSheet(this.isAddMenuOpen, this.AddMethodSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
      backgroundColor: this.isDarkTheme() ? '#F2303030' : '#FAFFFFFF',
      blurStyle: BlurStyle.COMPONENT_THIN,
      radius: LengthMetrics.vp(32),
      onDisappear: () => {
        this.isAddMenuOpen = false;
      }
    })
    .zIndex(20)
  }

  private clampAddButtonOffsetX(value: number): number {
    const baseX = this.isLeftHanded() ? ADD_BUTTON_RIGHT : this.pageWidth - ADD_BUTTON_RIGHT - ADD_BUTTON_SIZE;
    const minX = -baseX;
    const maxX = this.pageWidth - ADD_BUTTON_SIZE - baseX;
    return Math.max(minX, Math.min(maxX, value));
  }

  private snapAddButtonOffsetX(value: number): number {
    const baseX = this.isLeftHanded() ? ADD_BUTTON_RIGHT : this.pageWidth - ADD_BUTTON_RIGHT - ADD_BUTTON_SIZE;
    const currentCenterX = baseX + value + ADD_BUTTON_SIZE / 2;
    const targetX = currentCenterX < this.pageWidth / 2 ?
      ADD_BUTTON_RIGHT : this.pageWidth - ADD_BUTTON_RIGHT - ADD_BUTTON_SIZE;
    return this.clampAddButtonOffsetX(targetX - baseX);
  }

  private clampAddButtonOffsetY(value: number): number {
    const baseY = this.pageHeight - ADD_BUTTON_BOTTOM - ADD_BUTTON_SIZE;
    const minY = -baseY;
    const maxY = this.pageHeight - ADD_BUTTON_SIZE - baseY;
    return Math.max(minY, Math.min(maxY, value));
  }

  private isLeftHanded(): boolean {
    return this.smartGripEnabled &&
      this.holdingHandStatus === HoldingHandStatus.LEFT_HAND_HELD;
  }

  @Builder
  private AddMethodSheet() {
    Row() {
      this.AddMethodButton('录入', $r('app.media.ic_sheet_manual_input'), () => {
        this.isAddMenuOpen = false;
        this.openAddPage();
      })

      this.AddMethodButton('扫码', $r('app.media.ic_sheet_scan'), () => {
        this.isAddMenuOpen = false;
        this.scanTokenFromQrCode();
      })

      this.AddMethodButton('导入', $r('app.media.ic_sheet_import'), () => {
        this.isAddMenuOpen = false;
        this.importTokenFile();
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: 32,
      right: 32,
      top: 24,
      bottom: this.naviIndicatorHeight + 16
    })
  }

  @Builder
  private AddMethodButton(label: string, icon: Resource, onClick: () => void) {
    Column({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        this.SolidAccentCircle(icon, 50, 20, onClick)
      }
        .width(50)
        .height(50)
        .clip(false)

      Text(this.t(label))
        .fontSize(14)
        .fontColor(this.primaryTextColor())
        .fontWeight(FontWeight.Medium)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SolidAccentCircle(icon: Resource, size: number, iconSize: number, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .objectFit(ImageFit.Contain)
        .fillColor('#FFFFFF')
    }
    .width(size)
    .height(size)
    .padding(0)
    .backgroundColor(this.accentColor())
    .border({ width: 0.5, color: '#FFFFFF' })
    .stateEffect(true)
    .onClick(onClick)
  }

  @Builder
  private AdaptiveAccentCircle(icon: Resource, size: number, iconSize: number, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .objectFit(ImageFit.Contain)
        .fillColor('#FFFFFF')
    }
    .width(size)
    .height(size)
    .padding(0)
    .backgroundColor(this.accentColor())
    .backgroundEffect({
      radius: 18,
      saturation: 1.2,
      brightness: 1.05,
      color: this.accentColor(),
      adaptiveColor: AdaptiveColor.DEFAULT
    }, { disableSystemAdaptation: false })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
      .pointLight({
        sourceType: hdsEffect.PointLightSourceType.SOFT,
        illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER,
        options: {
          color: '#FFFFFF',
          intensity: 0.35,
          height: 12,
          bloom: 0.25
        }
      })
      .buildEffect())
    .border({ width: 0.5, color: '#FFFFFF' })
    .stateEffect(true)
    .onClick(onClick)
  }

  @Builder
  private TokenListItem(token: TokenRecord) {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        Row() {
          this.TokenSwipeActions(token)
        }
        .width('100%')
        .height(TOKEN_CARD_HEIGHT)
        .justifyContent(FlexAlign.End)
        .backgroundColor(this.tokenListItemBackgroundColor())

        Row() {
          this.TokenCard(token)
        }
        .width('100%')
        .height(TOKEN_CARD_HEIGHT)
        .translate({ x: this.tokenSwipeOffset(token.id) })
        .animation({ duration: 220, curve: Curve.Smooth })
        .gesture(PanGesture({ direction: PanDirection.Horizontal })
          .onActionUpdate((event: GestureEvent) => {
            this.handleTokenPanUpdate(token.id, event.offsetX);
          })
          .onActionEnd((event: GestureEvent) => {
            this.handleTokenPanEnd(token.id, event.offsetX);
          }))
      }
      .width('100%')
      .height(TOKEN_CARD_HEIGHT)
      .borderRadius(TOKEN_CARD_RADIUS)
      .clip(true)
      .backgroundColor(this.tokenListItemBackgroundColor())
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .borderRadius(TOKEN_CARD_RADIUS)
    .clip(true)
    .opacity(this.draggingTokenId === token.id ? 0.92 : 1)
    .animation({ duration: 120, curve: Curve.Smooth })
  }

  private tokenListItemBackgroundColor(): string {
    return this.pageBackgroundColor();
  }

  @Builder
  private TokenCard(token: TokenRecord) {
    if (this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE) {
      this.TokenDoubleColumnCard(token)
    } else {
      this.TokenSingleColumnCard(token)
    }
  }

  @Builder
  private TokenSingleColumnCard(token: TokenRecord) {
    Column() {
      Row({ space: 14 }) {
        this.IssuerLogoView(this.tokenLogoUri(token), token.name, token.remark, TOKEN_LOGO_SIZE,
          token.logoSource !== LOGO_SOURCE_MANUAL)

        Column({ space: 4 }) {
          Text(this.tokenDisplayName(token))
            .fontSize(TOKEN_NAME_TEXT_SIZE)
            .fontColor(this.primaryTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            Text(this.tokenCode(token))
              .fontSize(TOKEN_CODE_TEXT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.tokenValueColor())
              .letterSpacing(0)
              .maxLines(1)
              .contentTransition(new NumericTextTransition({
                flipDirection: FlipDirection.UP,
                enableBlur: true
              }))
              .animation({ duration: 400, curve: Curve.Smooth })

            if (this.showNextToken) {
              Text('←')
                .fontSize(12)
                .fontColor(this.nexttokenValueColor())
                .fontWeight(FontWeight.Regular)
                .opacity(0.65)

              Text(this.nextTokenCode(token))
                .fontSize(TOKEN_NEXT_CODE_TEXT_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.nexttokenValueColor())
                .letterSpacing(0)
                .maxLines(1)
                .contentTransition(new NumericTextTransition({
                  flipDirection: FlipDirection.UP,
                  enableBlur: true
                }))
                .animation({ duration: 400, curve: Curve.Smooth })
            }
          }
          .alignItems(VerticalAlign.Center)
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .height('100%')

        this.TokenCountdownRing(token)
      }
      .width('100%')
      .height(TOKEN_CARD_HEIGHT)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
      .borderRadius(TOKEN_CARD_RADIUS)
      .backgroundColor(this.cardBackgroundColor())
      .onClick(() => {
        this.handleTokenCardClick(token);
      })

    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
  }

  @Builder
  private TokenDoubleColumnCard(token: TokenRecord) {
    Row({ space: 10 }) {
      this.IssuerLogoView(this.tokenLogoUri(token), token.name, token.remark, TOKEN_LOGO_SIZE,
        token.logoSource !== LOGO_SOURCE_MANUAL)

      Column({ space: 6 }) {
        Text(this.tokenDisplayName(token))
          .fontSize(TOKEN_NAME_TEXT_SIZE)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.tokenCode(token))
          .fontSize(TOKEN_CODE_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.tokenValueColor())
          .letterSpacing(0)
          .maxLines(1)
          .contentTransition(new NumericTextTransition({
            flipDirection: FlipDirection.UP,
            enableBlur: true
          }))
          .animation({ duration: 400, curve: Curve.Smooth })
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(TOKEN_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
    .onClick(() => {
      this.handleTokenCardClick(token);
    })
  }

  private handleTokenCardClick(token: TokenRecord): void {
    if (this.openSwipeTokenId === token.id) {
      this.resetTokenSwipe();
    } else {
      this.copyTokenCode(token);
    }
    this.activeSwipeTokenId = '';
    this.activeSwipeOffset = 0;
  }

  @Builder
  private TokenCountdownRing(token: TokenRecord) {
    Stack() {
      if (this.normalizeTokenType(token.type) !== 'HOTP') {
        DataPanel({
          values: [this.tokenCountdownProgress(token)],
          max: 100,
          type: DataPanelType.Circle
        })
          .width(TOKEN_COUNTDOWN_SIZE)
          .height(TOKEN_COUNTDOWN_SIZE)
          .valueColors(this.tokenCountdownColors(token))
          .trackBackgroundColor('#00000000')
          .strokeWidth(TOKEN_COUNTDOWN_STROKE)
          .closeEffect(true)
      }

      Text(this.tokenCountdownText(token))
        .fontSize(this.normalizeTokenType(token.type) === 'HOTP' ? 8 : 12)
        .fontColor(this.primaryTextColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
    }
    .width(TOKEN_COUNTDOWN_SIZE)
    .height(TOKEN_COUNTDOWN_SIZE)
    .margin({ left: 8 })
  }

  @Builder
  private IssuerLogoView(logoUri: string, name: string, issuer: string, size: number, allowLocalLogo: boolean) {
    if (allowLocalLogo && this.localIssuerLogoKey(name, issuer) === 'openai') {
      Image(this.isDarkTheme() ? $r('app.media.logo_openai_dark') : $r('app.media.logo_openai_light'))
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Contain)
    } else if (logoUri.length > 0) {
      Image(logoUri)
        .width(size)
        .height(size)
        .borderRadius(size / 2)
        .objectFit(allowLocalLogo ? ImageFit.Contain : ImageFit.Cover)
        .clip(true)
    } else {
      Stack() {
        Circle()
          .width(size)
          .height(size)
          .fill(this.accentColor())
        Text(this.issuerLogoLetter(name, issuer))
          .fontSize(Math.max(16, Math.floor(size * 0.44)))
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(size)
      .height(size)
    }
  }

  @Builder
  private TokenSwipeActions(token: TokenRecord) {
    Row({ space: SWIPE_ACTION_GAP }) {
      this.SwipeActionButton($r('app.media.ic_token_edit'), () => {
        this.resetTokenSwipe();
        this.openEditPage(token);
      })

      this.SwipeActionButton($r('app.media.ic_token_delete'), () => {
        this.resetTokenSwipe();
        this.confirmDeleteToken(token);
      })
    }
    .width(SWIPE_ACTION_AREA_WIDTH)
    .height(TOKEN_CARD_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private SwipeActionButton(icon: Resource, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      Image(icon)
        .width(SWIPE_ACTION_SIZE)
        .height(SWIPE_ACTION_SIZE)
        .objectFit(ImageFit.Contain)
    }
    .width(SWIPE_ACTION_SIZE)
    .height(SWIPE_ACTION_SIZE)
    .backgroundColor(Color.Transparent)
    .padding(0)
    .onClick(onClick)
  }

  @Builder
  private AddTokenContent() {
    Scroll(this.addPageScroller) {
      Column() {
        this.AddTokenLogoEditor()

        GridRow({
          columns: { xs: 1, sm: 2, md: 2, lg: 2, xl: 2, xxl: 2 },
          gutter: PAGE_CARD_GAP,
          breakpoints: {
            value: ['600vp'],
            reference: BreakpointsReference.ComponentSize
          }
        }) {
          GridCol({ span: { xs: 1, sm: 1, md: 1, lg: 1, xl: 1, xxl: 1 } }) {
            this.AddTokenBasicCard()
          }

          GridCol({ span: { xs: 1, sm: 1, md: 1, lg: 1, xl: 1, xxl: 1 } }) {
            this.AddTokenDetailCard()
          }
        }
        .width('100%')
        .margin({ top: PAGE_CARD_GAP })

        if (this.validationMessage.length > 0) {
          Text(this.t(this.validationMessage))
            .fontSize(14)
            .fontColor(ERROR_RED)
            .width('100%')
            .margin({ top: PAGE_CARD_GAP, left: 8 })
        }

        Button() {
          Text(this.isSaving ? this.t('保存中') : this.t('确认'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.canSaveToken() ? this.cardBackgroundColor() : this.disabledButtonTextColor())
        }
        .height(46)
        .width('100%')
        .borderRadius(24)
        .backgroundColor(this.canSaveToken() ? this.accentColor() : this.disabledColor())
        .margin({ top: PAGE_CARD_GAP })
        .enabled(this.canSaveToken())
        .onClick(() => {
          this.saveToken();
        })
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP,
        bottom: this.naviIndicatorHeight + 24
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
  }

  @Builder
  private AddTokenLogoEditor() {
    Column({ space: 12 }) {
      Stack() {
        ForEach([this.formLogoRenderVersion], (version: number) => {
          this.IssuerLogoView(this.formLogoUri(), this.nameInput, this.remarkInput, FORM_LOGO_SIZE,
            this.logoSourceInput !== LOGO_SOURCE_MANUAL)
        }, (version: number) => {
          return 'form-logo-' + version.toString() + '-' + this.formLogoUri();
        })
        Circle()
          .width(FORM_LOGO_SIZE)
          .height(FORM_LOGO_SIZE)
          .fill('#80000000')
        Image($r('app.media.ic_sheet_manual_input'))
          .width(36)
          .height(36)
          .objectFit(ImageFit.Contain)
      }
      .width(FORM_LOGO_SIZE)
      .height(FORM_LOGO_SIZE)
      .onClick(() => {
        this.pickIssuerLogo();
      })

      Text(this.t('根据发行方带出，可修改'))
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private AddTokenBasicCard() {
    Column() {
      this.InputRow('名称', this.nameInput, '请输入', (value: string) => {
        this.nameInput = value;
        this.validationMessage = '';
        this.scheduleFormLogoLookup();
      })
      this.Separator()
      this.InputRow('发行方', this.remarkInput, '请输入', (value: string) => {
        this.remarkInput = value;
        this.validationMessage = '';
        this.scheduleFormLogoLookup();
      })
      this.Separator()
      this.SecretInputRow('密钥', this.secretInput, '请输入', (value: string) => {
        this.secretInput = value;
        this.validationMessage = value.trim().length > 0 &&
          !Totp.isValidSecret(value, this.formTokenType()) ?
          '密钥格式无效，请输入有效的Base32密钥' : '';
      })
    }
    .width('100%')
    .height(FORM_BASIC_CARD_HEIGHT)
    .padding({ left: 24, right: 20 })
    .borderRadius(15)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private AddTokenDetailCard() {
    Column() {
      this.SelectRow('类型', this.formTokenType(), TYPE_OPTIONS, (value: string) => {
        this.typeInput = this.normalizeTokenType(value);
        this.applyTypeDefaults();
        this.validationMessage = '';
        this.scheduleFormLogoLookup();
      })
      this.Separator()
      this.AlgorithmSelectRow()
      this.Separator()
      this.TokenLengthSelectRow()
      this.Separator()
      this.RefreshTimeSelectRow()
    }
    .width('100%')
    .height(FORM_DETAIL_CARD_HEIGHT)
    .padding({ left: 24, right: 20 })
    .borderRadius(15)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private InputRow(label: string, value: string, placeholder: string, onChanged: (value: string) => void) {
    Row() {
      this.RequiredFieldLabel(label)

      TextInput({ text: value, placeholder: this.t(placeholder) })
        .height(FORM_ROW_HEIGHT - 1)
        .layoutWeight(1)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
        .placeholderColor(this.secondaryTextColor())
        .placeholderFont({ size: FORM_TEXT_SIZE })
        .backgroundColor(Color.Transparent)
        .textAlign(TextAlign.End)
        .padding({ left: 8, right: 0 })
        .onChange((text: string) => {
          onChanged(text);
        })
    }
    .width('100%')
    .height(FORM_ROW_HEIGHT)
  }

  @Builder
  private SecretInputRow(label: string, value: string, placeholder: string, onChanged: (value: string) => void) {
    Row() {
      this.RequiredFieldLabel(label)

      TextInput({ text: value, placeholder: this.t(placeholder) })
        .height(FORM_ROW_HEIGHT - 1)
        .layoutWeight(1)
        .type(InputType.Password)
        .showPasswordIcon(true)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
        .placeholderColor(this.secondaryTextColor())
        .placeholderFont({ size: FORM_TEXT_SIZE })
        .backgroundColor(Color.Transparent)
        .textAlign(TextAlign.End)
        .padding({ left: 8, right: 0 })
        .onChange((text: string) => {
          onChanged(text);
        })
    }
    .width('100%')
    .height(FORM_ROW_HEIGHT)
  }

  @Builder
  private RequiredFieldLabel(label: string) {
    Row({ space: 6 }) {
      Text('*')
        .fontSize(18)
        .fontColor(ERROR_RED)
        .fontWeight(FontWeight.Medium)
      Text(this.t(label))
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
    }
    .width(92)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SelectRow(
    label: string,
    selectedValue: string,
    values: SelectOption[],
    onSelected: (value: string) => void
  ) {
    Row() {
      this.RequiredFieldLabel(label)

      Row() {
        Select(this.localizedOptions(values))
          .selected(this.optionIndex(values, selectedValue))
          .value(this.t(selectedValue))
          .font({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .fontColor(this.primaryTextColor())
          .selectedOptionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .selectedOptionFontColor(this.primaryTextColor())
          .selectedOptionBgColor(this.accentColor())
          .optionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .onSelect((index: number, value: string) => {
            onSelected(`${values[index].value}`);
          })
      }
      .height(FORM_ROW_HEIGHT - 1)
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(FORM_ROW_HEIGHT)
  }

  @Builder
  private AlgorithmSelectRow() {
    if (this.formTokenType() === 'TOTP') {
      this.SelectRow('算法', this.formAlgorithm(), ALGORITHM_OPTIONS, (value: string) => {
        this.algorithmInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    } else {
      this.SelectRow('算法', 'SHA1', SHA1_OPTIONS, (value: string) => {
        this.algorithmInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    }
  }

  @Builder
  private TokenLengthSelectRow() {
    if (this.formTokenType() === 'Steam') {
      this.SelectRow('令牌长度', '5位', STEAM_TOKEN_LENGTH_OPTIONS, (value: string) => {
        this.tokenLengthInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    } else if (this.formTokenType() === 'HOTP') {
      this.SelectRow('令牌长度', this.formTokenLength(), HOTP_TOKEN_LENGTH_OPTIONS, (value: string) => {
        this.tokenLengthInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    } else {
      this.SelectRow('令牌长度', this.formTokenLength(), TOKEN_LENGTH_OPTIONS, (value: string) => {
        this.tokenLengthInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    }
  }

  @Builder
  private RefreshTimeSelectRow() {
    if (this.formTokenType() === 'HOTP') {
      this.SelectRow('刷新时间', '不刷新', NO_REFRESH_TIME_OPTIONS, (value: string) => {
        this.refreshTimeInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    } else if (this.formTokenType() === 'Steam') {
      this.SelectRow('刷新时间', '30秒', STEAM_REFRESH_TIME_OPTIONS, (value: string) => {
        this.refreshTimeInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    } else {
      this.SelectRow('刷新时间', this.formRefreshTime(), REFRESH_TIME_OPTIONS, (value: string) => {
        this.refreshTimeInput = value;
        this.applyTypeDefaults();
        this.validationMessage = '';
      })
    }
  }

  private optionIndex(values: SelectOption[], selectedValue: string): number {
    for (let index = 0; index < values.length; index++) {
      if (values[index].value === selectedValue) {
        return index;
      }
    }
    return 0;
  }

  private applyColorMode(): void {
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.themeModeInput === '深色') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (this.themeModeInput === '浅色') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      this.showToast('无法切换深浅色模式');
    }
  }

  private refreshSystemLanguage(): void {
    try {
      this.systemLanguage = i18n.System.getSystemLanguage();
    } catch (error) {
      this.systemLanguage = 'zh-Hans';
    }
  }

  private t(text: string): string {
    return translate(text, this.languageInput, this.systemLanguage);
  }

  private tf(text: string, values: string[]): string {
    let result = this.t(text);
    values.forEach((value: string, index: number) => {
      result = result.replace(`{${index}}`, value);
    });
    return result;
  }

  private localizedOptions(values: SelectOption[]): SelectOption[] {
    return values.map((option: SelectOption): SelectOption => {
      return { value: this.t(`${option.value}`) };
    });
  }

  private isDarkTheme(): boolean {
    return this.themeModeInput === '深色' || (this.themeModeInput === '跟随系统' && this.systemDark);
  }

  private accentColor(): string {
    const dark = this.isDarkTheme();
    if (this.themeColorInput === '奶油黄') {
      return dark ? '#E4CA7B' : '#D6B75D';
    }
    if (this.themeColorInput === '鼠尾草绿') {
      return dark ? '#8DBBA5' : '#72A28B';
    }
    if (this.themeColorInput === '雾霾蓝') {
      return dark ? '#8AB4C9' : '#6F98AE';
    }
    if (this.themeColorInput === '灰豆沙粉') {
      return dark ? '#DDAEB9' : '#CE96A4';
    }
    if (this.themeColorInput === '清透炭黑') {
      return dark ? '#73777D' : '#292C30';
    }
    return dark ? '#F2CF3A' : '#E5BA0B';
  }

  private accentContrastColor(): string {
    return this.themeColorInput === '清透炭黑' ? '#FFFFFF' : '#1A1A1A';
  }

  private lightenColor(hex: string, amount: number): string {
    const r = Math.min(255, parseInt(hex.substring(1, 3), 16) + amount);
    const g = Math.min(255, parseInt(hex.substring(3, 5), 16) + amount);
    const b = Math.min(255, parseInt(hex.substring(5, 7), 16) + amount);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  private darkenColor(hex: string, amount: number): string {
    const r = Math.max(0, parseInt(hex.substring(1, 3), 16) - amount);
    const g = Math.max(0, parseInt(hex.substring(3, 5), 16) - amount);
    const b = Math.max(0, parseInt(hex.substring(5, 7), 16) - amount);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  private accentColorWithAlpha(alpha: number): string {
    const hex = this.accentColor();
    const a = Math.round(alpha).toString(16).padStart(2, '0');
    return `#${a}${hex.substring(1)}`;
  }

  private pageBackgroundColor(): string {
    return this.isDarkTheme() ? '#000000' : '#F2F3F5';
  }

  private cardBackgroundColor(): string {
    return this.isDarkTheme() ? '#191919' : '#FFFFFF';
  }

  private primaryTextColor(): string {
    return this.isDarkTheme() ? '#EEEEEE' : '#1A1A1A';
  }

  private tokenValueColor(): string {
    return this.isDarkTheme() ? '#FFFFFF' : '#000000';
  }

  private nexttokenValueColor(): string {
    return this.isDarkTheme() ? '#747474' : '#747474';
  }

  private secondaryTextColor(): string {
    return this.isDarkTheme() ? '#A3A3A3' : '#777777';
  }

  private dividerColor(): string {
    return this.isDarkTheme() ? '#444444' : '#E6E6E6';
  }

  private swipeRevealBackgroundColor(): string {
    return this.isDarkTheme() ? '#191919' : '#E6E9EA';
  }

  private searchBackgroundColor(): string {
    return this.isDarkTheme() ? '#E6303030' : '#F7FFFFFF';
  }

  private searchBorderColor(): string {
    return this.isDarkTheme() ? '#33FFFFFF' : '#FFFFFFFF';
  }

  private disabledColor(): string {
    return this.isDarkTheme() ? '#555555' : '#DADBDD';
  }

  private disabledButtonTextColor(): string {
    return this.isDarkTheme() ? '#E2E2E2' : '#555555';
  }

  @Builder
  private Separator() {
    Divider()
      .strokeWidth(1)
      .color(this.dividerColor())
  }

  private currentHomeTitle(): string {
    if (this.isWatchLayout()) {
      return this.t('令牌');
    }
    return this.selectedHomeTab === HomeTab.Token ? this.t('令牌') : this.t('我的');
  }

  private isWatchLayout(): boolean {
    const deviceType = this.deviceType.toLowerCase();
    return deviceType.indexOf('wear') >= 0 || deviceType.indexOf('watch') >= 0 ||
      (this.pageWidth <= WATCH_LAYOUT_MAX_WIDTH && this.pageHeight <= WATCH_LAYOUT_MAX_HEIGHT);
  }

  private shouldShowAddFloatingButton(): boolean {
    return !this.isWatchLayout() && this.selectedHomeTab === HomeTab.Token &&
      this.pageMode === PageMode.Home && this.homePathStack.size() === 0;
  }

  private homeNavigationScrollers(): Scroller[] {
    if (this.isWatchLayout()) {
      return [this.watchScroller];
    }
    return this.selectedHomeTab === HomeTab.Token ? [this.homeScroller] : [this.meScroller];
  }

  private navigationDestinationTitle(name: string): string {
    if (name === 'addToken') {
      return this.editingTokenId.length > 0 ? this.t('编辑令牌') : this.t('新增令牌');
    }
    if (name === 'cloudSpace') {
      return this.t('华为云空间');
    }
    return this.t('设置');
  }

  private navigationDestinationScrollers(name: string): Scroller[] {
    if (name === 'addToken') {
      return [this.addPageScroller];
    }
    if (name === 'cloudSpace') {
      return [this.cloudSpaceScroller];
    }
    return [this.settingsScroller];
  }

  private tokenDisplayName(token: TokenRecord): string {
    const remark = token.remark.trim();
    if (remark.length === 0) {
      return token.name;
    }
    return systemLanguageTag(this.languageInput, this.systemLanguage).startsWith('en') ?
      `${token.name} (${remark})` : `${token.name}（${remark}）`;
  }

  private issuerLogoLetter(name: string, issuer: string): string {
    const source = name.trim().length > 0 ? name.trim() : issuer.trim();
    return source.length > 0 ? source.charAt(0).toUpperCase() : 'A';
  }

  private localIssuerLogoKey(name: string, issuer: string): string {
    const source = `${issuer} ${name}`.toLowerCase();
    if (source.indexOf('openai') >= 0 || source.indexOf('chatgpt') >= 0 || source.indexOf('codex') >= 0) {
      return 'openai';
    }
    return '';
  }

  private tokenLogoUri(token: TokenRecord): string {
    const type = this.normalizeTokenType(token.type);
    if (token.logoSource === LOGO_SOURCE_MANUAL && type !== 'Steam') {
      return token.logoUri || '';
    }
    if (this.issuerLogoColorMode === '品牌色') {
      return token.logoUri || token.logoLightUri || token.logoDarkUri || '';
    }
    return this.isDarkTheme() ? (token.logoDarkUri || token.logoUri || '') : (token.logoLightUri || token.logoUri || '');
  }

  private formLogoUri(): string {
    if (this.logoSourceInput === LOGO_SOURCE_MANUAL && this.formTokenType() !== 'Steam') {
      return this.logoUriInput;
    }
    if (this.issuerLogoColorMode === '品牌色') {
      return this.logoUriInput || this.logoLightUriInput || this.logoDarkUriInput;
    }
    return this.isDarkTheme() ? (this.logoDarkUriInput || this.logoUriInput) : (this.logoLightUriInput || this.logoUriInput);
  }

  private logoLookupIssuer(type: string, issuer: string): string {
    return this.normalizeTokenType(type) === 'Steam' ? 'steam' : issuer;
  }

  private logoLookupName(type: string, name: string): string {
    return this.normalizeTokenType(type) === 'Steam' ? 'steam' : name;
  }

  private refreshTokenLogoDisplay(): void {
    this.logoRenderVersion += 1;
    this.tokens = this.tokens.map((token: TokenRecord): TokenRecord => {
      return this.cloneTokenRecord(token);
    });
    this.updateWidgetCards();
  }

  private cloneTokenRecord(token: TokenRecord): TokenRecord {
    return {
      id: token.id,
      name: token.name,
      remark: token.remark,
      type: token.type,
      algorithm: token.algorithm,
      secret: token.secret,
      logoUri: token.logoUri,
      logoLightUri: token.logoLightUri,
      logoDarkUri: token.logoDarkUri,
      logoSource: token.logoSource,
      digits: token.digits,
      period: token.period,
      counter: token.counter,
      createdAt: token.createdAt
    };
  }

  private tokenSwipeOffset(tokenId: string): number {
    if (this.activeSwipeTokenId === tokenId) {
      return this.activeSwipeOffset;
    }
    return this.openSwipeTokenId === tokenId ? -SWIPE_ACTION_AREA_WIDTH : 0;
  }

  private handleTokenPanUpdate(tokenId: string, offsetX: number): void {
    this.activeSwipeTokenId = tokenId;
    if (this.openSwipeTokenId === tokenId) {
      this.activeSwipeOffset = Math.max(-SWIPE_ACTION_AREA_WIDTH, Math.min(0, -SWIPE_ACTION_AREA_WIDTH + offsetX));
    } else {
      this.activeSwipeOffset = Math.max(-SWIPE_ACTION_AREA_WIDTH, Math.min(0, offsetX));
    }
  }

  private handleTokenPanEnd(tokenId: string, offsetX: number): void {
    if (offsetX < -30) {
      this.openSwipeTokenId = tokenId;
    } else if (offsetX > 20 || this.openSwipeTokenId === tokenId) {
      this.openSwipeTokenId = '';
    }
    this.activeSwipeTokenId = '';
    this.activeSwipeOffset = 0;
  }

  private resetTokenSwipe(): void {
    this.openSwipeTokenId = '';
    this.activeSwipeTokenId = '';
    this.activeSwipeOffset = 0;
  }

  private handleTokenDragStart(index: number): void {
    if (!this.canMoveTokenList()) {
      this.draggingTokenId = '';
      return;
    }
    const token = this.tokens[index];
    this.draggingTokenId = token ? token.id : '';
    this.resetTokenSwipe();
  }

  private handleTokenMove(from: number, to: number): void {
    if (!this.canMoveTokenList() || from === to || from < 0 || to < 0 ||
      from >= this.tokens.length || to >= this.tokens.length) {
      return;
    }

    const nextTokens = this.tokens.slice();
    const movedTokens = nextTokens.splice(from, 1);
    if (movedTokens.length === 0) {
      return;
    }

    nextTokens.splice(to, 0, movedTokens[0]);
    this.tokens = nextTokens;
    this.tokenDragReordered = true;
  }

  private handleTokenDragDrop(): void {
    this.draggingTokenId = '';
    if (!this.tokenDragReordered) {
      return;
    }
    this.tokenDragReordered = false;
    this.saveTokenOrder();
  }

  private canMoveTokenList(): boolean {
    return this.searchText.trim().length === 0;
  }

  private async saveTokenOrder(): Promise<void> {
    await this.persistTokens(this.tokens, '已排序');
  }

  private tokenDigitsForRecord(token: TokenRecord): number {
    const type = this.normalizeTokenType(token.type);
    if (type === 'Steam') {
      return 5;
    }
    if (type === 'HOTP') {
      return token.digits === 8 ? 8 : DEFAULT_TOKEN_DIGITS;
    }
    if (token.digits === 4 || token.digits === 8) {
      return token.digits;
    }
    return DEFAULT_TOKEN_DIGITS;
  }

  private tokenPeriodForRecord(token: TokenRecord): number {
    if (this.normalizeTokenType(token.type) === 'Steam') {
      return DEFAULT_TOKEN_PERIOD;
    }
    return token.period === 60 ? 60 : DEFAULT_TOKEN_PERIOD;
  }

  private tokenCounterForRecord(token: TokenRecord): number {
    return token.counter && token.counter > 0 ? Math.floor(token.counter) : 0;
  }

  private tokenCode(token: TokenRecord): string {
    return this.generateTokenCode(token, this.currentTimeMs, this.tokenCounterForRecord(token));
  }

  private async copyTokenCode(token: TokenRecord): Promise<void> {
    try {
      const code = this.tokenCode(token).replace(/\s/g, '');
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showToast('令牌已复制');
    } catch (error) {
      this.showToast('复制失败');
      console.error(`Failed to copy token: ${JSON.stringify(error)}`);
    }
  }

  private nextTokenCode(token: TokenRecord): string {
    if (this.normalizeTokenType(token.type) === 'HOTP') {
      return this.generateTokenCode(token, this.currentTimeMs, this.tokenCounterForRecord(token) + 1);
    }
    return this.generateTokenCode(token, this.currentTimeMs + this.tokenPeriodForRecord(token) * 1000,
      this.tokenCounterForRecord(token));
  }

  private generateTokenCode(token: TokenRecord, timeMs: number, counter: number): string {
    return Totp.formatCode(Totp.generate(
      token.secret,
      timeMs,
      token.algorithm,
      this.tokenDigitsForRecord(token),
      this.tokenPeriodForRecord(token),
      this.normalizeTokenType(token.type),
      counter
    ));
  }

  private tokenTimeText(token: TokenRecord): string {
    if (this.normalizeTokenType(token.type) === 'HOTP') {
      return 'HOTP';
    }
    return this.tf('{0} 秒', [`${Totp.remainingSeconds(this.currentTimeMs, this.tokenPeriodForRecord(token))}`]);
  }

  private tokenCountdownText(token: TokenRecord): string {
    if (this.normalizeTokenType(token.type) === 'HOTP') {
      return 'HOTP';
    }
    return `${this.tokenRemainingSeconds(token)}`;
  }

  private tokenRemainingSeconds(token: TokenRecord): number {
    return Totp.remainingSeconds(this.currentTimeMs, this.tokenPeriodForRecord(token));
  }

  private tokenCountdownProgress(token: TokenRecord): number {
    if (this.normalizeTokenType(token.type) === 'HOTP') {
      return 100;
    }
    return this.tokenRemainingSeconds(token) / this.tokenPeriodForRecord(token) * 100;
  }

  private tokenCountdownColors(token: TokenRecord): Array<ResourceColor | LinearGradient> {
    if (this.tokenRemainingSeconds(token) <= 5) {
      return [this.accentColor()];
    }
    return ['#D5D5D5'];
  }

  private normalizeTokenType(type: string): string {
    const normalized = type.trim().toUpperCase();
    if (normalized === 'STEAM') {
      return 'Steam';
    }
    if (normalized === 'HOTP') {
      return 'HOTP';
    }
    return 'TOTP';
  }

  private tokenDigitsLabel(digits?: number): string {
    if (digits === 4) {
      return '4位';
    }
    if (digits === 5) {
      return '5位';
    }
    if (digits === 8) {
      return '8位';
    }
    return '6位';
  }

  private tokenPeriodLabel(period?: number): string {
    return period === 60 ? '60秒' : '30秒';
  }

  private formTokenType(): string {
    return this.normalizeTokenType(this.typeInput);
  }

  private formAlgorithm(): string {
    return this.formTokenType() === 'TOTP' ? this.normalizeAlgorithm(this.algorithmInput) : 'SHA1';
  }

  private formTokenLength(): string {
    const type = this.formTokenType();
    if (type === 'Steam') {
      return '5位';
    }
    if (type === 'HOTP') {
      return this.tokenLengthInput === '8位' ? '8位' : '6位';
    }
    if (this.tokenLengthInput === '4位' || this.tokenLengthInput === '8位') {
      return this.tokenLengthInput;
    }
    return '6位';
  }

  private formRefreshTime(): string {
    const type = this.formTokenType();
    if (type === 'HOTP') {
      return '不刷新';
    }
    if (type === 'Steam') {
      return '30秒';
    }
    return this.refreshTimeInput === '60秒' ? '60秒' : '30秒';
  }

  private applyTypeDefaults(): void {
    const type = this.normalizeTokenType(this.typeInput);
    this.typeInput = type;

    if (type === 'Steam') {
      this.algorithmInput = 'SHA1';
      this.tokenLengthInput = '5位';
      this.refreshTimeInput = '30秒';
      return;
    }

    if (type === 'HOTP') {
      this.algorithmInput = 'SHA1';
      if (this.tokenLengthInput !== '8位') {
        this.tokenLengthInput = '6位';
      }
      this.refreshTimeInput = '不刷新';
      return;
    }

    this.algorithmInput = this.normalizeAlgorithm(this.algorithmInput);
    this.tokenLengthInput = this.formTokenLength();
    this.refreshTimeInput = this.formRefreshTime();
  }

  private selectedTokenDigits(): number {
    const type = this.formTokenType();
    if (type === 'Steam') {
      return 5;
    }
    if (type === 'HOTP') {
      return this.formTokenLength() === '8位' ? 8 : DEFAULT_TOKEN_DIGITS;
    }
    if (this.formTokenLength() === '4位') {
      return 4;
    }
    if (this.formTokenLength() === '8位') {
      return 8;
    }
    return DEFAULT_TOKEN_DIGITS;
  }

  private selectedTokenPeriod(): number {
    const type = this.formTokenType();
    if (type === 'Steam' || type === 'HOTP') {
      return DEFAULT_TOKEN_PERIOD;
    }
    return this.formRefreshTime() === '60秒' ? 60 : DEFAULT_TOKEN_PERIOD;
  }

  private selectedTokenAlgorithm(): string {
    return this.formAlgorithm();
  }

  private switchHomeTab(tab: HomeTab): void {
    if (this.selectedHomeTab === tab) {
      return;
    }
    this.isAddMenuOpen = false;
    this.selectedHomeTab = tab;
  }

  private canSaveToken(): boolean {
    return !this.isSaving &&
      this.isAddTokenFormComplete() &&
      Totp.isValidSecret(this.effectiveSecretInput(), this.formTokenType());
  }

  private isAddTokenFormComplete(): boolean {
    return this.nameInput.trim().length > 0 &&
      this.remarkInput.trim().length > 0 &&
      this.typeInput.trim().length > 0 &&
      this.algorithmInput.trim().length > 0 &&
      this.effectiveSecretInput().trim().length > 0 &&
      this.tokenLengthInput.trim().length > 0 &&
      this.refreshTimeInput.trim().length > 0;
  }

  private effectiveSecretInput(): string {
    const secret = this.secretInput.trim();
    if (this.editingTokenId.length > 0 &&
      this.editingOriginalSecret.length > 0 &&
      this.isMaskedSecretText(secret)) {
      return this.editingOriginalSecret;
    }
    return this.secretInput;
  }

  private isMaskedSecretText(secret: string): boolean {
    if (secret.length === 0) {
      return false;
    }
    for (let index = 0; index < secret.length; index++) {
      const char = secret.charAt(index);
      if (char !== '*' && char !== '•' && char !== '●') {
        return false;
      }
    }
    return true;
  }

  private async loginHuaweiAccount(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法拉起华为账号登录');
      return;
    }
    if (this.huaweiLoginInProgress) {
      return;
    }
    this.huaweiLoginInProgress = true;
    try {
      await this.delay(60);
      try {
        const provider = new authentication.HuaweiIDProvider();
        const cancelRequest = provider.createCancelAuthorizationRequest();
        const controller = new authentication.AuthenticationController(context);
        await controller.executeRequest(cancelRequest);
      } catch (e) {
      }
      const loginCode = await this.doLoginWithHuaweiID(context);
      if (loginCode === 0) {
        await this.doAuthorizeWithHuaweiID(context);
      }
    } finally {
      this.huaweiLoginInProgress = false;
    }
  }

  private async doLoginWithHuaweiID(context: common.UIAbilityContext): Promise<number> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createLoginWithHuaweiIDRequest();
    request.forceLogin = true;
    request.state = util.generateRandomUUID();

    try {
      const controller = new authentication.AuthenticationController(context);
      const result = await controller.executeRequest(request);
      const response = result as authentication.LoginWithHuaweiIDResponse;
      if (response.state && request.state !== response.state) {
        this.showToast('授权验证失败');
        return -1;
      }

      const credential = response.data;
      if (!credential || !credential.openID) {
        return -1;
      }
      return 0;
    } catch (error) {
      const code = this.getErrorCode(error);
      if (code === 1001502012) {
        return code;
      }
      this.showHuaweiLoginError(code);
      console.error(`Failed to login with Huawei ID: ${JSON.stringify(error)}`);
      return code;
    }
  }

  private async doAuthorizeWithHuaweiID(context: common.UIAbilityContext): Promise<number> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createAuthorizationWithHuaweiIDRequest();
    request.scopes = ['openid', 'profile'];
    request.forceAuthorization = true;
    request.state = util.generateRandomUUID();

    try {
      const controller = new authentication.AuthenticationController(context);
      const result = await controller.executeRequest(request);
      const response = result as authentication.AuthorizationWithHuaweiIDResponse;
      if (response.state && request.state !== response.state) {
        this.showToast('授权验证失败');
        return -1;
      }

      const credential = response.data;
      if (!credential) {
        this.showToast('未获取到账号信息');
        return -1;
      }

      this.isHuaweiLoggedIn = true;
      this.huaweiNickname = credential.nickName || '华为账号';
      this.huaweiAvatarUri = credential.avatarUri || '';
      this.huaweiUserId = credential.openID || '';
      this.saveSettings();
      this.showToast('登录成功');
      return 0;
    } catch (error) {
      const code = this.getErrorCode(error);
      if (code === 1001502012) {
        return code;
      }
      if (code === 1001500002) {
        this.showToast('登录请求正在处理，请稍后再试');
        return code;
      }
      if (code === 1001502005) {
        this.showToast('网络异常，请检查网络');
        return code;
      }
      this.showHuaweiLoginError(code);
      console.error(`Failed to authorize with Huawei ID: ${JSON.stringify(error)}`);
      return code;
    }
  }

  private showHuaweiLoginError(code: number): void {
    if (code === 1001500001) {
      this.showToast('应用签名指纹校验失败，请检查 AppGallery Connect 配置');
    } else if (code === 1001500003 || code === 1001502014) {
      this.showToast('华为账号权限未配置，请开通 openid 和 profile');
    } else if (code === 1001502001) {
      this.showToast('请先在系统设置中登录华为账号');
    } else if (code === 1001502002) {
      this.showToast('应用尚未获得华为账号授权');
    } else if (code === 1001502003 || code === 401) {
      this.showToast('华为账号登录参数配置错误');
    } else if (code === 1001502009 || code === 12300001) {
      this.showToast('华为账号服务暂时异常，请稍后重试');
    } else {
      this.showToast(code > 0 ? this.tf('华为账号登录失败（{0}）', [`${code}`]) : '华为账号登录失败');
    }
  }

  private async logoutHuaweiAccount(): Promise<void> {
    try {
      const provider = new authentication.HuaweiIDProvider();
      const cancelRequest = provider.createCancelAuthorizationRequest();
      const context = this.getAbilityContext();
      if (context) {
        const controller = new authentication.AuthenticationController(context);
        await controller.executeRequest(cancelRequest);
      }
    } catch (error) {
      console.error(`Failed to cancel authorization: ${JSON.stringify(error)}`);
    }
    this.isHuaweiLoggedIn = false;
    this.huaweiNickname = '';
    this.huaweiAvatarUri = '';
    this.huaweiUserId = '';
    this.cloudBackupEnabled = false;
    this.configureCloudAutoSync(false);
    this.saveSettings();
    this.showToast('已退出登录');
  }

  private async toggleCloudBackup(isOn: boolean): Promise<void> {
    if (!isOn) {
      this.beginCloudSync('同步中');
      await this.pullCloudTokensIntoLocal(false);
      await this.startCloudPush(false, true);
      await this.configureCloudAutoSync(false);
      this.cloudBackupEnabled = false;
      this.saveSettings();
      this.showToast('云空间自动同步已关闭');
      return;
    }

    this.cloudSyncStatus = '正在准备';
    this.saveSettings();

    if (!this.isHuaweiLoggedIn) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '请先登录华为账号';
      this.saveSettings();
      this.showToast('请先登录华为账号');
      return;
    }

    if (!await this.ensureDataSyncPermission()) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '未授权云同步';
      this.saveSettings();
      this.showToast('需要授权跨设备数据同步');
      return;
    }

    if (!await this.configureCloudAutoSync(true)) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '无法开启云同步';
      this.saveSettings();
      this.showToast('请确认已登录华为账号并开启云空间');
      return;
    }

    this.cloudBackupEnabled = true;
    this.saveSettings();
    this.showToast('云空间自动同步已开启');
    this.beginCloudSync('同步中');
    await this.pullCloudTokensIntoLocal(false);
    await this.startCloudPush(false, true);
  }

  private async configureCloudAutoSync(enabled: boolean): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      return false;
    }
    return await TokenRepository.configureCloudSync(context, enabled, (state: CloudSyncState): void => {
      this.updateCloudSyncState(state);
      if (state.finished && state.success) {
        this.loadTokens();
      }
    });
  }

  private async pushTokensToCloud(): Promise<void> {
    this.showToast('同步中');
    await this.startCloudPush(true);
  }

  private async startCloudPush(showOperationToast: boolean, keepCurrentSyncState: boolean = false): Promise<void> {
    console.info(`Cloud push requested: manual=${showOperationToast}, syncing=${this.cloudSyncing}, ` +
      `autoSync=${this.cloudBackupEnabled}, records=${this.tokens.length}`);
    if (this.cloudSyncing && !keepCurrentSyncState) {
      if (showOperationToast) {
        this.showToast('正在同步，请稍候');
      }
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      if (showOperationToast) {
        this.showToast('无法访问云空间');
      }
      return;
    }
    if (!keepCurrentSyncState || !this.cloudSyncing) {
      this.beginCloudSync('同步中');
    }
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步', showOperationToast);
      return;
    }
    if (!await TokenRepository.configureCloudSync(context, this.cloudBackupEnabled)) {
      this.finishCloudSyncFailure('云同步不可用', showOperationToast);
      return;
    }
    const success = await TokenRepository.pushToCloud(
      context,
      this.tokens,
      (state: CloudSyncState): void => {
        this.updateCloudSyncState(state);
      }
    );
    if (!success) {
      if (this.cloudSyncing) {
        this.finishCloudSyncFailure('推送失败', showOperationToast);
      } else if (showOperationToast) {
        this.showCloudSyncFailure();
      }
    } else if (this.cloudSyncing) {
      this.updateCloudSyncState({ status: '同步成功', finished: true, success: true });
    }
  }

  private async pullTokensFromCloud(): Promise<void> {
    console.info(`Manual cloud pull tapped: syncing=${this.cloudSyncing}, autoSync=${this.cloudBackupEnabled}`);
    if (this.cloudSyncing) {
      this.showToast('正在同步，请稍候');
      return;
    }
    this.showToast('同步中');
    await this.pullCloudTokensIntoLocal(true);
  }

  private async pullCloudTokensIntoLocal(showOperationToast: boolean): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      if (showOperationToast) {
        this.showToast('无法访问云空间');
      }
      return false;
    }
    if (!this.cloudSyncing) {
      this.beginCloudSync('同步中');
    }
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步', showOperationToast);
      return false;
    }
    if (!await TokenRepository.configureCloudSync(context, this.cloudBackupEnabled)) {
      this.finishCloudSyncFailure('云同步不可用', showOperationToast);
      return false;
    }
    const localSnapshot = [...this.tokens];
    const records = await TokenRepository.pullFromCloud(context, (state: CloudSyncState): void => {
      this.updateCloudSyncState(state);
    });
    if (!records) {
      if (this.cloudSyncing) {
        this.finishCloudSyncFailure('获取失败', showOperationToast);
      } else if (showOperationToast) {
        this.showCloudSyncFailure();
      }
      return false;
    }
    const mergedRecords = this.mergeCloudTokensWithoutDeletingLocal(localSnapshot, records);
    await TokenRepository.save(context, mergedRecords);
    this.tokens = mergedRecords;
    this.logoRenderVersion += 1;
    this.updateWidgetCards();
    if (this.cloudSyncing) {
      this.updateCloudSyncState({ status: '同步成功', finished: true, success: true });
    }
    return true;
  }

  private beginCloudSync(status: string): void {
    this.cloudSyncing = true;
    this.cloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private updateCloudSyncState(state: CloudSyncState): void {
    this.cloudSyncStatus = state.finished && !state.success ? (state.message || state.status) : state.status;
    this.cloudLastSyncTime = Date.now();
    if (state.finished) {
      this.cloudSyncing = false;
    }
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private showCloudSyncFailure(): void {
    this.showToast(`操作失败-${this.cloudSyncStatus}`);
  }

  private finishCloudSyncFailure(status: string, showOperationToast: boolean): void {
    this.cloudSyncing = false;
    this.cloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
    if (showOperationToast) {
      this.showToast(`操作失败-${status}`);
    }
  }

  private mergeCloudTokensWithoutDeletingLocal(localRecords: TokenRecord[], cloudRecords: TokenRecord[]): TokenRecord[] {
    const cloudMap = new Map<string, TokenRecord>();
    for (const record of cloudRecords) {
      if (record.id.length > 0) {
        cloudMap.set(record.id, record);
      }
    }
    const mergedRecords: TokenRecord[] = [];
    const usedIds = new Set<string>();
    for (const localRecord of localRecords) {
      const cloudRecord = cloudMap.get(localRecord.id);
      mergedRecords.push(cloudRecord || localRecord);
      usedIds.add(localRecord.id);
    }
    for (const cloudRecord of cloudRecords) {
      if (cloudRecord.id.length > 0 && !usedIds.has(cloudRecord.id)) {
        mergedRecords.push(cloudRecord);
      }
    }
    return mergedRecords;
  }

  private shouldShowCloudDisabledHint(): boolean {
    return this.cloudSyncStatus.indexOf('未启用') >= 0 || this.cloudSyncStatus.indexOf('（3）') >= 0 ||
      this.cloudSyncStatus.indexOf('(3)') >= 0;
  }

  private cloudLastSyncTimeText(): string {
    if (this.cloudLastSyncTime <= 0) {
      return '暂无记录';
    }
    const date = new Date(this.cloudLastSyncTime);
    return `${date.getFullYear()}-${this.twoDigit(date.getMonth() + 1)}-${this.twoDigit(date.getDate())} ` +
      `${this.twoDigit(date.getHours())}:${this.twoDigit(date.getMinutes())}`;
  }

  private twoDigit(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private async ensureDataSyncPermission(): Promise<boolean> {
    return await this.ensurePermission(DATA_SYNC_PERMISSION);
  }

  private async ensurePermission(permission: Permissions): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      return false;
    }
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, [permission]);
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      console.error(`Failed to request permission ${permission}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private async openCloudSpaceSettings(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法打开云空间管理');
      return;
    }
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: 'hicloud://cloudDrive/getInfo?path=MainActivity'
      });
    } catch (error) {
      this.showToast('请在系统设置中打开华为账号 > 云空间');
      console.error(`Failed to open cloud space settings: ${JSON.stringify(error)}`);
    }
  }

  private showExportFormatMenu(): void {
    this.showExportFormat = true;
  }

  private buildOtpAuthUri(token: TokenRecord): string {
    const type = this.normalizeTokenType(token.type).toLowerCase();
    const label = encodeURIComponent(
      token.remark.trim().length > 0 ? `${token.name}:${token.remark}` : token.name
    );
    const issuer = encodeURIComponent(token.name);
    const params: string[] = [
      `secret=${encodeURIComponent(token.secret)}`,
      `issuer=${issuer}`,
      `algorithm=${token.algorithm || 'SHA1'}`,
      `digits=${this.tokenDigitsForRecord(token)}`,
      `period=${this.tokenPeriodForRecord(token)}`
    ];
    if (type === 'hotp') {
      params.push(`counter=${this.tokenCounterForRecord(token)}`);
    }
    return `otpauth://${type}/${label}?${params.join('&')}`;
  }

  private exportSelectedTokens(): TokenRecord[] {
    return this.tokens.filter((t: TokenRecord) => this.exportSelectedIds.includes(t.id));
  }

  private exportQRCodeSize(): number {
    return Math.min(220, Math.max(160, this.pageWidth - 170));
  }

  private async saveCurrentQRCode(): Promise<void> {
    await this.saveQRCodeImages([this.exportQRIndex]);
  }

  private async saveAllQRCodes(): Promise<void> {
    const indices: number[] = [];
    for (let index = 0; index < this.exportSelectedTokens().length; index++) {
      indices.push(index);
    }
    await this.saveQRCodeImages(indices);
  }

  private async saveQRCodeImages(indices: number[]): Promise<void> {
    const context = this.getAbilityContext();
    const selectedTokens = this.exportSelectedTokens();
    if (!context || selectedTokens.length === 0 || indices.length === 0) {
      this.showToast('没有可保存的二维码');
      return;
    }

    const originalIndex = this.exportQRIndex;
    const temporaryPaths: string[] = [];
    const sourceUris: string[] = [];
    const creationSettings: photoAccessHelper.CreationSetting[] = [];
    let saveCompleted = false;
    this.isSavingQRCode = true;

    try {
      for (let position = 0; position < indices.length; position++) {
        const tokenIndex = indices[position];
        if (tokenIndex < 0 || tokenIndex >= selectedTokens.length) {
          continue;
        }
        this.exportQRIndex = tokenIndex;
        await this.delay(180);

        const pixelMap = await this.getUIContext().getComponentSnapshot().get('exportCurrentQrCode');
        const packer = image.createImagePacker();
        let pngData: ArrayBuffer = new ArrayBuffer(0);
        try {
          pngData = await packer.packToData(pixelMap, {
            format: 'image/png',
            quality: 100
          });
        } finally {
          await packer.release();
          await pixelMap.release();
        }

        const title = `Authenticator_${this.formatExportDate()}_${tokenIndex + 1}`;
        const path = `${context.filesDir}/${title}_${Date.now()}.png`;
        const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(file.fd, pngData);
        } finally {
          fileIo.closeSync(file);
        }
        temporaryPaths.push(path);
        sourceUris.push(fileUri.getUriFromPath(path));
        creationSettings.push({
          title: title,
          fileNameExtension: 'png',
          photoType: photoAccessHelper.PhotoType.IMAGE
        });
      }

      if (sourceUris.length === 0) {
        this.showToast('二维码生成失败');
        return;
      }

      const savedUris = await photoAccessHelper.getPhotoAccessHelper(context).showAssetsCreationDialogEx(
        sourceUris,
        creationSettings
      );
      const savedCount = savedUris.length;
      if (savedCount === 0) {
        this.showToast('未保存图片');
        return;
      }
      const copiedCount = this.copyTemporaryImagesToGallery(temporaryPaths, savedUris);
      if (copiedCount === 0) {
        this.showToast('保存图片失败');
        return;
      }

      saveCompleted = true;
      this.showToast(copiedCount === 1 ? '图片已保存到图库' :
        this.tf('已保存 {0} 张图片', [`${copiedCount}`]));
    } catch (error) {
      this.showToast('保存图片失败');
      console.error(`Save QR code images failed: ${JSON.stringify(error)}`);
    } finally {
      this.exportQRIndex = originalIndex;
      this.isSavingQRCode = false;
      if (saveCompleted) {
        setTimeout(() => {
          this.cleanupTemporaryFiles(temporaryPaths);
        }, 10000);
      } else {
        this.cleanupTemporaryFiles(temporaryPaths);
      }
    }
  }

  private copyTemporaryImagesToGallery(temporaryPaths: string[], savedUris: string[]): number {
    const count = Math.min(temporaryPaths.length, savedUris.length);
    let copiedCount = 0;
    for (let index = 0; index < count; index++) {
      try {
        fileIo.copyFileSync(temporaryPaths[index], savedUris[index]);
        copiedCount += 1;
      } catch (error) {
        if (this.copyTemporaryImageByStream(temporaryPaths[index], savedUris[index])) {
          copiedCount += 1;
        } else {
          console.error(`Copy QR code image to gallery failed: ${JSON.stringify(error)}`);
        }
      }
    }
    return copiedCount;
  }

  private copyTemporaryImageByStream(sourcePath: string, targetUri: string): boolean {
    let source: fileIo.File | null = null;
    let target: fileIo.File | null = null;
    try {
      const stat = fileIo.statSync(sourcePath);
      if (stat.size <= 0) {
        return false;
      }
      const buffer = new ArrayBuffer(stat.size);
      source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      const readSize = fileIo.readSync(source.fd, buffer, { offset: 0, length: stat.size });
      if (readSize <= 0) {
        return false;
      }
      target = fileIo.openSync(targetUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      const writeSize = fileIo.writeSync(target.fd, buffer, { offset: 0, length: readSize });
      return writeSize === readSize;
    } catch (error) {
      console.error(`Write QR code image to gallery uri failed: ${JSON.stringify(error)}`);
      return false;
    } finally {
      if (source) {
        fileIo.closeSync(source);
      }
      if (target) {
        fileIo.closeSync(target);
      }
    }
  }

  private cleanupTemporaryFiles(paths: string[]): void {
    for (let index = 0; index < paths.length; index++) {
      try {
        fileIo.unlinkSync(paths[index]);
      } catch (error) {
      }
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, milliseconds);
    });
  }

  private async exportAsJSON(): Promise<void> {
    const selectedTokens = this.exportSelectedTokens();
    if (selectedTokens.length === 0) {
      return;
    }
    const uris: string[] = selectedTokens.map((t: TokenRecord) => this.buildOtpAuthUri(t));
    const portableTokens: Record<string, Object>[] = selectedTokens.map((token: TokenRecord) => {
      const portableToken: Record<string, Object> = {
        'uri': this.buildOtpAuthUri(token),
        'name': token.name,
        'issuer': token.name,
        'account': token.remark,
        'secret': token.secret,
        'type': this.normalizeTokenType(token.type),
        'algorithm': token.algorithm || 'SHA1',
        'digits': this.tokenDigitsForRecord(token),
        'period': this.tokenPeriodForRecord(token),
        'counter': this.tokenCounterForRecord(token)
      };
      return portableToken;
    });
    const exportData: Record<string, Object> = {
      'encrypted': false,
      'exportDate': new Date().toISOString(),
      'app': 'Authenticator',
      'format': 'otpauth-uri',
      'version': 2,
      'uris': uris,
      'tokens': portableTokens
    };
    const jsonContent = JSON.stringify(exportData, null, 2);
    const fileName = `2fa_backup_${this.formatExportDate()}.json`;
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.save(options);
      if (result && result.length > 0) {
        const file = fileIo.openSync(result[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, jsonContent);
        fileIo.closeSync(file);
        this.showToast('已导出到文件');
      }
    } catch (error) {
      this.showToast('导出失败');
      console.error(`Export JSON failed: ${JSON.stringify(error)}`);
    }
  }

  private formatExportDate(): string {
    const d = new Date();
    return `${d.getFullYear()}${(d.getMonth() + 1).toString().padStart(2, '0')}${d.getDate().toString().padStart(2, '0')}`;
  }

  private async toggleSmartGrip(isOn: boolean): Promise<void> {
    if (!isOn) {
      this.stopSmartGrip();
      return;
    }
    if (!await this.ensurePermission(DETECT_GESTURE_PERMISSION) || !this.startSmartGrip()) {
      this.smartGripEnabled = false;
      this.holdingHandStatus = HoldingHandStatus.NOT_HELD;
      this.saveSettings();
      this.showToast('智感握姿不可用或未授权');
      return;
    }
    this.smartGripEnabled = true;
    this.saveSettings();
    this.showToast('智感握姿已开启');
  }

  private async toggleAntiPeep(isOn: boolean): Promise<void> {
    if (!isOn) {
      this.stopAntiPeep();
      return;
    }

    if (!await this.ensurePermission(DLP_ANTI_PEEP_PERMISSION) || !await this.startAntiPeep()) {
      this.antiPeepEnabled = false;
      this.saveSettings();
      this.showToast('防窥保护不可用或未授权');
      return;
    }
    this.antiPeepEnabled = true;
    this.saveSettings();
    this.showToast('防窥保护已开启');
  }

  private startSmartGrip(): boolean {
    try {
      this.stopSmartGrip(false);
      this.holdingHandCallback = (status: motion.HoldingHandStatus): void => {
        this.applyHoldingHandStatus(status);
      };
      motion.on('holdingHandChanged', this.holdingHandCallback);
      try {
        const recentHand = motion.getRecentOperatingHandStatus();
        if (recentHand === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
          this.holdingHandStatus = HoldingHandStatus.LEFT_HAND_HELD;
        } else if (recentHand === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
          this.holdingHandStatus = HoldingHandStatus.NOT_HELD;
        }
      } catch (error) {
      }
      return true;
    } catch (error) {
      console.error(`Failed to start smart grip: ${JSON.stringify(error)}`);
      this.holdingHandCallback = null;
      return false;
    }
  }

  private applyHoldingHandStatus(status: motion.HoldingHandStatus): void {
    this.holdingHandStatus = status === motion.HoldingHandStatus.LEFT_HAND_HELD ?
      HoldingHandStatus.LEFT_HAND_HELD : HoldingHandStatus.NOT_HELD;
  }

  private stopSmartGrip(save: boolean = true): void {
    try {
      if (this.holdingHandCallback) {
        motion.off('holdingHandChanged', this.holdingHandCallback);
      }
    } catch (error) {
      console.error(`Failed to stop smart grip: ${JSON.stringify(error)}`);
    }
    this.holdingHandCallback = null;
    this.smartGripEnabled = false;
    this.holdingHandStatus = HoldingHandStatus.NOT_HELD;
    if (save) {
      this.saveSettings();
    }
  }

  private async startAntiPeep(): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      return false;
    }
    try {
      const switchOn = await dlpAntiPeep.isDlpAntiPeepSwitchOn();
      if (!switchOn) {
        const result = await dlpAntiPeep.requestAntiPeepOptions(context);
        if (result !== dlpAntiPeep.AntiPeepOptionsResult.SUCCESS &&
          result !== dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) {
          return false;
        }
      }
      this.stopAntiPeep(false);
      this.antiPeepCallback = (status: dlpAntiPeep.DlpAntiPeepStatus): void => {
        if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
          this.publishAntiPeepInformation();
        }
      };
      dlpAntiPeep.on('dlpAntiPeep', this.antiPeepCallback);
      if (dlpAntiPeep.getDlpAntiPeepInfo() === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
        this.publishAntiPeepInformation();
      }
      return true;
    } catch (error) {
      console.error(`Failed to start anti peep: ${JSON.stringify(error)}`);
      this.antiPeepCallback = null;
      return false;
    }
  }

  private stopAntiPeep(save: boolean = true): void {
    try {
      if (this.antiPeepCallback) {
        dlpAntiPeep.off('dlpAntiPeep', this.antiPeepCallback);
      }
    } catch (error) {
      console.error(`Failed to stop anti peep: ${JSON.stringify(error)}`);
    }
    this.antiPeepCallback = null;
    this.antiPeepEnabled = false;
    if (save) {
      this.saveSettings();
    }
  }

  private async publishAntiPeepInformation(): Promise<void> {
    try {
      await dlpAntiPeep.publishAntiPeepInformation();
      this.showToast('已检测到防窥风险');
    } catch (error) {
      console.error(`Failed to publish anti peep information: ${JSON.stringify(error)}`);
    }
  }

  private toggleAppLock(isOn: boolean): void {
    if (!isOn) {
      this.appLockEnabled = false;
      this.isLocked = false;
      this.saveSettings();
      return;
    }
    this.appLockEnabled = true;
    this.isLocked = false;
    this.saveSettings();
  }

  private updateHomeScroll(scrollOffset: number): void {
    if (this.homeScrollY <= 0 && scrollOffset > 0 && this.homeScroller.currentOffset().yOffset <= 0) {
      return;
    }

    const nextScrollY = this.clamp(this.homeScrollY + scrollOffset, 0, HOME_SEARCH_COLLAPSE_DISTANCE);
    if (Math.abs(nextScrollY - this.homeScrollY) > 0.5) {
      this.homeScrollY = nextScrollY;
    }

    const collapseRatio = nextScrollY / HOME_SEARCH_COLLAPSE_DISTANCE;
    if (!this.isHomeSearchCollapsed && collapseRatio >= HOME_SEARCH_COLLAPSE_HIDE_THRESHOLD) {
      this.setHomeSearchCollapsed(true);
    } else if (this.isHomeSearchCollapsed && collapseRatio <= HOME_SEARCH_COLLAPSE_SHOW_THRESHOLD) {
      this.setHomeSearchCollapsed(false);
    }
  }

  private searchCollapseProgress(): number {
    return this.isHomeSearchCollapsed ? 1 : 0;
  }

  private setHomeSearchCollapsed(collapsed: boolean): void {
    if (this.isHomeSearchCollapsed === collapsed) {
      return;
    }
    this.getUIContext().animateTo({
      duration: HOME_SEARCH_FADE_DURATION,
      curve: Curve.Smooth
    }, () => {
      this.isHomeSearchCollapsed = collapsed;
    });
  }

  private scrollHomeSearchIntoView(): void {
    this.homeScroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: {
        duration: 520,
        curve: Curve.Smooth
      }
    });
    this.getUIContext().animateTo({
      duration: 520,
      curve: Curve.Smooth
    }, () => {
      this.homeScrollY = 0;
      this.isHomeSearchCollapsed = false;
    });
  }

  private clamp(value: number, min: number = 0, max: number = 1): number {
    return Math.min(Math.max(value, min), max);
  }

  private lengthToNumber(value: Length, fallback: number): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = parseFloat(value);
      return isNaN(parsed) ? fallback : parsed;
    }
    return fallback;
  }

  private filteredTokens(): TokenRecord[] {
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.tokens;
    }

    return this.tokens.filter((token: TokenRecord) => {
      return token.name.toLowerCase().includes(keyword) ||
        token.remark.toLowerCase().includes(keyword);
    });
  }

  private openAddPage(): void {
    this.isAddMenuOpen = false;
    this.editingTokenId = '';
    this.nameInput = '';
    this.remarkInput = '';
    this.resetFormLogo();
    this.typeInput = 'TOTP';
    this.algorithmInput = 'SHA1';
    this.secretInput = '';
    this.editingOriginalSecret = '';
    this.tokenLengthInput = '6位';
    this.refreshTimeInput = '30秒';
    this.applyTypeDefaults();
    this.validationMessage = '';
    this.pageMode = PageMode.AddToken;
    this.homePathStack.pushPath({ name: 'addToken' }, true);
  }

  private async pickIssuerLogo(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法打开图片选择器');
      return;
    }
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      options.isEditSupported = true;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select(options);
      if (!result.photoUris || result.photoUris.length === 0) {
        return;
      }
      const pickedUri = result.photoUris[0];
      this.applyManualFormLogo(pickedUri);
      const logoUri = await this.persistPickedLogo(context, pickedUri);
      this.applyManualFormLogo(logoUri);
    } catch (error) {
      this.showToast('选择图片失败');
      console.error(`Failed to pick issuer logo: ${JSON.stringify(error)}`);
    }
  }

  private async persistPickedLogo(context: common.UIAbilityContext, uri: string): Promise<string> {
    const targetPath = `${context.filesDir}/issuer_logo_${Date.now()}.png`;
    try {
      await fileIo.copyFile(uri, targetPath);
      return fileUri.getUriFromPath(targetPath);
    } catch (error) {
      console.error(`Failed to copy issuer logo, use original uri: ${JSON.stringify(error)}`);
      return uri;
    }
  }

  private resetFormLogo(): void {
    this.clearLogoLookupTimer();
    this.logoUriInput = '';
    this.logoLightUriInput = '';
    this.logoDarkUriInput = '';
    this.logoSourceInput = '';
    this.formLogoRenderVersion += 1;
  }

  private clearLogoLookupTimer(): void {
    if (this.logoLookupTimer > 0) {
      clearTimeout(this.logoLookupTimer);
      this.logoLookupTimer = 0;
    }
  }

  private scheduleFormLogoLookup(): void {
    if (this.logoSourceInput === LOGO_SOURCE_MANUAL && this.formTokenType() !== 'Steam') {
      return;
    }
    this.clearLogoLookupTimer();
    this.logoLookupSerial += 1;
    this.logoUriInput = '';
    this.logoLightUriInput = '';
    this.logoDarkUriInput = '';
    this.logoSourceInput = '';
    this.formLogoRenderVersion += 1;
    const lookupIssuer = this.logoLookupIssuer(this.typeInput, this.remarkInput);
    const lookupName = this.logoLookupName(this.typeInput, this.nameInput);
    if (lookupName.trim().length === 0 && lookupIssuer.trim().length === 0) {
      return;
    }
    const serial = this.logoLookupSerial;
    this.logoLookupTimer = setTimeout(async () => {
      this.logoLookupTimer = 0;
      await this.resolveFormLogo(serial);
    }, 450);
  }

  private async resolveFormLogo(serial: number): Promise<void> {
    if (serial !== this.logoLookupSerial || this.logoSourceInput === LOGO_SOURCE_MANUAL) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    const result = await LogoResolver.resolve(
      context,
      this.logoLookupIssuer(this.typeInput, this.remarkInput),
      this.logoLookupName(this.typeInput, this.nameInput)
    );
    if (serial !== this.logoLookupSerial || !result) {
      return;
    }
    this.applyFormLogo(result);
  }

  private async ensureFormLogoResolved(): Promise<void> {
    const lookupIssuer = this.logoLookupIssuer(this.typeInput, this.remarkInput);
    const lookupName = this.logoLookupName(this.typeInput, this.nameInput);
    if ((this.logoSourceInput === LOGO_SOURCE_MANUAL && this.formTokenType() !== 'Steam') ||
      (this.logoUriInput.length > 0 && this.formTokenType() !== 'Steam') ||
      (lookupName.trim().length === 0 && lookupIssuer.trim().length === 0)) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    const result = await LogoResolver.resolve(context, lookupIssuer, lookupName);
    if (result) {
      this.applyFormLogo(result);
    }
  }

  private async ensureFormLogoResolvedForSave(): Promise<void> {
    let finished = false;
    await new Promise<void>((resolve): void => {
      const timeoutId = setTimeout((): void => {
        if (!finished) {
          finished = true;
          resolve();
        }
      }, LOGO_SAVE_LOOKUP_TIMEOUT_MS);
      this.ensureFormLogoResolved().then((): void => {
        if (!finished) {
          finished = true;
          clearTimeout(timeoutId);
          resolve();
        }
      }).catch((): void => {
        if (!finished) {
          finished = true;
          clearTimeout(timeoutId);
          resolve();
        }
      });
    });
  }

  private applyFormLogo(result: LogoResolveResult): void {
    this.logoUriInput = result.logoUri;
    this.logoLightUriInput = result.logoLightUri;
    this.logoDarkUriInput = result.logoDarkUri;
    this.logoSourceInput = result.logoSource;
    this.formLogoRenderVersion += 1;
  }

  private applyManualFormLogo(uri: string): void {
    this.clearLogoLookupTimer();
    this.logoUriInput = uri;
    this.logoLightUriInput = uri;
    this.logoDarkUriInput = uri;
    this.logoSourceInput = LOGO_SOURCE_MANUAL;
    this.formLogoRenderVersion += 1;
  }

  private completeOnboarding(): void {
    this.onboardingCompleted = true;
    this.showOnboarding = false;
    this.saveSettings();
  }

  private handleMeAction(group: number, index: number): void {
    if (group === 0) {
      if (index === 0) {
        this.homePathStack.pushPath({ name: 'cloudSpace' }, true);
      } else if (index === 1) {
        this.exportSelectedIds = [];
        this.showExportPicker = true;
      } else {
        this.homePathStack.pushPath({ name: 'settings' }, true);
      }
      return;
    }
    if (group === 1) {
      if (index === 0) {
        this.showToast('订阅会员服务暂未开放');
      } else {
        this.showToast('敬请期待');
      }
      return;
    }
    if (index === 0) {
      this.openExternalUrl('https://gitcode.com/mroble/Tool_2FA');
    } else if (index === 1) {
      this.openExternalUrl(USER_AGREEMENT_URL);
    } else if (index === 2) {
      this.openPrivacyLink(privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK, '隐私声明');
    } else {
      this.showFeedbackDialog();
    }
  }

  private openPrivacyLink(type: privacyManager.AppPrivacyLinkType, label: string): void {
    try {
      const info = privacyManager.getAppPrivacyMgmtInfo();
      for (const link of info.privacyInfo) {
        if (link.type === type && link.url.length > 0) {
          this.openExternalUrl(link.url);
          return;
        }
      }
      this.showToast(this.tf('未配置{0}地址', [this.t(label)]));
    } catch (error) {
      console.error(`Failed to query ${label}: ${JSON.stringify(error)}`);
      this.showToast(this.tf('暂时无法打开{0}', [this.t(label)]));
    }
  }

  private showFeedbackDialog(): void {
    this.getUIContext().showAlertDialog({
      title: this.t('帮助与反馈'),
      message: this.t('反馈邮箱：1207523787@qq.com'),
      autoCancel: true,
      primaryButton: {
        value: this.t('确定'),
        action: () => {
        }
      }
    });
  }

  private async openExternalUrl(uri: string): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法打开链接');
      return;
    }
    try {
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: uri
      });
    } catch (error) {
      this.showToast('无法打开链接');
    }
  }

  private openEditPage(token: TokenRecord): void {
    this.isAddMenuOpen = false;
    this.editingTokenId = token.id;
    this.nameInput = token.name;
    this.remarkInput = token.remark;
    this.logoUriInput = token.logoUri || '';
    this.logoLightUriInput = token.logoLightUri || token.logoUri || '';
    this.logoDarkUriInput = token.logoDarkUri || token.logoUri || '';
    this.logoSourceInput = token.logoSource || '';
    this.formLogoRenderVersion += 1;
    this.typeInput = this.normalizeTokenType(token.type);
    this.algorithmInput = this.normalizeAlgorithm(token.algorithm);
    this.secretInput = token.secret;
    this.editingOriginalSecret = token.secret;
    this.tokenLengthInput = this.tokenDigitsLabel(token.digits);
    this.refreshTimeInput = this.tokenPeriodLabel(token.period);
    this.validationMessage = '';
    this.pageMode = PageMode.AddToken;
    this.homePathStack.pushPath({ name: 'addToken' }, true);
  }

  private backHome(): void {
    this.clearAddPageNavigationState();
    this.homePathStack.pop(true);
  }

  private clearAddPageNavigationState(): void {
    this.validationMessage = '';
    this.editingTokenId = '';
    this.editingOriginalSecret = '';
    this.pageMode = PageMode.Home;
  }

  private confirmDeleteToken(token: TokenRecord): void {
    this.getUIContext().showAlertDialog({
      title: this.t('删除令牌'),
      message: this.tf('确定删除“{0}”？删除后无法恢复。', [token.name]),
      autoCancel: true,
      primaryButton: {
        value: this.t('取消'),
        action: () => {
        }
      },
      secondaryButton: {
        value: this.t('删除'),
        fontColor: ERROR_RED,
        action: () => {
          this.deleteToken(token.id);
        }
      }
    });
  }

  private async deleteToken(tokenId: string): Promise<void> {
    const nextTokens = this.tokens.filter((token: TokenRecord) => token.id !== tokenId);
    if (nextTokens.length === this.tokens.length) {
      return;
    }
    await this.persistTokens(nextTokens, '已删除');
  }

  private async scanTokenFromQrCode(): Promise<void> {
    if (this.isScanning) {
      return;
    }

    if (this.isDesktopDevice()) {
      this.showToast('当前设备暂不支持相机扫码，请选择文件导入');
      await this.importTokenFile();
      return;
    }

    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法打开扫码');
      return;
    }

    this.isAddMenuOpen = false;
    this.isScanning = true;

    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      });
      await this.saveScannedToken(result.originalValue);
    } catch (error) {
      const code = this.getErrorCode(error);
      if (code !== scanCore.ScanErrorCode.SCAN_SERVICE_CANCELED) {
        this.showToast('扫码失败，请重试');
        console.error(`Failed to scan token: ${JSON.stringify(error)}`);
      }
    } finally {
      this.isScanning = false;
    }
  }

  private isDesktopDevice(): boolean {
    return this.deviceType === '2in1';
  }

  private async saveScannedToken(scannedValue: string): Promise<void> {
    const records = this.createTokensFromScannedValue(scannedValue);
    if (records.length === 0) {
      const isGoogleMigration = scannedValue.trim().toLowerCase().startsWith('otpauth-migration://offline?');
      this.showToast(isGoogleMigration ? 'Google迁移码解析失败' : '未识别到有效密钥');
      return;
    }

    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('保存失败，请重试');
      return;
    }

    const uniqueRecords = this.uniqueTokenRecords(records);
    this.beginImportProgress(uniqueRecords.length, '正在导入令牌');
    const recordsWithLogos = await this.hydrateTokenLogos(uniqueRecords);
    const nextTokens = this.mergeImportedTokens(recordsWithLogos, this.tokens);
    const addedCount = nextTokens.length - this.tokens.length;
    const skippedCount = Math.max(0, recordsWithLogos.length - addedCount);
    if (addedCount === 0) {
      this.finishImportProgress(0, skippedCount, '没有新增令牌');
      this.showToast('令牌已存在');
      return;
    }
    const message = addedCount > 1 ? this.tf('已导入{0}个令牌', [`${addedCount}`]) : '已保存';
    if (!await this.persistTokens(nextTokens, message)) {
      this.finishImportProgress(addedCount, skippedCount, '导入失败');
      return;
    }
    this.finishImportProgress(addedCount, skippedCount, message);
    this.searchText = '';
    this.pageMode = PageMode.Home;
  }

  private async importTokenFile(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法打开文件导入');
      return;
    }

    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const uris = await documentPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['2FA|.txt,.json,.csv,.tsv,.otpauth,.mafile,.2fas']
      });
      if (uris.length === 0) {
        return;
      }

      const content = await this.readImportFile(uris[0]);
      const records = this.parseImportedTokenContent(content);
      if (records.length === 0) {
        this.showToast(this.importRejectedCount > 0 ?
          this.tf('文件中有{0}条无效令牌', [`${this.importRejectedCount}`]) : '未识别到可导入的令牌');
        return;
      }

      this.beginImportProgress(records.length, '正在导入令牌');
      const recordsWithLogos = await this.hydrateTokenLogos(records);
      const nextTokens = this.mergeImportedTokens(recordsWithLogos, this.tokens);
      const addedCount = nextTokens.length - this.tokens.length;
      const skippedCount = this.importRejectedCount + Math.max(0, recordsWithLogos.length - addedCount);
      if (addedCount === 0) {
        this.finishImportProgress(0, skippedCount, '没有新增令牌');
        this.showToast('所选令牌已存在');
        return;
      }
      const importMessage = this.importRejectedCount > 0 ?
        this.tf('已导入{0}个，跳过{1}个无效令牌', [`${addedCount}`, `${this.importRejectedCount}`]) :
        this.tf('已导入{0}个令牌', [`${addedCount}`]);
      if (!await this.persistTokens(nextTokens, importMessage)) {
        this.finishImportProgress(addedCount, skippedCount, '导入失败');
        return;
      }
      this.finishImportProgress(addedCount, skippedCount, importMessage);
      this.searchText = '';
      this.pageMode = PageMode.Home;
    } catch (error) {
      this.showToast('导入失败，请选择有效文件');
      console.error(`Failed to import token file: ${JSON.stringify(error)}`);
    }
  }

  private beginImportProgress(total: number, message: string): void {
    this.importProgressTotal = Math.max(total, 1);
    this.importProgressProcessed = 0;
    this.importProgressSuccess = 0;
    this.importProgressFailed = 0;
    this.importProgressMessage = this.t(message);
    this.importProgressVisible = true;
  }

  private updateImportProgress(processed: number, success: number, failed: number, message?: string): void {
    this.importProgressProcessed = Math.min(Math.max(processed, 0), this.importProgressTotal);
    this.importProgressSuccess = Math.max(success, 0);
    this.importProgressFailed = Math.max(failed, 0);
    if (message) {
      this.importProgressMessage = this.t(message);
    }
  }

  private finishImportProgress(success: number, failed: number, message: string): void {
    this.updateImportProgress(this.importProgressTotal, success, failed, message);
    setTimeout(() => {
      if (this.importProgressMessage === this.t(message)) {
        this.importProgressVisible = false;
      }
    }, 900);
  }

  private async readImportFile(uri: string): Promise<string> {
    try {
      return await fileIo.readText(uri, { encoding: 'utf-8' });
    } catch (error) {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        const size = Math.min(stat.size, 1024 * 1024);
        const buffer = new ArrayBuffer(size);
        const readLength = fileIo.readSync(file.fd, buffer);
        return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buffer, 0, readLength));
      } finally {
        fileIo.closeSync(file);
      }
    }
  }

  private parseImportedTokenContent(content: string): TokenRecord[] {
    const records: TokenRecord[] = [];
    this.importRejectedCount = 0;
    const trimmed = content.trim();
    if (trimmed.length === 0) {
      return records;
    }

    let parsedJson = false;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        this.collectImportedJsonTokens(JSON.parse(trimmed), records);
        parsedJson = true;
      } catch (error) {
      }
    }

    if (!parsedJson) {
      const lines = trimmed.split(/\r?\n/);
      const header = this.importHeader(lines);
      lines.forEach((line: string, index: number) => {
        const lineRecord = this.parseImportedLine(line, header, index);
        if (lineRecord) {
          records.push(lineRecord);
        }
      });
    }
    return this.uniqueTokenRecordsWithValidation(records, true);
  }

  private importHeader(lines: string[]): Map<string, number> {
    const header = new Map<string, number>();
    if (lines.length === 0) {
      return header;
    }

    const columns = this.splitImportLine(lines[0]);
    const hasSecret = columns.some((column: string) => column.trim().toLowerCase() === 'secret');
    if (!hasSecret) {
      return header;
    }

    columns.forEach((column: string, index: number) => {
      header.set(column.trim().toLowerCase(), index);
    });
    return header;
  }

  private parseImportedLine(line: string, header: Map<string, number>, index: number): TokenRecord | undefined {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return undefined;
    }

    const uriStart = trimmed.indexOf('otpauth://');
    if (uriStart >= 0) {
      return this.createTokenFromScannedValue(trimmed.substring(uriStart));
    }

    const columns = this.splitImportLine(trimmed);
    if (columns.length === 0 || header.size > 0 && index === 0) {
      return undefined;
    }

    if (header.size > 0) {
      const secret = this.headerValue(columns, header, 'secret');
      if (secret.length === 0) {
        return undefined;
      }
      return this.createImportedTokenRecord(
        this.headerValue(columns, header, 'name') || this.headerValue(columns, header, 'account'),
        this.headerValue(columns, header, 'issuer') || this.headerValue(columns, header, 'remark'),
        secret,
        this.headerValue(columns, header, 'type'),
        this.headerValue(columns, header, 'algorithm') || this.headerValue(columns, header, 'algo'),
        parseInt(this.headerValue(columns, header, 'digits'), 10),
        parseInt(this.headerValue(columns, header, 'period'), 10),
        parseInt(this.headerValue(columns, header, 'counter'), 10)
      );
    }

    if (columns.length >= 2) {
      return this.createImportedTokenRecord(
        columns[0],
        columns.length > 2 ? columns[2] : '',
        columns[1],
        columns.length > 3 ? columns[3] : 'TOTP',
        columns.length > 4 ? columns[4] : 'SHA1',
        columns.length > 5 ? parseInt(columns[5], 10) : DEFAULT_TOKEN_DIGITS,
        columns.length > 6 ? parseInt(columns[6], 10) : DEFAULT_TOKEN_PERIOD,
        columns.length > 7 ? parseInt(columns[7], 10) : 0
      );
    }

    return this.createImportedTokenRecord(`${this.t('导入令牌')}${index + 1}`, '', columns[0], 'TOTP', 'SHA1',
      DEFAULT_TOKEN_DIGITS, DEFAULT_TOKEN_PERIOD, 0);
  }

  private splitImportLine(line: string): string[] {
    const delimiter = line.includes('\t') ? '\t' : line.includes(';') ? ';' : ',';
    return line.split(delimiter).map((part: string) => part.trim().replace(/^"|"$/g, ''));
  }

  private headerValue(columns: string[], header: Map<string, number>, key: string): string {
    const index = header.get(key);
    if (index === undefined || index < 0 || index >= columns.length) {
      return '';
    }
    return columns[index].trim();
  }

  private collectImportedJsonTokens(value: Object, records: TokenRecord[]): void {
    if (typeof value === 'string') {
      const normalizedValue = value.trim().toLowerCase();
      if (normalizedValue.startsWith('otpauth://') ||
        normalizedValue.startsWith('otpauth-migration://offline?')) {
        const importedRecords = this.createTokensFromScannedValue(value);
        if (importedRecords.length === 0) {
          this.importRejectedCount++;
        }
        importedRecords.forEach((record: TokenRecord) => {
          records.push(record);
        });
      }
      return;
    }

    if (Array.isArray(value)) {
      value.forEach((item: Object) => {
        this.collectImportedJsonTokens(item, records);
      });
      return;
    }

    if (typeof value !== 'object' || value === null) {
      return;
    }

    const source = value as Record<string, Object>;
    const tokenItems = this.importedJsonValue(source, 'tokens');
    if (Array.isArray(tokenItems)) {
      tokenItems.forEach((item: Object) => {
        this.collectImportedJsonTokens(item, records);
      });
      return;
    }

    const uriItems = this.importedJsonValue(source, 'uris');
    if (Array.isArray(uriItems)) {
      uriItems.forEach((item: Object) => {
        this.collectImportedJsonTokens(item, records);
      });
      return;
    }

    const uri = this.firstString(source, ['uri', 'url', 'totp', 'otpUri', 'otpAuthUri', 'otpauth', 'otpAuth']);
    if (uri.length > 0) {
      const uriRecords = this.createTokensFromScannedValue(uri);
      if (uriRecords.length === 0) {
        this.importRejectedCount++;
      }
      uriRecords.forEach((record: TokenRecord) => {
        records.push(record);
      });
      return;
    }

    const info = this.objectValue(this.importedJsonValue(source, 'info'));
    const otp = this.objectValue(this.importedJsonValue(source, 'otp'));
    const tokenSource = info || otp || source;
    const secret = this.firstString(source, ['secret', 'secretKey', 'secret_key', 'shared_secret', 'tokenSecret',
      'otpSecret', 'otp_secret', 'seed', 'key']) ||
      this.firstString(tokenSource, ['secret', 'secretKey', 'secret_key', 'shared_secret', 'tokenSecret', 'otpSecret',
        'otp_secret', 'seed', 'key']);
    if (secret.length > 0) {
      let jsonType = this.firstString(source, ['type', 'tokenType', 'otpType', 'otp_type']) ||
        this.firstString(tokenSource, ['type', 'tokenType', 'otpType', 'otp_type']);
      if (jsonType.length === 0 && this.firstString(tokenSource, ['shared_secret']).length > 0) {
        jsonType = 'Steam';
      }
      records.push(this.createImportedTokenRecord(
        this.firstString(source, ['name', 'service', 'label', 'accountName', 'account_name', 'account', 'accountId',
          'account_id', 'username']) ||
          this.firstString(tokenSource, ['name', 'service', 'label', 'accountName', 'account_name', 'account',
            'accountId', 'account_id', 'username']),
        this.firstString(source, ['issuer', 'remark', 'platform', 'provider', 'vendor', 'email']) ||
          this.firstString(tokenSource, ['issuer', 'remark', 'platform', 'provider', 'vendor', 'email']),
        secret,
        jsonType,
        this.firstString(source, ['algorithm', 'algo']) || this.firstString(tokenSource, ['algorithm', 'algo']),
        this.firstNumber(source, ['digits']) || this.firstNumber(tokenSource, ['digits']),
        this.firstNumber(source, ['period', 'interval', 'timeStep', 'time_step']) ||
          this.firstNumber(tokenSource, ['period', 'interval', 'timeStep', 'time_step']),
        this.firstNumber(source, ['counter']) || this.firstNumber(tokenSource, ['counter'])
      ));
      return;
    }

    Object.keys(source).forEach((key: string) => {
      const normalizedKey = key.toLowerCase();
      if (normalizedKey !== 'uri' &&
        normalizedKey !== 'url' &&
        normalizedKey !== 'totp' &&
        normalizedKey !== 'otpuri' &&
        normalizedKey !== 'otpauthuri' &&
        normalizedKey !== 'otpauth' &&
        normalizedKey !== 'info' &&
        normalizedKey !== 'otp') {
        this.collectImportedJsonTokens(source[key], records);
      }
    });
  }

  private createImportedTokenRecord(
    name: string,
    remark: string,
    secret: string,
    type: string,
    algorithm: string,
    digits: number,
    period: number,
    counter: number
  ): TokenRecord {
    const rawType = type.trim();
    const tokenType = this.normalizeTokenType(rawType || 'TOTP');
    const isConfigurationValid = this.isImportedConfigurationValid(
      rawType,
      tokenType,
      algorithm,
      digits,
      period,
      counter
    );
    const normalizedSecret = isConfigurationValid ? Totp.normalizeSecret(secret, tokenType) : '';
    return {
      id: `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name.trim().length > 0 ? name.trim() : this.t('导入令牌'),
      remark: remark.trim(),
      type: tokenType,
      algorithm: this.standardAlgorithmForType(tokenType, algorithm || 'SHA1'),
      secret: normalizedSecret,
      digits: this.standardDigitsForType(tokenType, isNaN(digits) ? DEFAULT_TOKEN_DIGITS : digits),
      period: this.standardPeriodForType(tokenType, isNaN(period) ? DEFAULT_TOKEN_PERIOD : period),
      counter: this.normalizeTokenCounter(isNaN(counter) ? 0 : counter),
      createdAt: Date.now()
    };
  }

  private firstString(source: Record<string, Object>, keys: string[]): string {
    for (const key of keys) {
      const value = this.importedJsonValue(source, key);
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim();
      }
    }
    return '';
  }

  private firstNumber(source: Record<string, Object>, keys: string[]): number {
    for (const key of keys) {
      const value = this.importedJsonValue(source, key);
      if (typeof value === 'number') {
        return value;
      }
      if (typeof value === 'string') {
        const parsed = parseInt(value, 10);
        if (!isNaN(parsed)) {
          return parsed;
        }
      }
    }
    return 0;
  }

  private importedJsonValue(source: Record<string, Object>, key: string): Object | undefined {
    if (source[key] !== undefined) {
      return source[key];
    }
    const normalizedKey = key.toLowerCase();
    const sourceKeys = Object.keys(source);
    for (let index = 0; index < sourceKeys.length; index++) {
      if (sourceKeys[index].toLowerCase() === normalizedKey) {
        return source[sourceKeys[index]];
      }
    }
    return undefined;
  }

  private objectValue(value: Object | undefined): Record<string, Object> | undefined {
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
    return undefined;
  }

  private isImportedConfigurationValid(
    rawType: string,
    tokenType: string,
    algorithm: string,
    digits: number,
    period: number,
    counter: number
  ): boolean {
    const normalizedRawType = rawType.trim().toUpperCase();
    if (normalizedRawType.length > 0 &&
      normalizedRawType !== 'TOTP' &&
      normalizedRawType !== 'HOTP' &&
      normalizedRawType !== 'STEAM') {
      return false;
    }

    const normalizedAlgorithm = algorithm.trim().toUpperCase();
    if (normalizedAlgorithm.length > 0) {
      if (tokenType === 'TOTP' &&
        !ALGORITHM_OPTIONS.some((option: SelectOption) => option.value === normalizedAlgorithm)) {
        return false;
      }
      if (tokenType !== 'TOTP' && normalizedAlgorithm !== 'SHA1' && normalizedAlgorithm !== 'SHA-1') {
        return false;
      }
    }

    if (!isNaN(digits) && digits > 0) {
      if (tokenType === 'Steam' && digits !== 5) {
        return false;
      }
      if (tokenType === 'HOTP' && digits !== 6 && digits !== 8) {
        return false;
      }
      if (tokenType === 'TOTP' && digits !== 4 && digits !== 6 && digits !== 8) {
        return false;
      }
    }

    if (!isNaN(period) && period > 0) {
      if (tokenType === 'TOTP' && period !== 30 && period !== 60) {
        return false;
      }
      if (tokenType === 'Steam' && period !== 30) {
        return false;
      }
    }

    return isNaN(counter) || counter >= 0;
  }

  private isValidTokenRecord(record: TokenRecord): boolean {
    const type = this.normalizeTokenType(record.type);
    const digits = this.tokenDigitsForRecord(record);
    const period = this.tokenPeriodForRecord(record);
    return record.name.trim().length > 0 &&
      Totp.isValidSecret(record.secret, type) &&
      this.isImportedConfigurationValid(
        type,
        type,
        record.algorithm,
        digits,
        period,
        this.tokenCounterForRecord(record)
      );
  }

  private uniqueTokenRecords(records: TokenRecord[]): TokenRecord[] {
    return this.uniqueTokenRecordsWithValidation(records, false);
  }

  private uniqueTokenRecordsWithValidation(records: TokenRecord[], trackRejected: boolean): TokenRecord[] {
    const uniqueRecords: TokenRecord[] = [];
    records.forEach((record: TokenRecord) => {
      if (!this.isValidTokenRecord(record)) {
        if (trackRejected) {
          this.importRejectedCount++;
        }
        return;
      }
      const exists = uniqueRecords.some((item: TokenRecord) => {
        return item.secret === record.secret && item.name === record.name && item.type === record.type;
      });
      if (!exists) {
        uniqueRecords.push(record);
      }
    });
    return uniqueRecords;
  }

  private mergeImportedTokens(records: TokenRecord[], currentTokens: TokenRecord[]): TokenRecord[] {
    const filteredRecords = records.filter((record: TokenRecord) => {
      return !currentTokens.some((token: TokenRecord) => {
        return token.secret === record.secret && token.name === record.name && token.type === record.type;
      });
    });
    return filteredRecords.concat(currentTokens);
  }

  private createTokenFromScannedValue(scannedValue: string): TokenRecord | undefined {
    const rawValue = scannedValue.trim();
    if (rawValue.length === 0) {
      return undefined;
    }

    let name = this.t('扫描令牌');
    let remark = '';
    let secret = rawValue;
    let type = 'TOTP';
    let algorithm = 'SHA1';
    let digits = DEFAULT_TOKEN_DIGITS;
    let period = DEFAULT_TOKEN_PERIOD;
    let counter = 0;
    const lowerValue = rawValue.toLowerCase();

    if (lowerValue.startsWith('otpauth://totp/') ||
      lowerValue.startsWith('otpauth://hotp/') ||
      lowerValue.startsWith('otpauth://steam/')) {
      if (lowerValue.startsWith('otpauth://hotp/')) {
        type = 'HOTP';
      } else if (lowerValue.startsWith('otpauth://steam/')) {
        type = 'Steam';
      }
      const schemeEnd = rawValue.indexOf('/', 'otpauth://'.length);
      const payload = rawValue.substring(schemeEnd + 1);
      const queryStart = payload.indexOf('?');
      const rawLabel = queryStart >= 0 ? payload.substring(0, queryStart) : payload;
      const label = this.decodeQrText(rawLabel);
      const params = this.parseQrQuery(queryStart >= 0 ? payload.substring(queryStart + 1) : '');
      const parsedSecret = params.get('secret') || '';

      if (parsedSecret.trim().length === 0) {
        return undefined;
      }

      secret = parsedSecret.trim();
      algorithm = this.normalizeAlgorithm(params.get('algorithm') || algorithm);
      const parsedDigits = parseInt(params.get('digits') || '', 10);
      if (parsedDigits === 4 || parsedDigits === 6 || parsedDigits === 8) {
        digits = parsedDigits;
      }
      const parsedPeriod = parseInt(params.get('period') || '', 10);
      if (parsedPeriod === 30 || parsedPeriod === 60) {
        period = parsedPeriod;
      }
      const parsedCounter = parseInt(params.get('counter') || '', 10);
      if (!isNaN(parsedCounter) && parsedCounter >= 0) {
        counter = parsedCounter;
      }
      const issuer = (params.get('issuer') || '').trim();
      if (issuer.toLowerCase() === 'steam') {
        type = 'Steam';
      }
      if (issuer.length > 0) {
        remark = issuer;
      }

      const labelParts = label.split(':');
      if (labelParts.length > 1 && labelParts[1].trim().length > 0) {
        name = labelParts[1].trim();
        if (remark.length === 0) {
          remark = labelParts[0].trim();
        }
      } else if (label.trim().length > 0) {
        name = label.trim();
      } else if (issuer.length > 0) {
        name = issuer;
      }
    }

    type = this.normalizeTokenType(type);
    algorithm = this.standardAlgorithmForType(type, algorithm);
    digits = this.standardDigitsForType(type, digits);
    period = this.standardPeriodForType(type, period);
    secret = Totp.normalizeSecret(secret, type);
    if (secret.length === 0) {
      return undefined;
    }

    return {
      id: `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name,
      remark: remark,
      type: type,
      algorithm: algorithm,
      secret: secret,
      digits: digits,
      period: period,
      counter: counter,
      createdAt: Date.now()
    };
  }

  private createTokensFromScannedValue(scannedValue: string): TokenRecord[] {
    const trimmedValue = scannedValue.trim();
    if (trimmedValue.startsWith('{') || trimmedValue.startsWith('[')) {
      const records: TokenRecord[] = [];
      try {
        this.collectImportedJsonTokens(JSON.parse(trimmedValue), records);
      } catch (error) {
      }
      return this.uniqueTokenRecords(records);
    }
    if (trimmedValue.toLowerCase().startsWith('otpauth-migration://offline?')) {
      return GoogleAuthenticatorMigration.parse(scannedValue).map((item: GoogleOtpParameter): TokenRecord => {
        return this.createImportedTokenRecord(
          item.name,
          item.issuer,
          item.secret,
          item.type,
          item.algorithm,
          item.digits,
          DEFAULT_TOKEN_PERIOD,
          item.counter
        );
      });
    }
    const record = this.createTokenFromScannedValue(scannedValue);
    return record ? [record] : [];
  }

  private normalizeTokenCounter(counter?: number): number {
    return counter && counter > 0 ? Math.floor(counter) : 0;
  }

  private standardAlgorithmForType(type: string, algorithm: string): string {
    return type === 'TOTP' ? this.normalizeAlgorithm(algorithm) : 'SHA1';
  }

  private standardDigitsForType(type: string, digits: number): number {
    if (type === 'Steam') {
      return 5;
    }
    if (type === 'HOTP') {
      return digits === 8 ? 8 : DEFAULT_TOKEN_DIGITS;
    }
    if (digits === 4 || digits === 8) {
      return digits;
    }
    return DEFAULT_TOKEN_DIGITS;
  }

  private standardPeriodForType(type: string, period: number): number {
    if (type === 'Steam' || type === 'HOTP') {
      return DEFAULT_TOKEN_PERIOD;
    }
    return period === 60 ? 60 : DEFAULT_TOKEN_PERIOD;
  }

  private normalizeAlgorithm(algorithm: string): string {
    const normalized = algorithm.trim().toUpperCase();
    return ALGORITHM_OPTIONS.some((option: SelectOption) => option.value === normalized) ? normalized : 'SHA1';
  }

  private parseQrQuery(query: string): Map<string, string> {
    const params = new Map<string, string>();
    if (query.length === 0) {
      return params;
    }

    query.split('&').forEach((pair: string) => {
      const equalIndex = pair.indexOf('=');
      const rawKey = equalIndex >= 0 ? pair.substring(0, equalIndex) : pair;
      const rawValue = equalIndex >= 0 ? pair.substring(equalIndex + 1) : '';
      const key = this.decodeQrText(rawKey).toLowerCase();
      if (key.length > 0) {
        params.set(key, this.decodeQrText(rawValue));
      }
    });
    return params;
  }

  private decodeQrText(value: string): string {
    try {
      return decodeURIComponent(value.replace(/\+/g, ' '));
    } catch (error) {
      return value;
    }
  }

  private getErrorCode(error: Object): number {
    const maybeError = error as Record<string, Object>;
    const code = maybeError['code'];
    return typeof code === 'number' ? code : -1;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: this.t(message) });
    } catch (error) {
      console.error(`Failed to show toast: ${JSON.stringify(error)}`);
    }
  }

  private async hydrateTokenLogos(records: TokenRecord[]): Promise<TokenRecord[]> {
    const context = this.getAbilityContext();
    if (!context) {
      return records;
    }
    const result: TokenRecord[] = [];
    for (let index = 0; index < records.length; index++) {
      const record = records[index];
      if (!this.needsLogoHydration(record)) {
        result.push(record);
        if (this.importProgressVisible) {
          this.updateImportProgress(index + 1, index + 1, this.importRejectedCount, '正在导入令牌');
        }
        continue;
      }
      const logo = await LogoResolver.resolve(
        context,
        this.logoLookupIssuer(record.type, record.remark),
        this.logoLookupName(record.type, record.name)
      );
      result.push(logo ? this.withResolvedLogo(record, logo) : record);
      if (this.importProgressVisible) {
        this.updateImportProgress(index + 1, index + 1, this.importRejectedCount, '正在导入令牌');
      }
    }
    return result;
  }

  private withResolvedLogo(record: TokenRecord, logo: LogoResolveResult): TokenRecord {
    return {
      id: record.id,
      name: record.name,
      remark: record.remark,
      type: record.type,
      algorithm: record.algorithm,
      secret: record.secret,
      logoUri: logo.logoUri,
      logoLightUri: logo.logoLightUri,
      logoDarkUri: logo.logoDarkUri,
      logoSource: logo.logoSource,
      digits: record.digits,
      period: record.period,
      counter: record.counter,
      createdAt: record.createdAt
    };
  }

  private needsLogoHydration(record: TokenRecord): boolean {
    if (this.normalizeTokenType(record.type) === 'Steam' && record.logoSource !== 'simple-icons-v2:steam') {
      return true;
    }
    if (record.logoSource === LOGO_SOURCE_MANUAL) {
      return false;
    }
    const source = record.logoSource || '';
    if (source.indexOf('simple-icons:') === 0 || source.indexOf('simple-icons-brand:') === 0) {
      return true;
    }
    return (record.logoUri || '').length === 0 && (record.logoLightUri || '').length === 0 &&
      (record.logoDarkUri || '').length === 0;
  }

  private async hydrateMissingTokenLogos(): Promise<void> {
    if (this.tokens.every((token: TokenRecord) => !this.needsLogoHydration(token))) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    const nextTokens = await this.hydrateTokenLogos(this.tokens);
    let changed = false;
    for (let i = 0; i < nextTokens.length; i++) {
      if ((nextTokens[i].logoUri || '') !== (this.tokens[i].logoUri || '') ||
        (nextTokens[i].logoLightUri || '') !== (this.tokens[i].logoLightUri || '') ||
        (nextTokens[i].logoDarkUri || '') !== (this.tokens[i].logoDarkUri || '')) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }
    if (await TokenRepository.save(context, nextTokens)) {
      this.tokens = nextTokens;
      this.updateWidgetCards();
    }
  }

  private async loadTokens(): Promise<void> {
    try {
      const context = this.getAbilityContext();
      if (!context) {
        return;
      }
      this.tokens = await TokenRepository.load(context);
      this.updateWidgetCards();
      this.hydrateMissingTokenLogos();
    } catch (error) {
      console.error(`Failed to load tokens: ${JSON.stringify(error)}`);
    }
  }

  private async loadCardTokenIds(): Promise<void> {
    this.cardSelectedTokenIds = await FormManager.getCardTokenIds();
  }

  private async saveCardTokenIds(): Promise<void> {
    await FormManager.setCardTokenIds(this.cardSelectedTokenIds);
    this.updateWidgetCards();
  }

  private async updateWidgetCards(): Promise<void> {
    await FormManager.updateAllForms(this.tokens);
  }

  private async openCardTokenPicker(): Promise<void> {
    this.cardSelectedTokenIds = await FormManager.getCardTokenIds();
    this.pendingCardTokenIds = [...this.cardSelectedTokenIds];
    this.showCardTokenPicker = true;
  }

  private async openSystemFormManager(): Promise<void> {
    await this.updateWidgetCards();
    const want: Want = {
      bundleName: 'com.example.tool_2fa',
      abilityName: 'FormAbility',
      parameters: {
        'ohos.extra.param.key.form_dimension': formInfo.FormDimension.Dimension_2_4,
        'ohos.extra.param.key.form_name': 'widget_medium',
        'ohos.extra.param.key.module_name': 'entry'
      }
    };
    try {
      formProvider.openFormManager(want);
    } catch (error) {
      this.showToast('当前设备无法打开服务卡片管理器');
      console.error(`Failed to open form manager: ${JSON.stringify(error)}`);
    }
  }

  private pendingCardTokenIndex(tokenId: string): number {
    return this.pendingCardTokenIds.indexOf(tokenId);
  }

  private togglePendingCardToken(tokenId: string): void {
    const index = this.pendingCardTokenIndex(tokenId);
    if (index >= 0) {
      this.pendingCardTokenIds.splice(index, 1);
    } else {
      if (this.pendingCardTokenIds.length >= CARD_TOKEN_LIMIT) {
        this.showToast(this.tf('最多选择{0}个令牌', [`${CARD_TOKEN_LIMIT}`]));
        return;
      }
      this.pendingCardTokenIds.push(tokenId);
    }
    this.pendingCardTokenIds = [...this.pendingCardTokenIds];
  }

  private async commitCardTokenSelection(): Promise<void> {
    if (this.tokens.length > 0 && this.pendingCardTokenIds.length === 0) {
      this.showToast('请至少选择1个令牌');
      return;
    }
    this.cardSelectedTokenIds = [...this.pendingCardTokenIds];
    await this.saveCardTokenIds();
    this.showCardTokenPicker = false;
    this.showToast('服务卡片已更新');
  }

  private cardTokenSelectionSummary(): string {
    if (this.cardSelectedTokenIds.length === 0) {
      return this.tf('默认显示首页前{0}个令牌', [`${CARD_TOKEN_LIMIT}`]);
    }
    const names: string[] = [];
    for (const id of this.cardSelectedTokenIds) {
      const token = this.tokens.find((item: TokenRecord) => item.id === id);
      if (token) {
        names.push(this.tokenDisplayName(token));
      }
    }
    return names.length > 0 ? names.join(systemLanguageTag(this.languageInput, this.systemLanguage).startsWith('en') ? ', ' : '、') :
      this.t('所选令牌已不存在，请重新选择');
  }

  private async saveToken(): Promise<void> {
    if (this.isSaving) {
      return;
    }

    if (!this.isAddTokenFormComplete()) {
      this.validationMessage = '请完整填写令牌信息';
      return;
    }

    const editingId = this.editingTokenId;
    const editingToken = editingId.length > 0 ?
      this.tokens.find((token: TokenRecord) => token.id === editingId) : undefined;
    if (editingId.length > 0 && !editingToken) {
      this.validationMessage = '原令牌不存在，请返回后重试';
      return;
    }
    const name = this.nameInput.trim();
    const type = this.normalizeTokenType(this.typeInput);
    const secret = Totp.normalizeSecret(this.effectiveSecretInput(), type);
    if (secret.length === 0) {
      this.validationMessage = type === 'Steam' ?
        '密钥格式无效，请输入有效的Base32或Steam Base64密钥' :
        '密钥格式无效，请输入有效的Base32密钥';
      return;
    }

    this.isSaving = true;
    try {
      await this.ensureFormLogoResolvedForSave();
      const record: TokenRecord = {
        id: editingToken ? editingToken.id : `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
        name: name,
        remark: this.remarkInput.trim(),
        type: type,
        algorithm: this.selectedTokenAlgorithm(),
        secret: secret,
        logoUri: this.logoUriInput,
        logoLightUri: this.logoLightUriInput,
        logoDarkUri: this.logoDarkUriInput,
        logoSource: this.logoSourceInput,
        digits: this.selectedTokenDigits(),
        period: this.selectedTokenPeriod(),
        counter: editingToken ? this.normalizeTokenCounter(editingToken.counter) : 0,
        createdAt: editingToken ? editingToken.createdAt : Date.now()
      };
      const nextTokens = editingId.length > 0 ?
        this.tokens.map((token: TokenRecord) => token.id === record.id ? record : token) :
        [record].concat(this.tokens);
      if (!await this.persistTokens(nextTokens, editingToken ? '已更新' : '已保存')) {
        this.validationMessage = '保存失败，请重试';
        return;
      }
      this.backHome();
    } catch (error) {
      this.validationMessage = '保存失败，请重试';
      console.error(`Failed to save token: ${JSON.stringify(error)}`);
    } finally {
      this.isSaving = false;
    }
  }

  private async persistTokens(nextTokens: TokenRecord[], successMessage: string): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('保存失败，请重试');
      return false;
    }

    const saved = await TokenRepository.save(context, nextTokens);
    if (!saved) {
      this.showToast('保存失败，请重试');
      return false;
    }

    this.tokens = nextTokens;
    this.logoRenderVersion += 1;
    this.updateWidgetCards();
    this.showToast(successMessage);
    if (this.cloudBackupEnabled) {
      this.startCloudPush(false);
    }

    return true;
  }

  private getAbilityContext(): common.UIAbilityContext | undefined {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      return undefined;
    }
    return hostContext as common.UIAbilityContext;
  }
}
