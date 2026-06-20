import { abilityAccessCtrl, common, ConfigurationConstant, Permissions, Want } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { privacyManager } from '@kit.AppGalleryKit';
import { util } from '@kit.ArkTS';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { fileIo, picker } from '@kit.CoreFileKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { motion } from '@kit.MultimodalAwarenessKit';
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
  HdsTabsController,
  ScrollEffectType,
  hdsMaterial
} from '@kit.UIDesignKit';
import { CloudSyncState, TokenRepository } from '../data/TokenRepository';
import { TokenRecord } from '../model/TokenRecord';
import { Totp } from '../utils/Totp';
import { SettingsRepository } from '../data/SettingsRepository';
import { FormManager } from '../form/FormManager';
import { GoogleAuthenticatorMigration, GoogleOtpParameter } from '../utils/GoogleAuthenticatorMigration';

const APPLOCK_DOMAIN = 0x0001;
const APPLOCK_TAG = 'AppLock';
const DATA_SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const ERROR_RED: string = '#D93025';
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
const DEFAULT_TOKEN_DIGITS: number = 6;
const DEFAULT_TOKEN_PERIOD: number = 30;
const FORM_TEXT_SIZE: number = 14;
const PAGE_CARD_GAP: number = 10;
const FORM_ROW_HEIGHT: number = 60;
const FORM_BASIC_CARD_HEIGHT: number = FORM_ROW_HEIGHT * 2 + 1;
const FORM_DETAIL_CARD_HEIGHT: number = FORM_ROW_HEIGHT * 5 + 4;
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
const RESPONSIVE_CARD_MAX_WIDTH: number = 480;
const CARD_TOKEN_LIMIT: number = 8;
const TOKEN_CARD_HEIGHT: number = 75;
const TOKEN_NAME_TEXT_SIZE: number = 14;
const TOKEN_CODE_TEXT_SIZE: number = 24;
const TOKEN_TIME_TEXT_SIZE: number = 14;
const TOKEN_NEXT_CODE_TEXT_SIZE: number = 18;
const TOKEN_COUNTDOWN_SIZE: number = 40;
const TOKEN_COUNTDOWN_STROKE: number = 4;
const ME_CARD_RADIUS: number = 15;
const ME_LOGIN_CARD_HEIGHT: number = 75;
const ME_ROW_HEIGHT: number = 60;
const ME_AVATAR_SIZE: number = 48;
const ME_TEXT_SIZE: number = 18;
const ME_ACTION_TEXT_SIZE: number = 14;
const ME_ACTION_ICON_SIZE: number = 20;
const ME_ARROW_WIDTH: number = 7;
const ME_ARROW_HEIGHT: number = 14;
const ADD_BUTTON_SIZE: number = 50;
const ADD_BUTTON_RIGHT: number = 36;
const ADD_BUTTON_BOTTOM: number = 142;
const ADD_BUTTON_ICON_SIZE: number = 24;
const SWIPE_ACTION_SIZE: number = 40;
const SWIPE_ACTION_GAP: number = 10;
const SWIPE_ACTION_AREA_WIDTH: number = SWIPE_ACTION_SIZE * 3 + SWIPE_ACTION_GAP * 4;

enum PageMode {
  Home,
  AddToken
}

enum HomeTab {
  Token,
  Me
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
  @State private tokenLengthInput: string = '6位';
  @State private refreshTimeInput: string = '30秒';
  @State private currentTimeMs: number = Date.now();
  @State private isSaving: boolean = false;
  @State private isAddMenuOpen: boolean = false;
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
  @State private cloudBackupEnabled: boolean = false;
  @State private smartGripEnabled: boolean = false;
  @State private holdingHandStatus: motion.HoldingHandStatus = motion.HoldingHandStatus.NOT_HELD;
  @State private antiPeepEnabled: boolean = false;
  @State private appLockEnabled: boolean = false;
  @State private showNextToken: boolean = false;
  @State private themeModeInput: string = '跟随系统';
  @State private themeColorInput: string = '柠檬黄';
  @State private cloudSyncStatus: string = '尚未同步';
  @State private cloudLastSyncTime: number = 0;
  @State private cloudSyncing: boolean = false;
  @State private onboardingCompleted: boolean = false;
  @State private showOnboarding: boolean = false;
  @State private onboardingPage: number = 0;
  @StorageLink('tool2fa_systemDark') private systemDark: boolean = false;
  @StorageLink('tool2fa_requireAuth') private requireAuth: boolean = false;
  @StorageLink('tool2fa_isLocked') private isLocked: boolean = false;

  aboutToAppear(): void {
    this.loadTokens();
    this.loadSettings();
    this.loadCardTokenIds();
    this.timerId = setInterval(() => {
      this.currentTimeMs = Date.now();
    }, 1000);
    this.cardTimerId = setInterval(() => {
      this.updateWidgetCards();
    }, 5000);
    try {
      motion.on('holdingHandChanged', this.holdingHandChanged);
    } catch (error) {
      console.error(`Failed to register holdingHandChanged: ${JSON.stringify(error)}`);
    }
  }
  @StorageProp('tool2fa_statusBarHeight') private statusBarHeight: number = 0;
  @StorageProp('tool2fa_naviIndicatorHeight') private naviIndicatorHeight: number = 0;
  private homeScroller: Scroller = new Scroller();
  private meScroller: Scroller = new Scroller();
  private settingsScroller: Scroller = new Scroller();
  private cloudSpaceScroller: Scroller = new Scroller();
  private homePathStack: NavPathStack = new NavPathStack();
  private addPageScroller: Scroller = new Scroller();
  private homeTabsController: HdsTabsController = new HdsTabsController();
  private onboardingSwiperController: SwiperController = new SwiperController();
  private timerId: number = -1;
  private authInstance: userAuth.UserAuthInstance | null = null;
  private cardTimerId: number = -1;
  @State private cardSelectedTokenIds: string[] = [];
  @State private pendingCardTokenIds: string[] = [];
  @State private showCardTokenPicker: boolean = false;
  @State private showExportPicker: boolean = false;
  @State private exportSelectedIds: string[] = [];
  @State private showExportQR: boolean = false;
  @State private exportQRIndex: number = 0;
  private antiPeepCallback = (status: dlpAntiPeep.DlpAntiPeepStatus): void => {
    if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) {
      dlpAntiPeep.publishAntiPeepInformation();
      this.showToast('检测到多人注视，已触发防窥保护');
    }
  };

  private holdingHandChanged = (status: motion.HoldingHandStatus): void => {
    this.holdingHandStatus = status;
  };

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
    this.isHuaweiLoggedIn = settings.huaweiLoggedIn;
    this.huaweiNickname = settings.huaweiNickname;
    this.huaweiAvatarUri = settings.huaweiAvatarUri;
    this.huaweiUserId = settings.huaweiUserId;
    this.themeModeInput = settings.themeMode;
    this.themeColorInput = settings.themeColor;
    this.cloudSyncStatus = settings.cloudSyncStatus;
    this.cloudLastSyncTime = settings.cloudLastSyncTime;
    this.onboardingCompleted = settings.onboardingCompleted;
    this.showOnboarding = !settings.onboardingCompleted;
    this.applyColorMode();
    if (this.cloudBackupEnabled && this.isHuaweiLoggedIn) {
      this.configureCloudAutoSync(true);
    } else if (this.cloudBackupEnabled) {
      this.cloudBackupEnabled = false;
      this.saveSettings();
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
      huaweiLoggedIn: this.isHuaweiLoggedIn,
      huaweiNickname: this.huaweiNickname,
      huaweiAvatarUri: this.huaweiAvatarUri,
      huaweiUserId: this.huaweiUserId,
      themeMode: this.themeModeInput,
      themeColor: this.themeColorInput,
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
      title: '请进行身份验证',
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
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.appLockEnabled && this.isLocked) {
        Column() {
          Text('应用已锁定')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Text('请完成身份验证后使用')
            .fontSize(14)
            .fontColor(this.secondaryTextColor())
            .margin({ top: 8 })
          Button('验证身份')
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

      if (this.pageMode === PageMode.Home) {
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
        .bindToScrollable(this.selectedHomeTab === HomeTab.Token ? [this.homeScroller] : [this.meScroller])
        .hideBackButton(true)
        .titleMode(HdsNavigationTitleMode.MINI)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .width('100%')
        .height('100%')

        if (this.selectedHomeTab === HomeTab.Token) {
          this.AddFloatingButton()
        }
      } else {
        HdsNavigation() {
          this.AddTokenContent()
        }
        .mode(NavigationMode.Stack)
        .titleBar({
          content: {
            title: {
              mainTitle: this.editingTokenId.length > 0 ? '编辑令牌' : '新增令牌'
            },
            backIcon: {
              action: () => {
                this.backHome();
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
        .bindToScrollable([this.addPageScroller])
        .hideBackButton(false)
        .titleMode(HdsNavigationTitleMode.MINI)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .width('100%')
        .height('100%')
      }

      if (this.showOnboarding) {
        this.OnboardingOverlay()
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
        Button('跳过')
          .height(44)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.cardBackgroundColor())
          .onClick(() => {
            this.completeOnboarding();
          })

        Button(this.onboardingPage === 3 ? '开始使用' : '下一页')
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
        Text('Authenticator')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text('专注、安全、随时可用的二次验证器')
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
        Text('多种录入方式')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text('录入密钥、扫描二维码或导入备份，轻松迁移你的令牌。')
          .fontSize(16)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
        this.OnboardingFeatureList(['兼容 Google Authenticator 迁移二维码', '支持 JSON 和 otpauth 数据'])
      } else if (index === 2) {
        Image($r('app.media.ic_tab_token_selected'))
          .width(80)
          .height(80)
          .objectFit(ImageFit.Contain)
        Text('一眼掌握所有令牌')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text('手机、折叠屏和平板自适应排版，桌面服务卡片让常用令牌抬眼即见。')
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
        Text('备份与隐私，都由你决定')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
        Text('可选华为云空间同步、JSON 或二维码备份，并提供应用锁与防窥保护。')
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
          Text(feature)
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
    HdsTabs({ controller: this.homeTabsController }) {
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

  @Builder
  private SettingsNavDestination(name: string, pageInfos: Object) {
    NavDestination() {
      HdsNavigation() {
        if (name === 'cloudSpace') {
          this.CloudSpacePageContent()
        } else {
          this.SettingsPageContent()
        }
      }
      .mode(NavigationMode.Stack)
      .titleBar({
        content: {
          title: {
            mainTitle: name === 'cloudSpace' ? '华为云空间' : '设置'
          },
          backIcon: {
            action: () => {
              this.homePathStack.pop(true);
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
      .bindToScrollable(name === 'cloudSpace' ? [this.cloudSpaceScroller] : [this.settingsScroller])
      .hideBackButton(false)
      .titleMode(HdsNavigationTitleMode.MINI)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .mode(NavDestinationMode.STANDARD)
    .systemTransition(NavigationSystemTransitionType.DEFAULT)
    .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private TokenListContent() {
    List({ scroller: this.homeScroller }) {
      ListItemGroup({
        header: this.HomeSearchGroupHeader,
        footer: this.TokenListFooter,
        space: PAGE_CARD_GAP
      }) {
        ForEach(this.filteredTokens(), (token: TokenRecord) => {
          ListItem() {
            this.TokenCard(token)
          }
          .width('100%')
          .clip(true)
          .swipeAction({
            end: () => {
              this.TokenSwipeActions(token)
            },
            edgeEffect: SwipeEdgeEffect.Spring
          })
        }, (token: TokenRecord) => token.id)
      }
    }
    .width('100%')
    .height('100%')
    .lanes({ minLength: RESPONSIVE_CARD_MIN_WIDTH, maxLength: RESPONSIVE_CARD_MAX_WIDTH }, PAGE_CARD_GAP)
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
  private MePageContent() {
    List({ scroller: this.meScroller }) {
      ListItemGroup({ header: this.MeLoginGroupHeader, space: PAGE_CARD_GAP }) {
        ListItem() {
          this.MeActionCard([
            ['华为云空间', $r('app.media.ic_me_cloud')],
            ['备份导出', $r('app.media.ic_me_cloud')],
            ['设置', $r('app.media.ic_me_settings')]
          ], 0)
        }
        .width('100%')

        ListItem() {
          this.MeActionCard([
            ['订阅会员服务', $r('app.media.ic_me_subscription')],
            ['更多作品', $r('app.media.ic_me_more')]
          ], 1)
        }
        .width('100%')

        ListItem() {
          this.MeActionCard([
            ['开源地址', $r('app.media.ic_me_gitcode')],
            ['用户协议', $r('app.media.ic_me_contract')],
            ['隐私声明', $r('app.media.ic_me_contract')],
            ['建议与反馈', $r('app.media.ic_me_feedback')]
          ], 2)
        }
        .width('100%')
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
        Text(this.isHuaweiLoggedIn ? this.huaweiNickname : '登录华为账号')
          .fontSize(ME_TEXT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.isHuaweiLoggedIn ? '已登录·点击退出' : '点击登录')
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
      } else {
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

      Text(label)
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
      this.SettingsSectionTitle('功能与安全')
      this.SettingsSecurityCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsAppearanceSection() {
    Column() {
      this.SettingsSectionTitle('界面外观')
      this.SettingsAppearanceCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsWidgetSection() {
    Column() {
      this.SettingsSectionTitle('服务卡片')
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
          Text('同步设置')
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

          Text('同步操作')
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

          Text('同步记录')
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width('100%')
            .padding({ left: 20, top: 18, bottom: 8 })

          Column() {
            this.CloudSpaceInfoRow('同步状态', this.cloudSyncStatus)
            this.MeCardDivider()
            this.CloudSpaceInfoRow('最后同步时间', this.cloudLastSyncTimeText())
          }
          .width('100%')
          .height(ME_ROW_HEIGHT * 2 + 1)
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
        Text('选择要导出的令牌')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text(this.exportSelectedIds.length === this.tokens.length ? '取消全选' : '全选')
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

      Text(`已选 ${this.exportSelectedIds.length} 个令牌`)
        .width('100%')
        .fontSize(12)
        .fontColor(this.secondaryTextColor())
        .padding({ left: 20, right: 20, bottom: 8 })

      List() {
        if (this.tokens.length === 0) {
          ListItem() {
            Text('暂无令牌，请先添加令牌')
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
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.searchBackgroundColor())
          .onClick(() => {
            this.showExportPicker = false;
          })

        Button('下一步')
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
      .padding({ left: 20, right: 20, top: 10, bottom: this.naviIndicatorHeight + 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ExportQRCodeSheet() {
    Column() {
      if (this.exportQRIndex < this.exportSelectedTokens().length) {
        Text(this.tokenDisplayName(this.exportSelectedTokens()[this.exportQRIndex]))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .margin({ top: 8, bottom: 16 })

        QRCode(this.buildOtpAuthUri(this.exportSelectedTokens()[this.exportQRIndex]))
          .width(220)
          .height(220)
          .color(this.primaryTextColor())
          .backgroundColor(this.cardBackgroundColor())
          .margin({ bottom: 12 })

        Text(`${this.exportQRIndex + 1}/${this.exportSelectedTokens().length}`)
          .fontSize(12)
          .fontColor(this.secondaryTextColor())
          .margin({ bottom: 16 })

        Row({ space: 12 }) {
          Button('上一个')
            .fontSize(14)
            .layoutWeight(1)
            .enabled(this.exportQRIndex > 0)
            .onClick(() => {
              if (this.exportQRIndex > 0) {
                this.exportQRIndex--;
              }
            })
          Button(this.exportQRIndex === this.exportSelectedTokens().length - 1 ? '完成' : '下一个')
            .fontSize(14)
            .layoutWeight(1)
            .fontColor(this.accentContrastColor())
            .backgroundColor(this.accentColor())
            .onClick(() => {
              if (this.exportQRIndex < this.exportSelectedTokens().length - 1) {
                this.exportQRIndex++;
              } else {
                this.showExportQR = false;
              }
            })
        }
        .width('100%')
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
      Text(label)
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
      Text(label)
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      Text(value)
        .fontSize(ME_ACTION_TEXT_SIZE)
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
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .padding({ left: 20, right: 18 })
    .borderRadius(ME_CARD_RADIUS)
    .backgroundColor(this.cardBackgroundColor())
  }

  @Builder
  private SettingsSwitchRow(label: string, isOn: boolean, onChanged: (isOn: boolean) => void) {
    Row() {
      Text(label)
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
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
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
      Text(label)
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

      Select(values)
        .selected(this.optionIndex(values, selectedValue))
        .value(selectedValue)
        .font({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .fontColor(this.secondaryTextColor())
        .selectedOptionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .selectedOptionFontColor(this.accentContrastColor())
        .selectedOptionBgColor(this.accentColor())
        .optionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onSelect((index: number, value: string) => {
          onSelected(value);
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
            `已选择 ${this.cardSelectedTokenIds.length} 个令牌` : '按首页顺序显示')
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
  }

  @Builder
  private CardTokenPickerSheet() {
    Column() {
      Row() {
        Text('选择卡片显示的令牌')
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

      Text('卡片按勾选顺序显示令牌')
        .width('100%')
        .fontSize(12)
        .fontColor(this.secondaryTextColor())
        .padding({ left: 20, right: 20, bottom: 8 })

      List() {
        if (this.tokens.length === 0) {
          ListItem() {
            Text('暂无令牌，请先添加令牌')
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
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .backgroundColor(this.searchBackgroundColor())
          .onClick(() => {
            this.showCardTokenPicker = false;
          })

        Button('完成')
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
    Text(`- 共${this.filteredTokens().length}个 -`)
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
      Search({ value: this.searchText, placeholder: 'Search' })
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
    if (this.selectedHomeTab !== HomeTab.Token || !this.isHomeSearchCollapsed) {
      return { value: [], maxCount: 0 };
    }

    return {
      value: [{
        content: {
          icon: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            .fontColor([this.primaryTextColor()]),
          label: '搜索',
          action: () => {
            this.scrollHomeSearchIntoView();
          }
        }
      }],
      maxCount: 1
    };
  }

  private tokenTabBarStyle(): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier($r('sys.symbol.key_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.primaryTextColor()]),
      selected: new SymbolGlyphModifier($r('sys.symbol.key_fill'))
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([this.accentColor()])
    }, '令牌')
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
    }, '我的')
      .labelStyle({
        font: { size: HOME_NAV_TEXT_SIZE },
        unselectedColor: this.primaryTextColor(),
        selectedColor: this.accentColor()
      });
  }

  @Builder
  private AddFloatingButton() {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.ic_add_page'))
        .width(ADD_BUTTON_ICON_SIZE)
        .height(ADD_BUTTON_ICON_SIZE)
        .objectFit(ImageFit.Contain)
    }
    .width(ADD_BUTTON_SIZE)
    .height(ADD_BUTTON_SIZE)
    .margin({
      left: this.isLeftHanded() ? ADD_BUTTON_RIGHT : 0,
      right: this.isLeftHanded() ? 0 : ADD_BUTTON_RIGHT,
      bottom: ADD_BUTTON_BOTTOM
    })
    .backgroundColor(this.accentColor())
    .onClick(() => {
      this.isAddMenuOpen = true;
    })
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

  private isLeftHanded(): boolean {
    return this.smartGripEnabled &&
      this.holdingHandStatus === motion.HoldingHandStatus.LEFT_HAND_HELD;
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
      Button({ type: ButtonType.Circle }) {
        Image(icon)
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
      }
      .width(50)
      .height(50)
      .backgroundColor(this.accentColor())
      .onClick(onClick)

      Text(label)
        .fontSize(14)
        .fontColor(this.primaryTextColor())
        .fontWeight(FontWeight.Medium)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private TokenCard(token: TokenRecord) {
    Row() {
      Column() {
        Text(this.tokenDisplayName(token))
          .fontSize(TOKEN_NAME_TEXT_SIZE)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          Text(this.tokenCode(token))
            .fontSize(TOKEN_CODE_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentColor())
            .letterSpacing(0)
            .maxLines(1)
            .contentTransition(new NumericTextTransition({
              flipDirection: FlipDirection.UP,
              enableBlur: true
            }))
            .animation({ duration: 400, curve: Curve.Smooth })

          if (this.showNextToken) {
            Text('←')
              .fontSize(14)
              .fontColor('#D5D5D5')
              .fontWeight(FontWeight.Regular)

            Text(this.nextTokenCode(token))
              .fontSize(TOKEN_NEXT_CODE_TEXT_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor('#D5D5D5')
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
      .justifyContent(FlexAlign.SpaceEvenly)
      .layoutWeight(1)
      .height('100%')

      this.TokenCountdownRing(token)
    }
    .height(TOKEN_CARD_HEIGHT)
    .width('100%')
    .padding({ left: 24, right: 18, top: 4, bottom: 4 })
    .borderRadius(15)
    .backgroundColor(this.cardBackgroundColor())
    .alignItems(VerticalAlign.Center)
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
  private TokenSwipeActions(token: TokenRecord) {
    Row({ space: SWIPE_ACTION_GAP }) {
      this.SwipeActionButton($r('app.media.ic_token_top'), () => {
        this.pinTokenToTop(token.id);
      })

      this.SwipeActionButton($r('app.media.ic_token_edit'), () => {
        this.openEditPage(token);
      })

      this.SwipeActionButton($r('app.media.ic_token_delete'), () => {
        this.confirmDeleteToken(token);
      })
    }
    .width(SWIPE_ACTION_AREA_WIDTH)
    .height(TOKEN_CARD_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
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

        if (this.validationMessage.length > 0) {
          Text(this.validationMessage)
            .fontSize(14)
            .fontColor(ERROR_RED)
            .width('100%')
            .margin({ top: PAGE_CARD_GAP, left: 8 })
        }

        Button() {
          Text(this.isSaving ? '保存中' : '确认')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.cardBackgroundColor())
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
  private AddTokenBasicCard() {
    Column() {
      this.InputRow('名称', this.nameInput, '请输入', (value: string) => {
        this.nameInput = value;
        this.validationMessage = '';
      })
      this.Separator()
      this.InputRow('备注', this.remarkInput, '请输入', (value: string) => {
        this.remarkInput = value;
        this.validationMessage = '';
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
      this.InputRow('密钥', this.secretInput, '请输入', (value: string) => {
        this.secretInput = value;
        this.validationMessage = '';
      })
      this.Separator()
      this.SelectRow('类型', this.formTokenType(), TYPE_OPTIONS, (value: string) => {
        this.typeInput = this.normalizeTokenType(value);
        this.applyTypeDefaults();
        this.validationMessage = '';
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
      Text(label)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
        .width(72)

      TextInput({ text: value, placeholder: placeholder })
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
  private SelectRow(
    label: string,
    selectedValue: string,
    values: SelectOption[],
    onSelected: (value: string) => void
  ) {
    Row() {
      Text(label)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
        .width(72)

      Row() {
        Select(values)
          .selected(this.optionIndex(values, selectedValue))
          .value(selectedValue)
          .font({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .fontColor(this.primaryTextColor())
          .selectedOptionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .selectedOptionFontColor(this.primaryTextColor())
          .selectedOptionBgColor(this.accentColor())
          .optionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .onSelect((index: number, value: string) => {
            onSelected(value);
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

  private pageBackgroundColor(): string {
    return this.isDarkTheme() ? '#000000' : '#F2F3F5';
  }

  private cardBackgroundColor(): string {
    return this.isDarkTheme() ? '#303030' : '#FFFFFF';
  }

  private primaryTextColor(): string {
    return this.isDarkTheme() ? '#EEEEEE' : '#1A1A1A';
  }

  private secondaryTextColor(): string {
    return this.isDarkTheme() ? '#A3A3A3' : '#777777';
  }

  private dividerColor(): string {
    return this.isDarkTheme() ? '#444444' : '#E6E6E6';
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

  @Builder
  private Separator() {
    Divider()
      .strokeWidth(1)
      .color(this.dividerColor())
  }

  private currentHomeTitle(): string {
    return this.selectedHomeTab === HomeTab.Token ? '令牌' : '我的';
  }

  private tokenDisplayName(token: TokenRecord): string {
    const remark = token.remark.trim();
    return remark.length > 0 ? `${token.name}（${remark}）` : token.name;
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
    return `${Totp.remainingSeconds(this.currentTimeMs, this.tokenPeriodForRecord(token))} 秒`;
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
    return !this.isSaving && this.isAddTokenFormComplete();
  }

  private isAddTokenFormComplete(): boolean {
    return this.nameInput.trim().length > 0 &&
      this.remarkInput.trim().length > 0 &&
      this.typeInput.trim().length > 0 &&
      this.algorithmInput.trim().length > 0 &&
      this.secretInput.trim().length > 0 &&
      this.tokenLengthInput.trim().length > 0 &&
      this.refreshTimeInput.trim().length > 0;
  }

  private async loginHuaweiAccount(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法拉起华为账号登录');
      return;
    }

    try {
      const provider = new authentication.HuaweiIDProvider();
      const cancelRequest = provider.createCancelAuthorizationRequest();
      const controller = new authentication.AuthenticationController(context);
      await controller.executeRequest(cancelRequest);
    } catch (error) {
      // ignore cancel failure
    }

    const authResultCode = await this.doAuthorizeWithHuaweiID(context);
  }

  private async doAuthorizeWithHuaweiID(context: common.UIAbilityContext): Promise<number> {
    const provider = new authentication.HuaweiIDProvider();
    const request = provider.createAuthorizationWithHuaweiIDRequest();
    request.scopes = ['openid', 'profile'];
    request.permissions = ['serviceauthcode'];
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
        return code;
      }
      if (code === 1001502005) {
        this.showToast('网络异常，请检查网络');
        return code;
      }
      if (code === 1001502001) {
        const loginOk = await this.doLoginWithHuaweiID(context);
        if (loginOk) {
          return await this.doAuthorizeWithHuaweiID(context);
        }
        return code;
      }
      this.showToast('华为账号登录失败');
      console.error(`Failed to authorize with Huawei ID: ${JSON.stringify(error)}`);
      return code;
    }
  }

  private async doLoginWithHuaweiID(context: common.UIAbilityContext): Promise<boolean> {
    const provider = new authentication.HuaweiIDProvider();
    const loginRequest = provider.createLoginWithHuaweiIDRequest();
    loginRequest.forceLogin = true;
    loginRequest.state = util.generateRandomUUID();

    try {
      const controller = new authentication.AuthenticationController(context);
      await controller.executeRequest(loginRequest);
      return true;
    } catch (error) {
      const errorCode = this.getErrorCode(error);
      if (errorCode === 1001502012) {
        return false;
      }
      if (errorCode === 1001500002) {
        return false;
      }
      this.showToast('登录失败，请重试');
      console.error(`Failed to login with Huawei ID: ${JSON.stringify(error)}`);
      return false;
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
      await this.configureCloudAutoSync(false);
      this.cloudBackupEnabled = false;
      this.saveSettings();
      this.showToast('云空间自动同步已关闭');
      return;
    }

    this.cloudBackupEnabled = true;

    if (!this.isHuaweiLoggedIn) {
      setTimeout((): void => {
        this.cloudBackupEnabled = false;
        this.cloudSyncStatus = '请先登录华为账号';
        this.saveSettings();
      }, 0);
      this.showToast('开启自动同步失败，请先登录华为账号');
      return;
    }

    if (!await this.ensureDataSyncPermission()) {
      this.cloudSyncStatus = '未授权云同步';
      this.saveSettings();
      this.showToast('需要授权跨设备数据同步');
      return;
    }

    if (!await this.configureCloudAutoSync(true)) {
      this.cloudSyncStatus = '无法开启云同步';
      this.saveSettings();
      this.showToast('请确认已登录华为账号并开启云空间');
      return;
    }

    this.cloudBackupEnabled = true;
    this.saveSettings();
    this.showToast('云空间自动同步已开启');
    await this.pushTokensToCloud();
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
    if (this.cloudSyncing) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法访问云空间');
      return;
    }
    this.cloudSyncing = true;
    this.cloudSyncStatus = '正在推送';
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步');
      return;
    }
    if (!await TokenRepository.configureCloudSync(context, this.cloudBackupEnabled)) {
      this.finishCloudSyncFailure('云同步不可用');
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
        this.finishCloudSyncFailure('推送失败');
      } else {
        this.showCloudSyncFailure();
      }
    } else if (this.cloudSyncing) {
      this.updateCloudSyncState({ status: '同步成功', finished: true, success: true });
      this.showToast('推送成功');
    } else {
      this.showToast('推送成功');
    }
  }

  private async pullTokensFromCloud(): Promise<void> {
    if (this.cloudSyncing) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法访问云空间');
      return;
    }
    this.cloudSyncing = true;
    this.cloudSyncStatus = '正在获取';
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步');
      return;
    }
    if (!await TokenRepository.configureCloudSync(context, this.cloudBackupEnabled)) {
      this.finishCloudSyncFailure('云同步不可用');
      return;
    }
    const records = await TokenRepository.pullFromCloud(context, (state: CloudSyncState): void => {
      this.updateCloudSyncState(state);
    });
    if (!records) {
      if (this.cloudSyncing) {
        this.finishCloudSyncFailure('获取失败');
      } else {
        this.showCloudSyncFailure();
      }
      return;
    }
    this.tokens = records;
    if (this.cloudSyncing) {
      this.updateCloudSyncState({ status: '同步成功', finished: true, success: true });
    }
    this.showToast('获取成功');
  }

  private updateCloudSyncState(state: CloudSyncState): void {
    this.cloudSyncStatus = state.status;
    if (state.finished) {
      this.cloudSyncing = false;
      if (state.success) {
        this.cloudLastSyncTime = Date.now();
      }
      this.saveSettings();
    }
  }

  private showCloudSyncFailure(): void {
    if (this.cloudSyncStatus === '云服务未启用（3）') {
      this.showToast('云服务未启用（3），请核对云数据库与测试应用开关');
      return;
    }
    this.showToast(this.cloudSyncStatus);
  }

  private finishCloudSyncFailure(status: string): void {
    this.cloudSyncing = false;
    this.cloudSyncStatus = status;
    this.saveSettings();
    this.showToast(status);
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
    const context = this.getAbilityContext();
    if (!context) {
      return false;
    }
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, [DATA_SYNC_PERMISSION]);
      return result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      console.error(`Failed to request data sync permission: ${JSON.stringify(error)}`);
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
    this.getUIContext().showActionSheet({
      title: '选择导出格式',
      message: '选择密钥备份的导出方式',
      sheets: [
        {
          title: '导出密钥 JSON 文件',
          action: () => {
            this.exportAsJSON();
          }
        },
        {
          title: '生成二维码',
          action: () => {
            this.exportQRIndex = 0;
            this.showExportQR = true;
          }
        }
      ],
      autoCancel: true,
      cancel: () => {
      }
    });
  }

  private buildOtpAuthUri(token: TokenRecord): string {
    const type = this.normalizeTokenType(token.type).toLowerCase();
    const label = encodeURIComponent(
      token.remark.trim().length > 0 ? `${token.name}:${token.remark}` : token.name
    );
    const issuer = encodeURIComponent(token.name);
    const params: string[] = [
      `secret=${token.secret}`,
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

  private async exportAsJSON(): Promise<void> {
    const selectedTokens = this.exportSelectedTokens();
    if (selectedTokens.length === 0) {
      return;
    }
    const uris: string[] = selectedTokens.map((t: TokenRecord) => this.buildOtpAuthUri(t));
    const exportData: Record<string, Object> = {
      'encrypted': false,
      'exportDate': new Date().toISOString(),
      'app': 'Tool_2FA',
      'version': 1,
      'uris': uris
    };
    const jsonContent = JSON.stringify(exportData, null, 2);
    const fileName = `2fa_backup_${this.formatExportDate()}.json`;
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.save(options);
      if (result && result.length > 0) {
        const file = fileIo.openSync(result[0], fileIo.OpenMode.READ_WRITE);
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

  private toggleSmartGrip(isOn: boolean): void {
    if (!isOn) {
      this.smartGripEnabled = false;
      this.holdingHandStatus = motion.HoldingHandStatus.NOT_HELD;
      this.saveSettings();
      return;
    }
    this.smartGripEnabled = true;
    this.saveSettings();
  }

  private async toggleAntiPeep(isOn: boolean): Promise<void> {
    if (!isOn) {
      this.unregisterAntiPeep();
      this.antiPeepEnabled = false;
      this.saveSettings();
      return;
    }

    const context = this.getAbilityContext();
    if (!context) {
      this.antiPeepEnabled = false;
      this.saveSettings();
      this.showToast('无法打开防窥保护');
      return;
    }

    try {
      const capSupported = canIUse('SystemCapability.Security.DlpAntiPeep');
      if (!capSupported) {
        this.antiPeepEnabled = false;
        this.saveSettings();
        this.showToast('当前设备不支持防窥保护');
        return;
      }
      const result = await dlpAntiPeep.requestAntiPeepOptions(context);
      if (result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
        result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) {
        dlpAntiPeep.on('dlpAntiPeep', this.antiPeepCallback);
        this.antiPeepEnabled = true;
        this.showToast('防窥保护已开启');
        this.saveSettings();
        return;
      }
      this.antiPeepEnabled = false;
      this.saveSettings();
      this.showToast('防窥保护开启失败');
    } catch (error) {
      this.isLocked = false;
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

  private unregisterAntiPeep(): void {
    try {
      dlpAntiPeep.off('dlpAntiPeep', this.antiPeepCallback);
    } catch (error) {
      console.error(`Failed to unregister anti-peep: ${JSON.stringify(error)}`);
    }
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
    this.typeInput = 'TOTP';
    this.algorithmInput = 'SHA1';
    this.secretInput = '';
    this.tokenLengthInput = '6位';
    this.refreshTimeInput = '30秒';
    this.applyTypeDefaults();
    this.validationMessage = '';
    this.pageMode = PageMode.AddToken;
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
      this.openPrivacyLink(privacyManager.AppPrivacyLinkType.USER_AGREEMENT_LINK, '用户协议');
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
      this.showToast(`未配置${label}地址`);
    } catch (error) {
      console.error(`Failed to query ${label}: ${JSON.stringify(error)}`);
      this.showToast(`暂时无法打开${label}`);
    }
  }

  private showFeedbackDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '帮助与反馈',
      message: '反馈邮箱：1207523787@qq.com',
      autoCancel: true,
      primaryButton: {
        value: '确定',
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
    this.typeInput = this.normalizeTokenType(token.type);
    this.algorithmInput = this.normalizeAlgorithm(token.algorithm);
    this.secretInput = token.secret;
    this.tokenLengthInput = this.tokenDigitsLabel(token.digits);
    this.refreshTimeInput = this.tokenPeriodLabel(token.period);
    this.applyTypeDefaults();
    this.validationMessage = '';
    this.pageMode = PageMode.AddToken;
  }

  private backHome(): void {
    this.validationMessage = '';
    this.editingTokenId = '';
    this.pageMode = PageMode.Home;
  }

  private async pinTokenToTop(tokenId: string): Promise<void> {
    const index = this.tokens.findIndex((token: TokenRecord) => token.id === tokenId);
    if (index <= 0) {
      return;
    }

    const target = this.tokens[index];
    const nextTokens = [target].concat(this.tokens.filter((token: TokenRecord) => token.id !== tokenId));
    await this.persistTokens(nextTokens, '已置顶');
  }

  private confirmDeleteToken(token: TokenRecord): void {
    this.getUIContext().showAlertDialog({
      title: '删除令牌',
      message: `确定删除“${token.name}”？删除后无法恢复。`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
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

    const nextTokens = this.mergeImportedTokens(this.uniqueTokenRecords(records), this.tokens);
    const addedCount = nextTokens.length - this.tokens.length;
    if (addedCount === 0) {
      this.showToast('令牌已存在');
      return;
    }
    const message = addedCount > 1 ? `已导入${addedCount}个令牌` : '已保存';
    if (!await this.persistTokens(nextTokens, message)) {
      return;
    }
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
        fileSuffixFilters: ['2FA|.txt,.json,.csv,.tsv,.otpauth,.mafile']
      });
      if (uris.length === 0) {
        return;
      }

      const content = await this.readImportFile(uris[0]);
      const records = this.parseImportedTokenContent(content);
      if (records.length === 0) {
        this.showToast('未识别到可导入的令牌');
        return;
      }

      const nextTokens = this.mergeImportedTokens(records, this.tokens);
      if (!await this.persistTokens(nextTokens, `已导入${records.length}个令牌`)) {
        return;
      }
      this.searchText = '';
      this.pageMode = PageMode.Home;
    } catch (error) {
      this.showToast('导入失败，请选择有效文件');
      console.error(`Failed to import token file: ${JSON.stringify(error)}`);
    }
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
    const trimmed = content.trim();
    if (trimmed.length === 0) {
      return records;
    }

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        this.collectImportedJsonTokens(JSON.parse(trimmed), records);
      } catch (error) {
      }
    }

    const lines = trimmed.split(/\r?\n/);
    const header = this.importHeader(lines);
    lines.forEach((line: string, index: number) => {
      const lineRecord = this.parseImportedLine(line, header, index);
      if (lineRecord) {
        records.push(lineRecord);
      }
    });
    return this.uniqueTokenRecords(records);
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

    return this.createImportedTokenRecord(`导入令牌${index + 1}`, '', columns[0], 'TOTP', 'SHA1',
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
    const uri = this.firstString(source, ['uri', 'otpAuthUri', 'otpauth', 'otpAuth']);
    if (uri.length > 0) {
      const uriRecord = this.createTokenFromScannedValue(uri);
      if (uriRecord) {
        records.push(uriRecord);
      }
    }

    const info = this.objectValue(source['info']);
    const otp = this.objectValue(source['otp']);
    const tokenSource = info || otp || source;
    const secret = this.firstString(tokenSource, ['secret', 'secretKey', 'shared_secret']);
    if (secret.length > 0) {
      let jsonType = this.firstString(source, ['type', 'tokenType']) || this.firstString(tokenSource, ['type', 'tokenType']);
      if (jsonType.length === 0 && this.firstString(tokenSource, ['shared_secret']).length > 0) {
        jsonType = 'Steam';
      }
      records.push(this.createImportedTokenRecord(
        this.firstString(source, ['name', 'account', 'label']) || this.firstString(tokenSource, ['name', 'account']),
        this.firstString(source, ['issuer', 'remark']) || this.firstString(tokenSource, ['issuer']),
        secret,
        jsonType,
        this.firstString(source, ['algorithm', 'algo']) || this.firstString(tokenSource, ['algorithm', 'algo']),
        this.firstNumber(source, ['digits']) || this.firstNumber(tokenSource, ['digits']),
        this.firstNumber(source, ['period']) || this.firstNumber(tokenSource, ['period']),
        this.firstNumber(source, ['counter']) || this.firstNumber(tokenSource, ['counter'])
      ));
    }

    Object.keys(source).forEach((key: string) => {
      this.collectImportedJsonTokens(source[key], records);
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
    const tokenType = this.normalizeTokenType(type || 'TOTP');
    return {
      id: `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name.trim().length > 0 ? name.trim() : '导入令牌',
      remark: remark.trim(),
      type: tokenType,
      algorithm: this.standardAlgorithmForType(tokenType, algorithm || 'SHA1'),
      secret: secret.trim(),
      digits: this.standardDigitsForType(tokenType, isNaN(digits) ? DEFAULT_TOKEN_DIGITS : digits),
      period: this.standardPeriodForType(tokenType, isNaN(period) ? DEFAULT_TOKEN_PERIOD : period),
      counter: this.normalizeTokenCounter(isNaN(counter) ? 0 : counter),
      createdAt: Date.now()
    };
  }

  private firstString(source: Record<string, Object>, keys: string[]): string {
    for (const key of keys) {
      const value = source[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim();
      }
    }
    return '';
  }

  private firstNumber(source: Record<string, Object>, keys: string[]): number {
    for (const key of keys) {
      const value = source[key];
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

  private objectValue(value: Object): Record<string, Object> | undefined {
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      return value as Record<string, Object>;
    }
    return undefined;
  }

  private uniqueTokenRecords(records: TokenRecord[]): TokenRecord[] {
    const uniqueRecords: TokenRecord[] = [];
    records.forEach((record: TokenRecord) => {
      const exists = uniqueRecords.some((item: TokenRecord) => {
        return item.secret === record.secret && item.name === record.name && item.type === record.type;
      });
      if (!exists && record.secret.trim().length > 0) {
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

    let name = '扫描令牌';
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
    if (scannedValue.trim().toLowerCase().startsWith('otpauth-migration://offline?')) {
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
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
      console.error(`Failed to show toast: ${JSON.stringify(error)}`);
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

  private openCardTokenPicker(): void {
    this.pendingCardTokenIds = [...this.cardSelectedTokenIds];
    this.showCardTokenPicker = true;
  }

  private openSystemFormManager(): void {
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
        this.showToast(`最多选择${CARD_TOKEN_LIMIT}个令牌`);
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
      return `默认显示首页前${CARD_TOKEN_LIMIT}个令牌`;
    }
    const names: string[] = [];
    for (const id of this.cardSelectedTokenIds) {
      const token = this.tokens.find((item: TokenRecord) => item.id === id);
      if (token) {
        names.push(this.tokenDisplayName(token));
      }
    }
    return names.length > 0 ? names.join('、') : '所选令牌已不存在，请重新选择';
  }

  private async saveToken(): Promise<void> {
    if (this.isSaving) {
      return;
    }

    this.applyTypeDefaults();

    if (!this.isAddTokenFormComplete()) {
      this.validationMessage = '请完整填写令牌信息';
      return;
    }

    const name = this.nameInput.trim();
    const secret = this.secretInput.trim();

    this.isSaving = true;
    const editingToken = this.tokens.find((token: TokenRecord) => token.id === this.editingTokenId);
    const record: TokenRecord = {
      id: editingToken ? editingToken.id : `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name,
      remark: this.remarkInput.trim(),
      type: this.normalizeTokenType(this.typeInput),
      algorithm: this.selectedTokenAlgorithm(),
      secret: secret,
      digits: this.selectedTokenDigits(),
      period: this.selectedTokenPeriod(),
      counter: editingToken ? this.normalizeTokenCounter(editingToken.counter) : 0,
      createdAt: editingToken ? editingToken.createdAt : Date.now()
    };

    try {
      const nextTokens = editingToken ?
        this.tokens.map((token: TokenRecord) => token.id === record.id ? record : token) :
        [record].concat(this.tokens);
      if (!await this.persistTokens(nextTokens, editingToken ? '已更新' : '已保存')) {
        this.validationMessage = '保存失败，请重试';
        return;
      }
      this.pageMode = PageMode.Home;
      this.editingTokenId = '';
      this.validationMessage = '';
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
    this.showToast(successMessage);

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
