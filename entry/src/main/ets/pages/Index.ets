import { abilityAccessCtrl, bundleManager, common, ConfigurationConstant, Permissions, Want } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { privacyManager } from '@kit.AppGalleryKit';
import { util } from '@kit.ArkTS';
import { ButtonModifier, LengthMetrics, SymbolGlyphModifier, display, window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import deviceInfo from '@ohos.deviceInfo';
import { fileIo, fileUri, picker } from '@kit.CoreFileKit';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { image } from '@kit.ImageKit';
import { i18n } from '@kit.LocalizationKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { motion } from '@kit.MultimodalAwarenessKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { vibrator } from '@kit.SensorServiceKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import { wearEngine } from '@kit.WearEngine';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { formInfo, formProvider } from '@kit.FormKit';
import { ImmersionButton, ImmersionSearch } from '@tangs/components';
import {
  BlurStrategy,
  HdsNavigation,
  HdsNavigationMenuContentOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsAttribute,
  IconStyleMode,
  ScrollEffectType,
  SystemMaterialParams,
  TitleBarStyleOptions,
  hdsEffect,
  hdsMaterial
} from '@kit.UIDesignKit';
import { CloudStageResult, CloudSyncState, TokenRepository } from '../data/TokenRepository';
import {
  LanWatchPairingInfo,
  LanWatchReceiver,
  LanWatchReceiverState,
  LanWatchSender,
  watchTransferRecords
} from '../data/LanWatchSyncService';
import {
  SteamGuardCloudRecord,
  SteamGuardCloudRepository
} from '../data/SteamGuardCloudRepository';
import { TokenRecord } from '../model/TokenRecord';
import { Totp } from '../utils/Totp';
import { Settings, SettingsRepository } from '../data/SettingsRepository';
import { FormManager } from '../form/FormManager';
import { GoogleAuthenticatorMigration, GoogleOtpParameter } from '../utils/GoogleAuthenticatorMigration';
import { LogoResolver, LogoResolveResult } from '../utils/LogoResolver';
import { SteamQrLoginInfo, SteamService } from '../data/SteamService';
import {
  SteamAuthenticatorDraft,
  SteamEnrollmentService,
  SteamLoginChallenge,
  SteamLoginSession
} from '../data/SteamEnrollmentService';
import {
  canUseSteamRemoteFeatures,
  createSdaMaFile,
  parseSdaMaFile,
  parseSteamGuardData,
  serializeSteamGuardData,
  SteamConfirmation,
  SteamGuardData
} from '../model/SteamGuardData';
import { SteamMaFile } from '../utils/SteamMaFile';
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

interface UpdateLogEntry {
  version: string;
  date: string;
  summary: string;
  items: string[];
}

const APPLOCK_DOMAIN = 0x0001;
const APPLOCK_TAG = 'AppLock';
const APP_COMMENT_TAG = 'AppComment';
const DATA_SYNC_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const DETECT_GESTURE_PERMISSION: Permissions = 'ohos.permission.DETECT_GESTURE';
const DLP_ANTI_PEEP_PERMISSION: Permissions = 'ohos.permission.DLP_GET_HIDE_STATUS';
const ERROR_RED: string = '#D93025';
const ERROR_RED_TINT: string = '#33D93025';
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
const MATERIAL_TYPE_OPTIONS: SelectOption[] = [
  { value: '自适应' },
  { value: '沉浸' },
  { value: '无材质' }
];
const MATERIAL_LEVEL_OPTIONS: SelectOption[] = [
  { value: '自适应' },
  { value: '精致' },
  { value: '柔和' },
  { value: '平滑' }
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
const CUSTOM_BACKGROUND_CACHE_PREFIX: string = 'custom_background_render_';
const CARD_PRESSED_SCALE: number = 0.97;
const CARD_PRESS_ANIMATION_DURATION: number = 160;
const DEFAULT_TOKEN_DIGITS: number = 6;
const DEFAULT_TOKEN_PERIOD: number = 30;
const USER_AGREEMENT_EMAIL: string = '1207523787@qq.com';
const CAMLINK_URL: string =
  'https://appgallery.huawei.com/link/invite-test-wap?taskId=6bf169d3025820402aaed7f6fb4bc841&invitationCode=9zfV0wKisw1';
const QQ_GROUP_NUMBER: string = '1061983927';
const APP_VERSION_FALLBACK: string = 'V1.4.3';
const APP_VERSION_CODE_FALLBACK: string = '1000043';
const UPDATE_NOTICE_VERSION: string = 'V1.4.3';
const UPDATE_LOGS: UpdateLogEntry[] = [
  {
    version: '1.4.3',
    date: '2026.07.30',
    summary: '完善账号、备份与发行方 Logo 体验',
    items: [
      '华为账号退出改为主题色光感按钮，并增加二次确认，避免误操作。',
      '修复二维码和 JSON 备份重新导入后令牌名称与发行方颠倒的问题。',
      'JSON 备份文件名统一为 OpenAuthenticator_backup_当前年月日。',
      '新增 GitCode 远程发行方 Logo 维护库，按“内置、GitCode、Simple Icons”的顺序匹配并支持离线缓存。',
      '新增 GitCode、Bitget、Bybit、Kimi 品牌资源，统一 Microsoft 与 GitCode 图标视觉尺寸。',
      '“关于”页面的应用版本改为自动读取当前安装包版本。'
    ]
  },
  {
    version: '1.4.1',
    date: '2026.07.27',
    summary: '优化界面适配、背景体验与交互细节',
    items: [
      '优化“我的”、设置、第三方库等页面在手机、平板及宽屏设备上的响应式布局。',
      '新增背景图明亮程度调节，并修复从图库选择背景后未立即刷新的问题。',
      '复用预解码背景并缓存静态渲染结果，提升启用背景图后的页面转场流畅度。',
      '修复顶部导航栏开始滚动时模糊效果短暂缺失的问题。',
      '完善 QQ 群号复制与二维码保存、多语言文案、应用图标及 Microsoft 品牌资源。'
    ]
  },
  {
    version: '1.4.0',
    date: '2026.07.23',
    summary: 'Steam Guard、云同步与应用体验全面升级',
    items: [
      '完整支持 Steam maFile 导入、扫码登录、交易确认及 maFile 备份导出。',
      '支持登录尚未启用移动验证器的 Steam 账号，自动生成 maFile 并保存恢复码。',
      'Steam 完整登录凭证与交易信息通过独立加密云表同步，通用令牌同步逻辑保持不变。',
      '通用令牌与 Steam 完整数据分别显示上传、下载数量及同步状态。',
      '新增全局背景显示、背景模糊调节和主题图片，二级页面可统一显示所选背景。',
      '新增历史更新日志、AppGallery 评价入口及 SDA 开源项目说明。'
    ]
  },
  {
    version: '1.3.4',
    date: '2026.07.22',
    summary: '完善 Steam 验证器工作流与主题体验',
    items: [
      '补齐 Steam 登录验证、验证器激活、恢复码保存和本地 maFile 生成流程。',
      '支持 Steam 二维码登录和交易确认，并优化风险告知与异常提示。',
      '新增自定义背景、预设主题图及全局沉浸光感设置。'
    ]
  },
  {
    version: '1.3.3',
    date: '2026.07.19',
    summary: '重构云同步并增强数据安全',
    items: [
      '本机完整令牌与通用令牌云同步镜像分离。',
      '优化手动推送、手动获取和自动同步，增加超时、状态反馈与失败恢复。',
      '删除令牌时支持“删除本地及云端”或“仅从本设备删除”。',
      '升级用户存在本地令牌时自动跳过首次引导。'
    ]
  },
  {
    version: '1.3.2',
    date: '2026.07.18',
    summary: '新增 Steam Guard 并扩展验证器体验',
    items: [
      '新增 Steam Guard 数据模型、令牌展示及基础远程操作能力。',
      '加入多套背景图片、更多作品、赞助、手表同步等功能入口。',
      '优化服务卡片、深浅色主题和多语言界面。'
    ]
  },
  {
    version: '1.1.0',
    date: '2026.07.08',
    summary: '优化令牌导入与服务卡片',
    items: [
      '增强令牌文件导入兼容性与异常提示。',
      '重构多尺寸服务卡片布局、刷新状态和深浅色视觉。',
      '完善服务卡片配置与系统能力声明。'
    ]
  },
  {
    version: '1.0.3',
    date: '2026.06.28',
    summary: '完善界面、图标与导入流程',
    items: [
      '新增发行方 Logo 自动匹配及浅色、深色资源。',
      '优化首页搜索、单双列布局、编辑参数和导入交互。',
      '补充应用商店展示素材与多语言资源。'
    ]
  },
  {
    version: '1.0.0',
    date: '2026.06.20',
    summary: '首个完整可用版本',
    items: [
      '支持 TOTP、HOTP、Steam 动态令牌及多种 HMAC 算法。',
      '支持手动录入、扫码、文件导入和 Google Authenticator 批量迁移。',
      '提供本地存储、备份导出、华为云空间同步、应用锁与服务卡片。',
      '适配手机、平板、折叠屏与 2in1 设备。'
    ]
  }
];
const STEAM_ENROLLMENT_RISK: string = 'risk';
const STEAM_ENROLLMENT_CREDENTIALS: string = 'credentials';
const STEAM_ENROLLMENT_GUARD: string = 'guard';
const STEAM_ENROLLMENT_ACTIVATION: string = 'activation';
const STEAM_ENROLLMENT_RECOVERY: string = 'recovery';
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
const TOKEN_CARD_PADDING: number = 12;
const TOKEN_LAYOUT_TRANSITION_DURATION: number = 420;
const TOKEN_NAME_TEXT_SIZE: number = 14;
const TOKEN_CODE_TEXT_SIZE: number = 24;
const TOKEN_TIME_TEXT_SIZE: number = 14;
const TOKEN_NEXT_CODE_TEXT_SIZE: number = 24;
const TOKEN_DIGIT_HEIGHT_FACTOR: number = 1.35;
const TOKEN_DIGIT_WIDTH_FACTOR: number = 0.62;
const TOKEN_STEAM_CHARACTER_WIDTH_FACTOR: number = 0.72;
const TOKEN_DIGIT_SPACE_FACTOR: number = 0.34;
const TOKEN_DIGIT_SCROLL_DURATION: number = 400;
const TOKEN_COUNTDOWN_SIZE: number = 40;
const TOKEN_COUNTDOWN_STROKE: number = 4;
const TOKEN_LOGO_SIZE: number = 40;
const ACCENT_TINT_ALPHA: number = 51;
const PRIMARY_ACTION_FILL_ALPHA: number = 26;
const ACCENT_GLOW_ALPHA: number = 92;
const ACCENT_GLOW_RADIUS: number = 5;
const ME_CARD_RADIUS: number = 15;
const ME_LOGIN_CARD_HEIGHT: number = 75;
const ME_ROW_HEIGHT: number = 60;
const STEAM_ACCESS_HINT_HEIGHT: number = 58;
const DONATION_QR_IMAGE_MAX_WIDTH: number = 420;
const DONATION_QR_IMAGE_RATIO: number = 1653 / 1397;
const DONATION_QR_CARD_FIXED_HEIGHT: number = 164;
const DONATION_SUPPORTER_AVATAR_SIZE: number = 72;
const CLOUD_STATUS_ROW_HEIGHT: number = 76;
const ME_AVATAR_SIZE: number = 48;
const ME_TEXT_SIZE: number = 18;
const ME_ACTION_TEXT_SIZE: number = 15;
const ME_ACTION_ICON_SIZE: number = 20;
const ME_ACTION_CONTENT_GAP: number = 16;
const ME_LOGOUT_BUTTON_WIDTH: number = 88;
const ME_LOGOUT_BUTTON_HEIGHT: number = 34;
const ME_ARROW_WIDTH: number = 8;
const ME_ARROW_HEIGHT: number = 15;
const BACKGROUND_THUMBNAIL_WIDTH: number = 38;
const BACKGROUND_THUMBNAIL_HEIGHT: number = 56;
const BACKGROUND_PICKER_ROW_HEIGHT: number = 146;
const BACKGROUND_BLUR_ROW_HEIGHT: number = 82;
const BACKGROUND_BRIGHTNESS_ROW_HEIGHT: number = 82;
const BACKGROUND_BLUR_MAX_RADIUS: number = 50;
const ADD_BUTTON_SIZE: number = 50;
const ADD_BUTTON_RIGHT: number = 36;
const ADD_BUTTON_BOTTOM: number = 142;
const ADD_BUTTON_ICON_SIZE: number = 24;
const LOGO_SAVE_LOOKUP_TIMEOUT_MS: number = 1500;
const SWIPE_ACTION_SIZE: number = 40;
const SWIPE_ACTION_ICON_SIZE: number = 20;
const SWIPE_ACTION_GAP: number = 10;
const SWIPE_ACTION_AREA_WIDTH: number = SWIPE_ACTION_SIZE * 2 + SWIPE_ACTION_GAP * 3;
const WATCH_LAYOUT_MAX_WIDTH: number = 320;
const WATCH_LAYOUT_MAX_HEIGHT: number = 360;
const WATCH_HORIZONTAL_PADDING: number = 18;
const WATCH_TOKEN_CARD_HEIGHT: number = 108;
const WATCH_TOKEN_CODE_SIZE: number = 28;
const WATCH_EMPTY_CARD_HEIGHT: number = 92;
const WATCH_EMPTY_TITLE_SIZE: number = 14;
const WATCH_EMPTY_BODY_SIZE: number = 11;
const WATCH_PAGE_SWIPE_DISTANCE: number = 64;
const WATCH_FEATURE_TOP_PADDING: number = 12;
const WATCH_FEATURE_CARD_HEIGHT: number = 152;
const WATCH_FEATURE_ICON_SIZE: number = 36;
const WATCH_FEATURE_BODY_MAX_LINES: number = 5;
const WATCH_SYNC_TITLE_SIZE: number = 18;
const WATCH_SYNC_PATH_SIZE: number = 11;
const WATCH_SYNC_PATH_MAX_LINES: number = 2;
const WATCH_LAN_QR_FRAME_SIZE: number = 120;
const WATCH_LAN_QR_SIZE: number = 112;
const WATCH_TOKEN_FOCUS_KEY: string = 'watch-token-scroll';
const WATCH_FEATURE_FOCUS_KEY: string = 'watch-feature-scroll';
const WATCH_LAN_SYNC_FOCUS_KEY: string = 'watch-lan-sync-page';
const WATCH_SYNC_ACTION: string = 'tool2fa.watch.tokens.replace';
const SHEET_HORIZONTAL_PADDING: number = 20;
const SHEET_CONTENT_TOP_PADDING: number = 10;
const SHEET_ROW_HEIGHT: number = 58;
const SHEET_PRIMARY_TEXT_SIZE: number = 15;
const SHEET_SECONDARY_TEXT_SIZE: number = 12;
const SHEET_ACTION_BUTTON_HEIGHT: number = 44;
const SHEET_ACTION_GAP: number = 12;
const SHEET_ACTION_BAR_RADIUS: number = 28;
const SHEET_ACTION_BOTTOM_GAP: number = 12;
const SHEET_ACTION_SAFE_SPACE: number = 88;
const SHEET_EMPTY_STATE_HEIGHT: number = 120;
const SHEET_OPTION_CARD_RADIUS: number = 18;
const UPDATE_NOTICE_SHEET_HEIGHT: number = 560;
const SHEET_ADD_METHOD_HEIGHT: number = 228;
const SHEET_EXPORT_FORMAT_HEIGHT: number = 344;
const SHEET_QR_BASE_HEIGHT: number = 252;
const STEAM_CONFIRMATION_POLL_INTERVAL_MS: number = 30000;
const ONBOARDING_PAGE_COUNT: number = 4;
const ONBOARDING_CONTENT_MAX_WIDTH: number = 560;
const ONBOARDING_CARD_MAX_WIDTH: number = 420;
const ONBOARDING_PAGE_SIDE: number = 24;
const ONBOARDING_PAGE_SIDE_WIDE: number = 32;
const ONBOARDING_CARD_RADIUS: number = 24;
const ONBOARDING_ICON_CONTAINER_SIZE: number = 40;
const ONBOARDING_ICON_SIZE: number = 20;
const ONBOARDING_ACTION_HEIGHT: number = 48;
const ONBOARDING_ACTION_MAX_WIDTH: number = 240;
const ONBOARDING_TOP_BAR_HEIGHT: number = 40;
const ONBOARDING_TOP_OVERLAY_VERTICAL_SPACE: number = 24;
const ONBOARDING_BOTTOM_SAFE_GAP: number = 16;
const ONBOARDING_BOTTOM_CONTROL_GAP: number = 16;
const ONBOARDING_INDICATOR_HEIGHT: number = 6;
const ONBOARDING_CONTENT_CHROME_GAP: number = 24;
const ONBOARDING_HERO_SIZE: number = 68;
const ONBOARDING_FEATURE_ROW_HEIGHT: number = 64;
const ONBOARDING_FEATURE_CARD_HEIGHT: number = ONBOARDING_FEATURE_ROW_HEIGHT * 3 + 2;
const ONBOARDING_TOKEN_PREVIEW_HEIGHT: number = 116;
const ONBOARDING_TITLE_SIZE: number = 30;
const ONBOARDING_BODY_SIZE: number = 14;
const ONBOARDING_ROW_TITLE_SIZE: number = 15;
const ONBOARDING_ROW_BODY_SIZE: number = 12;
const ONBOARDING_ACCENT_COLOR: string = '#F2CF3A';
const ONBOARDING_PRIMARY_TEXT_COLOR: string = '#FFFFFFFF';
const ONBOARDING_SECONDARY_TEXT_COLOR: string = '#BFFFFFFF';
const ONBOARDING_DIVIDER_COLOR: string = '#33FFFFFF';
const ONBOARDING_BORDER_COLOR: string = '#66FFFFFF';
const ONBOARDING_ICON_TINT_COLOR: string = '#22F2CF3A';
const ONBOARDING_GLOW_COLOR: string = '#5CF2CF3A';
const ONBOARDING_MATERIAL_TINT_COLOR: string = '#30000000';
const ONBOARDING_BUTTON_TINT_COLOR: string = '#4D000000';
const FORCE_DARK_SYSTEM_BARS_KEY: string = 'tool2fa_forceDarkSystemBars';
const STEAM_BEIAN_URL: string = 'https://beian.miit.gov.cn/';
const STEAM_REFERENCE_URL: string = 'https://github.com/kdada/Authenticator';
const SDA_REFERENCE_URL: string = 'https://github.com/Jessecar96/SteamDesktopAuthenticator';
const TANGS_COMPONENTS_URL: string = 'https://ohpm.openharmony.cn/#/cn/detail/@tangs%2Fcomponents';
const APP_BUNDLE_NAME: string = 'com.example.tool_2fa';

class HomeSearchModifier implements AttributeModifier<SearchAttribute> {
  private textColor: ResourceColor;
  private hintColor: ResourceColor;
  private change: (value: string) => void;

  constructor(textColor: ResourceColor, hintColor: ResourceColor, change: (value: string) => void) {
    this.textColor = textColor;
    this.hintColor = hintColor;
    this.change = change;
  }

  applyNormalAttribute(instance: SearchAttribute): void {
    instance.fontColor(this.textColor)
      .placeholderColor(this.hintColor)
      .onWillChange((value: EditableTextChangeValue): boolean => {
        this.change(value.content);
        return true;
      });
  }
}

class ActionButtonModifier implements AttributeModifier<ButtonModifier> {
  private buttonWidth: Length;
  private buttonHeight: number;
  private fillColor: ResourceColor;
  private strokeColor: ResourceColor;

  constructor(buttonWidth: Length, buttonHeight: number, fillColor: ResourceColor, strokeColor: ResourceColor) {
    this.buttonWidth = buttonWidth;
    this.buttonHeight = buttonHeight;
    this.fillColor = fillColor;
    this.strokeColor = strokeColor;
  }

  applyNormalAttribute(instance: ButtonModifier): void {
    instance.width(this.buttonWidth)
      .height(this.buttonHeight)
      .backgroundColor(this.fillColor)
      .border({ width: 0.5, color: this.strokeColor });
  }
}

enum PageMode {
  Home,
  AddToken
}

enum HomeTab {
  Token,
  Me
}

enum WatchHomePage {
  Tokens = 0,
  Features = 1
}

enum HoldingHandStatus {
  NOT_HELD = 0,
  LEFT_HAND_HELD = 1
}

enum SettingsSwitchKey {
  SteamEnhancedAccess,
  CloudBackup,
  SmartGrip,
  AntiPeep,
  AppLock,
  ShowNextToken,
  GlobalImmersion,
  GlobalBackground
}

enum SettingsSelectKey {
  Language,
  IssuerLogoColor,
  MaterialType,
  MaterialLevel,
  ThemeMode,
  ThemeColor
}

interface WearMessageReceiver {
  deviceId: string;
  appParam: wearEngine.P2pAppParam;
  callback: (message: wearEngine.P2pMessage) => void;
}

interface WatchSyncPayload {
  action: string;
  version: number;
  tokens: TokenRecord[];
  pushedAt: number;
}

interface SheetActionButtonParam {
  label: string;
  isPrimary: boolean;
  isEnabled: boolean;
  isLoading: boolean;
  action: () => void;
}

interface SheetFloatingActionsParam {
  secondaryLabel: string;
  secondaryAction: () => void;
  secondaryIsPrimary?: boolean;
  primaryLabel: string;
  primaryEnabled: boolean;
  primaryLoading: boolean;
  primaryAction: () => void;
}

interface SheetSingleFloatingActionParam {
  label: string;
  action: () => void;
}

interface SteamPendingConfirmation {
  tokenId: string;
  tokenName: string;
  confirmation: SteamConfirmation;
}

interface ImportFileContent {
  uri: string;
  fileName: string;
  content: string;
}

@Entry
@Component
struct Index {
  @State private pageMode: PageMode = PageMode.Home;
  @State private tokens: TokenRecord[] = [];
  @State private tokenDataLoaded: boolean = false;
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
  private homeScrollY: number = 0;
  @State private isHomeSearchCollapsed: boolean = false;
  @State private isHuaweiLoggedIn: boolean = false;
  @State private huaweiNickname: string = '';
  @State private huaweiAvatarUri: string = '';
  @State private huaweiUserId: string = '';
  @State private huaweiLoginInProgress: boolean = false;
  @State private huaweiLogoutInProgress: boolean = false;
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
  @State private materialTypeInput: string = '自适应';
  @State private materialLevelInput: string = '自适应';
  @State private globalImmersionEnabled: boolean = false;
  @State private backgroundSelection: string = 'none';
  @State private customBackgroundUri: string = '';
  @State private customBackgroundRenderVersion: number = 0;
  private customBackgroundPixelMap: image.PixelMap | undefined = undefined;
  private customBackgroundPixelMapUri: string = '';
  private customBackgroundLoadSerial: number = 0;
  @State private backgroundBlurPercent: number = 0;
  @State private backgroundBrightnessPercent: number = 50;
  @State private globalBackgroundEnabled: boolean = true;
  @State private appVersion: string = APP_VERSION_FALLBACK;
  @State private appVersionCode: string = APP_VERSION_CODE_FALLBACK;
  @State private updateNoticeVersion: string = '';
  @State private showUpdateNotice: boolean = false;
  @State private showUpdateLogSheet: boolean = false;
  @State private expandedUpdateLogVersion: string = '1.4.3';
  @State private languageInput: string = LANGUAGE_SYSTEM;
  @State private systemLanguage: string = 'zh-Hans';
  @State private cloudSyncStatus: string = '尚未同步';
  @State private steamCloudSyncStatus: string = '尚未同步';
  @State private cloudLastSyncTime: number = 0;
  @State private cloudSyncing: boolean = false;
  @State private tokenCloudSyncing: boolean = false;
  @State private steamCloudSyncing: boolean = false;
  @State private cloudSyncRefreshKey: number = 0;
  private cloudMirrorMerging: boolean = false;
  private steamCloudMirrorMerging: boolean = false;
  @State private onboardingCompleted: boolean = false;
  @State private showOnboarding: boolean = false;
  @State private onboardingPage: number = 0;
  @StorageLink('tool2fa_systemDark') @Watch('onSystemDarkChanged') private systemDark: boolean = false;
  @StorageLink('tool2fa_requireAuth') private requireAuth: boolean = false;
  @StorageLink('tool2fa_isLocked') @Watch('onLockStateChanged') private isLocked: boolean = false;

  aboutToAppear(): void {
    this.refreshSystemLanguage();
    this.refreshResponsiveWaterFlowSections();
    this.initializeAppData();
    this.timerId = setInterval(() => {
      if (!this.isHomeListScrolling &&
        (this.selectedHomeTab === HomeTab.Token || this.isWatchLayout())) {
        this.currentTimeMs = Date.now();
      }
      this.checkSteamConfirmationsIfNeeded();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.updateNoticePresentationTimer >= 0) {
      clearTimeout(this.updateNoticePresentationTimer);
      this.updateNoticePresentationTimer = -1;
    }
    this.stopSmartGrip();
    this.stopAntiPeep();
    this.clearLogoLookupTimer();
    this.unregisterWearSyncReceivers();
    this.stopLanWatchReceiver();
  }

  onPageShow(): void {
    this.phoneRootReady = true;
    this.scheduleUpdateNoticePresentation();
  }
  @StorageProp('tool2fa_statusBarHeight') private statusBarHeight: number = 0;
  @StorageProp('tool2fa_naviIndicatorHeight') private naviIndicatorHeight: number = 0;
  private homeScroller: Scroller = new Scroller();
  private meScroller: Scroller = new Scroller();
  private meWaterFlowSections: WaterFlowSections = new WaterFlowSections();
  private settingsScroller: Scroller = new Scroller();
  private appearanceSettingsScroller: Scroller = new Scroller();
  private featureSecurityScroller: Scroller = new Scroller();
  private cloudSpaceScroller: Scroller = new Scroller();
  private watchScroller: Scroller = new Scroller();
  private watchFeatureScroller: Scroller = new Scroller();
  private watchSyncScroller: Scroller = new Scroller();
  private moreAppsScroller: Scroller = new Scroller();
  private donationScroller: Scroller = new Scroller();
  private aboutScroller: Scroller = new Scroller();
  private watchTokenPickerSheetScroller: Scroller = new Scroller();
  private exportTokenPickerSheetScroller: Scroller = new Scroller();
  private exportFormatSheetScroller: Scroller = new Scroller();
  private exportQRCodeSheetScroller: Scroller = new Scroller();
  private cardTokenPickerSheetScroller: Scroller = new Scroller();
  private addMethodSheetScroller: Scroller = new Scroller();
  private userAgreementSheetScroller: Scroller = new Scroller();
  private updateNoticeSheetScroller: Scroller = new Scroller();
  private updateLogSheetScroller: Scroller = new Scroller();
  private steamLoginSheetScroller: Scroller = new Scroller();
  private steamDecryptSheetScroller: Scroller = new Scroller();
  private steamEnrollmentSheetScroller: Scroller = new Scroller();
  private homePathStack: NavPathStack = new NavPathStack();
  private addPageScroller: Scroller = new Scroller();
  private onboardingSwiperController: SwiperController = new SwiperController();
  private timerId: number = -1;
  private watchCrownLastHapticAt: number = 0;
  private updateNoticePresentationTimer: number = -1;
  private settingsLoaded: boolean = false;
  private settingsLoadPromise: Promise<void> | undefined = undefined;
  private phoneRootReady: boolean = false;
  private isHomeListScrolling: boolean = false;
  private tokenCodeCache: Map<string, string> = new Map<string, string>();
  private tokenCodeCacheVersion: number = -1;
  private authInstance: userAuth.UserAuthInstance | null = null;
  private holdingHandCallback: ((status: motion.HoldingHandStatus) => void) | null = null;
  private antiPeepCallback: ((status: dlpAntiPeep.DlpAntiPeepStatus) => void) | null = null;
  private importRejectedCount: number = 0;
  private logoLookupTimer: number = 0;
  private logoLookupSerial: number = 0;
  private deviceType: string = deviceInfo.deviceType;
  private addButtonDragStartX: number = 0;
  private addButtonDragStartY: number = 0;
  private webSheetController: webview.WebviewController = new webview.WebviewController();
  @State private cardSelectedTokenIds: string[] = [];
  @State private pendingCardTokenIds: string[] = [];
  @State private showCardTokenPicker: boolean = false;
  @State private showExportPicker: boolean = false;
  @State private exportSelectedIds: string[] = [];
  @State private sheetSelectionRevision: number = 0;
  @State private openSwipeTokenId: string = '';
  @State private activeSwipeTokenId: string = '';
  @State private activeSwipeOffset: number = 0;
  @State private draggingTokenId: string = '';
  @State private pressedTokenId: string = '';
  @State private pressedCardId: string = '';
  @State private measuredCardHeights: Map<string, number> = new Map<string, number>();
  @State private showExportFormat: boolean = false;
  @State private showExportQR: boolean = false;
  @State private exportQRIndex: number = 0;
  @State private isSavingQRCode: boolean = false;
  @State private showUserAgreementSheet: boolean = false;
  @State private showWebSheet: boolean = false;
  @State private showQQGroupSheet: boolean = false;
  @State private isSavingQQGroupQRCode: boolean = false;
  @State private webSheetTitle: string = '';
  @State private webSheetUrl: string = 'about:blank';
  @State private importProgressVisible: boolean = false;
  @State private importProgressTotal: number = 0;
  @State private importProgressProcessed: number = 0;
  @State private importProgressSuccess: number = 0;
  @State private importProgressFailed: number = 0;
  @State private importProgressMessage: string = '';
  @State private watchSelectedTokenIds: string[] = [];
  @State private pendingWatchTokenIds: string[] = [];
  @State private showWatchTokenPicker: boolean = false;
  @State private watchPushStatus: string = '尚未同步';
  @State private watchLastPushTime: number = 0;
  @State private watchPushing: boolean = false;
  @State private watchReceiverStatus: string = '';
  @State private watchLanQrText: string = '';
  @State private watchLanStatus: string = '';
  @State private watchLanReceiving: boolean = false;
  @State private watchLanExpiresAt: number = 0;
  @State private watchHomePageIndex: WatchHomePage = WatchHomePage.Tokens;
  @State private watchLanSyncPageVisible: boolean = false;
  @State private steamEnhancedAccess: boolean = false;
  @State private steamGatewayUrl: string = '';
  @State private steamGatewayToken: string = '';
  @State private showSteamLoginPicker: boolean = false;
  @State private pendingSteamLoginTokenId: string = '';
  @State private steamLoading: boolean = false;
  @State private showSteamEnrollmentSheet: boolean = false;
  @State private steamEnrollmentStage: string = STEAM_ENROLLMENT_RISK;
  @State private steamRiskAccepted: boolean = false;
  @State private steamEnrollmentAccount: string = '';
  @State private steamEnrollmentPassword: string = '';
  @State private steamEnrollmentCode: string = '';
  @State private steamEnrollmentGuardType: number = 0;
  @State private steamEnrollmentGuardMessage: string = '';
  @State private steamEnrollmentGuardSubmitted: boolean = false;
  @State private steamEnrollmentLoading: boolean = false;
  @State private steamEnrollmentError: string = '';
  @State private steamRecoveryCode: string = '';
  @State private steamRecoverySaved: boolean = false;
  @State private steamEnrollmentTokenId: string = '';
  @State private showSteamDecryptSheet: boolean = false;
  @State private steamDecryptPassword: string = '';
  @State private steamDecrypting: boolean = false;
  private pendingSteamEncryptedContent: string = '';
  private pendingSteamManifestContent: string = '';
  private pendingSteamFileName: string = '';
  private steamEnrollmentChallenge: SteamLoginChallenge | null = null;
  private steamEnrollmentSession: SteamLoginSession | null = null;
  private steamAuthenticatorDraft: SteamAuthenticatorDraft | null = null;
  private importUpdatedCount: number = 0;
  private steamConfirmationChecking: boolean = false;
  private steamConfirmationDialogVisible: boolean = false;
  private lastSteamConfirmationCheckMs: number = 0;
  private pendingSteamConfirmations: SteamPendingConfirmation[] = [];
  private tokenDragReordered: boolean = false;
  private wearMessageReceivers: WearMessageReceiver[] = [];
  private lanWatchReceiver: LanWatchReceiver | undefined = undefined;
  private thirdPartyScroller: Scroller = new Scroller();
  private thirdPartyWaterFlowSections: WaterFlowSections = new WaterFlowSections();

  private async initializeAppData(): Promise<void> {
    try {
      await this.loadTokens();
      await this.loadSettings();
      await this.loadCardTokenIds();
      await this.loadAppVersion();
    } catch (error) {
      console.error(`Failed to initialize startup data: ${JSON.stringify(error)}`);
    }
  }

  private async loadAppVersion(): Promise<void> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      const versionName = bundleInfo.versionName.trim();
      if (versionName.length > 0) {
        const normalizedVersion = versionName.charAt(0).toLowerCase() === 'v' ?
          versionName.substring(1) : versionName;
        this.appVersion = `V${normalizedVersion}`;
      }
      this.appVersionCode = bundleInfo.versionCode.toString();
    } catch (error) {
      console.error(`Failed to load app version: ${JSON.stringify(error)}`);
    }
  }

  private async loadSettings(): Promise<void> {
    if (this.settingsLoaded) {
      return;
    }
    if (this.settingsLoadPromise === undefined) {
      this.settingsLoadPromise = this.performLoadSettings();
    }
    const activeLoadPromise: Promise<void> = this.settingsLoadPromise;
    await activeLoadPromise;
    if (this.settingsLoadPromise === activeLoadPromise) {
      this.settingsLoadPromise = undefined;
    }
  }

  private async performLoadSettings(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.settingsLoaded = true;
      return;
    }
    const settings = await SettingsRepository.load(context);
    this.cloudBackupEnabled = settings.cloudBackup;
    this.smartGripEnabled = settings.smartGrip;
    this.antiPeepEnabled = settings.antiPeep;
    this.appLockEnabled = settings.appLock;
    this.showNextToken = settings.showNextToken;
    const logoColorModeChanged = this.issuerLogoColorMode !== settings.issuerLogoColorMode;
    this.issuerLogoColorMode = settings.issuerLogoColorMode;
    if (logoColorModeChanged && this.tokens.length > 0) {
      this.refreshTokenLogoDisplay();
    }
    this.tokenLayoutMode = settings.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? TOKEN_LAYOUT_DOUBLE : TOKEN_LAYOUT_SINGLE;
    this.isHuaweiLoggedIn = settings.huaweiLoggedIn;
    this.huaweiNickname = settings.huaweiNickname;
    this.huaweiAvatarUri = settings.huaweiAvatarUri;
    this.huaweiUserId = settings.huaweiUserId;
    this.themeModeInput = settings.themeMode;
    this.themeColorInput = settings.themeColor;
    this.materialTypeInput = settings.materialType;
    this.materialLevelInput = settings.materialLevel;
    this.globalImmersionEnabled = settings.globalImmersionEnabled;
    let loadedBackgroundUri: string = settings.customBackgroundUri;
    let loadedBackgroundSelection: string = settings.backgroundSelection;
    let backgroundCacheMigrated = false;
    if (settings.backgroundSelection === 'custom' && loadedBackgroundUri.length === 0) {
      loadedBackgroundSelection = 'none';
    }
    if (settings.backgroundSelection === 'custom' && loadedBackgroundUri.length > 0) {
      const backgroundPrepared = await this.prepareCustomBackground(loadedBackgroundUri);
      if (!backgroundPrepared) {
        loadedBackgroundSelection = 'none';
      } else if (!this.isOptimizedCustomBackgroundUri(loadedBackgroundUri)) {
        const optimizedUri = await this.persistPreparedCustomBackground(context);
        if (optimizedUri.length > 0) {
          loadedBackgroundUri = optimizedUri;
          this.customBackgroundPixelMapUri = optimizedUri;
          backgroundCacheMigrated = true;
        }
      }
    }
    this.customBackgroundUri = loadedBackgroundUri;
    this.backgroundSelection = loadedBackgroundSelection;
    this.backgroundBlurPercent = this.clamp(settings.backgroundBlurPercent, 0, 100);
    this.backgroundBrightnessPercent = this.clamp(settings.backgroundBrightnessPercent, 0, 100);
    this.globalBackgroundEnabled = settings.globalBackgroundEnabled;
    this.updateNoticeVersion = settings.updateNoticeVersion;
    this.languageInput = normalizeSelectedLanguage(settings.language);
    this.refreshSystemLanguage();
    this.cloudSyncStatus = settings.cloudSyncStatus;
    this.steamCloudSyncStatus = settings.steamCloudSyncStatus;
    if (this.steamCloudSyncStatus === '尚未同步' && this.cloudSyncStatus.indexOf('Steam') >= 0) {
      this.steamCloudSyncStatus = this.cloudSyncStatus;
      this.cloudSyncStatus = '尚未同步';
    }
    this.cloudLastSyncTime = settings.cloudLastSyncTime;
    this.watchSelectedTokenIds = settings.watchSelectedTokenIds;
    this.watchPushStatus = settings.watchPushStatus;
    this.watchLastPushTime = settings.watchLastPushTime;
    this.steamEnhancedAccess = settings.steamEnhancedAccess;
    this.steamGatewayUrl = settings.steamGatewayUrl;
    this.steamGatewayToken = settings.steamGatewayToken;
    const migratedExistingUser = !settings.onboardingCompleted && this.tokens.length > 0;
    this.onboardingCompleted = settings.onboardingCompleted || migratedExistingUser;
    this.showOnboarding = !this.onboardingCompleted;
    if (this.showOnboarding) {
      this.showUpdateNotice = false;
    }
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
    if (this.isWatchLayout()) {
      this.registerWearSyncReceivers();
    }
    this.settingsLoaded = true;
    if (migratedExistingUser || backgroundCacheMigrated) {
      await this.saveSettings();
      if (migratedExistingUser) {
        console.info('Skipped onboarding for upgraded user with existing local tokens');
      }
    }
    this.scheduleUpdateNoticePresentation();
    hilog.info(APPLOCK_DOMAIN, APPLOCK_TAG, 'loadSettings: appLock=%{public}d, isLocked=%{public}d, huaweiLoggedIn=%{public}d', this.appLockEnabled ? 1 : 0, this.isLocked ? 1 : 0, this.isHuaweiLoggedIn ? 1 : 0);
  }

  private async saveSettings(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    const snapshot: Settings = {
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
      materialType: this.materialTypeInput,
      materialLevel: this.materialLevelInput,
      globalImmersionEnabled: this.globalImmersionEnabled,
      backgroundSelection: this.backgroundSelection,
      customBackgroundUri: this.customBackgroundUri,
      backgroundBlurPercent: this.backgroundBlurPercent,
      backgroundBrightnessPercent: this.backgroundBrightnessPercent,
      globalBackgroundEnabled: this.globalBackgroundEnabled,
      updateNoticeVersion: this.updateNoticeVersion,
      language: normalizeSelectedLanguage(this.languageInput),
      cloudSyncStatus: this.cloudSyncStatus,
      steamCloudSyncStatus: this.steamCloudSyncStatus,
      cloudLastSyncTime: this.cloudLastSyncTime,
      watchSelectedTokenIds: this.watchSelectedTokenIds,
      watchPushStatus: this.watchPushStatus,
      watchLastPushTime: this.watchLastPushTime,
      onboardingCompleted: this.onboardingCompleted,
      steamEnhancedAccess: this.steamEnhancedAccess,
      steamGatewayUrl: this.steamGatewayUrl,
      steamGatewayToken: this.steamGatewayToken
    };
    await SettingsRepository.save(context, snapshot);
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
          ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
            text: this.t('验证身份'),
            buttonModify: {
              applyNormalAttribute(instance: ButtonModifier): void {
                instance.width(160).height(44)
              }
            },
            click: (): void => {
              this.startAppLockAuth();
            }
          })
            .margin({ top: 24 })
            .width(160)
            .height(44)
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
            enableScrollEffect: false,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          blurStrategy: BlurStrategy.ADAPTIVE,
          originalStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
          systemMaterialEffect: {
            materialType: this.configuredMaterialType(),
            materialLevel: this.configuredMaterialLevel()
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

      this.SteamLoginSheetAnchor()
      this.SteamDecryptSheetAnchor()
      this.SteamEnrollmentSheetAnchor()
      this.QQGroupSheetAnchor()
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
        this.refreshResponsiveWaterFlowSections();
      }
      if (nextHeight > 0 && Math.abs(nextHeight - this.pageHeight) > 0.5) {
        this.pageHeight = nextHeight;
      }
    })
    .onAppear(() => {
      this.phoneRootReady = true;
      this.scheduleUpdateNoticePresentation();
    })
    .bindSheet($$this.showUpdateNotice, this.UpdateNoticeSheet(), {
      height: this.sheetShortHeight(UPDATE_NOTICE_SHEET_HEIGHT),
      dragBar: true,
      showClose: false,
      maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
      backgroundColor: this.sheetSurfaceBackgroundColor(),
      blurStyle: this.sheetSurfaceBlurStyle(),
      radius: LengthMetrics.vp(28)
    })
  }

  @Builder
  private WatchAppRoot() {
    Stack() {
      this.PageBackground()
      if (this.watchLanSyncPageVisible) {
        this.WatchLanSyncPageContent()
      } else {
        this.WatchHomePageContent()
      }
      if (this.importProgressVisible) {
        this.ImportProgressOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => {
      this.handleWatchCrown(event);
    })
    .backgroundColor(this.pageBackgroundColor())
    .onAppear(() => {
      this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 80);
    })
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
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.backgroundSelection !== 'none') {
        this.SelectedBackgroundImage('100%', 0)
      }
    }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(this.pageBackgroundColor())
      .clip(true)
      .renderGroup(this.backgroundSelection !== 'none')
      .brightness(this.backgroundImageBrightness())
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private SelectedBackgroundImage(height: Length, radius: number) {
    if (this.backgroundSelection === 'custom' && this.customBackgroundUri.length > 0) {
      ForEach([this.customBackgroundRenderVersion], (version: number) => {
        this.CustomBackgroundImageLayer(this.customBackgroundUri, height, radius)
      }, (version: number) => version.toString())
    } else if (this.backgroundSelection === 'preset_2') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_2'), height, radius)
    } else if (this.backgroundSelection === 'preset_3') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_3'), height, radius)
    } else if (this.backgroundSelection === 'preset_4') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_4'), height, radius)
    } else if (this.backgroundSelection === 'preset_5') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_5'), height, radius)
    } else if (this.backgroundSelection === 'preset_6') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_6'), height, radius)
    } else if (this.backgroundSelection === 'preset_7') {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_7'), height, radius)
    } else {
      this.PresetBackgroundImageLayer($r('app.media.background_preset_1'), height, radius)
    }
  }

  @Builder
  private PresetBackgroundImageLayer(source: Resource, height: Length, radius: number) {
    Image(source)
      .width('100%')
      .height(height)
      .syncLoad(true)
      .objectFit(ImageFit.Cover)
      .borderRadius(radius)
      .blur(this.backgroundBlurRadius())
      .scale({ x: this.backgroundImageScale(), y: this.backgroundImageScale() })
      .zIndex(0)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private CustomBackgroundImageLayer(source: string, height: Length, radius: number) {
    Image(this.customBackgroundImageSource(source))
      .width('100%')
      .height(height)
      .syncLoad(true)
      .objectFit(ImageFit.Cover)
      .borderRadius(radius)
      .blur(this.backgroundBlurRadius())
      .scale({ x: this.backgroundImageScale(), y: this.backgroundImageScale() })
      .zIndex(0)
      .hitTestBehavior(HitTestMode.None)
  }

  private customBackgroundImageSource(source: string): image.PixelMap | string {
    if (this.customBackgroundPixelMap !== undefined) {
      return this.customBackgroundPixelMap;
    }
    return source;
  }

  @Builder
  private ImmersionMaterialLayer(cardHeight: Length, cardRadius: number) {
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs() {
        TabContent() {
        }
        .backdropBlur(0)
        .tabBar(this.ImmersionMaterialContent(cardHeight))
        .clip(false)
      }
      .width(this.immersionExpandedWidth(cardHeight))
      .height(cardHeight)
      .barWidth(this.immersionExpandedWidth(cardHeight))
      .barHeight(this.immersionMaterialBarHeight(cardHeight))
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barBackgroundStyle({
        maskColor: '#00000000'
      })
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barFloatingStyle({
        barBottomMargin: 0,
        systemMaterialEffect: {
          materialType: this.configuredMaterialType(),
          materialLevel: this.configuredMaterialLevel()
        },
        gradientMask: {
          maskColor: '#09999999'
        }
      })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.None)
      .clip(false)
    }
    .width('100%')
    .height(cardHeight)
    .borderRadius(cardRadius)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.None)
    .zIndex(1)
  }

  @Builder
  private OnboardingImmersionMaterialLayer(cardHeight: Length, cardRadius: number) {
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs() {
        TabContent() {
        }
        .backdropBlur(0)
        .tabBar(this.ImmersionMaterialContent(cardHeight))
        .clip(false)
      }
      .width(this.immersionExpandedWidth(cardHeight))
      .height(cardHeight)
      .barWidth(this.immersionExpandedWidth(cardHeight))
      .barHeight(this.immersionMaterialBarHeight(cardHeight))
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barBackgroundStyle({ maskColor: '#00000000' })
      .barBackgroundBlurStyle(BlurStyle.NONE)
      .barFloatingStyle({
        barBottomMargin: 0,
        systemMaterialEffect: this.onboardingMaterialEffect(),
        gradientMask: { maskColor: '#09999999' }
      })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.None)
      .clip(false)
      Column()
        .width('100%')
        .height(cardHeight)
        .backgroundColor(ONBOARDING_MATERIAL_TINT_COLOR)
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(cardHeight)
    .borderRadius(cardRadius)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.None)
    .zIndex(1)
  }

  @Builder
  private ImmersionMaterialContent(cardHeight: Length) {
    Stack()
      .width(this.immersionExpandedWidth(cardHeight))
      .height(this.immersionMaterialBarHeight(cardHeight))
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private ImmersionCardSurface(cardHeight: Length, cardRadius: number) {
    this.ImmersionMaterialLayer(cardHeight, cardRadius)
  }

  @Builder
  private MeasuredImmersionCardSurface(cardId: string, cardRadius: number) {
    if (this.shouldUseCardMaterial() && this.measuredCardHeight(cardId) > 0) {
      this.ImmersionCardSurface(this.measuredCardHeight(cardId), cardRadius)
    }
  }

  @Builder
  private SheetActionMaterialBackground() {
    if (this.shouldUseCardMaterial()) {
      this.ImmersionCardSurface('100%', SHEET_ACTION_BAR_RADIUS)
    } else {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.sheetFloatingBarColor())
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    }
  }

  private immersionExpandedWidth(cardHeight: Length): number {
    return Math.max(this.pageWidth, RESPONSIVE_CARD_MAX_WIDTH) + this.immersionMaterialBarHeight(cardHeight) * 2;
  }

  private immersionMaterialBarHeight(cardHeight: Length): number {
    return typeof cardHeight === 'number' ? cardHeight : RESPONSIVE_CARD_MAX_WIDTH;
  }

  private measuredCardHeight(cardId: string): number {
    const height = this.measuredCardHeights.get(cardId);
    return height === undefined ? 0 : height;
  }

  private updateMeasuredCardHeight(cardId: string, area: Area): void {
    const height = this.lengthToNumber(area.height, 0);
    if (height <= 0 || Math.abs(height - this.measuredCardHeight(cardId)) <= 0.5) {
      return;
    }
    const nextHeights = new Map<string, number>(this.measuredCardHeights);
    nextHeights.set(cardId, height);
    this.measuredCardHeights = nextHeights;
  }

  private immersionBorderColor(): ResourceColor {
    return this.isDarkTheme() ? '#80FFFFFF' : '#80000000';
  }

  private backgroundBlurRadius(): number {
    return this.backgroundBlurPercent / 100 * BACKGROUND_BLUR_MAX_RADIUS;
  }

  private backgroundImageScale(): number {
    return 1 + this.backgroundBlurPercent / 100 * 0.12;
  }

  private backgroundImageBrightness(): number {
    return this.backgroundBrightnessPercent / 50;
  }

  @Builder
  private OnboardingOverlay() {
    Stack() {
      this.OnboardingBackdrop()
      Swiper(this.onboardingSwiperController) {
        this.OnboardingPage(0)
        this.OnboardingPage(1)
        this.OnboardingPage(2)
        this.OnboardingPage(3)
      }
      .index(this.onboardingPage)
      .loop(false)
      .indicator(false)
      .duration(360)
      .curve(Curve.EaseInOut)
      .onChange((index: number) => {
        this.onboardingPage = index;
      })
      .width('100%')
      .height('100%')
      .zIndex(1)

      this.OnboardingTopOverlay()
      this.OnboardingBottomOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .clip(true)
    .zIndex(200)
    .onAppear(() => {
      this.setOnboardingSystemBars(true);
    })
  }

  @Builder
  private OnboardingTopOverlay() {
    Column() {
      this.OnboardingTopBar()
    }
    .width('100%')
    .height(this.onboardingTopOverlayHeight())
    .padding({
      top: this.statusBarHeight + 8,
      left: this.onboardingPageSide(),
      right: this.onboardingPageSide(),
      bottom: 16
    })
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(10)
  }

  @Builder
  private OnboardingBottomOverlay() {
    Column() {
      this.OnboardingPageIndicator()
      Stack({ alignContent: Alignment.Center }) {
        ImmersionButton({
          systemMaterialEffect: this.onboardingMaterialEffect(),
          buttonModify: new ActionButtonModifier(
            '100%', ONBOARDING_ACTION_HEIGHT, ONBOARDING_BUTTON_TINT_COLOR, ONBOARDING_ACCENT_COLOR),
          click: (): void => {
            if (this.onboardingPage < ONBOARDING_PAGE_COUNT - 1) {
              this.onboardingSwiperController.showNext();
            } else {
              this.completeOnboarding();
            }
          }
        }) {
          Text(this.onboardingPage === ONBOARDING_PAGE_COUNT - 1 ? this.t('开始使用') : this.t('下一页'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(ONBOARDING_ACCENT_COLOR)
        }
      }
      .width('100%')
      .height(ONBOARDING_ACTION_HEIGHT)
      .constraintSize({ maxWidth: ONBOARDING_ACTION_MAX_WIDTH })
      .margin({ top: ONBOARDING_BOTTOM_CONTROL_GAP })
    }
    .width('100%')
    .height(this.onboardingBottomOverlayHeight())
    .padding({
      left: this.onboardingPageSide(),
      right: this.onboardingPageSide(),
      bottom: this.naviIndicatorHeight + ONBOARDING_BOTTOM_SAFE_GAP
    })
    .justifyContent(FlexAlign.End)
    .position({ x: 0, y: Math.max(this.pageHeight - this.onboardingBottomOverlayHeight(), 0) })
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(10)
  }

  @Builder
  private OnboardingBackdrop() {
    Image($r('app.media.background_preset_1'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .scale({ x: 1.015, y: 1.015 })
      .hitTestBehavior(HitTestMode.None)
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#52000000')
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private OnboardingTopBar() {
    Row() {
      Row({ space: 8 }) {
        Image($r('app.media.app_icon_black'))
          .width(28)
          .height(28)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
        Text(this.t('开源验证器'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        ImmersionButton({
          systemMaterialEffect: this.onboardingMaterialEffect(),
          buttonModify: new ActionButtonModifier(
            64, 40, ONBOARDING_BUTTON_TINT_COLOR, ONBOARDING_ACCENT_COLOR),
          click: (): void => {
            this.completeOnboarding();
          }
        }) {
          Text(this.t('跳过'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(ONBOARDING_ACCENT_COLOR)
        }
      }
      .width(64)
      .height(40)
      .clip(false)
    }
    .width('100%')
    .constraintSize({ maxWidth: ONBOARDING_CONTENT_MAX_WIDTH })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private OnboardingPageIndicator() {
    Row({ space: 8 }) {
      ForEach([0, 1, 2, 3], (index: number) => {
        Row()
          .width(this.onboardingPage === index ? 24 : 6)
          .height(6)
          .backgroundColor(this.onboardingPage === index ? ONBOARDING_ACCENT_COLOR : '#66FFFFFF')
          .borderRadius(3)
          .animation({ duration: 220, curve: Curve.EaseInOut })
      }, (index: number) => index.toString())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private OnboardingPage(index: number) {
    Scroll() {
      Column({ space: 20 }) {
        if (index === 0) {
          this.OnboardingSecurityPage()
        } else if (index === 1) {
          this.OnboardingImportPage()
        } else if (index === 2) {
          this.OnboardingAppearancePage()
        } else {
          this.OnboardingBackupPage()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: ONBOARDING_CONTENT_MAX_WIDTH })
      .padding({
        top: this.onboardingContentTopInset(),
        left: this.onboardingPageSide(),
        right: this.onboardingPageSide(),
        bottom: this.onboardingContentBottomInset()
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private OnboardingSecurityPage() {
    Column({ space: 18 }) {
      this.OnboardingPageHeader('01 / 04', $r('sys.symbol.key_shield'))
      this.OnboardingPageCopy(
        '安全底座',
        '密钥留在本地，安全从第一步开始',
        '验证码在设备端生成；不开启同步时，令牌数据不会离开你的设备。')
      this.OnboardingSecurityCard()
    }
    .width('100%')
    .constraintSize({ maxWidth: ONBOARDING_CARD_MAX_WIDTH })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OnboardingPageHeader(sequence: string, icon: Resource) {
    Row() {
      Text(sequence)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#E6FFFFFF')
        .letterSpacing(0.8)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor('#1FFFFFFF')
        .border({ width: 0.5, color: '#4DFFFFFF' })
        .borderRadius(16)
      Blank()
      Stack({ alignContent: Alignment.Center }) {
        this.OnboardingImmersionMaterialLayer(ONBOARDING_HERO_SIZE, ONBOARDING_HERO_SIZE / 2)
        SymbolGlyph(icon)
          .fontSize(30)
          .fontColor([ONBOARDING_ACCENT_COLOR])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .zIndex(2)
      }
      .width(ONBOARDING_HERO_SIZE)
      .height(ONBOARDING_HERO_SIZE)
      .backgroundColor(Color.Transparent)
      .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
      .borderRadius(ONBOARDING_HERO_SIZE / 2)
      .clip(true)
      .shadow({ radius: 24, color: ONBOARDING_GLOW_COLOR, offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private OnboardingImportPage() {
    Column({ space: 18 }) {
      this.OnboardingPageHeader('02 / 04', $r('sys.symbol.qrcode'))
      this.OnboardingPageCopy(
        '导入与兼容',
        '从常用验证器，轻松迁移',
        '手动录入、扫码或文件导入，兼容主流标准与发行方。')
      this.OnboardingImportHero()
      this.OnboardingImportCard()
    }
    .width('100%')
    .constraintSize({ maxWidth: ONBOARDING_CARD_MAX_WIDTH })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OnboardingImportHero() {
    Column({ space: 14 }) {
      Row() {
        this.OnboardingRoundIcon($r('sys.symbol.square_and_pencil'))
        this.OnboardingRoundIcon($r('sys.symbol.barcode_viewfinder'))
        this.OnboardingRoundIcon($r('sys.symbol.square_and_arrow_down'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      Column({ space: 8 }) {
        this.OnboardingProviderTag('Google Authenticator')
        Row({ space: 8 }) {
          this.OnboardingProviderTag('OpenAI')
          this.OnboardingProviderTag('Steam')
        }
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private OnboardingProviderTag(label: string) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor('#20FFFFFF')
      .border({ width: 0.5, color: '#55FFFFFF' })
      .borderRadius(18)
  }

  @Builder
  private OnboardingAppearancePage() {
    Column({ space: 18 }) {
      this.OnboardingPageHeader('03 / 04', $r('sys.symbol.paintpalette'))
      this.OnboardingPageCopy(
        '沉浸体验',
        '精致光感，让令牌抬眼即见',
        '全局沉浸材质贯穿页面与卡片，手机、平板和折叠屏自然适配。')
      this.OnboardingTokenPreview()
      this.OnboardingAppearanceCard()
    }
    .width('100%')
    .constraintSize({ maxWidth: ONBOARDING_CARD_MAX_WIDTH })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OnboardingTokenPreview() {
    Stack({ alignContent: Alignment.Top }) {
      this.OnboardingImmersionMaterialLayer(ONBOARDING_TOKEN_PREVIEW_HEIGHT, ONBOARDING_CARD_RADIUS)
      Column({ space: 8 }) {
        Row() {
          Row({ space: 8 }) {
            Circle()
              .width(28)
              .height(28)
              .fill(ONBOARDING_ACCENT_COLOR)
            Text('OpenAI')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(ONBOARDING_PRIMARY_TEXT_COLOR)
          }
          .layoutWeight(1)
          Text('18s')
            .fontSize(12)
            .fontColor(ONBOARDING_SECONDARY_TEXT_COLOR)
        }
        .width('100%')
        Text('482 193')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(ONBOARDING_PRIMARY_TEXT_COLOR)
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.square_grid_2x2'))
            .fontSize(14)
            .fontColor([ONBOARDING_ACCENT_COLOR])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          Text(this.t('服务卡片 · 精致材质'))
            .fontSize(12)
            .fontColor(ONBOARDING_SECONDARY_TEXT_COLOR)
        }
      }
      .width('100%')
      .height(ONBOARDING_TOKEN_PREVIEW_HEIGHT)
      .padding(20)
      .zIndex(2)
    }
    .width('100%')
    .height(ONBOARDING_TOKEN_PREVIEW_HEIGHT)
    .constraintSize({ maxWidth: 340 })
    .borderRadius(ONBOARDING_CARD_RADIUS)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
    .shadow({
      radius: 28,
      color: '#52000000',
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  private OnboardingBackupPage() {
    Column({ space: 18 }) {
      this.OnboardingPageHeader('04 / 04', $r('sys.symbol.person_shield'))
      this.OnboardingPageCopy(
        '备份与隐私',
        '数据去哪里，始终由你决定',
        '需要时再导出或同步；本地优先，备份、云空间与隐私能力均可独立控制。')
      this.OnboardingBackupHero()
      this.OnboardingBackupCard()
    }
    .width('100%')
    .constraintSize({ maxWidth: ONBOARDING_CARD_MAX_WIDTH })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OnboardingBackupHero() {
    Row() {
      this.OnboardingRoundIcon($r('sys.symbol.square_and_arrow_down'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#99FFFFFF'])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      this.OnboardingRoundIcon($r('sys.symbol.icloud'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#99FFFFFF'])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      this.OnboardingRoundIcon($r('sys.symbol.person_shield'))
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceAround)
  }

  @Builder
  private OnboardingPageCopy(eyebrow: string, title: string, body: string) {
    Column({ space: 8 }) {
      Text(this.t(eyebrow))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(ONBOARDING_ACCENT_COLOR)
      Text(this.t(title))
        .fontSize(ONBOARDING_TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Start)
        .maxLines(2)
      Text(this.t(body))
        .fontSize(ONBOARDING_BODY_SIZE)
        .fontColor('#CCFFFFFF')
        .textAlign(TextAlign.Start)
        .lineHeight(21)
        .maxLines(3)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OnboardingRoundIcon(icon: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      this.OnboardingImmersionMaterialLayer(52, 26)
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([ONBOARDING_ACCENT_COLOR])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .zIndex(2)
    }
    .width(52)
    .height(52)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
    .borderRadius(26)
    .clip(true)
  }

  @Builder
  private OnboardingSecurityCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.OnboardingImmersionMaterialLayer(ONBOARDING_FEATURE_CARD_HEIGHT, 18)
      Column() {
        this.OnboardingInfoRow($r('sys.symbol.key_fill'), '本地存储', '密钥与令牌默认保存在当前设备')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.checkmark_shield'), '离线可用', 'TOTP、HOTP 与 Steam 验证码本地生成')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.person_shield'), '隐私守护', '应用锁与系统防窥保护敏感信息')
      }
      .width('100%')
      .height(ONBOARDING_FEATURE_CARD_HEIGHT)
      .zIndex(2)
    }
    .width('100%')
    .height(ONBOARDING_FEATURE_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
  }

  @Builder
  private OnboardingImportCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.OnboardingImmersionMaterialLayer(ONBOARDING_FEATURE_CARD_HEIGHT, 18)
      Column() {
        this.OnboardingInfoRow($r('sys.symbol.qrcode'), '扫码导入', '支持 otpauth 与 Google Authenticator 迁移二维码')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.square_and_arrow_down'), '文件导入', '支持 JSON 备份与 Steam maFile')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.gamecontroller'), 'Steam 增强能力', '扫码登录，并处理交易与市场确认')
      }
      .width('100%')
      .height(ONBOARDING_FEATURE_CARD_HEIGHT)
      .zIndex(2)
    }
    .width('100%')
    .height(ONBOARDING_FEATURE_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
  }

  @Builder
  private OnboardingAppearanceCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.OnboardingImmersionMaterialLayer(ONBOARDING_FEATURE_CARD_HEIGHT, 18)
      Column() {
        this.OnboardingInfoRow($r('sys.symbol.paintpalette'), '全局沉浸光感', '自适应、沉浸等材质效果可自由选择')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.square_grid_2x2'), '服务卡片', '多种规格展示常用令牌，无需进入应用')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.key_fill'), '自适应布局', '单列、双列、深色模式与自定义背景')
      }
      .width('100%')
      .height(ONBOARDING_FEATURE_CARD_HEIGHT)
      .zIndex(2)
    }
    .width('100%')
    .height(ONBOARDING_FEATURE_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
  }

  @Builder
  private OnboardingBackupCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.OnboardingImmersionMaterialLayer(ONBOARDING_FEATURE_CARD_HEIGHT, 18)
      Column() {
        this.OnboardingInfoRow($r('sys.symbol.square_and_arrow_down'), '备份导出', '导出 JSON 文件或二维码，便于恢复与迁移')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.icloud'), '华为云空间', '登录后可选择自动同步或手动推送、获取')
        this.OnboardingFeatureDivider()
        this.OnboardingInfoRow($r('sys.symbol.person_shield'), '隐私守护', '应用锁、防窥保护与隐私声明清晰可控')
      }
      .width('100%')
      .height(ONBOARDING_FEATURE_CARD_HEIGHT)
      .zIndex(2)
    }
    .width('100%')
    .height(ONBOARDING_FEATURE_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(Color.Transparent)
    .border({ width: 0.5, color: ONBOARDING_BORDER_COLOR })
  }

  @Builder
  private OnboardingFeatureDivider() {
    Divider()
      .strokeWidth(1)
      .color(ONBOARDING_DIVIDER_COLOR)
      .margin({ left: ONBOARDING_ICON_CONTAINER_SIZE + 28 })
  }

  @Builder
  private OnboardingInfoRow(icon: Resource, title: string, body: string) {
    Row({ space: 12 }) {
      Stack() {
        Circle()
          .width(ONBOARDING_ICON_CONTAINER_SIZE)
          .height(ONBOARDING_ICON_CONTAINER_SIZE)
          .fill(ONBOARDING_ICON_TINT_COLOR)
        SymbolGlyph(icon)
          .fontSize(ONBOARDING_ICON_SIZE)
          .fontColor([ONBOARDING_ACCENT_COLOR])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }
      .width(ONBOARDING_ICON_CONTAINER_SIZE)
      .height(ONBOARDING_ICON_CONTAINER_SIZE)
      Column({ space: 2 }) {
        Text(this.t(title))
          .fontSize(ONBOARDING_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ONBOARDING_PRIMARY_TEXT_COLOR)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.t(body))
          .fontSize(ONBOARDING_ROW_BODY_SIZE)
          .fontColor(ONBOARDING_SECONDARY_TEXT_COLOR)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(ONBOARDING_FEATURE_ROW_HEIGHT)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  private HomePageContent() {
    if (this.isWatchLayout()) {
      this.WatchHomePageContent()
    } else {
      Stack() {
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
            materialType: this.configuredMaterialType(),
            materialLevel: this.configuredMaterialLevel()
          }
        })
        .onChange((index: number) => {
          this.selectedHomeTab = index === 0 ? HomeTab.Token : HomeTab.Me;
          this.isHomeListScrolling = false;
          if (this.selectedHomeTab === HomeTab.Token) {
            this.currentTimeMs = Date.now();
          }
        })
        .width('100%')
        .height('100%')

      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  private WatchHomePageContent() {
    Stack() {
      if (this.watchHomePageIndex === WatchHomePage.Tokens) {
        this.WatchTokenPageContent()
      } else {
        this.WatchFeaturePageContent()
      }
    }
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 12 })
      .onActionEnd((event: GestureEvent) => {
        if (this.watchHomePageIndex === WatchHomePage.Tokens) {
          if (event.offsetX <= -WATCH_PAGE_SWIPE_DISTANCE) {
            this.showWatchHomePage(WatchHomePage.Features);
          } else if (event.offsetX >= WATCH_PAGE_SWIPE_DISTANCE) {
            this.exitWatchApp();
          }
        } else if (event.offsetX >= WATCH_PAGE_SWIPE_DISTANCE) {
          this.showWatchHomePage(WatchHomePage.Tokens);
        }
      }))
    .width('100%')
    .height('100%')
  }

  @Builder
  private WatchTokenPageContent() {
    Scroll(this.watchScroller) {
      Column({ space: 10 }) {
        if (this.tokenDataLoaded) {
          if (this.watchVisibleTokens().length === 0) {
            this.WatchEmptyCard()
          } else {
            ForEach(this.watchVisibleTokens(), (token: TokenRecord) => {
              this.WatchTokenCard(token)
            }, (token: TokenRecord) => token.id)
          }
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
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .id(WATCH_TOKEN_FOCUS_KEY)
      .focusable(true)
      .focusOnTouch(true)
      .defaultFocus(true)
      .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
      .align(Alignment.Top)
      .onAppear(() => {
        this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 150);
      })
      .clip(false)
      .width('100%')
      .height('100%')
      .clip(false)
    }

  @Builder
  private WatchFeaturePageContent() {
    Scroll(this.watchFeatureScroller) {
      Column({ space: 12 }) {
        Text(this.t('功能'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        this.WatchFeatureActionCard()

        Text(this.t('右滑返回令牌'))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 4 })
      }
      .width('100%')
      .padding({
        left: WATCH_HORIZONTAL_PADDING,
        right: WATCH_HORIZONTAL_PADDING,
        top: this.statusBarHeight + WATCH_FEATURE_TOP_PADDING,
        bottom: this.naviIndicatorHeight + 18
      })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .id(WATCH_FEATURE_FOCUS_KEY)
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
    .align(Alignment.Top)
    .clip(false)
    .onAppear(() => {
      this.requestWatchFocus(WATCH_FEATURE_FOCUS_KEY, 80);
    })
  }

  @Builder
  private WatchFeatureActionCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(WATCH_FEATURE_CARD_HEIGHT, 18)
      }
      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.barcode_viewfinder'))
              .fontSize(20)
              .fontColor([this.accentColor()])
              .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          }
          .width(WATCH_FEATURE_ICON_SIZE)
          .height(WATCH_FEATURE_ICON_SIZE)
          .borderRadius(WATCH_FEATURE_ICON_SIZE / 2)
          .backgroundColor(this.accentTintColor())

          Text(this.t('手机扫码同步'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([this.secondaryTextColor()])
            .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.t('手机端下载「开源验证器」，连接相同WIFI，「我的>手表端数据同步>扫码同步到手表」选择令牌并同步到手表'))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
          .lineHeight(14)
          .maxLines(WATCH_FEATURE_BODY_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .height(WATCH_FEATURE_CARD_HEIGHT)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .height(WATCH_FEATURE_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-phone-sync'), y: this.appCardScale('watch-phone-sync') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-phone-sync', event.type);
    })
    .onClick(() => {
      this.openWatchLanSyncPage();
    })
  }

  @Builder
  private WatchLanSyncPageContent() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.watchLanReceiving && this.watchLanQrText.length > 0) {
        Stack({ alignContent: Alignment.Center }) {
          QRCode(this.watchLanQrText)
            .width(WATCH_LAN_QR_SIZE)
            .height(WATCH_LAN_QR_SIZE)
            .color('#000000')
            .backgroundColor('#FFFFFF')
        }
        .width(WATCH_LAN_QR_FRAME_SIZE)
        .height(WATCH_LAN_QR_FRAME_SIZE)
        .padding(4)
        .borderRadius(8)
        .backgroundColor('#FFFFFF')
      } else if (this.watchLanReceiving) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(34)
            .height(34)
            .color(this.accentColor())

          Text(this.t(this.watchLanStatus.length > 0 ? this.watchLanStatus : '正在创建配对码'))
            .fontSize(12)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 36, right: 36 })
      } else {
        Column({ space: 16 }) {
          Text(this.t(this.watchLanStatus.length > 0 ? this.watchLanStatus : '局域网同步不可用'))
            .fontSize(13)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .width('100%')

          Button(this.t('重新生成配对码'))
            .height(38)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentContrastColor())
            .backgroundColor(this.accentColor())
            .onClick(() => {
              this.startLanWatchReceiver();
            })
        }
        .width('100%')
        .padding({ left: 36, right: 36 })
      }

      Column({ space: 2 }) {
        Text(this.t('打开手机端'))
          .fontSize(WATCH_SYNC_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.watchLanReceiving && this.watchLanQrText.length > 0) {
          Text(this.t('「我的>手表端数据同步>扫码同步到手表」'))
            .fontSize(WATCH_SYNC_PATH_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .textAlign(TextAlign.Center)
            .lineHeight(14)
            .maxLines(WATCH_SYNC_PATH_MAX_LINES)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 28,
        right: 28,
        top: this.statusBarHeight + 8
      })
      .justifyContent(FlexAlign.Start)
      .hitTestBehavior(HitTestMode.None)

      Column({ space: 1 }) {
        if (this.watchLanReceiving && this.watchLanQrText.length > 0) {
          Text(this.watchLanCountdownText())
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')

          Text(this.t(this.watchLanStatus))
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        Text(this.t('右滑退出'))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding({
        left: 30,
        right: 30,
        bottom: this.naviIndicatorHeight + 6
      })
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .id(WATCH_LAN_SYNC_FOCUS_KEY)
    .focusable(true)
    .focusOnTouch(true)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 12 })
      .onActionEnd((event: GestureEvent) => {
        if (event.offsetX >= WATCH_PAGE_SWIPE_DISTANCE) {
          this.closeWatchLanSyncPage();
        }
      }))
  }

  @Builder
  private WatchEmptyCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(WATCH_EMPTY_CARD_HEIGHT, 18)
      }
      Column({ space: 6 }) {
        Text(this.t('暂无令牌'))
          .fontSize(WATCH_EMPTY_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .width('100%')

        Text(this.t('左滑进行手机端令牌同步'))
          .fontSize(WATCH_EMPTY_BODY_SIZE)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .lineHeight(15)
          .maxLines(2)
          .width('100%')

      }
      .width('100%')
      .height(WATCH_EMPTY_CARD_HEIGHT)
      .padding({ top: 14, bottom: 14, left: 16, right: 16 })
      .justifyContent(FlexAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .height(WATCH_EMPTY_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-empty'), y: this.appCardScale('watch-empty') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-empty', event.type);
    })
    .onClick(() => {
      this.showWatchHomePage(WatchHomePage.Features);
    })
  }

  @Builder
  private WatchCloudCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.MeasuredImmersionCardSurface('watch-cloud', 18)
      this.WatchCloudCardContent()
    }
    .width('100%')
    .borderRadius(18)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-cloud'), y: this.appCardScale('watch-cloud') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-cloud', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('watch-cloud', newValue);
    })
  }

  @Builder
  private WatchCloudCardContent() {
    Column({ space: 8 }) {
      Text(this.isHuaweiLoggedIn ? this.displayHuaweiNickname() : this.t('登录华为账号'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
          buttonModify: {
            applyNormalAttribute(instance: ButtonModifier): void {
              instance.width('100%').height(36)
            }
          },
          click: (): void => {
            if (this.cloudSyncing) {
              return;
            }
            if (this.isHuaweiLoggedIn) {
              this.pullTokensFromCloud();
            } else {
              this.loginHuaweiAccount();
            }
          }
        }) {
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
      }
      .width('100%')
      .height(36)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .zIndex(2)
  }

  @Builder
  private WatchTokenCard(token: TokenRecord) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(WATCH_TOKEN_CARD_HEIGHT, 18)
      }
      this.WatchTokenCardContent(token)
    }
    .width('100%')
    .height(WATCH_TOKEN_CARD_HEIGHT)
    .borderRadius(18)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-token-' + token.id), y: this.appCardScale('watch-token-' + token.id) })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-token-' + token.id, event.type);
    })
  }

  @Builder
  private WatchTokenCardContent(token: TokenRecord) {
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

      Stack({ alignContent: Alignment.Center }) {
        this.TokenCodeView(token, false, WATCH_TOKEN_CODE_SIZE, this.tokenValueColor(), FontWeight.Medium, 0)

        Row() {
          Blank()
            .layoutWeight(1)

          Text(this.tokenCountdownText(token))
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(this.tokenDigitHeight(WATCH_TOKEN_CODE_SIZE))
    }
    .width('100%')
    .height(WATCH_TOKEN_CARD_HEIGHT)
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .justifyContent(FlexAlign.Center)
    .zIndex(2)
  }

  @Builder
  private SettingsNavDestination(name: string, pageInfos: Object) {
    NavDestination() {
      Stack() {
        if (this.globalBackgroundEnabled) {
          this.PageBackground()
        }

        HdsNavigation() {
          if (name === 'addToken') {
            this.AddTokenContent()
          } else if (name === 'cloudSpace') {
            this.CloudSpacePageContent()
          } else if (name === 'watchSync') {
            this.WatchSyncPageContent()
          } else if (name === 'moreApps') {
            this.MoreAppsPageContent()
          } else if (name === 'donation') {
            this.DonationPageContent()
          } else if (name === 'about') {
            this.AboutPageContent()
          } else if (name === 'thirdParty') {
            this.ThirdPartyPageContent()
          } else if (name === 'appearanceSettings') {
            this.AppearanceSettingsPageContent()
          } else if (name === 'featureSecurity') {
            this.FeatureSecurityPageContent()
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
              enableScrollEffect: false,
              scrollEffectType: ScrollEffectType.GRADIENT_BLUR
            },
            blurStrategy: BlurStrategy.ADAPTIVE,
            originalStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
            scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00ffffff' } },
            systemMaterialEffect: {
              materialType: this.configuredMaterialType(),
              materialLevel: this.configuredMaterialLevel()
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
      .width('100%')
      .height('100%')
      .backgroundColor(this.pageBackgroundColor())
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
    Stack({ alignContent: Alignment.Top }) {
      List({ scroller: this.homeScroller }) {

      if (this.tokenDataLoaded) {
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
      }
      .width('100%')
      .height('100%')
      .lanes(!this.tokenDataLoaded || this.filteredTokens().length === 0 ? 1 : this.tokenListLaneCount(),
        PAGE_CARD_GAP)
      .padding({
        left: HOME_HORIZONTAL_PADDING,
        right: HOME_HORIZONTAL_PADDING,
        top: this.statusBarHeight + HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP + HOME_SEARCH_HEIGHT + PAGE_CARD_GAP
      })
      .contentEndOffset(this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP)
      .cachedCount(HOME_LIST_CACHE_COUNT, true)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)
      .onScrollStart(() => {
        this.isHomeListScrolling = true;
      })
      .onScrollStop(() => {
        this.isHomeListScrolling = false;
        this.currentTimeMs = Date.now();
      })

      Row() {
        this.HomeSearchBar()
      }
      .width('100%')
      .padding({ left: HOME_HORIZONTAL_PADDING, right: HOME_HORIZONTAL_PADDING })
      .position({ x: 0, y: this.statusBarHeight + HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP })
      .zIndex(12)
    }
    .width('100%')
    .height('100%')
    .clip(false)
  }

  @Builder
  private TokenListForEach() {
    ForEach(this.filteredTokens(), (token: TokenRecord) => {
      ListItem() {
        this.TokenListItem(token)
      }
      .width('100%')
      .margin({ bottom: PAGE_CARD_GAP })
      .clip(false)
    }, (token: TokenRecord) => `${token.id}-${this.logoRenderVersion}`)
  }

  @Builder
  private MovableTokenListForEach() {
    ForEach(this.filteredTokens(), (token: TokenRecord) => {
      ListItem() {
        this.TokenListItem(token)
      }
      .width('100%')
      .margin({ bottom: PAGE_CARD_GAP })
      .clip(false)
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

      ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
        text: this.t('新增令牌'),
        buttonModify: {
          applyNormalAttribute(instance: ButtonModifier): void {
            instance.width(148).height(44)
          }
        },
        click: (): void => {
          this.isAddMenuOpen = true;
        }
      })
        .width(148)
        .height(44)

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

      this.ImportProgressCard()
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    .zIndex(180)
    .hitTestBehavior(HitTestMode.Block)
  }

  @Builder
  private ImportProgressCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('import-progress', 24)
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
      .width('100%')
      .padding({ left: 22, right: 22, top: 22, bottom: 22 })
      .zIndex(2)
    }
    .width(Math.min(300, this.pageWidth - HOME_HORIZONTAL_PADDING * 2))
    .borderRadius(24)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('import-progress'), y: this.appCardScale('import-progress') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('import-progress', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('import-progress', newValue);
    })
    .shadow({
      radius: 24,
      color: this.isDarkTheme() ? '#66000000' : '#18000000',
      offsetX: 0,
      offsetY: 10
    })
  }

  @Builder
  private MePageContent() {
    Stack() {
      WaterFlow({
        scroller: this.meScroller,
        sections: this.meWaterFlowSections
      }) {
        FlowItem() {
          this.MeLoginCard()
        }
        .width('100%')

        FlowItem() {
          this.MeActionCard([
            ['华为云空间', $r('sys.symbol.icloud')],
            ['手表端数据同步', $r('sys.symbol.square_grid_2x2')],
            ['备份导出', $r('sys.symbol.square_and_arrow_down')]
          ], 0)
        }
        .width('100%')
        .bindSheet($$this.showExportPicker, this.ExportTokenPickerSheet(), {
          height: SheetSize.MEDIUM,
          dragBar: true,
          showClose: false,
          backgroundColor: this.sheetSurfaceBackgroundColor(),
          blurStyle: this.sheetSurfaceBlurStyle(),
          radius: LengthMetrics.vp(28)
        })

        FlowItem() {
          this.MeActionCard([
            ['外观与主题', $r('sys.symbol.paintpalette')],
            ['功能与安全', $r('sys.symbol.key_shield')]
          ], 1)
        }
        .width('100%')

        FlowItem() {
          this.MeActionCard([
            ['打赏一杯咖啡', $r('sys.symbol.heart')],
            ['更多作品', $r('sys.symbol.square_grid_2x2')]
          ], 2)
        }
        .width('100%')
        .bindSheet($$this.showExportQR, this.ExportQRCodeSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false,
          backgroundColor: this.sheetSurfaceBackgroundColor(),
          blurStyle: this.sheetSurfaceBlurStyle(),
          radius: LengthMetrics.vp(28)
        })

        FlowItem() {
          this.MeActionCard([
            ['开源地址', $r('sys.symbol.link_slash')],
            ['用户协议', $r('sys.symbol.checkmark_shield')],
            ['隐私声明', $r('sys.symbol.person_shield')],
            ['关于', $r('sys.symbol.person_2')]
          ], 3)
        }
        .width('100%')
        .bindSheet($$this.showExportFormat, this.ExportFormatSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          showClose: false,
          backgroundColor: this.sheetSurfaceBackgroundColor(),
          blurStyle: this.sheetSurfaceBlurStyle(),
          radius: LengthMetrics.vp(28)
        })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: HOME_HORIZONTAL_PADDING,
        right: HOME_HORIZONTAL_PADDING
      })
      .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
      .contentEndOffset(this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP + 18)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)

      this.MeSheetAnchors()
    }
    .width('100%')
    .height('100%')
    .clip(false)
  }

  @Builder
  private MeSheetAnchors() {
    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showUserAgreementSheet, this.UserAgreementSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28)
      })

    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showWebSheet, this.WebPageSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28)
      })
  }

  @Builder
  private SteamLoginSheetAnchor() {
    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showSteamLoginPicker, this.SteamLoginPickerSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28),
        onDisappear: () => {
          this.pendingSteamLoginTokenId = '';
        }
      })
  }

  @Builder
  private QQGroupSheetAnchor() {
    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showQQGroupSheet, this.QQGroupSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28)
      })
  }

  @Builder
  private SteamDecryptSheetAnchor() {
    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showSteamDecryptSheet, this.SteamDecryptPasswordSheet(), {
        height: SheetSize.MEDIUM,
        dragBar: true,
        showClose: false,
        maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28),
        onDisappear: () => {
          if (!this.steamDecrypting) {
            this.steamDecryptPassword = '';
            this.pendingSteamEncryptedContent = '';
            this.pendingSteamManifestContent = '';
            this.pendingSteamFileName = '';
          }
        }
      })
  }

  @Builder
  private SteamEnrollmentSheetAnchor() {
    Column()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.showSteamEnrollmentSheet, this.SteamEnrollmentSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
        backgroundColor: this.sheetSurfaceBackgroundColor(),
        blurStyle: this.sheetSurfaceBlurStyle(),
        radius: LengthMetrics.vp(28),
        onDisappear: () => {
          if (!this.steamEnrollmentLoading) {
            this.clearSteamEnrollmentSecrets();
          }
        }
      })
  }

  @Builder
  private UpdateNoticeSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll(this.updateNoticeSheetScroller) {
          Column({ space: 12 }) {
            this.UpdateNoticeHero()
            this.UpdateNoticeItem('1', '账号退出更安全',
              '华为账号退出使用主题色光感按钮，并在操作前进行二次确认。',
              '我的 → 华为账号 → 退出')
            this.UpdateNoticeItem('2', '备份导入更准确',
              '修复二维码和 JSON 备份重新导入后令牌名称与发行方颠倒的问题。',
              '我的 → 备份与导入')
            this.UpdateNoticeItem('3', '远程 Logo 维护',
              '新增 GitCode 发行方 Logo 维护库，无需重新发布安装包即可补充品牌资源。',
              '内置 Logo → GitCode → Simple Icons')
            this.UpdateNoticeItem('4', '品牌显示更统一',
              '新增 GitCode、Bitget、Bybit、Kimi Logo，并统一 Microsoft 与 GitCode 图标尺寸。',
              '令牌卡片与新增、编辑页面')
            this.UpdateNoticeItem('5', '版本信息自动同步',
              '“关于”页面会直接读取当前安装包的版本名称和版本号。',
              '我的 → 关于 → 应用版本')
          }
          .width('100%')
          .padding({
            left: SHEET_HORIZONTAL_PADDING,
            right: SHEET_HORIZONTAL_PADDING,
            top: SHEET_CONTENT_TOP_PADDING,
            bottom: this.sheetListBottomPadding()
          })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        this.SheetSingleFloatingAction({
          label: this.t('不再提醒'),
          action: () => {
            this.dismissUpdateNotice();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('本次更新') },
        menu: this.sheetCloseMenu(() => {
          this.showUpdateNotice = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.updateNoticeSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private UpdateNoticeHero() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('update-hero', SHEET_OPTION_CARD_RADIUS)
      this.UpdateNoticeHeroContent()
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.accentTintColor()))
    .border({
      width: this.shouldUseCardMaterial() ? this.cardSurfaceBorderWidth() : 0.5,
      color: this.shouldUseCardMaterial() ? this.immersionBorderColor() : this.accentColor()
    })
    .scale({ x: this.appCardScale('update-hero'), y: this.appCardScale('update-hero') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('update-hero', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('update-hero', newValue);
    })
  }

  @Builder
  private UpdateNoticeHeroContent() {
    Row({ space: 14 }) {
      Image($r('app.media.app_icon_black'))
        .width(52)
        .height(52)
        .borderRadius(14)
        .objectFit(ImageFit.Cover)

      Column({ space: 4 }) {
        Text(this.t('账号、备份与品牌体验升级'))
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())

        Text(this.t('V1.4.3：账号退出更安全，备份导入更准确，发行方 Logo 可远程维护。'))
          .fontSize(13)
          .fontColor(this.secondaryTextColor())
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .alignItems(VerticalAlign.Center)
    .zIndex(2)
  }

  @Builder
  private UpdateNoticeItem(index: string, title: string, description: string, path: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('update-item-' + index, SHEET_OPTION_CARD_RADIUS)
      this.UpdateNoticeItemContent(index, title, description, path)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.pageBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('update-item-' + index), y: this.appCardScale('update-item-' + index) })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('update-item-' + index, event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('update-item-' + index, newValue);
    })
  }

  @Builder
  private UpdateNoticeItemContent(index: string, title: string, description: string, path: string) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(index)
          .width(28)
          .height(28)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.accentContrastColor())
          .textAlign(TextAlign.Center)
          .backgroundColor(this.accentColor())
          .borderRadius(14)

        Column({ space: 3 }) {
          Text(this.t(title))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text(this.t(description))
            .fontSize(12)
            .lineHeight(18)
            .fontColor(this.secondaryTextColor())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 3 }) {
        Text(this.t('操作路径'))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())

        Text(this.t(path))
          .fontSize(11)
          .lineHeight(16)
          .fontColor(this.primaryTextColor())
          .maxLines(2)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius(12)
      .backgroundColor(this.sheetControlBackgroundColor())
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .zIndex(2)
  }

  @Builder
  private SteamLoginPickerSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ scroller: this.steamLoginSheetScroller }) {
          ListItem() {
            this.SheetMetaRow(
              this.t('仅显示已通过登录凭据完整性校验的 Steam 令牌'),
              this.steamLoginTokens().length.toString()
            )
          }

          if (this.steamLoginTokens().length === 0) {
            ListItem() {
              this.SteamLoginEmptyState()
            }
          } else {
            ListItem() {
              this.SteamAccountSourceActions()
            }

            ForEach(this.steamLoginTokens(), (token: TokenRecord) => {
              ListItem() {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.gamecontroller'))
                    .fontSize(22)
                    .fontColor([this.accentColor()])
                    .renderingStrategy(SymbolRenderingStrategy.SINGLE)

                  Column({ space: 2 }) {
                    Text(this.tokenDisplayName(token))
                      .fontSize(SHEET_PRIMARY_TEXT_SIZE)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(this.steamLoginAccountText(token))
                      .fontSize(SHEET_SECONDARY_TEXT_SIZE)
                      .fontColor(this.secondaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (parseSteamGuardData(token.steamData || '').fullyEnrolled) {
                    Checkbox({ name: 'steam-login-' + token.id + '-' + this.sheetSelectionRevision.toString() })
                      .select(this.pendingSteamLoginTokenId === token.id)
                      .selectedColor(this.accentColor())
                      .hitTestBehavior(HitTestMode.None)
                  } else {
                    Text(this.t('继续激活'))
                      .fontSize(13)
                      .fontColor(this.accentColor())
                  }
                }
                .width('100%')
                .height(SHEET_ROW_HEIGHT)
                .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.handleSteamLoginTokenSelection(token);
                })
              }
            }, (token: TokenRecord) => token.id + '-steam-login-' + this.sheetSelectionRevision.toString())
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: SHEET_CONTENT_TOP_PADDING, bottom: this.sheetListBottomPadding() })
        .cachedCount(HOME_LIST_CACHE_COUNT, true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        if (this.steamLoginTokens().length === 0) {
          this.SheetFloatingActions({
            secondaryLabel: this.t('登录 Steam 账号'),
            secondaryIsPrimary: true,
            secondaryAction: () => {
              this.openSteamEnrollmentFromPicker();
            },
            primaryLabel: this.t('导入 Steam maFile'),
            primaryEnabled: true,
            primaryLoading: false,
            primaryAction: () => {
              this.importSteamTokenFromLoginSheet();
            }
          })
        } else {
          this.SheetFloatingActions({
            secondaryLabel: this.t('取消'),
            secondaryAction: () => {
              this.showSteamLoginPicker = false;
            },
            primaryLabel: this.t('打开相机扫码'),
            primaryEnabled: this.pendingSteamLoginTokenId.length > 0,
            primaryLoading: this.steamLoading,
            primaryAction: () => {
              this.startSelectedSteamLoginScan();
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('选择 Steam 登录账号') },
        menu: this.sheetCloseMenu(() => {
          this.showSteamLoginPicker = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.steamLoginSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private SteamEnrollmentSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll(this.steamEnrollmentSheetScroller) {
            Column({ space: 16 }) {
              if (this.steamEnrollmentStage === STEAM_ENROLLMENT_RISK) {
                this.SteamEnrollmentRiskContent()
              } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_CREDENTIALS) {
                this.SteamEnrollmentCredentialsContent()
              } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_GUARD) {
                this.SteamEnrollmentGuardContent()
              } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_ACTIVATION) {
                this.SteamEnrollmentActivationContent()
              } else {
                this.SteamEnrollmentRecoveryContent()
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({
              left: SHEET_HORIZONTAL_PADDING,
              right: SHEET_HORIZONTAL_PADDING,
              top: SHEET_CONTENT_TOP_PADDING,
              bottom: this.sheetListBottomPadding()
            })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .clip(false)
        }
        .width('100%')
        .height('100%')
        .clip(false)

        this.SteamEnrollmentFloatingActions()
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.steamEnrollmentTitle() },
        menu: this.sheetCloseMenu(() => {
          this.closeSteamEnrollmentSheet();
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.steamEnrollmentSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private SteamEnrollmentRiskContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-risk', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 10 }) {
        Text(this.t('请优先使用 Steam 官方移动应用'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.t('本应用提供 Steam 相关辅助功能，仅用于帮助用户管理个人验证信息及提升使用体验。本应用与 Valve、Steam 官方不存在隶属、授权或合作关系。'))
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.t('登录过程中，账号认证请求由用户设备直接与 Steam 官方服务进行通信，登录成功后会实时删除账号密码等敏感信息。本应用不会收集、上传或存储用户的 Steam 密码、登录验证码等敏感信息。'))
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.t('生成的验证配置文件默认仅保存在本地设备中。若开启华为云备份功能，将采用加密方式保存相关配置数据到华为云空间，用于设备迁移或恢复使用。请妥善保管备份文件及恢复信息，避免因泄露导致账号安全风险。'))
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.t('请确保仅在本人授权的 Steam 账号上使用本功能，并从可信来源安装应用。因账号、设备或备份信息管理不当造成的风险，请用户自行承担。'))
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.primaryTextColor())
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-risk'), y: this.appCardScale('steam-enrollment-risk') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-risk', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-risk', newValue);
    })

    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-risk-accept', SHEET_OPTION_CARD_RADIUS)
      Row({ space: 10 }) {
        Checkbox({ name: 'steam-risk-accepted' })
          .select(this.steamRiskAccepted)
          .selectedColor(this.accentColor())
          .onChange((value: boolean) => {
            this.steamRiskAccepted = value;
          })

        Text(this.t('我已阅读并理解上述风险，自愿继续'))
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)
          .onClick(() => {
            this.steamRiskAccepted = !this.steamRiskAccepted;
          })
      }
      .width('100%')
      .padding(14)
      .alignItems(VerticalAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-risk-accept'), y: this.appCardScale('steam-enrollment-risk-accept') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-risk-accept', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-risk-accept', newValue);
    })
  }

  @Builder
  private SteamEnrollmentCredentialsContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-credentials', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 14 }) {
        Text(this.t('直连 Steam 官方服务（需要🪜）'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.t('需打开网络代理，登录凭证加密后通过 https 通道直接发送 Steam 官方服务 api.steampowered.com，不会进行任何第三方中转；成功发起登录后账号密码敏感信息会立即删除。'))
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.secondaryTextColor())
          .width('100%')

        TextInput({ text: this.steamEnrollmentAccount, placeholder: this.t('Steam 账号名称') })
          .width('100%')
          .height(50)
          .fontSize(15)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.secondaryTextColor())
          .backgroundColor(this.pageBackgroundColor())
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .maxLength(64)
          .onChange((value: string) => {
            this.steamEnrollmentAccount = value.trim();
            this.steamEnrollmentError = '';
          })

        TextInput({ text: this.steamEnrollmentPassword, placeholder: this.t('Steam 密码') })
          .type(InputType.Password)
          .showPasswordIcon(true)
          .width('100%')
          .height(50)
          .fontSize(15)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.secondaryTextColor())
          .backgroundColor(this.pageBackgroundColor())
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .maxLength(128)
          .onChange((value: string) => {
            this.steamEnrollmentPassword = value;
            this.steamEnrollmentError = '';
          })
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-credentials'), y: this.appCardScale('steam-enrollment-credentials') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-credentials', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-credentials', newValue);
    })
  }

  @Builder
  private SteamEnrollmentGuardContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-guard', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.key_shield'))
          .fontSize(36)
          .fontColor([this.accentColor()])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)

        Text(this.steamEnrollmentGuardTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())

        Text(this.steamEnrollmentGuardDescription())
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        if (this.steamEnrollmentGuardRequiresInput()) {
          TextInput({ text: this.steamEnrollmentCode, placeholder: this.t('输入 Steam 验证码') })
            .width('100%')
            .height(50)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .placeholderColor(this.secondaryTextColor())
            .backgroundColor(this.pageBackgroundColor())
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .maxLength(12)
            .onChange((value: string) => {
              this.steamEnrollmentCode = value.trim();
              this.steamEnrollmentError = '';
            })
        }
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-guard'), y: this.appCardScale('steam-enrollment-guard') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-guard', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-guard', newValue);
    })
  }

  @Builder
  private SteamEnrollmentActivationContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-activation', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 12 }) {
        Text(this.t('maFile 已先保存在本机'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .width('100%')

        Text(this.steamActivationDescription())
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.secondaryTextColor())
          .width('100%')

        TextInput({ text: this.steamEnrollmentCode, placeholder: this.t('输入激活验证码') })
          .width('100%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.secondaryTextColor())
          .backgroundColor(this.pageBackgroundColor())
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .maxLength(12)
          .onChange((value: string) => {
            this.steamEnrollmentCode = value.trim();
            this.steamEnrollmentError = '';
          })

        if (this.steamAuthenticatorDraft && this.steamAuthenticatorDraft.confirmType !== 3) {
          Button(this.t('重新发送短信验证码'))
            .height(34)
            .fontSize(13)
            .fontColor(this.accentContrastColor())
            .backgroundColor(this.accentColor())
            .borderRadius(17)
            .padding({ left: 14, right: 14 })
            .enabled(!this.steamEnrollmentLoading)
            .onClick(() => {
              this.resendSteamEnrollmentCode();
            })
        }

        Text(this.t('在完成前不要删除刚生成的本地令牌；它包含避免账号锁定所需的密钥和恢复码。'))
          .fontSize(12)
          .lineHeight(18)
          .fontColor(ERROR_RED)
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-activation'), y: this.appCardScale('steam-enrollment-activation') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-activation', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-activation', newValue);
    })
  }

  @Builder
  private SteamEnrollmentRecoveryContent() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-recovery', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.checkmark_shield'))
          .fontSize(36)
          .fontColor([this.accentColor()])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)

        Text(this.t('Steam 验证器已添加'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())

        Text(this.t('请立即保存恢复码。恢复码用于验证器丢失时恢复账号，关闭后仍可从导出的 maFile 中备份，但不建议只保留一份。'))
          .fontSize(14)
          .lineHeight(21)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.steamRecoveryCode)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .letterSpacing(2)
          .copyOption(CopyOptions.LocalDevice)

        Row() {
          this.SheetActionButton({
            label: this.t('复制恢复码'),
            isPrimary: false,
            isEnabled: true,
            isLoading: false,
            action: () => {
              this.copySteamRecoveryCode();
            }
          })
        }
        .width('100%')
        .height(SHEET_ACTION_BUTTON_HEIGHT)
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-recovery'), y: this.appCardScale('steam-enrollment-recovery') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-recovery', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-recovery', newValue);
    })

    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-enrollment-recovery-saved', SHEET_OPTION_CARD_RADIUS)
      Row({ space: 10 }) {
        Checkbox({ name: 'steam-recovery-saved' })
          .select(this.steamRecoverySaved)
          .selectedColor(this.accentColor())
          .onChange((value: boolean) => {
            this.steamRecoverySaved = value;
          })

        Text(this.t('我已将恢复码保存到安全位置'))
          .fontSize(14)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)
          .onClick(() => {
            this.steamRecoverySaved = !this.steamRecoverySaved;
          })
      }
      .width('100%')
      .padding(14)
      .alignItems(VerticalAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-enrollment-recovery-saved'), y: this.appCardScale('steam-enrollment-recovery-saved') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-enrollment-recovery-saved', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-enrollment-recovery-saved', newValue);
    })
  }

  @Builder
  private SteamEnrollmentFloatingActions() {
    if (this.steamEnrollmentStage === STEAM_ENROLLMENT_RISK) {
      this.SheetFloatingActions({
        secondaryLabel: this.t('取消'),
        secondaryAction: () => {
          this.closeSteamEnrollmentSheet();
        },
        primaryLabel: this.t('同意并继续'),
        primaryEnabled: this.steamRiskAccepted,
        primaryLoading: false,
        primaryAction: () => {
          this.steamEnrollmentStage = STEAM_ENROLLMENT_CREDENTIALS;
        }
      })
    } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_CREDENTIALS) {
      this.SheetFloatingActions({
        secondaryLabel: this.t('返回风险告知'),
        secondaryAction: () => {
          this.steamEnrollmentStage = STEAM_ENROLLMENT_RISK;
        },
        primaryLabel: this.t('登录 Steam'),
        primaryEnabled: this.steamEnrollmentAccount.length > 0 && this.steamEnrollmentPassword.length > 0,
        primaryLoading: this.steamEnrollmentLoading,
        primaryAction: () => {
          this.beginSteamEnrollmentLogin();
        }
      })
    } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_GUARD) {
      this.SheetFloatingActions({
        secondaryLabel: this.t('重新登录'),
        secondaryAction: () => {
          this.resetSteamEnrollmentLogin();
        },
        primaryLabel: this.steamEnrollmentGuardRequiresInput() ? this.t('验证并继续') : this.t('检查登录状态'),
        primaryEnabled: !this.steamEnrollmentGuardRequiresInput() || this.steamEnrollmentCode.length > 0,
        primaryLoading: this.steamEnrollmentLoading,
        primaryAction: () => {
          this.verifySteamEnrollmentLogin();
        }
      })
    } else if (this.steamEnrollmentStage === STEAM_ENROLLMENT_ACTIVATION) {
      this.SheetFloatingActions({
        secondaryLabel: this.t('稍后处理'),
        secondaryAction: () => {
          this.closeSteamEnrollmentSheet();
        },
        primaryLabel: this.t('完成添加'),
        primaryEnabled: this.steamEnrollmentCode.length > 0,
        primaryLoading: this.steamEnrollmentLoading,
        primaryAction: () => {
          this.finalizeSteamEnrollment();
        }
      })
    } else {
      this.SheetSingleFloatingAction({
        label: this.steamRecoverySaved ? this.t('完成') : this.t('请先确认已保存恢复码'),
        action: () => {
          if (this.steamRecoverySaved) {
            this.closeSteamEnrollmentSheet();
          }
        }
      })
    }
  }

  @Builder
  private SteamDecryptPasswordSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Stack({ alignContent: Alignment.TopStart }) {
          Scroll(this.steamDecryptSheetScroller) {
            Column({ space: 18 }) {
              Column({ space: 8 }) {
                Text(this.t('此 maFile 由 Steam Desktop Authenticator 加密。请输入 SDA 的加密密码，密码只用于本机解密，不会保存。'))
                  .fontSize(14)
                  .lineHeight(21)
                  .fontColor(this.secondaryTextColor())

                TextInput({ text: this.steamDecryptPassword, placeholder: this.t('SDA 加密密码') })
                  .type(InputType.Password)
                  .showPasswordIcon(true)
                  .width('100%')
                  .height(48)
                  .padding({ left: 14, right: 14 })
                  .fontSize(16)
                  .fontColor(this.primaryTextColor())
                  .placeholderColor(this.secondaryTextColor())
                  .backgroundColor(this.sheetControlBackgroundColor())
                  .borderRadius(14)
                  .onChange((value: string) => {
                    this.steamDecryptPassword = value;
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({
              left: SHEET_HORIZONTAL_PADDING,
              right: SHEET_HORIZONTAL_PADDING,
              top: SHEET_CONTENT_TOP_PADDING,
              bottom: this.sheetListBottomPadding()
            })
          }
          .width('100%')
          .height('100%')
          .align(Alignment.Top)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Off)
          .clip(false)
        }
        .width('100%')
        .height('100%')
        .clip(false)

        this.SheetFloatingActions({
          secondaryLabel: this.t('取消'),
          secondaryAction: () => {
            this.closeSteamDecryptSheet();
          },
          primaryLabel: this.t('解密并导入'),
          primaryEnabled: this.steamDecryptPassword.length > 0,
          primaryLoading: this.steamDecrypting,
          primaryAction: () => {
            this.confirmSteamMaFileDecryption();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('解密 Steam maFile') },
        menu: this.sheetCloseMenu(() => {
          this.closeSteamDecryptSheet();
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.steamDecryptSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private SteamLoginEmptyState() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.barcode_viewfinder'))
        .fontSize(34)
        .fontColor([this.accentColor()])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)

      Text(this.t('暂无可用于扫码登录的 Steam 令牌'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .textAlign(TextAlign.Center)

      Text(this.t('可以登录一个尚未启用 Steam 移动验证器的账号并在本机生成 maFile，也可以导入已有的完整 maFile。'))
        .fontSize(13)
        .fontColor(this.secondaryTextColor())
        .lineHeight(19)
        .textAlign(TextAlign.Center)

      this.SteamLoginGuideCard()
    }
    .width('100%')
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING, top: 18, bottom: 18 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SteamLoginGuideCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('steam-empty-guide', SHEET_OPTION_CARD_RADIUS)
      Column({ space: 10 }) {
        this.SteamLoginGuideStep('1', '没有启用移动验证器：点击左下方【登录 Steam 账号】，完成邮箱和手机验证码后自动生成 maFile。')
        this.SteamLoginGuideStep('2', '已有 maFile：点击右下方【导入 Steam maFile】，应用会校验登录与交易确认所需字段。')
        this.SteamLoginGuideStep('3', '已启用 Steam 移动验证器但没有 maFile：本功能不能复制原密钥，请导入原文件，或先在 Steam 官方应用移除旧验证器。')
      }
      .width('100%')
      .padding(14)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.pageBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('steam-empty-guide'), y: this.appCardScale('steam-empty-guide') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-empty-guide', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('steam-empty-guide', newValue);
    })
  }

  @Builder
  private SteamLoginGuideStep(index: string, content: string) {
    Row({ space: 10 }) {
      Text(index)
        .width(24)
        .height(24)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accentContrastColor())
        .textAlign(TextAlign.Center)
        .backgroundColor(this.accentColor())
        .borderRadius(12)

      Text(this.t(content))
        .fontSize(13)
        .fontColor(this.primaryTextColor())
        .lineHeight(19)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private SteamAccountSourceActions() {
    Row({ space: SHEET_ACTION_GAP }) {
      this.SheetActionButton({
        label: this.t('登录 Steam 账号'),
        isPrimary: false,
        isEnabled: true,
        isLoading: false,
        action: () => {
          this.openSteamEnrollmentFromPicker();
        }
      })
      this.SheetActionButton({
        label: this.t('导入 Steam maFile'),
        isPrimary: false,
        isEnabled: true,
        isLoading: false,
        action: () => {
          this.importSteamTokenFromLoginSheet();
        }
      })
    }
    .width('100%')
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING, bottom: 8 })
    .alignItems(VerticalAlign.Center)
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
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_LOGIN_CARD_HEIGHT, ME_CARD_RADIUS)
      }
      this.MeLoginCardContent()
    }
    .width('100%')
    .height(ME_LOGIN_CARD_HEIGHT)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('me-login'), y: this.appCardScale('me-login') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('me-login', event.type);
    })
  }

  @Builder
  private MeLoginCardContent() {
    Row({ space: ME_ACTION_CONTENT_GAP }) {
      this.MeAvatar()

      Column({ space: 4 }) {
        Text(this.isHuaweiLoggedIn ? this.displayHuaweiNickname() : this.t('登录华为账号'))
          .fontSize(ME_TEXT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (!this.isHuaweiLoggedIn) {
          Text(this.huaweiLoginInProgress ? this.t('正在登录') : this.t('点击登录'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.secondaryTextColor())
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.isHuaweiLoggedIn) {
        this.MeLogoutButton()
      }
    }
    .width('100%')
    .height(ME_LOGIN_CARD_HEIGHT)
    .padding({ left: 18, right: 20 })
    .alignItems(VerticalAlign.Center)
    .zIndex(2)
    .onClick(() => {
      if (!this.isHuaweiLoggedIn && !this.huaweiLoginInProgress) {
        this.loginHuaweiAccount();
      }
    })
  }

  @Builder
  private MeLogoutButton() {
    Stack({ alignContent: Alignment.Center }) {
      ImmersionButton({
        systemMaterialEffect: this.configuredMaterialEffect(),
        buttonModify: new ActionButtonModifier(
          ME_LOGOUT_BUTTON_WIDTH,
          ME_LOGOUT_BUTTON_HEIGHT,
          this.primaryActionFillColor(),
          this.accentColor()
        ),
        click: (): void => {
          this.confirmLogoutHuaweiAccount();
        }
      }) {
        Text(this.t(this.huaweiLogoutInProgress ? '退出中' : '退出'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())
      }
    }
    .width(ME_LOGOUT_BUTTON_WIDTH)
    .height(ME_LOGOUT_BUTTON_HEIGHT)
    .borderRadius(ME_LOGOUT_BUTTON_HEIGHT / 2)
    .clip(false)
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
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(items.length * ME_ROW_HEIGHT + items.length - 1, ME_CARD_RADIUS)
      }
      this.MeActionCardContent(items, group)
    }
    .width('100%')
    .height(items.length * ME_ROW_HEIGHT + items.length - 1)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('me-action-' + group.toString()),
      y: this.appCardScale('me-action-' + group.toString()) })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('me-action-' + group.toString(), event.type);
    })
  }

  @Builder
  private MeActionCardContent(items: Array<[string, Resource]>, group: number) {
    Column() {
      ForEach(items, (item: [string, Resource], index: number) => {
        this.MeActionRow(item[0], item[1], () => {
          this.handleMeAction(group, index);
        })
        if (index < items.length - 1) {
          this.MeActionCardDivider()
        }
      }, (item: [string, Resource]) => item[0])
    }
    .width('100%')
    .height(items.length * ME_ROW_HEIGHT + items.length - 1)
    .padding({ left: 20, right: 18 })
    .zIndex(2)
  }

  @Builder
  private MeActionRow(label: string, icon: Resource, action: () => void) {
    Row({ space: 16 }) {
      if (label === '手表端数据同步') {
        Image($r('app.media.ic_watch_sync'))
          .width(ME_ACTION_ICON_SIZE)
          .height(ME_ACTION_ICON_SIZE)
          .objectFit(ImageFit.Contain)
      } else {
        SymbolGlyph(icon)
          .fontSize(ME_ACTION_ICON_SIZE)
          .fontColor([this.primaryTextColor()])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      }

      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      this.TrailingArrowSymbol()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private TrailingArrowSymbol() {
    SymbolGlyph($r('sys.symbol.chevron_right'))
      .fontSize(ME_ACTION_ICON_SIZE)
      .fontColor([this.secondaryTextColor()])
      .fontWeight(FontWeight.Medium)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  private MeActionCardDivider() {
    Divider()
      .strokeWidth(1)
      .color(this.dividerColor())
      .margin({ left: ME_ACTION_ICON_SIZE + ME_ACTION_CONTENT_GAP })
  }

  @Builder
  private MoreAppsPageContent() {
    WaterFlow({ scroller: this.moreAppsScroller }) {
      FlowItem() {
        this.MoreAppsHeroCard()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private MoreAppsHeroCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('more-apps-hero', ME_CARD_RADIUS)
      Column({ space: 18 }) {
          Image($r('app.media.camlink'))
            .width(92)
            .height(92)
            .borderRadius(22)
            .objectFit(ImageFit.Cover)

          Text('CamLink')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text(this.t('相机直连，极速传输'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())

          Text(this.t('Wi-Fi直连单反相机传输照片与视频，适配索尼、尼康、佳能等多种相机。支持扫码连接、相机图片预览、深色模式与防窥保护等功能。'))
            .width('100%')
            .fontSize(16)
            .lineHeight(26)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)

          ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
            text: this.t('在应用市场查看'),
            buttonModify: {
              applyNormalAttribute(instance: ButtonModifier): void {
                instance.width(220).height(46)
              }
            },
            click: (): void => {
              this.openExternalUrl(CAMLINK_URL);
            }
          })
            .width(220)
            .height(46)
        }
        .width('100%')
        .constraintSize({ maxWidth: 560 })
        .padding({ left: 28, right: 28, top: 36, bottom: 36 })
        .alignItems(HorizontalAlign.Center)
        .zIndex(2)
    }
    .width('100%')
    .constraintSize({ maxWidth: 560 })
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('more-apps-hero'), y: this.appCardScale('more-apps-hero') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('more-apps-hero', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('more-apps-hero', newValue);
    })
  }

  @Builder
  private DonationPageContent() {
    WaterFlow({ scroller: this.donationScroller }) {
      FlowItem() {
        this.DonationHeroCard()
      }
      .width('100%')
      FlowItem() {
        this.DonationQrCard()
      }
      .width('100%')
      FlowItem() {
        this.DonationBenefitsCard()
      }
      .width('100%')
      FlowItem() {
        this.DonationSupportersCard()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private DonationHeroCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('donation-hero', ME_CARD_RADIUS)
      Column({ space: 10 }) {
          Text('☕')
            .fontSize(56)

          Text(this.t('赞助开发者'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())

          Text(this.t('您的支持是作者持续迭代的底气'))
            .fontSize(14)
            .fontColor(this.secondaryTextColor())

          Text(this.t('全部功能始终免费，赞助完全自愿，不解锁任何隐藏内容！'))
            .fontSize(16)
            .lineHeight(24)
            .fontColor(this.accentColor())
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 26, bottom: 26 })
        .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('donation-hero'), y: this.appCardScale('donation-hero') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('donation-hero', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('donation-hero', newValue);
    })
  }

  @Builder
  private DonationQrCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(this.donationQrCardHeight(), ME_CARD_RADIUS)
      }
      Column({ space: 16 }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.qrcode'))
              .fontSize(24)
              .fontColor([this.accentColor()])

            Column({ space: 3 }) {
              Text(this.t('微信打赏'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.primaryTextColor())
              Text(this.t('扫码或长按识别'))
                .fontSize(13)
                .fontColor(this.secondaryTextColor())
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Image($rawfile('wechat_donation_qr.png'))
            .width('100%')
            .constraintSize({ maxWidth: DONATION_QR_IMAGE_MAX_WIDTH })
            .aspectRatio(1397 / 1653)
            .objectFit(ImageFit.Contain)
            .borderRadius(16)

          Stack({ alignContent: Alignment.Center }) {
            ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
              buttonModify: new ActionButtonModifier(
                220, 44, this.primaryActionFillColor(), this.accentColor()),
              click: (): void => {
                this.saveRawImageToGallery('wechat_donation_qr.png', 'OpenAuthenticator_Donation');
              }
            }) {
              Text(this.t('保存到相册'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.accentColor())
            }
          }
          .width(220)
          .height(44)
        }
        .width('100%')
        .height(this.donationQrCardHeight())
        .padding({ left: 24, right: 24, top: 24, bottom: 24 })
        .alignItems(HorizontalAlign.Center)
        .zIndex(2)
    }
    .width('100%')
    .height(this.donationQrCardHeight())
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('donation-qr'), y: this.appCardScale('donation-qr') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('donation-qr', event.type);
    })
  }

  @Builder
  private DonationBenefitsCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('donation-benefits', ME_CARD_RADIUS)
      Column({ space: 12 }) {
          Text(this.t('赞助者福利'))
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Text(this.t('打赏时请在备注里写下QQ号，需求与BUG优先响应，并提供可行范围内的使用指导。'))
            .width('100%')
            .fontSize(14)
            .lineHeight(23)
            .fontColor(this.secondaryTextColor())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24, bottom: 24 })
        .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('donation-benefits'), y: this.appCardScale('donation-benefits') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('donation-benefits', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('donation-benefits', newValue);
    })
  }

  @Builder
  private DonationSupportersCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('donation-supporters', ME_CARD_RADIUS)
      Column({ space: 18 }) {
        Column({ space: 4 }) {
          Text(this.t('特别感谢'))
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
            .textAlign(TextAlign.Center)

          Text(this.t('感谢两位朋友对开源验证器的支持，每一份鼓励都让项目走得更远。'))
            .width('100%')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
        }

        Row({ space: 16 }) {
          this.DonationSupporterItem($rawfile('donor_zl.jpg'), 'Z*L')
          this.DonationSupporterItem($rawfile('donor_hua.jpg'), '*华')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 24 })
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('donation-supporters'), y: this.appCardScale('donation-supporters') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('donation-supporters', event.type);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('donation-supporters', newValue);
    })
  }

  @Builder
  private DonationSupporterItem(avatar: Resource, nickname: string) {
    Column({ space: 8 }) {
      Image(avatar)
        .width(DONATION_SUPPORTER_AVATAR_SIZE)
        .height(DONATION_SUPPORTER_AVATAR_SIZE)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .border({ width: 1, color: this.immersionBorderColor() })

      Text(nickname)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.t('感谢支持'))
        .fontSize(12)
        .fontColor(this.accentColor())
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private AboutPageContent() {
    WaterFlow({ scroller: this.aboutScroller }) {
      FlowItem() {
        this.AboutHeroCard()
      }
      .width('100%')
      FlowItem() {
        this.AboutActionsCard()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
    .bindSheet($$this.showUpdateLogSheet, this.UpdateLogSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
      backgroundColor: this.sheetSurfaceBackgroundColor(),
      blurStyle: this.sheetSurfaceBlurStyle(),
      radius: LengthMetrics.vp(28),
      onDisappear: () => {
        this.expandedUpdateLogVersion = '1.4.3';
      }
    })
  }

  @Builder
  private AboutHeroCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('about-hero', ME_CARD_RADIUS)
      Column({ space: 12 }) {
          Image($r('app.media.app_icon_black'))
            .width(82)
            .height(82)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)

          Text(this.t('开源验证器'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Text('OpenAuthenticator')
            .fontSize(20)
            .fontColor(this.primaryTextColor())

          Text(this.t('开源免费，本地存储'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())
            .margin({ top: 6 })

          Text(this.t('鸿蒙原生2FA/MFA令牌管理，兼容 OpenAI、Steam、Google Authenticator 等令牌。支持多端、华为云空间、服务卡片、深色模式、防窥保护与智感握姿等功能。'))
            .width('100%')
            .fontSize(15)
            .lineHeight(25)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)

          this.AboutCommentButton()
        }
        .width('100%')
        .padding({ left: 28, right: 28, top: 26, bottom: 26 })
        .alignItems(HorizontalAlign.Center)
        .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('about-hero', newValue);
    })
  }

  @Builder
  private AboutCommentButton() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(44, 22)
      }
      Button({ type: ButtonType.Capsule }) {
        Text(this.t('给一个好评'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accentColor())
      }
      .width(220)
      .height(44)
      .padding(0)
      .backgroundColor(this.shouldUseCardMaterial() ? Color.Transparent : this.primaryActionFillColor())
      .border({ width: 0.5, color: this.accentColor() })
      .stateEffect(true)
      .hitTestBehavior(HitTestMode.Block)
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
        .pointLight({
          sourceType: hdsEffect.PointLightSourceType.SOFT,
          illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER,
          options: {
            color: this.accentColor(),
            intensity: 0.1,
            height: 6,
            bloom: 0.08
          }
        })
        .buildEffect())
      .onClick(() => {
        this.showAppCommentDialog();
      })
      .zIndex(2)
    }
    .width(220)
    .height(44)
    .borderRadius(22)
    .clip(true)
  }

  @Builder
  private AboutActionsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 5 + 4, ME_CARD_RADIUS)
      }
      Column() {
          this.AboutActionRow('加入QQ群', QQ_GROUP_NUMBER, () => {
            this.showQQGroupSheet = true;
          })
          this.MeCardDivider()
          this.AboutActionRow('开源三方库使用清单', '', () => {
            this.homePathStack.pushPath({ name: 'thirdParty' }, true);
          })
          this.MeCardDivider()
          this.AboutActionRow('备案号', '京ICP备2026040690号-1A', () => {
            this.openExternalUrl(STEAM_BEIAN_URL);
          })
          this.MeCardDivider()
          this.AboutActionRow('更新日志', '', () => {
            this.expandedUpdateLogVersion = '1.4.3';
            this.showUpdateLogSheet = true;
          })
          this.MeCardDivider()
          this.AboutActionRow('应用版本', this.appVersion, () => {
          })
        }
        .width('100%')
        .height(ME_ROW_HEIGHT * 5 + 4)
        .padding({ left: 20, right: 18 })
        .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 5 + 4)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('about-actions'), y: this.appCardScale('about-actions') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('about-actions', event.type);
    })
  }

  @Builder
  private AboutActionRow(label: string, value: string, action: () => void) {
    Row({ space: 12 }) {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)
      Text(value)
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontColor(this.primaryTextColor())
      this.TrailingArrowSymbol()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private UpdateLogSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll(this.updateLogSheetScroller) {
          Column({ space: PAGE_CARD_GAP }) {
            this.UpdateLogCurrentVersionCard()
            ForEach(UPDATE_LOGS, (entry: UpdateLogEntry) => {
              this.UpdateLogVersionCard(entry)
            }, (entry: UpdateLogEntry) => entry.version)
          }
          .width('100%')
          .constraintSize({ maxWidth: 620 })
          .padding({
            left: SHEET_HORIZONTAL_PADDING,
            right: SHEET_HORIZONTAL_PADDING,
            top: SHEET_CONTENT_TOP_PADDING,
            bottom: this.sheetListBottomPadding()
          })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('更新日志') },
        menu: this.sheetCloseMenu(() => {
          this.showUpdateLogSheet = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.updateLogSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private UpdateLogCurrentVersionCard() {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('update-log-current', ME_CARD_RADIUS)
      Row({ space: 14 }) {
        Image($r('app.media.app_icon_black'))
          .width(58)
          .height(58)
          .borderRadius(15)
          .objectFit(ImageFit.Cover)

        Column({ space: 5 }) {
          Text(this.t('当前版本'))
            .fontSize(13)
            .fontColor(this.secondaryTextColor())

          Text(this.appVersion + ' (' + this.appVersionCode + ')')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .alignItems(VerticalAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.accentTintColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
  }

  @Builder
  private UpdateLogVersionCard(entry: UpdateLogEntry) {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('update-log-' + entry.version, ME_CARD_RADIUS)
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text(entry.version + '  ' + entry.date)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.primaryTextColor())
              .maxLines(1)

            Text(this.t(entry.summary))
              .fontSize(13)
              .fontColor(this.secondaryTextColor())
              .maxLines(2)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          this.UpdateLogDisclosure(this.expandedUpdateLogVersion === entry.version)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.expandedUpdateLogVersion === entry.version) {
          Divider()
            .strokeWidth(0.5)
            .color(this.dividerColor())

          Column({ space: 8 }) {
            ForEach(entry.items, (item: string, index: number) => {
              Row({ space: 9 }) {
                Text('•')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.accentColor())

                Text(this.t(item))
                  .fontSize(14)
                  .lineHeight(21)
                  .fontColor(this.secondaryTextColor())
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (item: string, index: number) => entry.version + '-' + index.toString())
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .zIndex(2)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .onClick(() => {
      this.expandedUpdateLogVersion =
        this.expandedUpdateLogVersion === entry.version ? '' : entry.version;
    })
  }

  @Builder
  private UpdateLogDisclosure(expanded: boolean) {
    SymbolGlyph($r('sys.symbol.chevron_right'))
      .fontSize(ME_ACTION_ICON_SIZE)
      .fontColor([this.secondaryTextColor()])
      .fontWeight(FontWeight.Medium)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      .rotate({ angle: expanded ? 90 : 0 })
      .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
  }

  @Builder
  private ThirdPartyPageContent() {
    WaterFlow({
      scroller: this.thirdPartyScroller,
      sections: this.thirdPartyWaterFlowSections
    }) {
      FlowItem() {
        Text(this.t('感谢以下开源项目与三方库作者的贡献'))
          .width('100%')
          .fontSize(15)
          .fontColor(this.secondaryTextColor())
          .padding({ left: 4, right: 4, bottom: 4 })
      }
      .width('100%')
      FlowItem() {
        this.ThirdPartyLibraryCard('@tangs/components', 'Apache-2.0',
          this.t('提供 ImmersionButton 与 ImmersionSearch 沉浸光感组件'), TANGS_COMPONENTS_URL)
      }
      .width('100%')
      FlowItem() {
        this.ThirdPartyLibraryCard('kdada/Authenticator', 'MIT',
          this.t('Steam Authenticator 功能实现参考'), STEAM_REFERENCE_URL)
      }
      .width('100%')
      FlowItem() {
        this.ThirdPartyLibraryCard('Jessecar96/SteamDesktopAuthenticator', 'MIT',
          this.t('Steam Desktop Authenticator（SDA）功能实现参考'), SDA_REFERENCE_URL)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private ThirdPartyLibraryCard(name: string, license: string, description: string, link: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.MeasuredImmersionCardSurface('third-party-' + name, ME_CARD_RADIUS)
      this.ThirdPartyLibraryCardContent(name, license, description)
    }
    .width('100%')
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('third-party-' + name), y: this.appCardScale('third-party-' + name) })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('third-party-' + name, event.type);
    })
    .onClick(() => {
      this.openExternalUrl(link);
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.updateMeasuredCardHeight('third-party-' + name, newValue);
    })
  }

  @Builder
  private ThirdPartyLibraryCardContent(name: string, license: string, description: string) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text(description)
          .fontSize(13)
          .fontColor(this.secondaryTextColor())
        Text('License: ' + license)
          .fontSize(12)
          .fontColor(this.secondaryTextColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      this.TrailingArrowSymbol()
    }
    .width('100%')
    .padding({ left: 20, right: 18, top: 18, bottom: 18 })
    .zIndex(2)
  }

  @Builder
  private QQGroupSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 14 }) {
          Image($rawfile('qq_group_qr.png'))
            .width('100%')
            .constraintSize({ maxWidth: 320, maxHeight: 420 })
            .layoutWeight(1)
            .objectFit(ImageFit.Contain)
            .borderRadius(18)

          Text(this.t('扫描二维码加入QQ群'))
            .fontSize(14)
            .fontColor(this.secondaryTextColor())
        }
        .width('100%')
        .height('100%')
        .padding({
          left: 24,
          right: 24,
          top: 12,
          bottom: this.sheetListBottomPadding()
        })
        .alignItems(HorizontalAlign.Center)

        this.SheetFloatingActions({
          secondaryLabel: this.t('复制群号'),
          secondaryAction: () => {
            this.copyQQGroupNumber();
          },
          primaryLabel: this.isSavingQQGroupQRCode ? this.t('保存中') : this.t('保存到相册'),
          primaryEnabled: !this.isSavingQQGroupQRCode,
          primaryLoading: this.isSavingQQGroupQRCode,
          primaryAction: () => {
            this.saveQQGroupQRCode();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('加入QQ群') },
        menu: this.sheetCloseMenu(() => {
          this.showQQGroupSheet = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private AppearanceSettingsPageContent() {
    WaterFlow({ scroller: this.appearanceSettingsScroller }) {
      FlowItem() {
        Column() {
          this.SettingsSectionTitle(this.t('令牌外观'))
          this.SettingsAppearanceTokenCard()
        }
        .width('100%')
      }
      .width('100%')
      FlowItem() {
        Column() {
          this.SettingsSectionTitle(this.t('高级材质'))
          this.SettingsAppearanceMaterialCard()
        }
        .width('100%')
      }
      .width('100%')
      FlowItem() {
        Column() {
          this.SettingsSectionTitle(this.t('颜色与背景'))
          this.SettingsAppearanceBackgroundCard()
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private FeatureSecurityPageContent() {
    WaterFlow({ scroller: this.featureSecurityScroller }) {
      FlowItem() {
        this.SettingsSecuritySection()
      }
      .width('100%')
      FlowItem() {
        this.SettingsWidgetSection()
      }
      .width('100%')
      FlowItem() {
        this.SettingsSteamAccessSection()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
  }

  @Builder
  private SettingsPageContent() {
    WaterFlow({ scroller: this.settingsScroller }) {
      FlowItem() {
        this.SettingsSecuritySection()
      }
      .width('100%')
      FlowItem() {
        this.SettingsAppearanceSection()
      }
      .width('100%')
      FlowItem() {
        this.SettingsWidgetSection()
      }
      .width('100%')
      FlowItem() {
        this.SettingsSteamAccessSection()
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .columnsTemplate(this.responsivePageColumnsTemplate())
    .columnsGap(PAGE_CARD_GAP)
    .rowsGap(PAGE_CARD_GAP)
    .padding({
      left: HOME_HORIZONTAL_PADDING,
      right: HOME_HORIZONTAL_PADDING,
      bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
    })
    .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .clip(false)
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
    Column({ space: PAGE_CARD_GAP }) {
      Column() {
        this.SettingsSectionTitle(this.t('令牌外观'))
        this.SettingsAppearanceTokenCard()
      }
      .width('100%')

      Column() {
        this.SettingsSectionTitle(this.t('高级材质'))
        this.SettingsAppearanceMaterialCard()
      }
      .width('100%')

      Column() {
        this.SettingsSectionTitle(this.t('颜色与背景'))
        this.SettingsAppearanceBackgroundCard()
      }
      .width('100%')
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
  private SettingsSteamAccessSection() {
    Column() {
      this.SettingsSectionTitle(this.t('Steam 增强访问'))
      this.SettingsSteamAccessCard()
    }
    .width('100%')
  }

  @Builder
  private SettingsSteamAccessCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(this.steamAccessCardHeight(), ME_CARD_RADIUS)
      }
      this.SettingsSteamAccessCardContent()
    }
    .width('100%')
    .height(this.steamAccessCardHeight())
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({
      x: this.appCardScale('steam-access'),
      y: this.appCardScale('steam-access')
    })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('steam-access', event.type);
    })
  }

  @Builder
  private SettingsSteamAccessCardContent() {
      Column() {
        this.SettingsSwitchRow(SettingsSwitchKey.SteamEnhancedAccess, '启用 Steam 增强访问')

        if (this.steamEnhancedAccess) {
          this.MeCardDivider()
          TextInput({ text: this.steamGatewayUrl, placeholder: this.t('兼容网关地址（HTTPS）') })
            .width('100%')
            .height(ME_ROW_HEIGHT)
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontColor(this.primaryTextColor())
            .placeholderColor(this.secondaryTextColor())
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.steamGatewayUrl = value.trim();
              this.saveSettings();
            })

          this.MeCardDivider()
          TextInput({ text: this.steamGatewayToken, placeholder: this.t('网关访问令牌（可选）') })
            .width('100%')
            .height(ME_ROW_HEIGHT)
            .type(InputType.Password)
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontColor(this.primaryTextColor())
            .placeholderColor(this.secondaryTextColor())
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.steamGatewayToken = value;
              this.saveSettings();
            })

          Text(this.t('仅在无法直接访问 Steam 服务时启用。网关需兼容原 Steam API 请求路径。'))
            .width('100%')
            .fontSize(12)
            .fontColor(this.secondaryTextColor())
            .lineHeight(18)
            .padding({ top: 8, bottom: 14 })
        }
      }
      .width('100%')
      .height(this.steamAccessCardHeight())
      .padding({ left: 20, right: 18 })
      .zIndex(2)
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
      WaterFlow({ scroller: this.cloudSpaceScroller }) {
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步设置'))
            this.CloudAutoSyncCard()
          }
          .width('100%')
        }
        .width('100%')
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步操作'))
            this.CloudActionsCard()
          }
          .width('100%')
        }
        .width('100%')
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步记录'))
            this.CloudRecordsCard()
          }
          .width('100%')
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .columnsTemplate(this.responsivePageColumnsTemplate())
      .columnsGap(PAGE_CARD_GAP)
      .rowsGap(PAGE_CARD_GAP)
      .padding({
        left: HOME_HORIZONTAL_PADDING,
        right: HOME_HORIZONTAL_PADDING,
        bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
      })
      .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private CloudAutoSyncCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT, ME_CARD_RADIUS)
      }
      Column() {
        this.SettingsSwitchRow(SettingsSwitchKey.CloudBackup, '云空间自动同步')
      }
      .width('100%')
      .height(ME_ROW_HEIGHT)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('cloud-auto-sync'), y: this.appCardScale('cloud-auto-sync') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('cloud-auto-sync', event.type);
    })
  }

  @Builder
  private CloudActionsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 3 + 2, ME_CARD_RADIUS)
      }
      Column() {
        this.CloudSpaceActionRow('手动推送', true, () => {
          this.pushTokensToCloud();
        })
        this.MeCardDivider()
        this.CloudSpaceActionRow('手动获取', true, () => {
          this.pullTokensFromCloud();
        })
        this.MeCardDivider()
        this.CloudSpaceActionRow('云空间管理', false, () => {
          this.openCloudSpaceSettings();
        })
      }
      .width('100%')
      .height(ME_ROW_HEIGHT * 3 + 2)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('cloud-actions'), y: this.appCardScale('cloud-actions') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('cloud-actions', event.type);
    })
  }

  @Builder
  private CloudRecordsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(this.shouldShowCloudDisabledHint() ?
          CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 58 :
          CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 2, ME_CARD_RADIUS)
      }
      Column() {
        Row() {
          Text(this.t('通用令牌同步'))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width(126)

          if (this.tokenCloudSyncing) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(this.accentColor())
              .margin({ right: 6 })
          }

          Text(this.t(this.cloudSyncStatus))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontColor(this.secondaryTextColor())
            .layoutWeight(1)
            .lineHeight(21)
            .maxLines(3)
            .textAlign(TextAlign.End)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(CLOUD_STATUS_ROW_HEIGHT)
        .alignItems(VerticalAlign.Center)

        this.MeCardDivider()

        Row() {
          Text(this.t('Steam 完整数据'))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .width(126)

          if (this.steamCloudSyncing) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(this.accentColor())
              .margin({ right: 6 })
          }

          Text(this.t(this.steamCloudSyncStatus))
            .fontSize(ME_ACTION_TEXT_SIZE)
            .fontColor(this.secondaryTextColor())
            .layoutWeight(1)
            .lineHeight(21)
            .maxLines(3)
            .textAlign(TextAlign.End)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(CLOUD_STATUS_ROW_HEIGHT)
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
          Text(this.t('请点击「云空间管理」或前往「设置-云空间」，找到开源验证器应用，并开启云同步！'))
            .fontSize(12)
            .fontColor(this.secondaryTextColor())
            .lineHeight(18)
            .width('100%')
            .padding({ top: 8, bottom: 10 })
        }
      }
      .width('100%')
      .height(this.shouldShowCloudDisabledHint() ? CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 58 :
        CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 2)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(this.shouldShowCloudDisabledHint() ? CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 58 :
      CLOUD_STATUS_ROW_HEIGHT * 2 + ME_ROW_HEIGHT + 2)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('cloud-records'), y: this.appCardScale('cloud-records') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('cloud-records', event.type);
    })
  }

  @Builder
  private WatchSyncPageContent() {
    Stack() {
      WaterFlow({ scroller: this.watchSyncScroller }) {
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步设置'))
            this.WatchTokenSelectionCard()
          }
          .width('100%')
        }
        .width('100%')
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步操作'))
            this.WatchActionsCard()
          }
          .width('100%')
        }
        .width('100%')
        FlowItem() {
          Column() {
            this.SettingsSectionTitle(this.t('同步记录'))
            this.WatchRecordsCard()
          }
          .width('100%')
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .columnsTemplate(this.responsivePageColumnsTemplate())
      .columnsGap(PAGE_CARD_GAP)
      .rowsGap(PAGE_CARD_GAP)
      .padding({
        left: HOME_HORIZONTAL_PADDING,
        right: HOME_HORIZONTAL_PADDING,
        bottom: this.naviIndicatorHeight + PAGE_CARD_GAP
      })
      .contentStartOffset(this.statusBarHeight + HOME_TITLE_HEIGHT + PAGE_CARD_GAP)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showWatchTokenPicker, this.WatchTokenPickerSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: this.sheetSurfaceBackgroundColor(),
      blurStyle: this.sheetSurfaceBlurStyle(),
      radius: LengthMetrics.vp(28),
      onDisappear: () => {
        this.pendingWatchTokenIds = [];
      }
    })
  }

  @Builder
  private WatchTokenSelectionCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 2 + 1, ME_CARD_RADIUS)
      }
      Column() {
        this.CloudSpaceActionRow('选择同步到手表端的令牌', false, () => {
          this.openWatchTokenPicker();
        })
        this.MeCardDivider()
        Row() {
          Text(this.watchTokenSelectionSummary())
            .fontSize(13)
            .fontColor(this.secondaryTextColor())
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .height(ME_ROW_HEIGHT)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(ME_ROW_HEIGHT * 2 + 1)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 2 + 1)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-token-selection'), y: this.appCardScale('watch-token-selection') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-token-selection', event.type);
    })
  }

  @Builder
  private WatchActionsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 2 + 1, ME_CARD_RADIUS)
      }
      Column() {
        this.WatchSyncActionRow('Wear Engine推送', () => {
          this.pushTokensToWear();
        })
        this.MeCardDivider()
        this.WatchSyncActionRow('扫码同步到手表', () => {
          this.pushTokensToWatchOverLan();
        })
      }
      .width('100%')
      .height(ME_ROW_HEIGHT * 2 + 1)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 2 + 1)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-actions'), y: this.appCardScale('watch-actions') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-actions', event.type);
    })
  }

  @Builder
  private WatchRecordsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 2 + 1, ME_CARD_RADIUS)
      }
      Column() {
        this.WatchSyncInfoRow('推送状态', this.watchPushing ? this.t('推送中') : this.t(this.watchPushStatus))
        this.MeCardDivider()
        this.WatchSyncInfoRow('最后推送时间', this.watchLastPushTimeText())
      }
      .width('100%')
      .height(ME_ROW_HEIGHT * 2 + 1)
      .padding({ left: 20, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 2 + 1)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('watch-records'), y: this.appCardScale('watch-records') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('watch-records', event.type);
    })
  }

  @Builder
  private WatchSyncActionRow(label: string, action: () => void) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      if (this.watchPushing) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.accentColor())
      } else {
        this.TrailingArrowSymbol()
      }
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .opacity(this.watchPushing ? 0.6 : 1)
    .onClick(() => {
      if (!this.watchPushing) {
        action();
      }
    })
  }

  @Builder
  private WatchSyncInfoRow(label: string, value: string) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      if (label === '推送状态' && this.watchPushing) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color(this.accentColor())
          .margin({ right: 6 })
      }

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
  private WatchTokenPickerSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ scroller: this.watchTokenPickerSheetScroller }) {
          ListItem() {
            this.SheetMetaRow(
              this.t('手表端按勾选顺序显示令牌'),
              this.pendingWatchTokenIds.length.toString() + '/' + this.tokens.length.toString()
            )
          }

          if (this.tokens.length === 0) {
            ListItem() {
              Text(this.t('暂无令牌，请先添加令牌'))
                .fontSize(14)
                .fontColor(this.secondaryTextColor())
                .width('100%')
                .height(SHEET_EMPTY_STATE_HEIGHT)
                .textAlign(TextAlign.Center)
            }
          } else {
            ForEach(this.tokens, (token: TokenRecord) => {
              ListItem() {
                Row({ space: 12 }) {
                  Stack() {
                    if (this.pendingWatchTokenIndex(token.id) >= 0) {
                      Circle()
                        .width(24)
                        .height(24)
                        .fill(this.accentColor())

                      Text((this.pendingWatchTokenIndex(token.id) + 1).toString())
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.accentContrastColor())
                    }
                  }
                  .width(24)
                  .height(24)

                  Column({ space: 2 }) {
                    Text(this.tokenDisplayName(token))
                      .fontSize(SHEET_PRIMARY_TEXT_SIZE)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(this.normalizeTokenType(token.type))
                      .fontSize(SHEET_SECONDARY_TEXT_SIZE)
                      .fontColor(this.secondaryTextColor())
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Checkbox({ name: 'watch-' + token.id + '-' + this.sheetSelectionRevision.toString() })
                    .select(this.pendingWatchTokenIndex(token.id) >= 0)
                    .selectedColor(this.accentColor())
                    .hitTestBehavior(HitTestMode.None)
                }
                .width('100%')
                .height(SHEET_ROW_HEIGHT)
                .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.togglePendingWatchToken(token.id);
                })
              }
            }, (token: TokenRecord) => token.id + '-watch-' + this.sheetSelectionRevision.toString())
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: SHEET_CONTENT_TOP_PADDING, bottom: this.sheetListBottomPadding() })
        .cachedCount(HOME_LIST_CACHE_COUNT, true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        this.SheetFloatingActions({
          secondaryLabel: this.t('取消'),
          secondaryAction: () => {
            this.showWatchTokenPicker = false;
          },
          primaryLabel: this.t('完成'),
          primaryEnabled: this.pendingWatchTokenIds.length > 0,
          primaryLoading: false,
          primaryAction: () => {
            this.commitWatchTokenSelection();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('选择同步到手表端的令牌') },
        menu: this.sheetCloseMenu(() => {
          this.showWatchTokenPicker = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.watchTokenPickerSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private ExportTokenPickerSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ scroller: this.exportTokenPickerSheetScroller }) {
          ListItem() {
            this.SheetMetaActionRow(
              this.tf('已选 {0} 个令牌', [this.exportSelectedIds.length.toString()]),
              this.exportSelectedIds.length === this.tokens.length ? this.t('取消全选') : this.t('全选'),
              () => {
                this.exportSelectedIds = this.exportSelectedIds.length === this.tokens.length ? [] :
                  this.tokens.map((token: TokenRecord) => token.id);
                this.bumpSheetSelectionRevision();
              }
            )
          }

          if (this.tokens.length === 0) {
            ListItem() {
              Text(this.t('暂无令牌，请先添加令牌'))
                .fontSize(14)
                .fontColor(this.secondaryTextColor())
                .width('100%')
                .height(SHEET_EMPTY_STATE_HEIGHT)
                .textAlign(TextAlign.Center)
            }
          } else {
            ForEach(this.tokens, (token: TokenRecord) => {
              ListItem() {
                Row({ space: 12 }) {
                  Column({ space: 2 }) {
                    Text(this.tokenDisplayName(token))
                      .fontSize(SHEET_PRIMARY_TEXT_SIZE)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.normalizeTokenType(token.type))
                      .fontSize(SHEET_SECONDARY_TEXT_SIZE)
                      .fontColor(this.secondaryTextColor())
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Checkbox({ name: 'export-' + token.id + '-' + this.sheetSelectionRevision.toString() })
                    .select(this.exportSelectedIds.includes(token.id))
                    .selectedColor(this.accentColor())
                    .hitTestBehavior(HitTestMode.None)
                }
                .width('100%')
                .height(SHEET_ROW_HEIGHT)
                .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.toggleExportToken(token.id);
                })
              }
            }, (token: TokenRecord) => token.id + '-export-' + this.sheetSelectionRevision.toString())
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: SHEET_CONTENT_TOP_PADDING, bottom: this.sheetListBottomPadding() })
        .cachedCount(HOME_LIST_CACHE_COUNT, true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        this.SheetFloatingActions({
          secondaryLabel: this.t('取消'),
          secondaryAction: () => {
            this.showExportPicker = false;
          },
          primaryLabel: this.t('下一步'),
          primaryEnabled: this.exportSelectedIds.length > 0,
          primaryLoading: false,
          primaryAction: () => {
            this.showExportPicker = false;
            setTimeout(() => {
              this.showExportFormatMenu();
            }, 180);
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('选择要导出的令牌') },
        menu: this.sheetCloseMenu(() => {
          this.showExportPicker = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.exportTokenPickerSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private ExportFormatSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll(this.exportFormatSheetScroller) {
          Column({ space: 16 }) {
            Text(this.t('请选择密钥备份的导出方式'))
              .width('100%')
              .fontSize(13)
              .fontColor(this.secondaryTextColor())
              .padding({ left: 2, right: 2 })

            this.ExportFormatOptionsCard()
          }
          .width('100%')
          .padding({
            left: SHEET_HORIZONTAL_PADDING,
            right: SHEET_HORIZONTAL_PADDING,
            top: SHEET_CONTENT_TOP_PADDING,
            bottom: this.sheetListBottomPadding()
          })
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        this.SheetSingleFloatingAction({
          label: this.t('取消'),
          action: () => {
            this.showExportFormat = false;
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('选择导出格式') },
        menu: this.sheetCloseMenu(() => {
          this.showExportFormat = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.exportFormatSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height(this.exportFormatSheetHeight())
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private ExportFormatOptionsCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(this.exportFormatOptionsHeight(), SHEET_OPTION_CARD_RADIUS)
      }
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

        if (this.exportSelectedSteamTokens().length > 0) {
          this.MeCardDivider()

          this.ExportFormatOption(
            this.t('Steam maFile 文件'),
            this.t('为选中的 Steam 令牌分别导出完整 maFile'),
            () => {
              this.showExportFormat = false;
              setTimeout(() => {
                this.exportSteamMaFiles();
              }, 180);
            }
          )
        }
      }
      .width('100%')
      .height(this.exportFormatOptionsHeight())
      .padding({ left: 18, right: 18 })
      .zIndex(2)
    }
    .width('100%')
    .height(this.exportFormatOptionsHeight())
    .borderRadius(SHEET_OPTION_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.sheetControlBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('export-format-options'), y: this.appCardScale('export-format-options') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('export-format-options', event.type);
    })
  }

  @Builder
  private ExportFormatOption(title: string, description: string, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(SHEET_PRIMARY_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())

        Text(description)
          .fontSize(SHEET_SECONDARY_TEXT_SIZE)
          .fontColor(this.secondaryTextColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.TrailingArrowSymbol()
    }
    .width('100%')
    .height(SHEET_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  private ExportQRCodeSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll(this.exportQRCodeSheetScroller) {
          Column() {
            if (this.exportQRIndex < this.exportSelectedTokens().length) {
              Text(this.tokenDisplayName(this.exportSelectedTokens()[this.exportQRIndex]))
                .fontSize(SHEET_PRIMARY_TEXT_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.primaryTextColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 8, bottom: 14 })

              Row({ space: 10 }) {
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.chevron_left'))
                    .fontSize(ME_ACTION_ICON_SIZE)
                    .fontColor([this.primaryTextColor()])
                    .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                }
                .width(40)
                .height(40)
                .backgroundColor(this.sheetControlBackgroundColor())
                .enabled(this.exportQRIndex > 0 && !this.isSavingQRCode)
                .opacity(this.exportQRIndex > 0 ? 1 : 0.35)
                .stateEffect(true)
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
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(ME_ACTION_ICON_SIZE)
                    .fontColor([this.primaryTextColor()])
                    .renderingStrategy(SymbolRenderingStrategy.SINGLE)
                }
                .width(40)
                .height(40)
                .backgroundColor(this.sheetControlBackgroundColor())
                .enabled(this.exportQRIndex < this.exportSelectedTokens().length - 1 && !this.isSavingQRCode)
                .opacity(this.exportQRIndex < this.exportSelectedTokens().length - 1 ? 1 : 0.35)
                .stateEffect(true)
                .onClick(() => {
                  if (this.exportQRIndex < this.exportSelectedTokens().length - 1) {
                    this.exportQRIndex++;
                  }
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)

              Text((this.exportQRIndex + 1).toString() + '/' + this.exportSelectedTokens().length.toString())
                .fontSize(SHEET_SECONDARY_TEXT_SIZE)
                .fontColor(this.secondaryTextColor())
                .margin({ top: 10, bottom: 14 })
            } else {
              Text(this.t('没有可导出的令牌'))
                .fontSize(14)
                .fontColor(this.secondaryTextColor())
                .height(SHEET_EMPTY_STATE_HEIGHT)
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({
            left: 24,
            right: 24,
            top: SHEET_CONTENT_TOP_PADDING,
            bottom: this.sheetListBottomPadding()
          })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        if (this.exportQRIndex < this.exportSelectedTokens().length) {
          this.SheetFloatingActions({
            secondaryLabel: this.isSavingQRCode ? this.t('保存中') : this.t('保存当前图片'),
            secondaryAction: () => {
              if (!this.isSavingQRCode) {
                this.saveCurrentQRCode();
              }
            },
            secondaryIsPrimary: true,
            primaryLabel: this.isSavingQRCode ? this.t('保存中') : this.t('保存所有图片'),
            primaryEnabled: !this.isSavingQRCode,
            primaryLoading: this.isSavingQRCode,
            primaryAction: () => {
              if (!this.isSavingQRCode) {
                this.saveAllQRCodes();
              }
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('二维码图片') },
        menu: this.sheetCloseMenu(() => {
          this.showExportQR = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.exportQRCodeSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height(this.exportQRCodeSheetHeight())
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private UserAgreementSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll(this.userAgreementSheetScroller) {
          Column() {
          this.AgreementTitle('开源验证器（OpenAuthenticator）用户协议')
          this.AgreementDate('更新日期：2026年6月19日')
          this.AgreementDate('生效日期：2026年6月19日')
          this.AgreementNotice('请您在使用开源验证器（OpenAuthenticator）前仔细阅读本协议，尤其是以加粗方式提示的条款。使用本应用即表示您理解并同意本协议。')

          this.AgreementHeading('1. 关于我们')
          this.AgreementParagraph('开源验证器（OpenAuthenticator，以下简称“本应用”）由开源验证器开发者（以下简称“我们”）提供和运营。本协议是您与我们之间关于下载、安装和使用本应用及相关服务所订立的协议。', false)

          this.AgreementHeading('2. 服务内容')
          this.AgreementParagraph('本应用用于管理基于时间或计数器的一次性验证码，包括 TOTP、HOTP 和 Steam 令牌。您可以手工录入、扫描二维码或从文件导入令牌信息，并可选择使用华为云空间同步功能。', false)
          this.AgreementParagraph('一次性验证码由您提供的密钥在设备本地计算。云空间同步属于可选功能，只有在您主动开启并满足华为账号及云空间服务条件后才会使用。', false)

          this.AgreementHeading('3. 使用要求')
          this.AgreementParagraph('您应具备与使用本应用相适应的民事行为能力。未成年人或限制民事行为能力人应在监护人阅读并同意本协议后使用。', false)
          this.AgreementParagraph('您应确保录入或导入的令牌密钥来源合法，并有权管理相关账号。不得利用本应用从事任何违法违规、侵犯他人权益或危害网络安全的活动。', true)

          this.AgreementHeading('4. 密钥与设备安全')
          this.AgreementParagraph('令牌密钥属于高度敏感信息。请妥善保管设备、锁屏凭据、备份数据及华为账号，避免截屏、转发或向他人披露密钥和迁移二维码。', true)
          this.AgreementParagraph('因设备遗失、越权访问、误删除、第三方账号异常、您主动共享密钥或未妥善保管备份而产生的风险和损失，由您自行承担。建议您同时保留服务提供方发放的恢复码或其他独立恢复方式。', false)

          this.AgreementHeading('5. 华为账号与云空间')
          this.AgreementParagraph('登录华为账号、云空间同步及标准化隐私声明等能力由相应的系统服务提供，并受华为账号、云空间及相关服务条款约束。网络、账号状态、云空间容量、系统配置或服务维护可能影响同步结果。', false)
          this.AgreementParagraph('在执行覆盖本地数据的云端获取操作前，请确认云端数据符合预期。您应自行核对同步状态和令牌可用性。', true)

          this.AgreementHeading('6. 服务变更与中止')
          this.AgreementParagraph('我们可能基于安全、兼容性、法律法规或产品维护需要更新本应用。我们会尽力维护服务稳定，但不保证所有设备、系统版本、第三方二维码格式或第三方账号服务始终兼容。', false)

          this.AgreementHeading('7. 免责声明')
          this.AgreementParagraph('本应用按现状提供。在法律允许的范围内，因网络故障、系统限制、第三方服务异常、不可抗力、用户操作错误或超出我们合理控制范围的原因导致服务中断、同步失败或数据损失，我们不承担超出法律规定范围的责任。', true)
          this.AgreementParagraph('本应用生成的验证码是否被第三方服务接受，取决于密钥、时间、算法、位数、刷新周期及第三方服务配置。请以相关第三方服务的实际验证结果为准。', false)

          this.AgreementHeading('8. 知识产权')
          this.AgreementParagraph('本应用的软件、界面和相关内容的知识产权归其权利人所有。未经授权，您不得对本应用进行违法复制、传播、出租、出售或用于侵犯他人权利的活动。开源组件按照各自许可证使用。', false)

          this.AgreementHeading('9. 隐私保护')
          this.AgreementParagraph('我们重视您的个人信息和令牌数据安全。关于信息处理范围、权限用途及您的权利，请查阅应用内“隐私声明”。本协议与隐私声明共同构成您使用本应用的依据。', false)

          this.AgreementHeading('10. 协议更新')
          this.AgreementParagraph('我们可能根据功能变化或法律法规要求更新本协议，并通过应用页面或发布渠道提供新版本。若您不同意更新后的协议，应停止使用本应用；继续使用即表示您接受更新内容。', false)

          this.AgreementHeading('11. 法律适用与争议解决')
          this.AgreementParagraph('本协议的订立、执行和解释适用中华人民共和国法律。发生争议时，双方应先友好协商；协商不成的，可依法向有管辖权的人民法院提起诉讼。', false)

          this.AgreementHeading('12. 联系我们')
          this.AgreementParagraph(this.tf('如对本协议或本应用有疑问，可发送邮件至 {0}。', [USER_AGREEMENT_EMAIL]), false)
          this.AgreementFooter('开源验证器开发者')
        }
        .width('100%')
        .padding({
          left: SHEET_HORIZONTAL_PADDING,
          right: SHEET_HORIZONTAL_PADDING,
          top: SHEET_CONTENT_TOP_PADDING,
          bottom: this.naviIndicatorHeight + 24
        })
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('用户协议') },
        menu: this.sheetCloseMenu(() => {
          this.showUserAgreementSheet = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.userAgreementSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private AgreementTitle(text: string) {
    Text(this.t(text))
      .width('100%')
      .fontSize(22)
      .lineHeight(30)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.primaryTextColor())
      .margin({ bottom: 4 })
  }

  @Builder
  private AgreementDate(text: string) {
    Text(this.t(text))
      .width('100%')
      .fontSize(13)
      .lineHeight(20)
      .fontColor(this.secondaryTextColor())
  }

  @Builder
  private AgreementNotice(text: string) {
    Text(this.t(text))
      .width('100%')
      .fontSize(14)
      .lineHeight(22)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.primaryTextColor())
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .margin({ top: 18, bottom: 4 })
      .borderRadius(12)
      .backgroundColor(this.sheetControlBackgroundColor())
      .border({ width: 1, color: this.accentColor() })
  }

  @Builder
  private AgreementHeading(text: string) {
    Text(this.t(text))
      .width('100%')
      .fontSize(17)
      .lineHeight(24)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.primaryTextColor())
      .margin({ top: 22, bottom: 4 })
  }

  @Builder
  private AgreementParagraph(text: string, emphasized: boolean) {
    Text(this.t(text))
      .width('100%')
      .fontSize(14)
      .lineHeight(24)
      .fontWeight(emphasized ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.primaryTextColor())
      .margin({ top: 6 })
  }

  @Builder
  private AgreementFooter(text: string) {
    Column({ space: 14 }) {
      Divider()
        .color(this.dividerColor())
      Text(this.t(text))
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(this.secondaryTextColor())
    }
    .width('100%')
    .margin({ top: 26 })
  }

  @Builder
  private WebPageSheet() {
    HdsNavigation() {
      Web({
        src: 'about:blank',
        controller: this.webSheetController,
        renderMode: RenderMode.SYNC_RENDER
      })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .backgroundColor(this.cardBackgroundColor())
        .onAppear(() => {
          this.loadWebSheetUrl();
        })
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t(this.webSheetTitle) },
        menu: this.sheetCloseMenu(() => {
          this.showWebSheet = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  private toggleExportToken(tokenId: string): void {
    if (this.exportSelectedIds.includes(tokenId)) {
      this.exportSelectedIds = this.exportSelectedIds.filter((id: string) => id !== tokenId);
    } else {
      this.exportSelectedIds = [...this.exportSelectedIds, tokenId];
    }
    this.bumpSheetSelectionRevision();
  }

  private bumpSheetSelectionRevision(): void {
    this.sheetSelectionRevision = this.sheetSelectionRevision + 1;
  }

  @Builder
  private CloudSpaceActionRow(label: string, requiresHuaweiLogin: boolean, action: () => void) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(requiresHuaweiLogin && !this.isHuaweiLoggedIn ? this.secondaryTextColor() :
          this.primaryTextColor())
        .layoutWeight(1)

      if (this.cloudSyncing && (label === '手动推送' || label === '手动获取')) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.accentColor())
      } else {
        this.TrailingArrowSymbol()
      }
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .opacity((this.cloudSyncing && (label === '手动推送' || label === '手动获取')) ||
      (requiresHuaweiLogin && !this.isHuaweiLoggedIn) ? 0.45 : 1)
    .onClick(() => {
      if (requiresHuaweiLogin && !this.isHuaweiLoggedIn) {
        this.showToast('请先登录华为账号');
        return;
      }
      if (this.cloudSyncing) {
        return;
      }
      action();
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
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 4 + 3, ME_CARD_RADIUS)
      }
      this.SettingsSecurityCardContent()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 4 + 3)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('settings-security'), y: this.appCardScale('settings-security') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('settings-security', event.type);
    })
  }

  @Builder
  private SettingsSecurityCardContent() {
    Column() {
      this.SettingsSwitchRow(SettingsSwitchKey.SmartGrip, '智感握姿')
      this.MeCardDivider()
      this.SettingsSwitchRow(SettingsSwitchKey.AntiPeep, '防窥保护')
      this.MeCardDivider()
      this.SettingsSwitchRow(SettingsSwitchKey.AppLock, '应用锁定')
      this.MeCardDivider()
      this.SettingsSelectRow(SettingsSelectKey.Language, '语言', LANGUAGE_OPTIONS, false)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 4 + 3)
    .padding({ left: 20, right: 18 })
    .zIndex(2)
  }

  @Builder
  private SettingsSwitchRow(key: SettingsSwitchKey, label: string) {
    Row() {
      Text(this.t(label))
        .fontSize(ME_ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.settingsSwitchValue(key) })
        .selectedColor(this.accentColor())
        .switchPointColor(this.cardBackgroundColor())
        .onChange((checked: boolean) => {
          if (checked !== this.settingsSwitchValue(key)) {
            this.updateSettingsSwitchValue(key, checked);
          }
        })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  private settingsSwitchValue(key: SettingsSwitchKey): boolean {
    if (key === SettingsSwitchKey.SteamEnhancedAccess) {
      return this.steamEnhancedAccess;
    }
    if (key === SettingsSwitchKey.CloudBackup) {
      return this.cloudBackupEnabled;
    }
    if (key === SettingsSwitchKey.SmartGrip) {
      return this.smartGripEnabled;
    }
    if (key === SettingsSwitchKey.AntiPeep) {
      return this.antiPeepEnabled;
    }
    if (key === SettingsSwitchKey.AppLock) {
      return this.appLockEnabled;
    }
    if (key === SettingsSwitchKey.ShowNextToken) {
      return this.showNextToken;
    }
    if (key === SettingsSwitchKey.GlobalImmersion) {
      return this.globalImmersionEnabled;
    }
    return this.globalBackgroundEnabled;
  }

  private updateSettingsSwitchValue(key: SettingsSwitchKey, checked: boolean): void {
    if (key === SettingsSwitchKey.SteamEnhancedAccess) {
      this.steamEnhancedAccess = checked;
      this.saveSettings();
      return;
    }
    if (key === SettingsSwitchKey.CloudBackup) {
      this.toggleCloudBackup(checked);
      return;
    }
    if (key === SettingsSwitchKey.SmartGrip) {
      this.toggleSmartGrip(checked);
      return;
    }
    if (key === SettingsSwitchKey.AntiPeep) {
      this.toggleAntiPeep(checked);
      return;
    }
    if (key === SettingsSwitchKey.AppLock) {
      this.toggleAppLock(checked);
      return;
    }
    if (key === SettingsSwitchKey.ShowNextToken) {
      this.showNextToken = checked;
      this.saveSettings();
      return;
    }
    if (key === SettingsSwitchKey.GlobalImmersion) {
      this.globalImmersionEnabled = checked;
      this.saveSettings();
      return;
    }
    this.globalBackgroundEnabled = checked;
    this.saveSettings();
  }

  @Builder
  private SettingsAppearanceTokenCard() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 2 + 1, ME_CARD_RADIUS)
      }
      this.SettingsAppearanceTokenCardContent()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 2 + 1)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('appearance-token'), y: this.appCardScale('appearance-token') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('appearance-token', event.type);
    })
  }

  @Builder
  private SettingsAppearanceTokenCardContent() {
    Column() {
      this.SettingsSwitchRow(SettingsSwitchKey.ShowNextToken, '显示下一组令牌')
      this.MeCardDivider()
      this.SettingsSelectRow(
        SettingsSelectKey.IssuerLogoColor,
        '发行方图标显示颜色',
        ISSUER_LOGO_COLOR_OPTIONS,
        false
      )
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 2 + 1)
    .padding({ left: 20, right: 18 })
    .zIndex(2)
  }

  @Builder
  private SettingsAppearanceMaterialCard() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 3 + 2, ME_CARD_RADIUS)
      }
      this.SettingsAppearanceMaterialCardContent()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('appearance-material'), y: this.appCardScale('appearance-material') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('appearance-material', event.type);
    })
  }

  @Builder
  private SettingsAppearanceMaterialCardContent() {
    Column() {
      this.SettingsSwitchRow(SettingsSwitchKey.GlobalImmersion, '全局沉浸光感')
      this.MeCardDivider()
      this.SettingsSelectRow(SettingsSelectKey.MaterialType, '材质类型', MATERIAL_TYPE_OPTIONS, false)
      this.MeCardDivider()
      this.SettingsSelectRow(SettingsSelectKey.MaterialLevel, '材质等级', MATERIAL_LEVEL_OPTIONS, false)
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .padding({ left: 20, right: 18 })
    .zIndex(2)
  }

  @Builder
  private SettingsAppearanceBackgroundCard() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(
          ME_ROW_HEIGHT * 3 + BACKGROUND_PICKER_ROW_HEIGHT + BACKGROUND_BLUR_ROW_HEIGHT +
            BACKGROUND_BRIGHTNESS_ROW_HEIGHT + 5,
          ME_CARD_RADIUS
        )
      }
      this.SettingsAppearanceBackgroundCardContent()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + BACKGROUND_PICKER_ROW_HEIGHT + BACKGROUND_BLUR_ROW_HEIGHT +
      BACKGROUND_BRIGHTNESS_ROW_HEIGHT + 5)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('appearance-background'), y: this.appCardScale('appearance-background') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('appearance-background', event.type);
    })
  }

  @Builder
  private SettingsAppearanceBackgroundCardContent() {
    Column() {
      this.SettingsSelectRow(SettingsSelectKey.ThemeMode, '颜色模式', THEME_MODE_OPTIONS, false)
      this.MeCardDivider()
      this.SettingsSelectRow(SettingsSelectKey.ThemeColor, '主题色', THEME_COLOR_OPTIONS, true)
      this.MeCardDivider()
      this.SettingsBackgroundPickerRow()
      this.MeCardDivider()
      this.SettingsBackgroundBlurRow()
      this.MeCardDivider()
      this.SettingsBackgroundBrightnessRow()
      this.MeCardDivider()
      this.SettingsSwitchRow(SettingsSwitchKey.GlobalBackground, '背景图是否全局显示')
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + BACKGROUND_PICKER_ROW_HEIGHT + BACKGROUND_BLUR_ROW_HEIGHT +
      BACKGROUND_BRIGHTNESS_ROW_HEIGHT + 5)
    .padding({ left: 20, right: 18 })
    .zIndex(2)
  }

  @Builder
  private SettingsBackgroundPickerRow() {
    Column({ space: 10 }) {
      Row() {
        Text(this.t('背景图选择'))
          .fontSize(ME_ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Button(this.t('从图库选择'))
          .height(34)
          .fontSize(13)
          .fontColor(this.accentContrastColor())
          .backgroundColor(this.accentColor())
          .borderRadius(17)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.pickCustomBackground();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Row({ space: 6 }) {
          this.BackgroundOffThumbnail()
          if (this.customBackgroundUri.length > 0) {
            this.CustomBackgroundThumbnail()
          }
          this.PresetBackgroundThumbnail('preset_1', $r('app.media.background_preset_1'))
          this.PresetBackgroundThumbnail('preset_2', $r('app.media.background_preset_2'))
          this.PresetBackgroundThumbnail('preset_3', $r('app.media.background_preset_3'))
          this.PresetBackgroundThumbnail('preset_4', $r('app.media.background_preset_4'))
          this.PresetBackgroundThumbnail('preset_5', $r('app.media.background_preset_5'))
          this.PresetBackgroundThumbnail('preset_6', $r('app.media.background_preset_6'))
          this.PresetBackgroundThumbnail('preset_7', $r('app.media.background_preset_7'))
        }
        .height(BACKGROUND_THUMBNAIL_HEIGHT)
      }
      .width('100%')
      .height(BACKGROUND_THUMBNAIL_HEIGHT)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height(BACKGROUND_PICKER_ROW_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private BackgroundOffThumbnail() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.t('关闭'))
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.secondaryTextColor())
    }
    .width(BACKGROUND_THUMBNAIL_WIDTH)
    .height(BACKGROUND_THUMBNAIL_HEIGHT)
    .backgroundColor(this.pageBackgroundColor())
    .borderRadius(8)
    .border({
      width: this.backgroundSelection === 'none' ? 3 : 0.5,
      color: this.backgroundSelection === 'none' ? this.accentColor() : this.dividerColor()
    })
    .onClick(() => {
      this.backgroundSelection = 'none';
      this.saveSettings();
    })
  }

  @Builder
  private PresetBackgroundThumbnail(id: string, source: Resource) {
    Image(source)
      .width(BACKGROUND_THUMBNAIL_WIDTH)
      .height(BACKGROUND_THUMBNAIL_HEIGHT)
      .objectFit(ImageFit.Cover)
      .borderRadius(8)
      .border({
        width: this.backgroundSelection === id ? 3 : 0.5,
        color: this.backgroundSelection === id ? this.accentColor() : this.dividerColor()
      })
      .onClick(() => {
        this.backgroundSelection = id;
        this.saveSettings();
      })
  }

  @Builder
  private CustomBackgroundThumbnail() {
    ForEach([this.customBackgroundRenderVersion], (version: number) => {
      Image(this.customBackgroundUri)
        .width(BACKGROUND_THUMBNAIL_WIDTH)
        .height(BACKGROUND_THUMBNAIL_HEIGHT)
        .syncLoad(true)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .border({
          width: this.backgroundSelection === 'custom' ? 3 : 0.5,
          color: this.backgroundSelection === 'custom' ? this.accentColor() : this.dividerColor()
        })
        .onClick(() => {
          this.activateCustomBackground();
        })
    }, (version: number) => version.toString())
  }

  @Builder
  private SettingsBackgroundBlurRow() {
    Column({ space: 6 }) {
      Row() {
        Text(this.t('背景图模糊程度'))
          .fontSize(ME_ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text(Math.round(this.backgroundBlurPercent).toString() + '%')
          .fontSize(HOME_SEARCH_TEXT_SIZE)
          .fontColor(this.secondaryTextColor())
      }
      .width('100%')

      Slider({ value: this.backgroundBlurPercent, min: 0, max: 100, step: 1 })
        .width('100%')
        .selectedColor(this.accentColor())
        .trackColor(this.dividerColor())
        .blockColor(this.accentColor())
        .enabled(this.backgroundSelection !== 'none')
        .opacity(this.backgroundSelection === 'none' ? 0.4 : 1)
        .onChange((value: number) => {
          this.backgroundBlurPercent = this.clamp(value, 0, 100);
          this.saveSettings();
        })
    }
    .width('100%')
    .height(BACKGROUND_BLUR_ROW_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SettingsBackgroundBrightnessRow() {
    Column({ space: 6 }) {
      Row() {
        Text(this.t('背景图明亮程度'))
          .fontSize(ME_ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .layoutWeight(1)

        Text(Math.round(this.backgroundBrightnessPercent).toString() + '%')
          .fontSize(HOME_SEARCH_TEXT_SIZE)
          .fontColor(this.secondaryTextColor())
      }
      .width('100%')

      Slider({ value: this.backgroundBrightnessPercent, min: 0, max: 100, step: 1 })
        .width('100%')
        .selectedColor(this.accentColor())
        .trackColor(this.dividerColor())
        .blockColor(this.accentColor())
        .enabled(this.backgroundSelection !== 'none')
        .opacity(this.backgroundSelection === 'none' ? 0.4 : 1)
        .onChange((value: number) => {
          this.backgroundBrightnessPercent = this.clamp(value, 0, 100);
          this.saveSettings();
        })
    }
    .width('100%')
    .height(BACKGROUND_BRIGHTNESS_ROW_HEIGHT)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SettingsSelectRow(
    key: SettingsSelectKey,
    label: string,
    values: SelectOption[],
    showColorDot: boolean
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
        .selected(this.optionIndex(values, this.settingsSelectValue(key)))
        .value(this.t(this.settingsSelectValue(key)))
        .font({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .fontColor(this.secondaryTextColor())
        .selectedOptionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .selectedOptionFontColor(this.accentContrastColor())
        .selectedOptionBgColor(this.accentColor())
        .optionFont({ size: ME_ACTION_TEXT_SIZE, weight: FontWeight.Regular })
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onSelect((index: number, value: string) => {
          const nextValue = index >= 0 && index < values.length ? `${values[index].value}` : value;
          if (nextValue !== this.settingsSelectValue(key)) {
            this.updateSettingsSelectValue(key, nextValue);
          }
        })
    }
    .width('100%')
    .height(ME_ROW_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  private settingsSelectValue(key: SettingsSelectKey): string {
    if (key === SettingsSelectKey.Language) {
      return this.languageInput;
    }
    if (key === SettingsSelectKey.IssuerLogoColor) {
      return this.issuerLogoColorMode;
    }
    if (key === SettingsSelectKey.MaterialType) {
      return this.materialTypeInput;
    }
    if (key === SettingsSelectKey.MaterialLevel) {
      return this.materialLevelInput;
    }
    if (key === SettingsSelectKey.ThemeMode) {
      return this.themeModeInput;
    }
    return this.themeColorInput;
  }

  private updateSettingsSelectValue(key: SettingsSelectKey, value: string): void {
    if (key === SettingsSelectKey.Language) {
      this.languageInput = normalizeSelectedLanguage(value);
      this.refreshSystemLanguage();
      this.saveSettings();
      return;
    }
    if (key === SettingsSelectKey.IssuerLogoColor) {
      this.issuerLogoColorMode = value;
      this.refreshTokenLogoDisplay();
      this.saveSettings();
      return;
    }
    if (key === SettingsSelectKey.MaterialType) {
      this.materialTypeInput = value;
      this.saveSettings();
      return;
    }
    if (key === SettingsSelectKey.MaterialLevel) {
      this.materialLevelInput = value;
      this.saveSettings();
      return;
    }
    if (key === SettingsSelectKey.ThemeMode) {
      this.themeModeInput = value;
      this.saveSettings().then((): void => {
        this.applyColorMode();
      });
      return;
    }
    this.themeColorInput = value;
    this.saveSettings();
  }

  @Builder
  private MeCardDivider() {
    Divider()
      .strokeWidth(1)
      .color(this.dividerColor())
  }

  @Builder
  private SettingsCardWidgetCard() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(ME_ROW_HEIGHT * 3 + 2, ME_CARD_RADIUS)
      }
      this.SettingsCardWidgetCardContent()
    }
    .width('100%')
    .height(ME_ROW_HEIGHT * 3 + 2)
    .borderRadius(ME_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('settings-widget'), y: this.appCardScale('settings-widget') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('settings-widget', event.type);
    })
    .bindSheet($$this.showCardTokenPicker, this.CardTokenPickerSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: this.sheetSurfaceBackgroundColor(),
      blurStyle: this.sheetSurfaceBlurStyle(),
      radius: LengthMetrics.vp(28),
      onDisappear: () => {
        this.pendingCardTokenIds = [];
      }
    })
  }

  @Builder
  private SettingsCardWidgetCardContent() {
    Column() {
      this.CloudSpaceActionRow('选择卡片显示的令牌', false, () => {
        this.openCardTokenPicker();
      })
      this.MeCardDivider()
      this.CloudSpaceActionRow('选择服务卡片', false, () => {
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
    .zIndex(2)
  }

  @Builder
  private CardTokenPickerSheet() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        List({ scroller: this.cardTokenPickerSheetScroller }) {
          ListItem() {
            this.SheetMetaRow(
              this.t('卡片按勾选顺序显示令牌'),
              this.pendingCardTokenIds.length.toString() + '/' + CARD_TOKEN_LIMIT.toString()
            )
          }

          if (this.tokens.length === 0) {
            ListItem() {
              Text(this.t('暂无令牌，请先添加令牌'))
                .fontSize(14)
                .fontColor(this.secondaryTextColor())
                .width('100%')
                .height(SHEET_EMPTY_STATE_HEIGHT)
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

                      Text((this.pendingCardTokenIndex(token.id) + 1).toString())
                        .fontSize(12)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.accentContrastColor())
                    }
                  }
                  .width(24)
                  .height(24)

                  Column({ space: 2 }) {
                    Text(this.tokenDisplayName(token))
                      .fontSize(SHEET_PRIMARY_TEXT_SIZE)
                      .fontColor(this.primaryTextColor())
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(this.normalizeTokenType(token.type))
                      .fontSize(SHEET_SECONDARY_TEXT_SIZE)
                      .fontColor(this.secondaryTextColor())
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Checkbox({ name: 'card-' + token.id + '-' + this.sheetSelectionRevision.toString() })
                    .select(this.pendingCardTokenIndex(token.id) >= 0)
                    .selectedColor(this.accentColor())
                    .hitTestBehavior(HitTestMode.None)
                }
                .width('100%')
                .height(SHEET_ROW_HEIGHT)
                .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.togglePendingCardToken(token.id);
                })
              }
            }, (token: TokenRecord) => token.id + '-card-' + this.sheetSelectionRevision.toString())
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: SHEET_CONTENT_TOP_PADDING, bottom: this.sheetListBottomPadding() })
        .cachedCount(HOME_LIST_CACHE_COUNT, true)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
        .clip(false)

        this.SheetFloatingActions({
          secondaryLabel: this.t('取消'),
          secondaryAction: () => {
            this.showCardTokenPicker = false;
          },
          primaryLabel: this.t('完成'),
          primaryEnabled: this.pendingCardTokenIds.length > 0,
          primaryLoading: false,
          primaryAction: () => {
            this.commitCardTokenSelection();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('选择卡片显示的令牌') },
        menu: this.sheetCloseMenu(() => {
          this.showCardTokenPicker = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.cardTokenPickerSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height('100%')
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
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
    ImmersionSearch({
      systemMaterialEffect: this.configuredMaterialEffect(),
      _height: HOME_SEARCH_HEIGHT,
      options: { placeholder: this.t('搜索令牌') },
      modifier: new HomeSearchModifier(
        this.primaryTextColor(),
        this.primaryTextColor(),
        (value: string): void => {
          this.searchText = value;
        }
      )
    })
    .height(HOME_SEARCH_HEIGHT)
    .width('100%')
    .clip(false)
  }

  private homeSearchMenu(): HdsNavigationMenuContentOptions {
    if (this.isWatchLayout() || this.selectedHomeTab !== HomeTab.Token) {
      return { value: [], maxCount: 0 };
    }

    return {
      value: [
        {
          content: {
            icon: $r('sys.symbol.barcode_viewfinder'),
            label: this.t('Steam 扫码登录'),
            action: () => {
              this.openSteamLoginPicker();
            }
          }
        },
        {
          content: {
            icon: this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ?
            $r('sys.symbol.list_bullet') : $r('sys.symbol.square_grid_2x2'),
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

  private responsivePageColumnCount(): number {
    const availableWidth = Math.max(1, this.pageWidth - HOME_HORIZONTAL_PADDING * 2);
    const columnCount = Math.max(1,
      Math.floor((availableWidth + PAGE_CARD_GAP) / (RESPONSIVE_CARD_MIN_WIDTH + PAGE_CARD_GAP)));
    return Math.min(6, columnCount);
  }

  private responsivePageColumnsTemplate(): string {
    const columnCount = this.responsivePageColumnCount();
    if (columnCount >= 6) {
      return '1fr 1fr 1fr 1fr 1fr 1fr';
    }
    if (columnCount === 5) {
      return '1fr 1fr 1fr 1fr 1fr';
    }
    if (columnCount === 4) {
      return '1fr 1fr 1fr 1fr';
    }
    if (columnCount === 3) {
      return '1fr 1fr 1fr';
    }
    if (columnCount === 2) {
      return '1fr 1fr';
    }
    return '1fr';
  }

  private responsivePageColumnWidth(): number {
    const availableWidth = Math.max(1, this.pageWidth - HOME_HORIZONTAL_PADDING * 2);
    const columnCount = this.responsivePageColumnCount();
    return Math.max(1, (availableWidth - PAGE_CARD_GAP * (columnCount - 1)) / columnCount);
  }

  private donationQrCardHeight(): number {
    const imageWidth = Math.min(DONATION_QR_IMAGE_MAX_WIDTH,
      Math.max(1, this.responsivePageColumnWidth() - 48));
    return DONATION_QR_CARD_FIXED_HEIGHT + imageWidth * DONATION_QR_IMAGE_RATIO;
  }

  private steamAccessCardHeight(): number {
    return this.steamEnhancedAccess ? ME_ROW_HEIGHT * 3 + 2 + STEAM_ACCESS_HINT_HEIGHT : ME_ROW_HEIGHT;
  }

  private refreshResponsiveWaterFlowSections(): void {
    const sectionBottomMargin: Margin = { bottom: PAGE_CARD_GAP };
    const meHeader: SectionOptions = {
      itemsCount: 1,
      crossCount: 1,
      margin: sectionBottomMargin
    };
    const meCards: SectionOptions = {
      itemsCount: 4,
      crossCount: this.responsivePageColumnCount(),
      columnsGap: PAGE_CARD_GAP,
      rowsGap: PAGE_CARD_GAP
    };
    if (this.meWaterFlowSections.length() === 0) {
      this.meWaterFlowSections.push(meHeader);
      this.meWaterFlowSections.push(meCards);
    } else {
      this.meWaterFlowSections.update(0, meHeader);
      this.meWaterFlowSections.update(1, meCards);
    }

    const thirdPartyHeader: SectionOptions = {
      itemsCount: 1,
      crossCount: 1,
      margin: sectionBottomMargin
    };
    const thirdPartyCards: SectionOptions = {
      itemsCount: 3,
      crossCount: this.responsivePageColumnCount(),
      columnsGap: PAGE_CARD_GAP,
      rowsGap: PAGE_CARD_GAP
    };
    if (this.thirdPartyWaterFlowSections.length() === 0) {
      this.thirdPartyWaterFlowSections.push(thirdPartyHeader);
      this.thirdPartyWaterFlowSections.push(thirdPartyCards);
    } else {
      this.thirdPartyWaterFlowSections.update(0, thirdPartyHeader);
      this.thirdPartyWaterFlowSections.update(1, thirdPartyCards);
    }

  }

  private emptyTokenStateHeight(): number {
    const topSpace = this.statusBarHeight + HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP + HOME_SEARCH_HEADER_HEIGHT +
    PAGE_CARD_GAP;
    const bottomSpace = this.naviIndicatorHeight + HOME_NAV_HEIGHT + PAGE_CARD_GAP;
    return Math.max(260, this.pageHeight - topSpace - bottomSpace);
  }

  private toggleTokenLayoutMode(): void {
    this.getUIContext().animateTo({
      duration: TOKEN_LAYOUT_TRANSITION_DURATION,
      curve: Curve.Smooth
    }, () => {
      this.tokenLayoutMode = this.tokenLayoutMode === TOKEN_LAYOUT_DOUBLE ? TOKEN_LAYOUT_SINGLE : TOKEN_LAYOUT_DOUBLE;
      this.resetTokenSwipe();
    });
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
      ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
        buttonModify: new ActionButtonModifier(
          ADD_BUTTON_SIZE, ADD_BUTTON_SIZE, this.primaryActionFillColor(), this.accentColor()),
        click: (): void => {
          if (!this.addButtonDragging) {
            this.isAddMenuOpen = true;
          }
        }
      }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(ADD_BUTTON_ICON_SIZE)
            .fontColor([this.accentColor()])
        }
        .width(ADD_BUTTON_SIZE)
        .height(ADD_BUTTON_SIZE)
      }
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
    .bindSheet($$this.isAddMenuOpen, this.AddMethodSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: false,
      maskColor: this.isDarkTheme() ? '#99000000' : '#66F2F3F5',
      backgroundColor: this.sheetSurfaceBackgroundColor(),
      blurStyle: this.sheetSurfaceBlurStyle(),
      radius: LengthMetrics.vp(28)
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
    HdsNavigation() {
      Scroll(this.addMethodSheetScroller) {
        Column() {
          Row({ space: 12 }) {
            this.AddMethodButton('录入', $r('sys.symbol.square_and_pencil'), () => {
              this.isAddMenuOpen = false;
              this.openAddPage();
            })

            this.AddMethodButton('扫码', $r('sys.symbol.barcode_viewfinder'), () => {
              this.isAddMenuOpen = false;
              this.scanTokenFromQrCode();
            })

            this.AddMethodButton('导入', $r('sys.symbol.square_and_arrow_down'), () => {
              this.isAddMenuOpen = false;
              this.importTokenFile();
            })

            this.AddMethodButton('登录 Steam 账号', $r('app.media.ic_steam'), () => {
              this.isAddMenuOpen = false;
              setTimeout(() => {
                this.resetSteamEnrollment();
                this.showSteamEnrollmentSheet = true;
              }, 180);
            }, true)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .padding({
            top: 18,
            bottom: 18
          })
        }
        .width('100%')
        .padding({
          left: SHEET_HORIZONTAL_PADDING,
          right: SHEET_HORIZONTAL_PADDING,
          top: SHEET_CONTENT_TOP_PADDING,
          bottom: this.naviIndicatorHeight + 18
        })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
      .clip(false)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      content: {
        title: { mainTitle: this.t('新增令牌') },
        menu: this.sheetCloseMenu(() => {
          this.isAddMenuOpen = false;
        })
      },
      style: this.sheetTitleBarStyle(),
      enableComponentSafeArea: true
    })
    .bindToScrollable([this.addMethodSheetScroller])
    .hideBackButton(true)
    .width('100%')
    .height(this.sheetShortHeight(SHEET_ADD_METHOD_HEIGHT))
    .backgroundColor(this.sheetSurfaceBackgroundColor())
    .backgroundBlurStyle(this.sheetSurfaceBlurStyle())
  }

  @Builder
  private AddMethodButton(label: string, icon: Resource, onClick: () => void, isBrandIcon: boolean = false) {
    Column({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
          buttonModify: new ActionButtonModifier(
            ADD_BUTTON_SIZE, ADD_BUTTON_SIZE, this.primaryActionFillColor(), this.accentColor()),
          click: onClick
        }) {
          Stack({ alignContent: Alignment.Center }) {
            if (isBrandIcon) {
              Image(icon)
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
                .fillColor(this.accentColor())
            } else {
              SymbolGlyph(icon)
                .fontSize(20)
                .fontColor([this.accentColor()])
                .renderingStrategy(SymbolRenderingStrategy.SINGLE)
            }
          }
          .width(50)
          .height(50)
        }
      }
      .width(50)
      .height(50)
      .clip(false)

      Text(this.t(label))
        .width('100%')
        .height(36)
        .fontSize(12)
        .fontColor(this.accentColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private AdaptiveAccentSymbolCircle(icon: Resource, size: number, iconSize: number, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(iconSize)
        .fontColor([this.accentColor()])
        .fontWeight(FontWeight.Medium)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }
    .width(size)
    .height(size)
    .padding(0)
    .backgroundColor(this.accentTintColor())
    .backgroundEffect({
      radius: 18,
      saturation: 1.08,
      brightness: 1.02,
      color: this.accentTintColor(),
      adaptiveColor: AdaptiveColor.DEFAULT
    }, { disableSystemAdaptation: false })
    .shadow({
      radius: ACCENT_GLOW_RADIUS,
      color: this.accentGlowColor(),
      offsetX: 0,
      offsetY: 0
    })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
      .pointLight({
        sourceType: hdsEffect.PointLightSourceType.SOFT,
        illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER,
        options: {
          color: this.accentColor(),
          intensity: 0.1,
          height: 6,
          bloom: 0.08
        }
      })
      .buildEffect())
    .border({ width: 0.5, color: this.accentColor() })
    .stateEffect(true)
    .onClick(onClick)
  }

  @Builder
  private TokenListItem(token: TokenRecord) {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        if (this.shouldRenderTokenSwipeActions(token.id)) {
          Row() {
            this.TokenSwipeActions(token)
          }
          .width('100%')
          .height(TOKEN_CARD_HEIGHT)
          .justifyContent(FlexAlign.End)
          .backgroundColor(Color.Transparent)
        }

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
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .borderRadius(TOKEN_CARD_RADIUS)
    .clip(true)
    .opacity(this.tokenCardItemOpacity(token.id))
    .scale({ x: this.tokenCardScale(token.id), y: this.tokenCardScale(token.id) })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleTokenTouch(token.id, event.type);
    })
  }

  private shouldRenderTokenSwipeActions(tokenId: string): boolean {
    return this.openSwipeTokenId === tokenId || this.activeSwipeTokenId === tokenId;
  }

  private tokenCardItemOpacity(tokenId: string): number {
    if (this.draggingTokenId === tokenId) {
      return 0.92;
    }
    return 1;
  }

  private tokenCardScale(tokenId: string): number {
    return this.pressedTokenId === tokenId && this.draggingTokenId.length === 0 ? CARD_PRESSED_SCALE : 1;
  }

  private handleTokenTouch(tokenId: string, type: TouchType): void {
    if (type === TouchType.Down && this.draggingTokenId.length === 0) {
      this.pressedTokenId = tokenId;
    } else if (type === TouchType.Up || type === TouchType.Cancel) {
      this.pressedTokenId = '';
    }
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
  private TokenCodeView(token: TokenRecord, nextCode: boolean, fontSize: number, fontColor: ResourceColor,
    fontWeight: FontWeight, layoutWeight: number) {
    Row() {
      this.TokenCodeCharacterAt(token, nextCode, 0, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 1, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 2, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 3, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 4, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 5, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 6, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 7, fontSize, fontColor, fontWeight)
      this.TokenCodeCharacterAt(token, nextCode, 8, fontSize, fontColor, fontWeight)
    }
    .height(this.tokenDigitHeight(fontSize))
    .alignItems(VerticalAlign.Center)
    .layoutWeight(layoutWeight)
  }

  @Builder
  private TokenCodeCharacterAt(token: TokenRecord, nextCode: boolean, index: number, fontSize: number,
    fontColor: ResourceColor, fontWeight: FontWeight) {
    if (this.tokenCodeCharacter(token, nextCode, index) === ' ') {
      Column()
        .width(this.tokenDigitSpaceWidth(fontSize))
        .height(this.tokenDigitHeight(fontSize))
    } else if (this.isTokenCodeDigit(this.tokenCodeCharacter(token, nextCode, index))) {
      Text(this.tokenCodeCharacter(token, nextCode, index))
        .fontSize(fontSize)
        .fontWeight(fontWeight)
        .fontColor(fontColor)
        .height(this.tokenDigitHeight(fontSize))
        .width(this.tokenCharacterWidth(token, fontSize))
        .letterSpacing(0)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .clip(true)
        .contentTransition(new NumericTextTransition({
          flipDirection: FlipDirection.UP,
          enableBlur: false
        }))
        .animation({ duration: TOKEN_DIGIT_SCROLL_DURATION, curve: Curve.Smooth })
    } else if (this.tokenCodeCharacter(token, nextCode, index).length > 0) {
      Text(this.tokenCodeCharacter(token, nextCode, index))
        .fontSize(fontSize)
        .fontWeight(fontWeight)
        .fontColor(fontColor)
        .height(this.tokenDigitHeight(fontSize))
        .width(this.tokenCharacterWidth(token, fontSize))
        .letterSpacing(0)
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
  }

  @Builder
  private TokenSingleColumnCard(token: TokenRecord) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(TOKEN_CARD_HEIGHT, TOKEN_CARD_RADIUS)
      }
      this.TokenSingleColumnCardContent(token)
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .borderRadius(TOKEN_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .onClick(() => {
      this.handleTokenCardClick(token);
    })
  }

  @Builder
  private TokenSingleColumnCardContent(token: TokenRecord) {
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
          this.TokenCodeView(token, false, TOKEN_CODE_TEXT_SIZE, this.tokenValueColor(), FontWeight.Medium, 0)

          if (this.showNextToken) {
            Text('←')
              .fontSize(12)
              .fontColor(this.nexttokenValueColor())
              .fontWeight(FontWeight.Regular)
              .opacity(0.65)

            this.TokenCodeView(token, true, TOKEN_NEXT_CODE_TEXT_SIZE, this.nexttokenValueColor(),
              FontWeight.Medium, 0)
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
    .padding(TOKEN_CARD_PADDING)
    .alignItems(VerticalAlign.Center)
    .zIndex(2)
  }

  @Builder
  private TokenDoubleColumnCard(token: TokenRecord) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(TOKEN_CARD_HEIGHT, TOKEN_CARD_RADIUS)
      }
      this.TokenDoubleColumnCardContent(token)
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .borderRadius(TOKEN_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .onClick(() => {
      this.handleTokenCardClick(token);
    })
  }

  @Builder
  private TokenDoubleColumnCardContent(token: TokenRecord) {
    Row({ space: 10 }) {
      this.IssuerLogoView(this.tokenLogoUri(token), token.name, token.remark, TOKEN_LOGO_SIZE,
        token.logoSource !== LOGO_SOURCE_MANUAL)

      Column({ space: 6 }) {
        Text(this.tokenDisplayName(token))
          .fontSize(TOKEN_NAME_TEXT_SIZE)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        this.TokenCodeView(token, false, TOKEN_CODE_TEXT_SIZE, this.tokenValueColor(), FontWeight.Medium, 0)
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height(TOKEN_CARD_HEIGHT)
    .padding(TOKEN_CARD_PADDING)
    .alignItems(VerticalAlign.Center)
    .zIndex(2)
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
        .syncLoad(true)
        .borderRadius(size / 2)
        .objectFit(ImageFit.Contain)
    } else if (allowLocalLogo && this.localIssuerLogoKey(name, issuer) === 'microsoft') {
      if (this.issuerLogoColorMode === '品牌色') {
        Image($r('app.media.logo_microsoft_brand'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      } else if (this.isDarkTheme()) {
        Image($r('app.media.logo_microsoft_dark'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      } else {
        Image($r('app.media.logo_microsoft_light'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      }
    } else if (allowLocalLogo && this.localIssuerLogoKey(name, issuer) === 'gitcode') {
      if (this.issuerLogoColorMode === '品牌色') {
        Image($r('app.media.logo_gitcode_brand'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      } else if (this.isDarkTheme()) {
        Image($r('app.media.logo_gitcode_dark'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      } else {
        Image($r('app.media.logo_gitcode_light'))
          .width(size)
          .height(size)
          .syncLoad(true)
          .objectFit(ImageFit.Contain)
      }
    } else if (logoUri.length > 0) {
      Image(logoUri)
        .width(size)
        .height(size)
        .syncLoad(true)
        .borderRadius(size / 2)
        .objectFit(allowLocalLogo ? ImageFit.Contain : ImageFit.Cover)
        .clip(true)
    } else {
      Stack() {
        Circle()
          .width(size)
          .height(size)
          .fill(this.accentTintColor())
        Text(this.issuerLogoLetter(name, issuer))
          .fontSize(Math.max(16, Math.floor(size * 0.44)))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.accentColor())
      }
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .border({ width: 0.5, color: this.accentColor() })
    }
  }

  @Builder
  private TokenSwipeActions(token: TokenRecord) {
    Row({ space: SWIPE_ACTION_GAP }) {
      this.SwipeActionButton($r('sys.symbol.square_and_pencil'), false, () => {
        this.resetTokenSwipe();
        this.openEditPage(token);
      })

      this.SwipeActionButton($r('sys.symbol.trash'), true, () => {
        this.resetTokenSwipe();
        this.confirmDeleteToken(token);
      })
    }
    .width(this.tokenSwipeActionAreaWidth(token))
    .height(TOKEN_CARD_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
  }

  private tokenSwipeActionAreaWidth(token: TokenRecord): number {
    const count = 2;
    return SWIPE_ACTION_SIZE * count + SWIPE_ACTION_GAP * (count + 1);
  }

  @Builder
  private SwipeActionButton(icon: Resource, isDestructive: boolean, onClick: () => void) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(icon)
        .fontSize(SWIPE_ACTION_ICON_SIZE)
        .fontColor([isDestructive ? ERROR_RED : this.accentColor()])
        .fontWeight(FontWeight.Medium)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
    }
    .width(SWIPE_ACTION_SIZE)
    .height(SWIPE_ACTION_SIZE)
    .padding(0)
    .backgroundColor(isDestructive ? ERROR_RED_TINT : this.accentTintColor())
    .border({ width: 0.5, color: isDestructive ? ERROR_RED : this.accentColor() })
    .stateEffect(true)
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

        Stack({ alignContent: Alignment.Center }) {
          ImmersionButton({
            systemMaterialEffect: this.configuredMaterialEffect(),
            buttonModify: new ActionButtonModifier(
              '100%',
              46,
              this.canSaveToken() ? this.primaryActionFillColor() : this.disabledColor(),
              this.canSaveToken() ? this.accentColor() : '#00000000'
            ),
            click: (): void => {
              if (this.canSaveToken()) {
                this.saveToken();
              }
            }
          }) {
            Text(this.isSaving ? this.t('保存中') : this.t('确认'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.canSaveToken() ? this.accentColor() : this.disabledButtonTextColor())
          }
        }
        .height(46)
        .width('100%')
        .margin({ top: PAGE_CARD_GAP })
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
    .clip(false)
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
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize(36)
          .fontColor(['#FFFFFFFF'])
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
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
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(FORM_BASIC_CARD_HEIGHT, 15)
      }
      this.AddTokenBasicCardContent()
    }
    .width('100%')
    .height(FORM_BASIC_CARD_HEIGHT)
    .borderRadius(15)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('add-token-basic'), y: this.appCardScale('add-token-basic') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('add-token-basic', event.type);
    })
  }

  @Builder
  private AddTokenBasicCardContent() {
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
    .zIndex(2)
  }

  @Builder
  private AddTokenDetailCard() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.shouldUseCardMaterial()) {
        this.ImmersionCardSurface(FORM_DETAIL_CARD_HEIGHT, 15)
      }
      this.AddTokenDetailCardContent()
    }
    .width('100%')
    .height(FORM_DETAIL_CARD_HEIGHT)
    .borderRadius(15)
    .clip(true)
    .backgroundColor(this.cardSurfaceBaseColor(this.cardBackgroundColor()))
    .border({ width: this.cardSurfaceBorderWidth(), color: this.immersionBorderColor() })
    .scale({ x: this.appCardScale('add-token-detail'), y: this.appCardScale('add-token-detail') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      this.handleAppCardTouch('add-token-detail', event.type);
    })
  }

  @Builder
  private AddTokenDetailCardContent() {
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
    .zIndex(2)
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

  private onSystemDarkChanged(): void {
    this.logoRenderVersion += 1;
    this.formLogoRenderVersion += 1;
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

  private accentTintColor(): string {
    return this.accentColorWithAlpha(ACCENT_TINT_ALPHA);
  }

  private primaryActionFillColor(): string {
    return this.accentColorWithAlpha(PRIMARY_ACTION_FILL_ALPHA);
  }

  private accentGlowColor(): string {
    return this.accentColorWithAlpha(ACCENT_GLOW_ALPHA);
  }

  private pageBackgroundColor(): string {
    return this.isDarkTheme() ? '#000000' : '#F2F3F5';
  }

  private cardBackgroundColor(): string {
    return this.isDarkTheme() ? '#191919' : '#FFFFFF';
  }

  private onboardingPageSide(): number {
    return this.pageWidth >= 600 ? ONBOARDING_PAGE_SIDE_WIDE : ONBOARDING_PAGE_SIDE;
  }

  private onboardingTopOverlayHeight(): number {
    return this.statusBarHeight + ONBOARDING_TOP_BAR_HEIGHT + ONBOARDING_TOP_OVERLAY_VERTICAL_SPACE;
  }

  private onboardingBottomOverlayHeight(): number {
    return this.naviIndicatorHeight + ONBOARDING_BOTTOM_SAFE_GAP + ONBOARDING_INDICATOR_HEIGHT +
      ONBOARDING_BOTTOM_CONTROL_GAP + ONBOARDING_ACTION_HEIGHT;
  }

  private onboardingContentTopInset(): number {
    return this.onboardingTopOverlayHeight() + ONBOARDING_CONTENT_CHROME_GAP;
  }

  private onboardingContentBottomInset(): number {
    return this.onboardingBottomOverlayHeight() + ONBOARDING_CONTENT_CHROME_GAP;
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
    if (this.shouldUseCardMaterial()) {
      return this.isDarkTheme() ? '#D0D0D0' : '#4A4A4A';
    }
    return this.isDarkTheme() ? '#B8B8B8' : '#666666';
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
    if (name === 'watchSync') {
      return this.t('手表端数据同步');
    }
    if (name === 'moreApps') {
      return this.t('更多作品');
    }
    if (name === 'donation') {
      return this.t('打赏一杯咖啡');
    }
    if (name === 'about') {
      return this.t('关于');
    }
    if (name === 'thirdParty') {
      return this.t('开源三方库使用清单');
    }
    if (name === 'appearanceSettings') {
      return this.t('外观与主题');
    }
    if (name === 'featureSecurity') {
      return this.t('功能与安全');
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
    if (name === 'watchSync') {
      return [this.watchSyncScroller];
    }
    if (name === 'moreApps') {
      return [this.moreAppsScroller];
    }
    if (name === 'donation') {
      return [this.donationScroller];
    }
    if (name === 'about') {
      return [this.aboutScroller];
    }
    if (name === 'thirdParty') {
      return [this.thirdPartyScroller];
    }
    if (name === 'appearanceSettings') {
      return [this.appearanceSettingsScroller];
    }
    if (name === 'featureSecurity') {
      return [this.featureSecurityScroller];
    }
    return [this.settingsScroller];
  }

  private sheetCloseMenu(action: () => void): HdsNavigationMenuContentOptions {
    return {
      value: [
        {
          content: {
            icon: $r('sys.symbol.xmark'),
            label: this.t('取消'),
            type: IconStyleMode.SMALL,
            action: action
          }
        }
      ],
      maxCount: 1
    };
  }

  private sheetTitleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: false,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      },
      blurStrategy: BlurStrategy.ADAPTIVE,
      originalStyle: {
        backgroundStyle: { backgroundColor: '#00ffffff' },
        contentStyle: {
          titleStyle: { mainTitleColor: this.primaryTextColor() },
          menuStyle: {
            backgroundColor: this.sheetControlBackgroundColor(),
            iconColor: this.primaryTextColor()
          },
          backIconStyle: {
            backgroundColor: this.sheetControlBackgroundColor(),
            iconColor: this.primaryTextColor()
          }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: { backgroundColor: '#00ffffff' },
        contentStyle: {
          titleStyle: { mainTitleColor: this.primaryTextColor() },
          menuStyle: {
            backgroundColor: this.sheetControlBackgroundColor(),
            iconColor: this.primaryTextColor()
          },
          backIconStyle: {
            backgroundColor: this.sheetControlBackgroundColor(),
            iconColor: this.primaryTextColor()
          }
        }
      },
      systemMaterialEffect: {
        materialType: this.configuredMaterialType(),
        materialLevel: this.configuredMaterialLevel()
      }
    };
  }

  private configuredMaterialType(): hdsMaterial.MaterialType {
    if (this.materialTypeInput === '沉浸') {
      return hdsMaterial.MaterialType.IMMERSIVE;
    }
    if (this.materialTypeInput === '无材质') {
      return hdsMaterial.MaterialType.NONE;
    }
    return hdsMaterial.MaterialType.ADAPTIVE;
  }

  private configuredMaterialLevel(): hdsMaterial.MaterialLevel {
    if (this.materialLevelInput === '精致') {
      return hdsMaterial.MaterialLevel.EXQUISITE;
    }
    if (this.materialLevelInput === '柔和') {
      return hdsMaterial.MaterialLevel.GENTLE;
    }
    if (this.materialLevelInput === '平滑') {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  private configuredMaterialEffect(): SystemMaterialParams {
    return {
      materialType: this.configuredMaterialType(),
      materialLevel: this.configuredMaterialLevel()
    };
  }

  private onboardingMaterialEffect(): SystemMaterialParams {
    return {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
    };
  }

  private shouldUseCardMaterial(): boolean {
    return this.globalImmersionEnabled && this.configuredMaterialType() !== hdsMaterial.MaterialType.NONE;
  }

  private cardSurfaceBaseColor(fallbackColor: ResourceColor): ResourceColor {
    return this.shouldUseCardMaterial() ? Color.Transparent : fallbackColor;
  }

  private cardSurfaceBorderWidth(): number {
    return this.shouldUseCardMaterial() ? 0.5 : 0;
  }

  private appCardScale(cardId: string): number {
    return this.pressedCardId === cardId ? CARD_PRESSED_SCALE : 1;
  }

  private handleAppCardTouch(cardId: string, type: TouchType): void {
    if (type === TouchType.Down) {
      this.pressedCardId = cardId;
    } else if ((type === TouchType.Up || type === TouchType.Cancel) && this.pressedCardId === cardId) {
      this.pressedCardId = '';
    }
  }

  private configuredSheetBlurStyle(): BlurStyle {
    if (this.materialLevelInput === '精致') {
      return BlurStyle.COMPONENT_ULTRA_THIN;
    }
    if (this.materialLevelInput === '柔和') {
      return BlurStyle.COMPONENT_THIN;
    }
    if (this.materialLevelInput === '平滑') {
      return BlurStyle.COMPONENT_REGULAR;
    }
    return this.configuredMaterialType() === hdsMaterial.MaterialType.IMMERSIVE ?
      BlurStyle.COMPONENT_REGULAR : BlurStyle.COMPONENT_THIN;
  }

  private sheetSurfaceBackgroundColor(): ResourceColor {
    return this.shouldUseCardMaterial() ? Color.Transparent : this.cardBackgroundColor();
  }

  private sheetSurfaceBlurStyle(): BlurStyle {
    return this.shouldUseCardMaterial() ? this.configuredSheetBlurStyle() : BlurStyle.COMPONENT_THIN;
  }

  private sheetFloatingBarColor(): string {
    return this.isDarkTheme() ? '#E6303030' : '#EEFFFFFF';
  }

  private sheetControlBackgroundColor(): string {
    return this.isDarkTheme() ? '#F23A3A3A' : '#F2F3F5';
  }

  private sheetFloatingShadowColor(): string {
    return this.isDarkTheme() ? '#4D000000' : '#10000000';
  }

  private sheetActionBottomInset(): number {
    return this.naviIndicatorHeight + SHEET_ACTION_BOTTOM_GAP;
  }

  private sheetListBottomPadding(): number {
    return this.naviIndicatorHeight + SHEET_ACTION_SAFE_SPACE;
  }

  private sheetShortHeight(baseHeight: number): number {
    const maxHeight = Math.max(280, this.pageHeight * 0.84);
    return Math.min(maxHeight, baseHeight + this.naviIndicatorHeight);
  }

  private exportQRCodeSheetHeight(): number {
    const selectedCount = this.exportSelectedTokens().length;
    const baseHeight = selectedCount > 0 ? this.exportQRCodeSize() + SHEET_QR_BASE_HEIGHT : 240;
    return this.sheetShortHeight(baseHeight);
  }

  private sheetButtonBackgroundColor(isPrimary: boolean, isEnabled: boolean): string {
    if (!isEnabled) {
      return this.disabledColor();
    }
    return isPrimary ? this.primaryActionFillColor() : '#00000000';
  }

  private sheetButtonBorderColor(isPrimary: boolean, isEnabled: boolean): string {
    return isPrimary && isEnabled ? this.accentColor() : '#00000000';
  }

  private sheetButtonTextColor(isPrimary: boolean, isEnabled: boolean): string {
    if (!isEnabled) {
      return this.disabledButtonTextColor();
    }
    return isPrimary ? this.accentColor() : this.primaryTextColor();
  }

  @Builder
  private SheetMetaRow(summary: string, value: string) {
    Row() {
      Text(summary)
        .fontSize(SHEET_SECONDARY_TEXT_SIZE)
        .fontColor(this.secondaryTextColor())
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(value)
        .fontSize(14)
        .fontColor(this.secondaryTextColor())
    }
    .width('100%')
    .height(40)
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SheetMetaActionRow(summary: string, actionLabel: string, action: () => void) {
    Row() {
      Text(summary)
        .fontSize(SHEET_SECONDARY_TEXT_SIZE)
        .fontColor(this.secondaryTextColor())
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Stack({ alignContent: Alignment.Center }) {
        ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
          buttonModify: {
            applyNormalAttribute(instance: ButtonModifier): void {
              instance.width(88).height(32)
            }
          },
          click: action
        }) {
          Text(actionLabel)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentColor())
            .padding({ left: 14, right: 14 })
        }
      }
      .height(32)
      .clip(false)
    }
    .width('100%')
    .height(46)
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SheetActionButton(param: SheetActionButtonParam) {
    Stack({ alignContent: Alignment.Center }) {
      ImmersionButton({
          systemMaterialEffect: this.configuredMaterialEffect(),
        buttonModify: new ActionButtonModifier(
          '100%',
          SHEET_ACTION_BUTTON_HEIGHT,
          this.sheetButtonBackgroundColor(param.isPrimary, param.isEnabled),
          this.sheetButtonBorderColor(param.isPrimary, param.isEnabled)
        ),
        click: (): void => {
          if (param.isEnabled && !param.isLoading) {
            param.action();
          }
        }
      }) {
        Row({ space: 6 }) {
          if (param.isLoading) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(this.sheetButtonTextColor(param.isPrimary, param.isEnabled))
          }

          Text(param.label)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.sheetButtonTextColor(param.isPrimary, param.isEnabled))
            .maxLines(1)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width('100%')
        .height(SHEET_ACTION_BUTTON_HEIGHT)
      }
    }
    .layoutWeight(1)
    .height(SHEET_ACTION_BUTTON_HEIGHT)
    .opacity(param.isEnabled ? 1 : 0.55)
    .clip(false)
  }

  @Builder
  private SheetFloatingActions(param: SheetFloatingActionsParam) {
    Row({ space: SHEET_ACTION_GAP }) {
      this.SheetActionButton({
        label: param.secondaryLabel,
        isPrimary: param.secondaryIsPrimary === true,
        isEnabled: !param.primaryLoading,
        isLoading: false,
        action: param.secondaryAction
      })
      this.SheetActionButton({
        label: param.primaryLabel,
        isPrimary: true,
        isEnabled: param.primaryEnabled && !param.primaryLoading,
        isLoading: param.primaryLoading,
        action: param.primaryAction
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: 520 })
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
    .align(Alignment.Bottom)
    .margin({ bottom: this.sheetActionBottomInset() })
    .zIndex(20)
  }

  @Builder
  private SheetSingleFloatingAction(param: SheetSingleFloatingActionParam) {
    Row() {
      this.SheetActionButton({
        label: param.label,
        isPrimary: true,
        isEnabled: true,
        isLoading: false,
        action: param.action
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: 520 })
    .padding({ left: SHEET_HORIZONTAL_PADDING, right: SHEET_HORIZONTAL_PADDING })
    .align(Alignment.Bottom)
    .margin({ bottom: this.sheetActionBottomInset() })
    .zIndex(20)
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
    if (source.indexOf('microsoft') >= 0 || source.indexOf('微软') >= 0) {
      return 'microsoft';
    }
    if (source.indexOf('gitcode') >= 0) {
      return 'gitcode';
    }
    return '';
  }

  private tokenLogoUri(token: TokenRecord): string {
    const type = this.normalizeTokenType(token.type);
    if (token.logoSource === LOGO_SOURCE_MANUAL && type !== 'Steam') {
      return token.logoUri || '';
    }
    if (type !== 'Steam' && this.issuerLogoColorMode === '品牌色') {
      return token.logoUri || token.logoLightUri || token.logoDarkUri || '';
    }
    return this.isDarkTheme() ? (token.logoDarkUri || token.logoUri || '') : (token.logoLightUri || token.logoUri || '');
  }

  private formLogoUri(): string {
    const type = this.formTokenType();
    if (this.logoSourceInput === LOGO_SOURCE_MANUAL && type !== 'Steam') {
      return this.logoUriInput;
    }
    if (type !== 'Steam' && this.issuerLogoColorMode === '品牌色') {
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
      steamData: token.steamData,
      createdAt: token.createdAt,
      modifiedTime: token.modifiedTime
    };
  }

  private tokenSwipeOffset(tokenId: string): number {
    const width = this.tokenSwipeWidth(tokenId);
    if (this.activeSwipeTokenId === tokenId) {
      return this.activeSwipeOffset;
    }
    return this.openSwipeTokenId === tokenId ? -width : 0;
  }

  private tokenSwipeWidth(tokenId: string): number {
    const token = this.tokens.find((item: TokenRecord) => item.id === tokenId);
    return token ? this.tokenSwipeActionAreaWidth(token) : SWIPE_ACTION_AREA_WIDTH;
  }

  private handleTokenPanUpdate(tokenId: string, offsetX: number): void {
    const width = this.tokenSwipeWidth(tokenId);
    this.activeSwipeTokenId = tokenId;
    if (this.openSwipeTokenId === tokenId) {
      this.activeSwipeOffset = Math.max(-width, Math.min(0, -width + offsetX));
    } else {
      this.activeSwipeOffset = Math.max(-width, Math.min(0, offsetX));
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
    this.pressedTokenId = '';
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
    this.pressedTokenId = '';
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
    return this.cachedTokenCode(token, this.currentTimeMs, this.tokenCounterForRecord(token));
  }

  private tokenCodeCharacter(token: TokenRecord, nextCode: boolean, index: number): string {
    const code = nextCode ? this.nextTokenCode(token) : this.tokenCode(token);
    return index < code.length ? code.charAt(index) : '';
  }

  private isTokenCodeDigit(character: string): boolean {
    if (character.length !== 1) {
      return false;
    }
    const codeUnit = character.charCodeAt(0);
    return codeUnit >= 48 && codeUnit <= 57;
  }

  private tokenDigitHeight(fontSize: number): number {
    return Math.ceil(fontSize * TOKEN_DIGIT_HEIGHT_FACTOR);
  }

  private tokenDigitWidth(fontSize: number): number {
    return Math.ceil(fontSize * TOKEN_DIGIT_WIDTH_FACTOR);
  }

  private tokenCharacterWidth(token: TokenRecord, fontSize: number): number {
    if (this.normalizeTokenType(token.type) === 'Steam') {
      return Math.ceil(fontSize * TOKEN_STEAM_CHARACTER_WIDTH_FACTOR);
    }
    return this.tokenDigitWidth(fontSize);
  }

  private tokenDigitSpaceWidth(fontSize: number): number {
    return Math.ceil(fontSize * TOKEN_DIGIT_SPACE_FACTOR);
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
      return this.cachedTokenCode(token, this.currentTimeMs, this.tokenCounterForRecord(token) + 1);
    }
    return this.cachedTokenCode(token, this.currentTimeMs + this.tokenPeriodForRecord(token) * 1000,
      this.tokenCounterForRecord(token));
  }

  private cachedTokenCode(token: TokenRecord, timeMs: number, counter: number): string {
    this.refreshTokenCodeCache();
    const type = this.normalizeTokenType(token.type);
    const period = this.tokenPeriodForRecord(token);
    const digits = this.tokenDigitsForRecord(token);
    const movingFactor = type === 'HOTP' ? counter : Math.floor(Math.floor(timeMs / 1000) / period);
    const key = token.id + '|' + token.secret + '|' + (token.algorithm || 'SHA1') + '|' +
      digits.toString() + '|' + period.toString() + '|' + type + '|' + movingFactor.toString();
    const cachedCode = this.tokenCodeCache.get(key);
    if (cachedCode !== undefined) {
      return cachedCode;
    }
    const code = this.generateTokenCode(token, timeMs, counter);
    this.tokenCodeCache.set(key, code);
    return code;
  }

  private refreshTokenCodeCache(): void {
    const version = Math.floor(this.currentTimeMs / (DEFAULT_TOKEN_PERIOD * 1000));
    if (version === this.tokenCodeCacheVersion) {
      return;
    }
    this.tokenCodeCache.clear();
    this.tokenCodeCacheVersion = version;
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
    if (this.huaweiLogoutInProgress) {
      return;
    }
    this.huaweiLogoutInProgress = true;
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
    this.huaweiLogoutInProgress = false;
  }

  private confirmLogoutHuaweiAccount(): void {
    if (this.huaweiLogoutInProgress) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: this.t('确认退出登录'),
      message: this.t('退出华为账号后，云空间自动同步将同时关闭。确定退出吗？'),
      autoCancel: true,
      primaryButton: {
        value: this.t('取消'),
        action: () => {
        }
      },
      secondaryButton: {
        value: this.t('退出'),
        fontColor: ERROR_RED,
        action: () => {
          this.logoutHuaweiAccount();
        }
      }
    });
  }

  private async toggleCloudBackup(isOn: boolean): Promise<void> {
    if (this.cloudSyncing) {
      this.showToast('正在同步，请稍候');
      return;
    }
    if (!isOn) {
      if (!await this.configureCloudAutoSync(false)) {
        this.showToast('关闭自动同步失败，请稍后重试');
        return;
      }
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '云空间自动同步已关闭';
      this.steamCloudSyncStatus = '云空间自动同步已关闭';
      this.saveSettings();
      this.showToast('云空间自动同步已关闭');
      return;
    }

    this.cloudSyncStatus = '正在准备';
    this.steamCloudSyncStatus = '正在准备';
    this.saveSettings();

    if (!this.isHuaweiLoggedIn) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '请先登录华为账号';
      this.steamCloudSyncStatus = '请先登录华为账号';
      this.saveSettings();
      this.showToast('请先登录华为账号');
      return;
    }

    if (!await this.ensureDataSyncPermission()) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '未授权云同步';
      this.steamCloudSyncStatus = '未授权云同步';
      this.saveSettings();
      this.showToast('需要授权跨设备数据同步');
      return;
    }

    if (!await this.configureCloudAutoSync(false)) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '无法开启云同步';
      this.steamCloudSyncStatus = '无法开启云同步';
      this.saveSettings();
      this.showToast('请确认已登录华为账号并开启云空间');
      return;
    }

    if (!await this.startCloudPush(false)) {
      this.cloudBackupEnabled = false;
      this.saveSettings();
      this.showCloudSyncFailure();
      return;
    }
    if (!await this.pullCloudTokensIntoLocal(false)) {
      this.cloudBackupEnabled = false;
      this.saveSettings();
      this.showCloudSyncFailure();
      return;
    }
    if (!await this.configureCloudAutoSync(true)) {
      this.cloudBackupEnabled = false;
      this.cloudSyncStatus = '无法开启云同步';
      this.steamCloudSyncStatus = '无法开启云同步';
      this.saveSettings();
      this.showToast('请确认已登录华为账号并开启云空间');
      return;
    }

    this.cloudBackupEnabled = true;
    this.cloudLastSyncTime = Date.now();
    this.saveSettings();
    this.showToast('云空间自动同步已开启');
  }

  private async configureCloudAutoSync(enabled: boolean): Promise<boolean> {
    const context = this.getAbilityContext();
    if (!context) {
      return false;
    }
    const steamPaused = await SteamGuardCloudRepository.configureCloudSync(context, false);
    if (!steamPaused) {
      console.error('Steam Guard cloud sync could not be paused before generic token configuration');
    }
    const tokenConfigured = await TokenRepository.configureCloudSync(context, enabled, (state: CloudSyncState): void => {
      if (enabled && state.finished && state.success && state.status === '云端数据已更新') {
        this.mergeCloudMirrorIntoLocal();
        return;
      }
      this.updateCloudSyncState(state);
    });
    if (!tokenConfigured) {
      return false;
    }
    if (!enabled) {
      return true;
    }
    const steamConfigured = await SteamGuardCloudRepository.configureCloudSync(
      context,
      true,
      (state: CloudSyncState): void => {
        if (state.finished && state.success && state.status === 'Steam 云端数据已更新') {
          this.mergeSteamGuardCloudMirrorIntoLocal();
          return;
        }
        this.updateSteamCloudSyncState(state);
      }
    );
    if (!steamConfigured) {
      console.error('Steam Guard cloud table is unavailable; generic token auto sync remains enabled');
    }
    return true;
  }

  private async pushTokensToCloud(): Promise<void> {
    if (!this.isHuaweiLoggedIn) {
      this.showToast('请先登录华为账号');
      return;
    }
    this.showToast('同步中');
    await this.startCloudPush(true);
  }

  private async startCloudPush(showOperationToast: boolean): Promise<boolean> {
    console.info(`Cloud push requested: manual=${showOperationToast}, syncing=${this.cloudSyncing}, ` +
      `autoSync=${this.cloudBackupEnabled}, records=${this.tokens.length}`);
    if (this.cloudSyncing) {
      if (showOperationToast) {
        this.showToast('正在同步，请稍候');
      }
      return false;
    }
    const context = this.getAbilityContext();
    if (!context) {
      if (showOperationToast) {
        this.showToast('无法访问云空间');
      }
      return false;
    }
    this.beginCloudSync('正在推送');
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步', showOperationToast);
      return false;
    }
    const restoreAutoSync = this.cloudBackupEnabled;
    if (!await this.configureCloudAutoSync(false)) {
      this.finishCloudSyncFailure('云同步不可用', showOperationToast);
      return false;
    }
    const success = await TokenRepository.pushToCloud(
      context,
      this.tokens,
      (state: CloudSyncState): void => {
        this.updateCloudSyncState(state);
      }
    );
    if (!success) {
      if (restoreAutoSync) {
        await this.configureCloudAutoSync(true);
      }
      if (this.cloudSyncing) {
        this.finishCloudSyncFailure('推送失败', showOperationToast);
      } else if (showOperationToast) {
        this.showCloudSyncFailure();
      }
      return false;
    }

    let steamSuccess = !this.hasCompleteSteamGuardData(this.tokens);
    let steamFailureStatus = '';
    const steamConfigured = steamSuccess || await SteamGuardCloudRepository.configureCloudSync(context, false);
    if (!steamSuccess && steamConfigured) {
      this.beginSteamCloudSync('正在推送 Steam 完整数据');
      steamSuccess = await SteamGuardCloudRepository.pushToCloud(
        context,
        this.tokens,
        (state: CloudSyncState): void => {
          if (state.finished && !state.success) {
            steamFailureStatus = state.message || state.status;
          }
          this.updateSteamCloudSyncState(state);
        }
      );
    } else if (!steamSuccess) {
      steamFailureStatus = SteamGuardCloudRepository.getLastFailureStatus();
    } else {
      this.updateSteamCloudSyncState({
        status: '同步成功（上传0条，下载0条）',
        finished: true,
        success: true,
        uploadTotal: 0,
        uploadSuccess: 0,
        uploadFailed: 0,
        downloadTotal: 0,
        downloadSuccess: 0,
        downloadFailed: 0
      });
    }
    if (restoreAutoSync) {
      await this.configureCloudAutoSync(true);
    }
    if (!steamSuccess) {
      const detail = steamFailureStatus.length > 0 ? steamFailureStatus : 'Steam 完整数据同步失败';
      this.finishSteamSupplementalWarning(detail, false);
      if (showOperationToast) {
        this.showToast('通用令牌推送成功，Steam 完整数据未同步');
      }
      return true;
    }
    if (this.steamCloudSyncing) {
      this.updateSteamCloudSyncState({ status: 'Steam 完整数据推送成功', finished: true, success: true });
    }
    if (showOperationToast) {
      this.showToast('推送成功');
    }
    return true;
  }

  private async pullTokensFromCloud(): Promise<void> {
    if (!this.isHuaweiLoggedIn) {
      this.showToast('请先登录华为账号');
      return;
    }
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
      this.beginCloudSync('正在获取');
    }
    if (!await this.ensureDataSyncPermission()) {
      this.finishCloudSyncFailure('未授权云同步', showOperationToast);
      return false;
    }
    const restoreAutoSync = this.cloudBackupEnabled;
    if (!await this.configureCloudAutoSync(false)) {
      this.finishCloudSyncFailure('云同步不可用', showOperationToast);
      return false;
    }
    const localSnapshot = [...this.tokens];
    const records = await TokenRepository.pullFromCloud(context, (state: CloudSyncState): void => {
      this.updateCloudSyncState(state);
    });
    if (!records) {
      if (restoreAutoSync) {
        await this.configureCloudAutoSync(true);
      }
      if (this.cloudSyncing) {
        this.finishCloudSyncFailure('获取失败', showOperationToast);
      } else if (showOperationToast) {
        this.showCloudSyncFailure();
      }
      return false;
    }
    const cloudRecords = await this.hydrateTokenLogos(records, true);
    let mergedRecords = this.mergeCloudTokensWithoutDeletingLocal(localSnapshot, cloudRecords);
    if (!await TokenRepository.save(context, mergedRecords)) {
      if (restoreAutoSync) {
        await this.configureCloudAutoSync(true);
      }
      this.finishCloudSyncFailure('本地更新失败', showOperationToast);
      return false;
    }

    let steamSuccess = !this.hasSteamTokens(mergedRecords);
    if (!steamSuccess && await SteamGuardCloudRepository.configureCloudSync(context, false)) {
      this.beginSteamCloudSync('正在获取 Steam 完整数据');
      const steamRecords = await SteamGuardCloudRepository.pullFromCloud(
        context,
        (state: CloudSyncState): void => {
          this.updateSteamCloudSyncState(state);
        }
      );
      if (steamRecords) {
        const steamMergedRecords = SteamGuardCloudRepository.mergeIntoTokens(mergedRecords, steamRecords);
        if (await TokenRepository.save(context, steamMergedRecords)) {
          mergedRecords = steamMergedRecords;
          steamSuccess = true;
        }
      }
    } else if (steamSuccess) {
      this.updateSteamCloudSyncState({
        status: '同步成功（上传0条，下载0条）',
        finished: true,
        success: true,
        uploadTotal: 0,
        uploadSuccess: 0,
        uploadFailed: 0,
        downloadTotal: 0,
        downloadSuccess: 0,
        downloadFailed: 0
      });
    }
    if (restoreAutoSync) {
      await this.configureCloudAutoSync(true);
    }
    this.tokens = mergedRecords;
    this.logoRenderVersion += 1;
    this.updateWidgetCards();
    if (!steamSuccess) {
      this.finishSteamSupplementalWarning('Steam 完整数据同步失败', false);
      if (showOperationToast) {
        this.showToast('通用令牌获取成功，Steam 完整数据未同步');
      }
      return true;
    }
    if (this.steamCloudSyncing) {
      this.updateSteamCloudSyncState({ status: 'Steam 完整数据获取成功', finished: true, success: true });
    }
    if (showOperationToast) {
      this.showToast('获取成功');
    }
    return true;
  }

  private async mergeCloudMirrorIntoLocal(): Promise<void> {
    if (this.cloudMirrorMerging) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    this.cloudMirrorMerging = true;
    try {
      const cloudRecords = await TokenRepository.loadCloudRecords(context);
      const hydratedRecords = await this.hydrateTokenLogos(cloudRecords, true);
      const excludedIds = await TokenRepository.loadLocalCloudExclusions(context);
      const visibleCloudRecords = hydratedRecords.filter((record: TokenRecord): boolean => {
        return !excludedIds.includes(record.id);
      });
      const mergedRecords = this.mergeCloudTokensWithoutDeletingLocal(this.tokens, visibleCloudRecords);
      if (await TokenRepository.save(context, mergedRecords)) {
        this.tokens = mergedRecords;
        this.logoRenderVersion += 1;
        this.updateWidgetCards();
        this.mergeSteamGuardCloudMirrorIntoLocal();
      }
    } finally {
      this.cloudMirrorMerging = false;
    }
  }

  private async mergeSteamGuardCloudMirrorIntoLocal(): Promise<void> {
    if (this.steamCloudMirrorMerging) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    this.steamCloudMirrorMerging = true;
    try {
      const cloudRecords: SteamGuardCloudRecord[] =
        await SteamGuardCloudRepository.loadCloudRecords(context);
      const mergedRecords = SteamGuardCloudRepository.mergeIntoTokens(this.tokens, cloudRecords);
      if (await TokenRepository.save(context, mergedRecords)) {
        this.tokens = mergedRecords;
        this.logoRenderVersion += 1;
        this.updateWidgetCards();
      }
    } finally {
      this.steamCloudMirrorMerging = false;
    }
  }

  private async queueTokensForAutoCloudPush(): Promise<void> {
    if (!this.cloudBackupEnabled) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    if (!this.cloudSyncing) {
      this.beginCloudSync('正在推送');
    }
    const result: CloudStageResult = await TokenRepository.stageAutoPush(context, this.tokens);
    if (!result.success) {
      this.finishCloudSyncFailure('自动推送失败', false);
      this.showToast('本地已保存，云端同步失败');
      return;
    }
    let steamResult: CloudStageResult = { success: true, changed: false };
    if (this.hasCompleteSteamGuardData(this.tokens)) {
      this.beginSteamCloudSync('等待同步 Steam 完整数据');
      steamResult = await SteamGuardCloudRepository.stageAutoPush(context, this.tokens);
    } else {
      this.updateSteamCloudSyncState({
        status: '同步成功（上传0条，下载0条）',
        finished: true,
        success: true,
        uploadTotal: 0,
        uploadSuccess: 0,
        uploadFailed: 0,
        downloadTotal: 0,
        downloadSuccess: 0,
        downloadFailed: 0
      });
    }
    if (!steamResult.success) {
      this.finishSteamSupplementalWarning('Steam 完整数据同步失败', false);
      this.showToast('通用令牌已保存，Steam 完整数据同步失败');
      return;
    }
    if (!result.changed) {
      this.updateCloudSyncState({ status: '同步成功', finished: true, success: true });
    }
    if (this.hasCompleteSteamGuardData(this.tokens) && !steamResult.changed) {
      this.updateSteamCloudSyncState({
        status: '同步成功（上传0条，下载0条）',
        finished: true,
        success: true,
        uploadTotal: 0,
        uploadSuccess: 0,
        uploadFailed: 0,
        downloadTotal: 0,
        downloadSuccess: 0,
        downloadFailed: 0
      });
    }
  }

  private beginCloudSync(status: string): void {
    this.cloudSyncing = true;
    this.tokenCloudSyncing = true;
    this.cloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private updateCloudSyncState(state: CloudSyncState): void {
    this.cloudSyncStatus = state.finished && !state.success ? (state.message || state.status) : state.status;
    this.cloudLastSyncTime = Date.now();
    if (state.finished) {
      this.tokenCloudSyncing = false;
      this.cloudSyncing = this.steamCloudSyncing;
    }
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private showCloudSyncFailure(): void {
    this.showToast(`操作失败-${this.cloudSyncStatus}`);
  }

  private finishCloudSyncFailure(status: string, showOperationToast: boolean): void {
    this.tokenCloudSyncing = false;
    this.cloudSyncing = this.steamCloudSyncing;
    this.cloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
    if (showOperationToast) {
      this.showToast(`操作失败-${status}`);
    }
  }

  private finishSteamSupplementalWarning(status: string, showOperationToast: boolean): void {
    this.steamCloudSyncing = false;
    this.cloudSyncing = this.tokenCloudSyncing;
    this.steamCloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
    console.error(status);
    if (showOperationToast) {
      this.showToast(status);
    }
  }

  private beginSteamCloudSync(status: string): void {
    this.cloudSyncing = true;
    this.steamCloudSyncing = true;
    this.steamCloudSyncStatus = status;
    this.cloudLastSyncTime = Date.now();
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private updateSteamCloudSyncState(state: CloudSyncState): void {
    this.steamCloudSyncStatus = state.finished && !state.success ? (state.message || state.status) : state.status;
    this.cloudLastSyncTime = Date.now();
    if (state.finished) {
      this.steamCloudSyncing = false;
      this.cloudSyncing = this.tokenCloudSyncing;
    }
    this.cloudSyncRefreshKey += 1;
    this.saveSettings();
  }

  private hasSteamTokens(records: TokenRecord[]): boolean {
    return records.some((record: TokenRecord): boolean => this.normalizeTokenType(record.type) === 'Steam');
  }

  private hasCompleteSteamGuardData(records: TokenRecord[]): boolean {
    return records.some((record: TokenRecord): boolean => {
      return this.normalizeTokenType(record.type) === 'Steam' && !!record.steamData && record.steamData.length > 0;
    });
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
      mergedRecords.push(cloudRecord ? this.mergeCloudToken(localRecord, cloudRecord) : localRecord);
      usedIds.add(localRecord.id);
    }
    for (const cloudRecord of cloudRecords) {
      if (cloudRecord.id.length > 0 && !usedIds.has(cloudRecord.id)) {
        mergedRecords.push(cloudRecord);
      }
    }
    return mergedRecords;
  }

  private mergeCloudToken(localRecord: TokenRecord, cloudRecord: TokenRecord): TokenRecord {
    return {
      id: cloudRecord.id,
      name: cloudRecord.name,
      remark: cloudRecord.remark,
      type: cloudRecord.type,
      algorithm: cloudRecord.algorithm,
      secret: cloudRecord.secret,
      logoUri: cloudRecord.logoUri,
      logoLightUri: cloudRecord.logoLightUri,
      logoDarkUri: cloudRecord.logoDarkUri,
      logoSource: cloudRecord.logoSource,
      digits: cloudRecord.digits,
      period: cloudRecord.period,
      counter: cloudRecord.counter,
      steamData: localRecord.steamData,
      createdAt: cloudRecord.createdAt,
      modifiedTime: Date.now()
    };
  }

  private shouldShowCloudDisabledHint(): boolean {
    return this.cloudSyncStatus.indexOf('未启用') >= 0 || this.cloudSyncStatus.indexOf('（3）') >= 0 ||
      this.cloudSyncStatus.indexOf('(3)') >= 0 || this.steamCloudSyncStatus.indexOf('未启用') >= 0 ||
      this.steamCloudSyncStatus.indexOf('（3）') >= 0 || this.steamCloudSyncStatus.indexOf('(3)') >= 0;
  }

  private cloudLastSyncTimeText(): string {
    if (this.cloudLastSyncTime <= 0) {
      return '暂无记录';
    }
    const date = new Date(this.cloudLastSyncTime);
    return `${date.getFullYear()}-${this.twoDigit(date.getMonth() + 1)}-${this.twoDigit(date.getDate())} ` +
      `${this.twoDigit(date.getHours())}:${this.twoDigit(date.getMinutes())}`;
  }

  private watchLastPushTimeText(): string {
    if (this.watchLastPushTime <= 0) {
      return this.t('暂无记录');
    }
    const date = new Date(this.watchLastPushTime);
    return `${date.getFullYear()}-${this.twoDigit(date.getMonth() + 1)}-${this.twoDigit(date.getDate())} ` +
      `${this.twoDigit(date.getHours())}:${this.twoDigit(date.getMinutes())}`;
  }

  private watchLanCountdownText(): string {
    const seconds = Math.max(0, Math.ceil((this.watchLanExpiresAt - this.currentTimeMs) / 1000));
    return this.tf('配对码剩余{0}秒', [seconds.toString()]);
  }

  private showWatchHomePage(index: WatchHomePage): void {
    if (this.watchHomePageIndex === index) {
      return;
    }
    this.watchHomePageIndex = index;
    this.requestWatchFocus(index === WatchHomePage.Tokens ?
      WATCH_TOKEN_FOCUS_KEY : WATCH_FEATURE_FOCUS_KEY, 80);
  }

  private requestWatchFocus(key: string, delayMs: number): void {
    this.scheduleWatchFocusRequest(key, delayMs);
    this.scheduleWatchFocusRequest(key, delayMs + 240);
  }

  private scheduleWatchFocusRequest(key: string, delayMs: number): void {
    setTimeout(() => {
      if (key === WATCH_LAN_SYNC_FOCUS_KEY && !this.watchLanSyncPageVisible) {
        return;
      }
      if (key === WATCH_TOKEN_FOCUS_KEY &&
        (this.watchLanSyncPageVisible || this.watchHomePageIndex !== WatchHomePage.Tokens)) {
        return;
      }
      if (key === WATCH_FEATURE_FOCUS_KEY &&
        (this.watchLanSyncPageVisible || this.watchHomePageIndex !== WatchHomePage.Features)) {
        return;
      }
      try {
        const focusController = this.getUIContext().getFocusController();
        focusController.activate(true, false);
        if (!focusControl.requestFocus(key)) {
          focusController.requestFocus(key);
        }
      } catch (error) {
        console.error('Failed to focus watch page: ' + JSON.stringify(error));
      }
    }, delayMs);
  }

  private handleWatchCrown(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE || this.watchLanSyncPageVisible) {
      return;
    }
    const scrollDelta = -event.degree * 2;
    if (Math.abs(scrollDelta) < 0.01) {
      return;
    }
    if (this.watchHomePageIndex === WatchHomePage.Features) {
      this.watchFeatureScroller.scrollBy(0, scrollDelta);
    } else {
      this.watchScroller.scrollBy(0, scrollDelta);
    }
    this.playWatchCrownHaptic();
    event.stopPropagation();
  }

  private playWatchCrownHaptic(): void {
    const now = Date.now();
    if (now - this.watchCrownLastHapticAt < 24) {
      return;
    }
    this.watchCrownLastHapticAt = now;
    try {
      vibrator.startVibration({
        type: 'preset',
        effectId: vibrator.EffectId.EFFECT_CLOCK_TIMER,
        count: 1
      }, {
        usage: 'physicalFeedback'
      }, () => {
      });
    } catch (error) {
      console.warn('Failed to play watch crown haptic: ' + JSON.stringify(error));
    }
  }

  private async exitWatchApp(): Promise<void> {
    if (this.watchLanSyncPageVisible || this.watchHomePageIndex !== WatchHomePage.Tokens) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    try {
      await context.terminateSelf();
    } catch (error) {
      console.error('Failed to exit watch app: ' + JSON.stringify(error));
    }
  }

  private openWatchLanSyncPage(): void {
    if (this.watchLanSyncPageVisible) {
      return;
    }
    this.watchLanSyncPageVisible = true;
    this.watchLanStatus = '';
    this.requestWatchFocus(WATCH_LAN_SYNC_FOCUS_KEY, 80);
    this.startLanWatchReceiver();
  }

  private closeWatchLanSyncPage(): void {
    this.watchLanSyncPageVisible = false;
    this.stopLanWatchReceiver();
    this.requestWatchFocus(WATCH_FEATURE_FOCUS_KEY, 80);
  }

  private async startLanWatchReceiver(): Promise<void> {
    if (this.watchLanReceiving) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.watchLanStatus = '局域网同步不可用';
      return;
    }

    this.watchLanReceiving = true;
    this.watchLanQrText = '';
    this.watchLanExpiresAt = 0;
    this.watchLanStatus = '正在创建配对码';
    const receiver = new LanWatchReceiver();
    this.lanWatchReceiver = receiver;
    try {
      const pairing: LanWatchPairingInfo = await receiver.start(
        context,
        async (records: TokenRecord[]): Promise<boolean> => {
          return await this.applyWearSyncPayload(records);
        },
        (state: LanWatchReceiverState): void => {
          if (this.lanWatchReceiver === receiver) {
            this.updateLanWatchReceiverState(state);
          }
        }
      );
      if (this.lanWatchReceiver !== receiver) {
        await receiver.stop();
        return;
      }
      this.watchLanQrText = pairing.qrText;
      this.watchLanExpiresAt = pairing.expiresAt;
      this.watchLanStatus = '等待手机连接';
    } catch (error) {
      if (this.lanWatchReceiver === receiver) {
        this.lanWatchReceiver = undefined;
        this.watchLanReceiving = false;
        this.watchLanQrText = '';
        this.watchLanExpiresAt = 0;
        this.watchLanStatus = '局域网同步不可用';
        this.showToast('请确认手表已连接Wi-Fi');
      }
    }
  }

  private async stopLanWatchReceiver(): Promise<void> {
    const receiver = this.lanWatchReceiver;
    this.lanWatchReceiver = undefined;
    if (receiver) {
      await receiver.stop();
    }
    if (this.lanWatchReceiver !== undefined) {
      return;
    }
    this.watchLanReceiving = false;
    this.watchLanQrText = '';
    this.watchLanExpiresAt = 0;
    if (this.watchLanStatus === '等待手机连接' || this.watchLanStatus === '正在接收' ||
      this.watchLanStatus === '正在创建配对码') {
      this.watchLanStatus = '已取消';
    }
  }

  private updateLanWatchReceiverState(state: LanWatchReceiverState): void {
    if (state === LanWatchReceiverState.Waiting) {
      this.watchLanStatus = '等待手机连接';
      return;
    }
    if (state === LanWatchReceiverState.Receiving) {
      this.watchLanStatus = '正在接收';
      return;
    }
    if (state === LanWatchReceiverState.InvalidData) {
      this.watchLanStatus = '收到无效同步数据';
      return;
    }
    if (state === LanWatchReceiverState.Success) {
      this.lanWatchReceiver = undefined;
      this.watchLanReceiving = false;
      this.watchLanQrText = '';
      this.watchLanExpiresAt = 0;
      this.watchLanStatus = '接收成功';
      this.showToast('接收成功');
      return;
    }
    if (state === LanWatchReceiverState.Expired) {
      this.lanWatchReceiver = undefined;
      this.watchLanReceiving = false;
      this.watchLanQrText = '';
      this.watchLanExpiresAt = 0;
      this.watchLanStatus = '配对码已过期';
      return;
    }
    if (state === LanWatchReceiverState.Failed) {
      this.lanWatchReceiver = undefined;
      this.watchLanReceiving = false;
      this.watchLanQrText = '';
      this.watchLanExpiresAt = 0;
      this.watchLanStatus = '局域网同步不可用';
    }
  }

  private openWatchTokenPicker(): void {
    this.pendingWatchTokenIds = this.validWatchSelectedTokenIds();
    this.bumpSheetSelectionRevision();
    this.showWatchTokenPicker = true;
  }

  private validWatchSelectedTokenIds(): string[] {
    return this.watchSelectedTokenIds.filter((id: string) => {
      return this.tokens.some((token: TokenRecord) => token.id === id);
    });
  }

  private pendingWatchTokenIndex(tokenId: string): number {
    return this.pendingWatchTokenIds.indexOf(tokenId);
  }

  private togglePendingWatchToken(tokenId: string): void {
    const index = this.pendingWatchTokenIndex(tokenId);
    if (index >= 0) {
      this.pendingWatchTokenIds = this.pendingWatchTokenIds.filter((id: string) => id !== tokenId);
    } else {
      this.pendingWatchTokenIds = this.pendingWatchTokenIds.concat([tokenId]);
    }
    this.bumpSheetSelectionRevision();
  }

  private commitWatchTokenSelection(): void {
    this.watchSelectedTokenIds = this.pendingWatchTokenIds;
    this.pendingWatchTokenIds = [];
    this.showWatchTokenPicker = false;
    this.saveSettings();
    this.showToast('已保存');
  }

  private watchSelectedTokens(): TokenRecord[] {
    if (this.watchSelectedTokenIds.length === 0) {
      return [];
    }
    const records: TokenRecord[] = [];
    this.watchSelectedTokenIds.forEach((id: string) => {
      const token = this.tokens.find((item: TokenRecord) => item.id === id);
      if (token) {
        records.push(token);
      }
    });
    return records;
  }

  private watchVisibleTokens(): TokenRecord[] {
    const selectedTokens = this.watchSelectedTokens();
    return selectedTokens.length > 0 ? selectedTokens : this.tokens;
  }

  private watchTokenSelectionSummary(): string {
    const selectedTokens = this.watchSelectedTokens();
    if (selectedTokens.length === 0) {
      return this.t('未选择令牌');
    }
    return selectedTokens.map((token: TokenRecord) => this.tokenDisplayName(token)).join('、');
  }

  private async pushTokensToWear(): Promise<void> {
    if (this.watchPushing) {
      return;
    }
    const selectedTokens = this.watchSelectedTokens();
    if (selectedTokens.length === 0) {
      this.showToast('请至少选择1个令牌');
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('推送失败');
      return;
    }
    this.watchPushing = true;
    this.watchPushStatus = '推送中';
    this.saveSettings();
    try {
      const devices = await this.connectedWearDevices(context);
      if (devices.length === 0) {
        this.finishWatchPush(false, '未发现已连接手表');
        return;
      }
      const appParam = await this.wearP2pAppParam();
      const p2pClient = wearEngine.getP2pClient(context);
      const payload: WatchSyncPayload = {
        action: WATCH_SYNC_ACTION,
        version: 1,
        tokens: watchTransferRecords(selectedTokens),
        pushedAt: Date.now()
      };
      const message: wearEngine.P2pMessage = {
        content: util.TextEncoder.create('utf-8').encodeInto(JSON.stringify(payload))
      };
      let successCount = 0;
      let lastFailure = '';
      for (let index = 0; index < devices.length; index++) {
        const device = devices[index];
        try {
          await p2pClient.startRemoteApp(device.randomId, appParam.remoteApp.bundleName, false);
        } catch (error) {
        }
        try {
          const result = await p2pClient.sendMessage(device.randomId, appParam, message);
          if (this.isWearP2pSuccess(result.code)) {
            successCount += 1;
          } else {
            lastFailure = this.wearP2pResultText(result.code);
          }
        } catch (error) {
          lastFailure = this.wearEngineErrorText(error);
        }
      }
      if (successCount > 0) {
        this.finishWatchPush(true, this.tf('推送成功（{0}台设备）', [`${successCount}`]));
      } else {
        this.finishWatchPush(false, lastFailure.length > 0 ? lastFailure : '推送失败');
      }
    } catch (error) {
      this.finishWatchPush(false, this.wearEngineErrorText(error));
    }
  }

  private async pushTokensToWatchOverLan(): Promise<void> {
    if (this.watchPushing || this.isScanning) {
      return;
    }
    const selectedTokens = this.watchSelectedTokens();
    if (selectedTokens.length === 0) {
      this.showToast('请至少选择1个令牌');
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('推送失败');
      return;
    }

    this.watchPushing = true;
    this.watchPushStatus = '等待扫描手表配对码';
    this.isScanning = true;
    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      });
      this.watchPushStatus = '正在通过局域网同步';
      const count = await LanWatchSender.push(context, result.originalValue, selectedTokens);
      const successText = this.tf('同步成功（{0}个令牌）', [count.toString()]);
      this.finishWatchPush(true, successText, successText);
    } catch (error) {
      const code = this.getErrorCode(error);
      if (code === scanCore.ScanErrorCode.SCAN_SERVICE_CANCELED) {
        this.watchPushing = false;
        this.watchPushStatus = '已取消';
        this.saveSettings();
      } else {
        this.finishWatchPush(false, this.lanWatchSyncErrorText(error));
      }
    } finally {
      this.isScanning = false;
    }
  }

  private lanWatchSyncErrorText(error: Object): string {
    const text = error.toString();
    if (text.indexOf('LAN_SYNC_INVALID_PAIRING_CODE') >= 0) {
      return '这不是OpenAuthenticator手表配对码';
    }
    if (text.indexOf('LAN_SYNC_SESSION_EXPIRED') >= 0) {
      return '手表配对码已过期';
    }
    if (text.indexOf('LAN_SYNC_DISCOVERY_TIMEOUT') >= 0 ||
      text.indexOf('LAN_SYNC_SERVICE_UNAVAILABLE') >= 0) {
      return '未发现手表，请确认连接同一Wi-Fi';
    }
    if (text.indexOf('LAN_SYNC_MESSAGE_TOO_LARGE') >= 0) {
      return '令牌数据过大，无法同步';
    }
    if (text.indexOf('LAN_SYNC_RESPONSE_TIMEOUT') >= 0 ||
      text.indexOf('LAN_SYNC_CONNECTION') >= 0) {
      return '手表连接超时，请重试';
    }
    if (text.indexOf('LAN_SYNC_REJECTED') >= 0) {
      return '手表拒绝了同步数据';
    }
    return '局域网同步失败';
  }

  private finishWatchPush(success: boolean, status: string, successToast: string = '操作成功，同步中'): void {
    this.watchPushing = false;
    this.watchPushStatus = status;
    this.watchLastPushTime = Date.now();
    this.saveSettings();
    this.showToast(success ? successToast : status);
  }

  private async connectedWearDevices(context: common.UIAbilityContext): Promise<wearEngine.Device[]> {
    const deviceClient = wearEngine.getDeviceClient(context);
    const devices = await deviceClient.getConnectedDevices();
    return devices.filter((device: wearEngine.Device) => {
      return device.category === wearEngine.DeviceCategory.WATCH ||
        device.category === wearEngine.DeviceCategory.BAND ||
        device.isSmartWatch === true;
    });
  }

  private async wearP2pAppParam(): Promise<wearEngine.P2pAppParam> {
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO
    );
    return {
      remoteApp: {
        bundleName: bundleInfo.name,
        fingerprint: bundleInfo.signatureInfo.fingerprint
      },
      transformLocalAppInfo: false
    };
  }

  private isWearP2pSuccess(code?: number): boolean {
    return code === wearEngine.P2pResultCode.COMMUNICATION_SUCCESS ||
      code === wearEngine.P2pResultCode.REMOTE_APP_RUNNING;
  }

  private wearP2pResultText(code?: number): string {
    if (code === wearEngine.P2pResultCode.REMOTE_APP_NOT_INSTALLED) {
      return '手表端应用未安装';
    }
    if (code === wearEngine.P2pResultCode.REMOTE_APP_NOT_RUNNING) {
      return '手表端应用未运行';
    }
    if (code === wearEngine.P2pResultCode.COMMUNICATION_FAILURE) {
      return '手表通信失败';
    }
    return code === undefined ? '推送失败' : `推送失败（${code}）`;
  }

  private wearEngineErrorText(error: Object): string {
    const code = this.getErrorCode(error);
    if (code === 1008500002 || code === 1008500003 || code === 1008500010) {
      return '未发现已连接手表';
    }
    if (code === 1008500004) {
      return 'Wear Engine服务未开通';
    }
    if (code === 1008500006) {
      return '用户未同意隐私协议';
    }
    if (code === 1008500008 || code === 1008500009) {
      return '请先登录华为账号';
    }
    return code > 0 ? `推送失败（${code}）` : '推送失败';
  }

  private async registerWearSyncReceivers(): Promise<void> {
    if (!this.isWatchLayout() || this.wearMessageReceivers.length > 0) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    try {
      const devices = await this.connectedWearDevices(context);
      if (devices.length === 0) {
        return;
      }
      const p2pClient = wearEngine.getP2pClient(context);
      const appParam = await this.wearP2pAppParam();
      for (let index = 0; index < devices.length; index++) {
        const device = devices[index];
        const callback = (message: wearEngine.P2pMessage): void => {
          this.receiveWearSyncMessage(message);
        };
        await p2pClient.registerMessageReceiver(device.randomId, appParam, callback);
        this.wearMessageReceivers.push({
          deviceId: device.randomId,
          appParam: appParam,
          callback: callback
        });
      }
      this.watchReceiverStatus = '已连接';
    } catch (error) {
      this.watchReceiverStatus = this.wearEngineErrorText(error);
      console.error(`Failed to register wear sync receiver: ${JSON.stringify(error)}`);
    }
  }

  private async unregisterWearSyncReceivers(): Promise<void> {
    if (this.wearMessageReceivers.length === 0) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.wearMessageReceivers = [];
      return;
    }
    const p2pClient = wearEngine.getP2pClient(context);
    for (let index = 0; index < this.wearMessageReceivers.length; index++) {
      const receiver = this.wearMessageReceivers[index];
      try {
        await p2pClient.unregisterMessageReceiver(receiver.deviceId, receiver.appParam, receiver.callback);
      } catch (error) {
      }
    }
    this.wearMessageReceivers = [];
  }

  private receiveWearSyncMessage(message: wearEngine.P2pMessage): void {
    try {
      const text = util.TextDecoder.create('utf-8').decodeToString(message.content);
      const payload = JSON.parse(text) as WatchSyncPayload;
      if (payload.action !== WATCH_SYNC_ACTION || !Array.isArray(payload.tokens)) {
        return;
      }
      this.applyWearSyncPayload(payload.tokens);
    } catch (error) {
      this.watchReceiverStatus = '手表端接收失败';
      console.error(`Failed to receive wear sync message: ${JSON.stringify(error)}`);
    }
  }

  private async applyWearSyncPayload(records: TokenRecord[]): Promise<boolean> {
    const validRecords = this.uniqueTokenRecordsWithValidation(records, false);
    if (validRecords.length === 0) {
      return false;
    }
    if (await this.persistTokens(validRecords, '')) {
      this.watchSelectedTokenIds = validRecords.map((token: TokenRecord) => token.id);
      this.watchPushStatus = '接收成功';
      this.watchLastPushTime = Date.now();
      this.saveSettings();
      this.hydrateMissingTokenLogos();
      return true;
    }
    return false;
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
      const status = manager.getSelfPermissionStatus(DATA_SYNC_PERMISSION);
      if (status === abilityAccessCtrl.PermissionStatus.GRANTED) {
        return true;
      }
      if (status === abilityAccessCtrl.PermissionStatus.DENIED) {
        const settingResults = await manager.requestPermissionOnSetting(context, [DATA_SYNC_PERMISSION]);
        return settingResults.length > 0 &&
          settingResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      }
      if (status !== abilityAccessCtrl.PermissionStatus.NOT_DETERMINED) {
        console.error('Data sync permission is unavailable, status=' + status.toString());
        return false;
      }

      await this.delay(80);
      const result = await manager.requestPermissionsFromUser(context, [DATA_SYNC_PERMISSION]);
      if (result.authResults.length > 0 &&
        result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }

      let dialogShown = false;
      if (result.dialogShownResults && result.dialogShownResults.length > 0) {
        dialogShown = result.dialogShownResults[0];
      }
      if (!dialogShown &&
        manager.getSelfPermissionStatus(DATA_SYNC_PERMISSION) === abilityAccessCtrl.PermissionStatus.DENIED) {
        const settingResults = await manager.requestPermissionOnSetting(context, [DATA_SYNC_PERMISSION]);
        return settingResults.length > 0 &&
          settingResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      }
      return false;
    } catch (error) {
      console.error(`Failed to request data sync permission: ${JSON.stringify(error)}`);
      return false;
    }
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
      token.remark.trim().length > 0 ? `${token.remark}:${token.name}` : token.name
    );
    const params: string[] = [
      `secret=${encodeURIComponent(token.secret)}`,
      `algorithm=${token.algorithm || 'SHA1'}`,
      `digits=${this.tokenDigitsForRecord(token)}`,
      `period=${this.tokenPeriodForRecord(token)}`
    ];
    if (token.remark.trim().length > 0) {
      params.push(`issuer=${encodeURIComponent(token.remark)}`);
    }
    if (type === 'hotp') {
      params.push(`counter=${this.tokenCounterForRecord(token)}`);
    }
    return `otpauth://${type}/${label}?${params.join('&')}`;
  }

  private exportSelectedTokens(): TokenRecord[] {
    return this.tokens.filter((t: TokenRecord) => this.exportSelectedIds.includes(t.id));
  }

  private exportSelectedSteamTokens(): TokenRecord[] {
    return this.exportSelectedTokens().filter((token: TokenRecord) => {
      return this.normalizeTokenType(token.type) === 'Steam';
    });
  }

  private exportFormatOptionsHeight(): number {
    const rowCount = this.exportSelectedSteamTokens().length > 0 ? 3 : 2;
    return ME_ROW_HEIGHT * rowCount + rowCount - 1;
  }

  private exportFormatSheetHeight(): number {
    const extraHeight = this.exportSelectedSteamTokens().length > 0 ? ME_ROW_HEIGHT : 0;
    return this.sheetShortHeight(SHEET_EXPORT_FORMAT_HEIGHT + extraHeight);
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

  private async copyQQGroupNumber(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, QQ_GROUP_NUMBER);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showToast('群号已复制');
    } catch (error) {
      console.error('Copy QQ group number failed: ' + JSON.stringify(error));
      this.showToast('复制失败');
    }
  }

  private async saveQQGroupQRCode(): Promise<void> {
    if (this.isSavingQQGroupQRCode) {
      return;
    }
    this.isSavingQQGroupQRCode = true;
    try {
      await this.saveRawImageToGallery('qq_group_qr.png', 'OpenAuthenticator_QQ_Group');
    } finally {
      this.isSavingQQGroupQRCode = false;
    }
  }

  private async saveRawImageToGallery(rawFileName: string, title: string): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('保存图片失败');
      return;
    }
    const path = context.filesDir + '/' + title + '_' + Date.now().toString() + '.png';
    let completed = false;
    try {
      const rawData = await context.resourceManager.getRawFileContent(rawFileName);
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, rawData.buffer);
      } finally {
        fileIo.closeSync(file);
      }
      const sourceUris: string[] = [fileUri.getUriFromPath(path)];
      const settings: photoAccessHelper.CreationSetting[] = [{
        title: title,
        fileNameExtension: 'png',
        photoType: photoAccessHelper.PhotoType.IMAGE
      }];
      const savedUris = await photoAccessHelper.getPhotoAccessHelper(context).showAssetsCreationDialogEx(
        sourceUris,
        settings
      );
      if (savedUris.length === 0 || this.copyTemporaryImagesToGallery([path], savedUris) === 0) {
        this.showToast('保存图片失败');
        return;
      }
      completed = true;
      this.showToast('图片已保存到图库');
    } catch (error) {
      console.error('Save bundled image failed: ' + JSON.stringify(error));
      this.showToast('保存图片失败');
    } finally {
      if (completed) {
        setTimeout(() => {
          this.cleanupTemporaryFiles([path]);
        }, 10000);
      } else {
        this.cleanupTemporaryFiles([path]);
      }
    }
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
        'issuer': token.remark,
        'account': token.name,
        'secret': token.secret,
        'type': this.normalizeTokenType(token.type),
        'algorithm': token.algorithm || 'SHA1',
        'digits': this.tokenDigitsForRecord(token),
        'period': this.tokenPeriodForRecord(token),
        'counter': this.tokenCounterForRecord(token)
      };
      if (this.normalizeTokenType(token.type) === 'Steam' && token.steamData && token.steamData.length > 0) {
        const steam = parseSteamGuardData(token.steamData);
        portableToken['steamData'] = token.steamData;
        portableToken['shared_secret'] = steam.sharedSecret;
        portableToken['identity_secret'] = steam.identitySecret;
        portableToken['device_id'] = steam.deviceId;
        portableToken['steamid'] = steam.steamId;
        portableToken['access_token'] = steam.accessToken;
        portableToken['refresh_token'] = steam.refreshToken;
        portableToken['session_id'] = steam.sessionId;
        portableToken['revocation_code'] = steam.revocationCode;
        portableToken['serial_number'] = steam.serialNumber;
        portableToken['steam_uri'] = steam.uri;
        portableToken['server_time'] = steam.serverTime;
        portableToken['token_gid'] = steam.tokenGid;
        portableToken['secret_1'] = steam.secret1;
        portableToken['status'] = steam.status;
        portableToken['fully_enrolled'] = steam.fullyEnrolled;
        portableToken['maFile'] = steam.maFile;
      }
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
    const fileName = `OpenAuthenticator_backup_${this.formatExportDate()}.json`;
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

  private steamMaFileContent(token: TokenRecord): string {
    const data = parseSteamGuardData(token.steamData || '');
    if (data.sharedSecret.length === 0) {
      data.sharedSecret = token.secret;
    }
    if (data.accountName.length === 0) {
      data.accountName = token.remark.trim().length > 0 ? token.remark : token.name;
    }
    if (data.maFile.trim().length > 0 && parseSdaMaFile(data.maFile).sharedSecret.length > 0) {
      return data.maFile.trim();
    }
    return createSdaMaFile(data);
  }

  private steamMaFileName(token: TokenRecord, index: number): string {
    const data = parseSteamGuardData(token.steamData || '');
    if (/^\d+$/.test(data.steamId)) {
      return data.steamId + '.maFile';
    }
    const accountName = data.accountName.length > 0 ? data.accountName : token.name;
    const safeName = accountName.replace(/[\\/:*?"<>|]/g, '_').trim();
    return (safeName.length > 0 ? safeName : 'Steam_' + (index + 1).toString()) + '.maFile';
  }

  private async exportSteamMaFiles(): Promise<void> {
    const steamTokens = this.exportSelectedSteamTokens();
    if (steamTokens.length === 0) {
      this.showToast('没有选中的 Steam 令牌');
      return;
    }
    const contents: string[] = [];
    const fileNames: string[] = [];
    for (let index = 0; index < steamTokens.length; index++) {
      const content = this.steamMaFileContent(steamTokens[index]);
      if (parseSdaMaFile(content).sharedSecret.length === 0) {
        this.showToast('Steam 令牌缺少可导出的验证器密钥');
        return;
      }
      contents.push(content);
      fileNames.push(this.steamMaFileName(steamTokens[index], index));
    }
    try {
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = fileNames;
      options.fileSuffixChoices = ['Steam maFile|.maFile'];
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.save(options);
      const savedCount = Math.min(result.length, contents.length);
      for (let index = 0; index < savedCount; index++) {
        const file = fileIo.openSync(result[index], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
        try {
          fileIo.writeSync(file.fd, contents[index]);
        } finally {
          fileIo.closeSync(file);
        }
      }
      if (savedCount > 0) {
        this.showToast(savedCount === 1 ? 'Steam maFile 已导出' :
          this.tf('已导出 {0} 个 Steam maFile', [savedCount.toString()]));
      }
    } catch (error) {
      this.showToast('Steam maFile 导出失败');
      console.error('Export Steam maFile failed: ' + JSON.stringify(error));
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

  private async pickCustomBackground(): Promise<void> {
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
      const materializedUri = await this.persistPickedBackground(context, pickedUri);
      if (materializedUri.length === 0) {
        this.showToast('背景图保存失败');
        return;
      }
      const backgroundPrepared = await this.prepareCustomBackground(materializedUri);
      if (!backgroundPrepared) {
        this.showToast('背景图加载失败');
        return;
      }
      this.commitCustomBackground(materializedUri);
      this.saveSettings();
      const persistedUri = await this.persistPreparedCustomBackground(context);
      if (persistedUri.length > 0) {
        this.commitCustomBackground(persistedUri);
        this.saveSettings();
      }
    } catch (error) {
      this.showToast('选择背景图失败');
      console.error('Failed to pick background: ' + JSON.stringify(error));
    }
  }

  private async activateCustomBackground(): Promise<void> {
    if (this.customBackgroundUri.length === 0) {
      return;
    }
    const backgroundPrepared = await this.prepareCustomBackground(this.customBackgroundUri);
    if (!backgroundPrepared) {
      this.showToast('背景图加载失败');
      return;
    }
    this.commitCustomBackground(this.customBackgroundUri);
    this.saveSettings();
  }

  private commitCustomBackground(uri: string): void {
    this.customBackgroundPixelMapUri = uri;
    this.customBackgroundUri = uri;
    this.backgroundSelection = 'custom';
    this.customBackgroundRenderVersion = this.customBackgroundRenderVersion + 1;
  }

  private async prepareCustomBackground(uri: string): Promise<boolean> {
    if (this.customBackgroundPixelMap !== undefined && this.customBackgroundPixelMapUri === uri) {
      return true;
    }
    const loadSerial = this.customBackgroundLoadSerial + 1;
    this.customBackgroundLoadSerial = loadSerial;
    let sourceFile: fileIo.File | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      sourceFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      imageSource = image.createImageSource(sourceFile.fd);
      const imageInfo: image.ImageInfo = await imageSource.getImageInfo();
      const screen: display.Display = display.getDefaultDisplaySync();
      const sourceLongEdge = Math.max(imageInfo.size.width, imageInfo.size.height);
      const targetLongEdge = Math.max(screen.width, screen.height);
      let pixelMap: image.PixelMap;
      if (sourceLongEdge > targetLongEdge && targetLongEdge > 0) {
        const decodeScale = targetLongEdge / sourceLongEdge;
        const desiredSize: image.Size = {
          width: Math.max(1, Math.round(imageInfo.size.width * decodeScale)),
          height: Math.max(1, Math.round(imageInfo.size.height * decodeScale))
        };
        const options: image.DecodingOptions = {
          desiredSize: desiredSize,
          editable: false
        };
        pixelMap = await imageSource.createPixelMap(options);
      } else {
        pixelMap = await imageSource.createPixelMap();
      }
      if (loadSerial !== this.customBackgroundLoadSerial) {
        pixelMap.release();
        return false;
      }
      const previousPixelMap = this.customBackgroundPixelMap;
      this.customBackgroundPixelMap = pixelMap;
      this.customBackgroundPixelMapUri = uri;
      if (previousPixelMap !== undefined) {
        previousPixelMap.release();
      }
      return true;
    } catch (error) {
      console.error('Failed to preload custom background: ' + JSON.stringify(error));
      return false;
    } finally {
      if (imageSource !== undefined) {
        await imageSource.release();
      }
      if (sourceFile !== undefined) {
        fileIo.closeSync(sourceFile);
      }
    }
  }

  private async persistPickedBackground(context: common.UIAbilityContext, uri: string): Promise<string> {
    const targetPath = context.filesDir + '/background_' + Date.now().toString() + '.jpg';
    let sourceFile: fileIo.File | undefined = undefined;
    try {
      sourceFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      await fileIo.copyFile(sourceFile.fd, targetPath);
      return fileUri.getUriFromPath(targetPath);
    } catch (error) {
      console.error('Failed to materialize picked background: ' + JSON.stringify(error));
      return '';
    } finally {
      if (sourceFile !== undefined) {
        fileIo.closeSync(sourceFile);
      }
    }
  }

  private isOptimizedCustomBackgroundUri(uri: string): boolean {
    return uri.indexOf(CUSTOM_BACKGROUND_CACHE_PREFIX) >= 0;
  }

  private async persistPreparedCustomBackground(context: common.UIAbilityContext): Promise<string> {
    if (this.customBackgroundPixelMap === undefined) {
      return '';
    }
    const targetPath = context.filesDir + '/' + CUSTOM_BACKGROUND_CACHE_PREFIX + Date.now().toString() + '.jpg';
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const jpegData: ArrayBuffer = await packer.packToData(this.customBackgroundPixelMap, {
        format: 'image/jpeg',
        quality: 92
      });
      const targetFile = fileIo.openSync(targetPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(targetFile.fd, jpegData);
      } finally {
        fileIo.closeSync(targetFile);
      }
      return fileUri.getUriFromPath(targetPath);
    } catch (error) {
      console.error('Failed to cache prepared background: ' + JSON.stringify(error));
      return '';
    } finally {
      await packer.release();
    }
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
    this.setOnboardingSystemBars(false);
    this.onboardingCompleted = true;
    this.showOnboarding = false;
    this.saveSettings();
    this.loadTokens();
    this.scheduleUpdateNoticePresentation();
  }

  private async setOnboardingSystemBars(forceDark: boolean): Promise<void> {
    AppStorage.setOrCreate<boolean>(FORCE_DARK_SYSTEM_BARS_KEY, forceDark);
    AppStorage.set<boolean>(FORCE_DARK_SYSTEM_BARS_KEY, forceDark);
    const context = this.getAbilityContext();
    if (!context) {
      return;
    }
    try {
      const mainWindow = await window.getLastWindow(context);
      const useDark = forceDark || this.isDarkTheme();
      mainWindow.setWindowBackgroundColor(useDark ? '#FF000000' : '#FFF2F3F5');
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        isStatusBarLightIcon: useDark,
        isNavigationBarLightIcon: useDark,
        navigationBarContentColor: useDark ? '#FFEEEEEE' : '#FF1A1A1A',
        statusBarContentColor: useDark ? '#FFEEEEEE' : '#FF1A1A1A'
      });
    } catch (error) {
      console.error('Failed to update onboarding system bars: ' + JSON.stringify(error));
    }
  }

  private scheduleUpdateNoticePresentation(): void {
    if (!this.settingsLoaded || !this.phoneRootReady || !this.onboardingCompleted || this.showOnboarding ||
      this.updateNoticePresentationTimer >= 0) {
      return;
    }
    this.updateNoticePresentationTimer = setTimeout((): void => {
      this.updateNoticePresentationTimer = -1;
      this.presentUpdateNoticeIfNeeded();
    }, 120);
  }

  private presentUpdateNoticeIfNeeded(): void {
    if (!this.settingsLoaded || !this.phoneRootReady || this.isWatchLayout() ||
      !this.onboardingCompleted || this.showOnboarding ||
      (this.appLockEnabled && this.isLocked) ||
      this.updateNoticeVersion === UPDATE_NOTICE_VERSION || this.showUpdateNotice) {
      return;
    }
    this.showUpdateNotice = true;
  }

  private dismissUpdateNotice(): void {
    this.updateNoticeVersion = UPDATE_NOTICE_VERSION;
    this.showUpdateNotice = false;
    this.saveSettings();
  }

  private onLockStateChanged(): void {
    if (this.appLockEnabled && this.isLocked) {
      this.showUpdateNotice = false;
      return;
    }
    this.scheduleUpdateNoticePresentation();
  }

  private handleMeAction(group: number, index: number): void {
    if (group === 0) {
      if (index === 0) {
        this.homePathStack.pushPath({ name: 'cloudSpace' }, true);
      } else if (index === 1) {
        this.homePathStack.pushPath({ name: 'watchSync' }, true);
      } else if (index === 2) {
        this.exportSelectedIds = [];
        this.bumpSheetSelectionRevision();
        this.showExportPicker = true;
      }
      return;
    }
    if (group === 1) {
      if (index === 0) {
        this.homePathStack.pushPath({ name: 'appearanceSettings' }, true);
      } else {
        this.homePathStack.pushPath({ name: 'featureSecurity' }, true);
      }
      return;
    }
    if (group === 2) {
      if (index === 0) {
        this.homePathStack.pushPath({ name: 'donation' }, true);
      } else {
        this.homePathStack.pushPath({ name: 'moreApps' }, true);
      }
      return;
    }
    if (index === 0) {
      this.openWebSheet('开源地址', 'https://gitcode.com/mroble/Tool_2FA');
    } else if (index === 1) {
      this.openUserAgreementSheet();
    } else if (index === 2) {
      this.openPrivacyLink(privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK, '隐私声明');
    } else {
      this.homePathStack.pushPath({ name: 'about' }, true);
    }
  }

  private openUserAgreementSheet(): void {
    this.showWebSheet = false;
    this.showUserAgreementSheet = true;
  }

  private openWebSheet(title: string, url: string): void {
    this.showUserAgreementSheet = false;
    this.webSheetTitle = title;
    this.webSheetUrl = url;
    this.showWebSheet = true;
    setTimeout(() => {
      this.loadWebSheetUrl();
    }, 120);
  }

  private loadWebSheetUrl(): void {
    if (this.webSheetUrl.length === 0 || this.webSheetUrl === 'about:blank') {
      return;
    }
    try {
      this.webSheetController.loadUrl(this.webSheetUrl);
    } catch (error) {
      console.error('Failed to load sheet web page: ' + JSON.stringify(error));
    }
  }

  private openPrivacyLink(type: privacyManager.AppPrivacyLinkType, label: string): void {
    try {
      const info = privacyManager.getAppPrivacyMgmtInfo();
      for (const link of info.privacyInfo) {
        if (link.type === type && link.url.length > 0) {
          this.openWebSheet(label, link.url);
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

  private async showAppCommentDialog(): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('暂时无法打开应用评论');
      return;
    }
    const commentWant: Want = {
      action: 'ohos.want.action.appdetail',
      uri: 'store://appgallery.huawei.com/app/detail?id=' + APP_BUNDLE_NAME + '&action=write-review'
    };
    hilog.info(APPLOCK_DOMAIN, APP_COMMENT_TAG, 'Opening AppGallery write-review page');
    try {
      await context.startAbility(commentWant);
      hilog.info(APPLOCK_DOMAIN, APP_COMMENT_TAG, 'AppGallery write-review page opened');
    } catch (error) {
      const code = this.getErrorCode(error);
      this.showToast(this.tf('暂时无法打开应用评论（错误码：{0}）', [code.toString()]));
      hilog.error(APPLOCK_DOMAIN, APP_COMMENT_TAG,
        'Failed to open AppGallery write-review page, code=%{public}d, error=%{public}s', code,
        JSON.stringify(error));
    }
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
    if (this.cloudBackupEnabled) {
      this.getUIContext().showAlertDialog({
        title: this.t('删除令牌'),
        message: this.tf('请选择“{0}”的删除范围。', [token.name]),
        autoCancel: true,
        buttons: [
          {
            value: this.t('删除本地及云端'),
            fontColor: ERROR_RED,
            action: () => {
              this.deleteTokenFromLocalAndCloud(token);
            }
          },
          {
            value: this.t('仅从本设备删除'),
            action: () => {
              this.deleteTokenFromLocal(token.id);
            }
          },
          {
            value: this.t('取消'),
            action: () => {
            }
          }
        ],
        buttonDirection: DialogButtonDirection.VERTICAL
      });
      return;
    }
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
          this.deleteTokenFromLocal(token.id);
        }
      }
    });
  }

  private async deleteTokenFromLocal(tokenId: string): Promise<void> {
    const previousTokens = this.tokens.slice();
    const nextTokens = this.tokens.filter((token: TokenRecord) => token.id !== tokenId);
    if (nextTokens.length === this.tokens.length) {
      return;
    }
    if (!this.cloudBackupEnabled) {
      await this.persistTokens(nextTokens, '已删除', false);
      return;
    }
    if (!await this.persistTokens(nextTokens, '', false)) {
      return;
    }
    const context = this.getAbilityContext();
    if (!context || !await TokenRepository.excludeCloudTokenFromLocal(context, tokenId)) {
      await this.persistTokens(previousTokens, '', false);
      this.showToast('仅本机删除失败，已恢复令牌');
      return;
    }
    this.showToast('已从本设备删除');
  }

  private async deleteTokenFromLocalAndCloud(token: TokenRecord): Promise<void> {
    if (this.cloudSyncing) {
      this.showToast('正在同步，请稍候');
      return;
    }
    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('无法访问云空间');
      return;
    }
    const previousTokens = this.tokens.slice();
    const nextTokens = this.tokens.filter((record: TokenRecord) => record.id !== token.id);
    if (nextTokens.length === previousTokens.length) {
      return;
    }
    if (!await this.persistTokens(nextTokens, '', false)) {
      return;
    }
    const restoreAutoSync = this.cloudBackupEnabled;
    this.beginCloudSync('正在删除');
    if (!await this.configureCloudAutoSync(false)) {
      await this.persistTokens(previousTokens, '', false);
      this.finishCloudSyncFailure('云同步不可用', true);
      return;
    }
    const success = await TokenRepository.deleteFromCloud(
      context,
      token,
      (state: CloudSyncState): void => {
        this.updateCloudSyncState(state);
      }
    );
    if (!success) {
      if (restoreAutoSync) {
        await this.configureCloudAutoSync(true);
      }
      await this.persistTokens(previousTokens, '', false);
      this.showToast('云端删除失败，已恢复本地令牌');
      return;
    }

    let steamDeleteSuccess = true;
    if (this.normalizeTokenType(token.type) === 'Steam' && token.steamData && token.steamData.length > 0) {
      steamDeleteSuccess = false;
      if (await SteamGuardCloudRepository.configureCloudSync(context, false)) {
        this.beginSteamCloudSync('正在删除 Steam 完整数据');
        steamDeleteSuccess = await SteamGuardCloudRepository.deleteFromCloud(
          context,
          token.id,
          (state: CloudSyncState): void => {
            this.updateSteamCloudSyncState(state);
          }
        );
      }
    }
    if (restoreAutoSync) {
      await this.configureCloudAutoSync(true);
    }
    if (!steamDeleteSuccess) {
      this.finishSteamSupplementalWarning('Steam 完整数据删除失败', false);
      this.showToast('通用令牌删除成功，Steam 完整数据未删除');
      return;
    }
    this.cloudSyncStatus = '删除成功';
    this.cloudLastSyncTime = Date.now();
    this.saveSettings();
    this.showToast('已删除本地及云端');
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

  private steamService(): SteamService {
    return new SteamService({
      enhancedAccess: this.steamEnhancedAccess,
      gatewayUrl: this.steamGatewayUrl,
      gatewayToken: this.steamGatewayToken
    });
  }

  private steamLoginTokens(): TokenRecord[] {
    return this.tokens.filter((token: TokenRecord) => {
      return this.normalizeTokenType(token.type) === 'Steam' &&
        canUseSteamRemoteFeatures(parseSteamGuardData(token.steamData || ''));
    });
  }

  private steamLoginAccountText(token: TokenRecord): string {
    const data = parseSteamGuardData(token.steamData || '');
    if (!data.fullyEnrolled) {
      return data.accountName.length > 0 ? data.accountName + ' · 等待完成激活' : this.t('等待完成激活');
    }
    if (data.accountName.length > 0) {
      return data.accountName;
    }
    return data.steamId.length > 0 ? 'Steam ID ' + data.steamId : this.t('已验证登录凭据');
  }

  private openSteamLoginPicker(): void {
    const supportedTokens = this.steamLoginTokens().filter((token: TokenRecord): boolean => {
      return parseSteamGuardData(token.steamData || '').fullyEnrolled;
    });
    this.pendingSteamLoginTokenId = supportedTokens.length === 1 ? supportedTokens[0].id : '';
    this.bumpSheetSelectionRevision();
    this.showSteamLoginPicker = true;
  }

  private selectSteamLoginToken(tokenId: string): void {
    this.pendingSteamLoginTokenId = this.pendingSteamLoginTokenId === tokenId ? '' : tokenId;
    this.bumpSheetSelectionRevision();
  }

  private handleSteamLoginTokenSelection(token: TokenRecord): void {
    const data = parseSteamGuardData(token.steamData || '');
    if (!data.fullyEnrolled) {
      this.resumeSteamEnrollment(token, data);
      return;
    }
    this.selectSteamLoginToken(token.id);
  }

  private openSteamEnrollmentFromPicker(): void {
    this.showSteamLoginPicker = false;
    setTimeout(() => {
      this.resetSteamEnrollment();
      this.showSteamEnrollmentSheet = true;
    }, 180);
  }

  private resumeSteamEnrollment(token: TokenRecord, data: SteamGuardData): void {
    this.showSteamLoginPicker = false;
    setTimeout(() => {
      this.resetSteamEnrollment();
      this.steamEnrollmentTokenId = token.id;
      this.steamRecoveryCode = data.revocationCode;
      this.steamAuthenticatorDraft = {
        data: data,
        confirmType: 0,
        phoneNumberHint: '',
        serverTimeReceivedAt: Date.now()
      };
      this.steamEnrollmentStage = STEAM_ENROLLMENT_ACTIVATION;
      this.showSteamEnrollmentSheet = true;
    }, 180);
  }

  private resetSteamEnrollment(): void {
    this.steamEnrollmentStage = STEAM_ENROLLMENT_RISK;
    this.steamRiskAccepted = false;
    this.steamEnrollmentAccount = '';
    this.steamEnrollmentPassword = '';
    this.steamEnrollmentCode = '';
    this.steamEnrollmentGuardType = 0;
    this.steamEnrollmentGuardMessage = '';
    this.steamEnrollmentGuardSubmitted = false;
    this.steamEnrollmentError = '';
    this.steamRecoveryCode = '';
    this.steamRecoverySaved = false;
    this.steamEnrollmentTokenId = '';
    this.steamEnrollmentChallenge = null;
    this.steamEnrollmentSession = null;
    this.steamAuthenticatorDraft = null;
  }

  private resetSteamEnrollmentLogin(): void {
    if (this.steamEnrollmentLoading) {
      return;
    }
    this.steamEnrollmentStage = STEAM_ENROLLMENT_CREDENTIALS;
    this.steamEnrollmentPassword = '';
    this.steamEnrollmentCode = '';
    this.steamEnrollmentGuardType = 0;
    this.steamEnrollmentGuardMessage = '';
    this.steamEnrollmentGuardSubmitted = false;
    this.steamEnrollmentError = '';
    this.steamEnrollmentChallenge = null;
    this.steamEnrollmentSession = null;
  }

  private closeSteamEnrollmentSheet(): void {
    if (this.steamEnrollmentLoading) {
      return;
    }
    this.showSteamEnrollmentSheet = false;
    this.clearSteamEnrollmentSecrets();
  }

  private clearSteamEnrollmentSecrets(): void {
    this.steamEnrollmentPassword = '';
    this.steamEnrollmentCode = '';
    this.steamEnrollmentChallenge = null;
    this.steamEnrollmentSession = null;
  }

  private showSteamEnrollmentError(message: string): void {
    this.steamEnrollmentError = '';
    if (message.indexOf('已启用 Steam') >= 0 || message.indexOf('现有验证器') >= 0) {
      this.showSteamEnrollmentRestriction();
      return;
    }
    this.getUIContext().showAlertDialog({
      title: this.t('Steam 登录失败'),
      message: this.t(message),
      autoCancel: true,
      primaryButton: {
        value: this.t('我知道了'),
        action: () => {
        }
      }
    });
  }

  private showSteamEnrollmentRestriction(): void {
    this.steamEnrollmentError = '';
    this.getUIContext().showAlertDialog({
      title: this.t('账号已启用 Steam 移动验证器'),
      message: this.t('当前账号已存在验证器，请直接导入原maFile文；如果原文件已丢失，请先在Steam官方应用中移除旧验证器，再返回此处重新生成验证器。'),
      autoCancel: true,
      primaryButton: {
        value: this.t('我知道了'),
        action: () => {
        }
      }
    });
  }

  private steamEnrollmentTitle(): string {
    if (this.steamEnrollmentStage === STEAM_ENROLLMENT_RISK) {
      return this.t('Steam 辅助功能使用说明');
    }
    if (this.steamEnrollmentStage === STEAM_ENROLLMENT_CREDENTIALS) {
      return this.t('登录 Steam 账号');
    }
    if (this.steamEnrollmentStage === STEAM_ENROLLMENT_GUARD) {
      return this.t('验证 Steam 登录');
    }
    if (this.steamEnrollmentStage === STEAM_ENROLLMENT_ACTIVATION) {
      return this.t('激活 Steam 验证器');
    }
    return this.t('保存恢复码');
  }

  private steamEnrollmentGuardNeedsCode(): boolean {
    return this.steamEnrollmentGuardType === 2 || this.steamEnrollmentGuardType === 3;
  }

  private steamEnrollmentGuardRequiresInput(): boolean {
    return this.steamEnrollmentGuardNeedsCode() && !this.steamEnrollmentGuardSubmitted;
  }

  private steamEnrollmentGuardTitle(): string {
    if (this.steamEnrollmentGuardType === 2) {
      return this.t('输入邮件验证码');
    }
    if (this.steamEnrollmentGuardType === 3) {
      return this.t('输入当前 Steam Guard 代码');
    }
    if (this.steamEnrollmentGuardType === 5) {
      return this.t('确认 Steam 邮件');
    }
    return this.t('在其他设备确认登录');
  }

  private steamEnrollmentGuardDescription(): string {
    if (this.steamEnrollmentGuardSubmitted) {
      return this.t('验证码已提交。如果 Steam 尚未签发登录令牌，请稍等片刻后再次检查。');
    }
    if (this.steamEnrollmentGuardMessage.length > 0) {
      return this.steamEnrollmentGuardMessage;
    }
    if (this.steamEnrollmentGuardType === 2) {
      return this.t('Steam 已向账号绑定邮箱发送验证码。');
    }
    if (this.steamEnrollmentGuardType === 3) {
      return this.t('请输入现有 Steam 移动验证器显示的 5 位代码。');
    }
    if (this.steamEnrollmentGuardType === 5) {
      return this.t('请打开 Steam 邮件并确认这次登录，然后返回继续。');
    }
    return this.t('请在已登录的 Steam 移动应用中批准这次登录，然后返回继续。');
  }

  private steamActivationDescription(): string {
    const draft = this.steamAuthenticatorDraft;
    if (draft && draft.confirmType === 3) {
      return this.t('Steam 已向账号绑定邮箱发送激活验证码，请输入后完成添加。');
    }
    if (draft && draft.confirmType === 1 && draft.phoneNumberHint.length > 0) {
      return this.t('Steam 已向尾号或提示为 ') + draft.phoneNumberHint + this.t(' 的手机号发送短信验证码。');
    }
    if (draft && draft.confirmType === 1) {
      return this.t('Steam 已向账号绑定手机号发送短信验证码，请输入后完成添加。');
    }
    return this.t('请输入 Steam 发送的激活验证码以完成添加。');
  }

  private async beginSteamEnrollmentLogin(): Promise<void> {
    if (this.steamEnrollmentLoading || this.steamEnrollmentAccount.length === 0 ||
      this.steamEnrollmentPassword.length === 0) {
      return;
    }
    this.steamEnrollmentLoading = true;
    this.steamEnrollmentError = '';
    const password = this.steamEnrollmentPassword;
    try {
      const service = new SteamEnrollmentService();
      const challenge = await service.beginLogin(this.steamEnrollmentAccount, password);
      this.steamEnrollmentChallenge = challenge;
      this.steamEnrollmentPassword = '';
      if (service.hasExistingMobileAuthenticator(challenge.confirmations)) {
        this.showSteamEnrollmentRestriction();
        return;
      }
      const confirmation = service.enrollmentConfirmation(challenge.confirmations);
      if (confirmation.type === 0) {
        throw new Error('Steam 未提供可用的登录验证方式');
      }
      this.steamEnrollmentGuardType = confirmation.type;
      this.steamEnrollmentGuardMessage = confirmation.message;
      this.steamEnrollmentGuardSubmitted = false;
      this.steamEnrollmentCode = '';
      if (confirmation.type === 1) {
        await this.completeSteamEnrollmentLogin(service, challenge);
      } else {
        this.steamEnrollmentStage = STEAM_ENROLLMENT_GUARD;
      }
    } catch (error) {
      this.showSteamEnrollmentError(this.errorMessage(error));
    } finally {
      this.steamEnrollmentPassword = '';
      this.steamEnrollmentLoading = false;
    }
  }

  private async verifySteamEnrollmentLogin(): Promise<void> {
    const challenge = this.steamEnrollmentChallenge;
    if (!challenge || this.steamEnrollmentLoading) {
      return;
    }
    if (this.steamEnrollmentGuardRequiresInput() && this.steamEnrollmentCode.length === 0) {
      return;
    }
    this.steamEnrollmentLoading = true;
    this.steamEnrollmentError = '';
    try {
      if (this.steamAuthenticatorDraft) {
        await this.persistSteamEnrollmentData(this.steamAuthenticatorDraft.data, false);
        this.steamEnrollmentStage = STEAM_ENROLLMENT_ACTIVATION;
        return;
      }
      const service = new SteamEnrollmentService();
      if (this.steamEnrollmentGuardRequiresInput()) {
        await service.submitGuardCode(
          challenge,
          this.steamEnrollmentGuardType,
          this.steamEnrollmentCode
        );
        this.steamEnrollmentGuardSubmitted = true;
        this.steamEnrollmentCode = '';
      }
      await this.completeSteamEnrollmentLogin(service, challenge);
    } catch (error) {
      this.showSteamEnrollmentError(this.errorMessage(error));
    } finally {
      this.steamEnrollmentLoading = false;
    }
  }

  private async completeSteamEnrollmentLogin(
    service: SteamEnrollmentService,
    challenge: SteamLoginChallenge
  ): Promise<void> {
    let session: SteamLoginSession | null | undefined = this.steamEnrollmentSession;
    if (!session) {
      session = await service.pollLogin(challenge);
    }
    if (!session) {
      throw new Error('Steam 尚未确认登录，请完成验证后再次点击继续');
    }
    this.steamEnrollmentSession = session;
    const deviceId = 'android:' + util.generateRandomUUID().toLowerCase();
    const draft = await service.addAuthenticator(session, deviceId);
    draft.data.maFile = createSdaMaFile(draft.data);
    this.steamAuthenticatorDraft = draft;
    this.steamRecoveryCode = draft.data.revocationCode;
    await this.persistSteamEnrollmentData(draft.data, false);
    this.steamEnrollmentCode = '';
    this.steamEnrollmentStage = STEAM_ENROLLMENT_ACTIVATION;
  }

  private async finalizeSteamEnrollment(): Promise<void> {
    const draft = this.steamAuthenticatorDraft;
    if (!draft || this.steamEnrollmentCode.length === 0 || this.steamEnrollmentLoading) {
      return;
    }
    this.steamEnrollmentLoading = true;
    this.steamEnrollmentError = '';
    try {
      const data = draft.data.fullyEnrolled ? draft.data :
        await new SteamEnrollmentService().finalizeAuthenticator(draft, this.steamEnrollmentCode);
      data.maFile = createSdaMaFile(data);
      await this.persistSteamEnrollmentData(data, true);
      this.steamEnrollmentCode = '';
      this.steamRecoveryCode = data.revocationCode;
      this.steamRecoverySaved = false;
      this.steamEnrollmentStage = STEAM_ENROLLMENT_RECOVERY;
    } catch (error) {
      this.showSteamEnrollmentError(this.errorMessage(error));
    } finally {
      this.steamEnrollmentLoading = false;
    }
  }

  private async resendSteamEnrollmentCode(): Promise<void> {
    const draft = this.steamAuthenticatorDraft;
    if (!draft || this.steamEnrollmentLoading) {
      return;
    }
    this.steamEnrollmentLoading = true;
    try {
      await new SteamEnrollmentService().sendPhoneVerificationCode(draft.data.accessToken);
      this.showToast('Steam 已重新发送短信验证码，请稍候查收');
    } catch (error) {
      this.showSteamEnrollmentError(this.errorMessage(error));
    } finally {
      this.steamEnrollmentLoading = false;
    }
  }

  private async persistSteamEnrollmentData(data: SteamGuardData, completed: boolean): Promise<void> {
    const context = this.getAbilityContext();
    if (!context) {
      throw new Error('无法访问本地存储');
    }
    let existing = this.steamEnrollmentTokenId.length > 0 ?
      this.tokens.find((token: TokenRecord): boolean => token.id === this.steamEnrollmentTokenId) : undefined;
    if (!existing) {
      existing = this.tokens.find((token: TokenRecord): boolean => {
        const stored = parseSteamGuardData(token.steamData || '');
        return stored.steamId.length > 0 && stored.steamId === data.steamId;
      });
    }
    const tokenSecret = this.resolveSteamEnrollmentTokenSecret(data, existing);
    if (tokenSecret.length === 0) {
      throw new Error('Steam 未返回可用的通用令牌密钥，已停止保存，请重新登录');
    }
    data.sharedSecret = tokenSecret;
    data.maFile = createSdaMaFile(data);
    const now = Date.now();
    const tokenId = existing ? existing.id : util.generateRandomUUID();
    const record: TokenRecord = {
      id: tokenId,
      name: data.accountName.trim().length > 0 ? data.accountName.trim() : existing ? existing.name : 'Steam',
      remark: 'Steam',
      type: 'Steam',
      algorithm: 'SHA1',
      secret: tokenSecret,
      logoUri: existing ? existing.logoUri : '',
      logoLightUri: existing ? existing.logoLightUri : '',
      logoDarkUri: existing ? existing.logoDarkUri : '',
      logoSource: existing && existing.logoSource ? existing.logoSource : 'simple-icons-v2:steam',
      digits: 5,
      period: 30,
      counter: 0,
      steamData: serializeSteamGuardData(data),
      createdAt: existing ? existing.createdAt : now,
      modifiedTime: now
    };
    const hydratedRecords = await this.hydrateTokenLogos([record]);
    const persistedRecord = hydratedRecords.length > 0 ? hydratedRecords[0] : record;
    const nextTokens = existing ?
      this.tokens.map((token: TokenRecord): TokenRecord => token.id === tokenId ? persistedRecord : token) :
      [persistedRecord].concat(this.tokens);
    if (!await this.persistTokens(nextTokens, '', completed)) {
      throw new Error('Steam 验证器信息本地保存失败');
    }
    this.steamEnrollmentTokenId = tokenId;
    if (completed) {
      this.showToast('Steam 验证器已保存到本机');
    }
  }

  private resolveSteamEnrollmentTokenSecret(data: SteamGuardData,
    existing: TokenRecord | undefined): string {
    let tokenSecret = Totp.normalizeSecret(data.sharedSecret, 'Steam');
    if (tokenSecret.length === 0 && data.maFile.trim().length > 0) {
      const maFileData = parseSdaMaFile(data.maFile);
      tokenSecret = Totp.normalizeSecret(maFileData.sharedSecret, 'Steam');
    }
    if (tokenSecret.length === 0 && existing) {
      tokenSecret = Totp.normalizeSecret(existing.secret, 'Steam');
    }
    return tokenSecret;
  }

  private async copySteamRecoveryCode(): Promise<void> {
    if (this.steamRecoveryCode.length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.steamRecoveryCode);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showToast('恢复码已复制');
    } catch (error) {
      this.showToast('复制失败');
    }
  }

  private startSelectedSteamLoginScan(): void {
    const tokenId = this.pendingSteamLoginTokenId;
    if (tokenId.length === 0 || this.steamLoading) {
      return;
    }
    this.showSteamLoginPicker = false;
    setTimeout(() => {
      this.scanSteamLoginQr(tokenId);
    }, 180);
  }

  private importSteamTokenFromLoginSheet(): void {
    this.showSteamLoginPicker = false;
    setTimeout(() => {
      this.importTokenFile();
    }, 180);
  }

  private async scanSteamLoginQr(tokenId: string): Promise<void> {
    const token = this.tokens.find((current: TokenRecord) => current.id === tokenId);
    if (!token) {
      this.showToast('所选 Steam 令牌已不存在');
      return;
    }
    const data = parseSteamGuardData(token.steamData || '');
    if (!canUseSteamRemoteFeatures(data) || !data.fullyEnrolled) {
      this.showToast('所选令牌缺少 Steam 登录凭据，请重新导入 maFile');
      return;
    }
    const context = this.getAbilityContext();
    if (!context || this.steamLoading) {
      return;
    }
    this.steamLoading = true;
    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      });
      if (!/^https:\/\/s\.team\/q\/\d+\/\d+(?:\?|$)/.test(result.originalValue.trim())) {
        throw new Error('无效的 Steam 登录二维码');
      }
      let detailsAvailable = true;
      let info: SteamQrLoginInfo;
      try {
        info = await this.steamService().qrLoginInfo(data, result.originalValue);
      } catch (error) {
        detailsAvailable = false;
        info = { ip: '', location: '', deviceName: '', persistent: true };
        console.error('Steam QR login details unavailable: ' + this.errorMessage(error));
      }
      await this.persistSteamGuardData(token, data);
      this.showSteamQrLoginDialog(token.id, result.originalValue, info, detailsAvailable);
    } catch (error) {
      const code = this.getErrorCode(error);
      if (code !== scanCore.ScanErrorCode.SCAN_SERVICE_CANCELED) {
        this.showToast('Steam 扫码登录失败：' + this.errorMessage(error));
        console.error('Steam QR login scan failed: ' + this.errorMessage(error));
      }
    } finally {
      this.steamLoading = false;
    }
  }

  private showSteamQrLoginDialog(
    tokenId: string,
    challengeUrl: string,
    info: SteamQrLoginInfo,
    detailsAvailable: boolean
  ): void {
    const details: string[] = [];
    if (info.deviceName.length > 0) {
      details.push(this.t('设备') + '：' + info.deviceName);
    }
    if (info.location.length > 0) {
      details.push(this.t('位置') + '：' + info.location);
    }
    if (info.ip.length > 0) {
      details.push('IP：' + info.ip);
    }
    if (!detailsAvailable) {
      details.push(this.t('暂时无法读取设备详情，请保证验证器由当前设备生成且已更换支持的网络'));
    }
    details.push(info.persistent ? this.t('此设备请求保持登录') : this.t('此设备请求单次登录'));
    this.getUIContext().showAlertDialog({
      title: this.t('Steam 登录确认'),
      message: details.join('\n'),
      autoCancel: false,
      primaryButton: {
        value: this.t('拒绝'),
        fontColor: ERROR_RED,
        action: () => {
          this.respondSteamQrLogin(tokenId, challengeUrl, info.persistent, false);
        }
      },
      secondaryButton: {
        value: this.t('确认登录'),
        action: () => {
          this.respondSteamQrLogin(tokenId, challengeUrl, info.persistent, true);
        }
      }
    });
  }

  private async respondSteamQrLogin(
    tokenId: string,
    challengeUrl: string,
    persistent: boolean,
    confirm: boolean
  ): Promise<void> {
    if (this.steamLoading) {
      return;
    }
    const token = this.tokens.find((current: TokenRecord) => current.id === tokenId);
    if (!token) {
      this.showToast('所选 Steam 令牌已不存在');
      return;
    }
    const data = parseSteamGuardData(token.steamData || '');
    this.steamLoading = true;
    try {
      await this.steamService().respondQrLogin(data, challengeUrl, persistent, confirm);
      await this.persistSteamGuardData(token, data);
      this.showToast(confirm ? 'Steam 登录已确认' : 'Steam 登录已拒绝');
    } catch (error) {
      this.showToast((confirm ? 'Steam 登录确认失败：' : 'Steam 登录拒绝失败：') + this.errorMessage(error));
    } finally {
      this.steamLoading = false;
    }
  }

  private steamConfirmationTokens(): TokenRecord[] {
    return this.steamLoginTokens().filter((token: TokenRecord) => {
      const data = parseSteamGuardData(token.steamData || '');
      return data.fullyEnrolled && data.identitySecret.length > 0 && data.deviceId.length > 0;
    });
  }

  private steamConfirmationHomeVisible(): boolean {
    return !this.isWatchLayout() && this.selectedHomeTab === HomeTab.Token &&
      this.pageMode === PageMode.Home && this.homePathStack.size() === 0 &&
      !this.showOnboarding && !(this.appLockEnabled && this.isLocked);
  }

  private async checkSteamConfirmationsIfNeeded(): Promise<void> {
    if (!this.steamConfirmationHomeVisible() || this.steamConfirmationChecking || this.steamLoading ||
      this.steamConfirmationDialogVisible || this.showSteamLoginPicker) {
      return;
    }
    if (this.pendingSteamConfirmations.length > 0) {
      this.showNextSteamConfirmationDialog();
      return;
    }
    const now = Date.now();
    if (now - this.lastSteamConfirmationCheckMs < STEAM_CONFIRMATION_POLL_INTERVAL_MS) {
      return;
    }
    const tokens = this.steamConfirmationTokens();
    this.lastSteamConfirmationCheckMs = now;
    if (tokens.length === 0) {
      return;
    }
    this.steamConfirmationChecking = true;
    const discovered: SteamPendingConfirmation[] = [];
    try {
      for (const token of tokens) {
        try {
          const data = parseSteamGuardData(token.steamData || '');
          const confirmations = await this.steamService().confirmations(data);
          await this.persistSteamGuardData(token, data);
          for (const confirmation of confirmations) {
            discovered.push({
              tokenId: token.id,
              tokenName: this.tokenDisplayName(token),
              confirmation: confirmation
            });
          }
        } catch (error) {
          console.error('Failed to check Steam confirmations for ' + token.id + ': ' + this.errorMessage(error));
        }
      }
    } finally {
      this.steamConfirmationChecking = false;
    }
    if (discovered.length > 0) {
      this.pendingSteamConfirmations = discovered;
      this.showNextSteamConfirmationDialog();
    }
  }

  private showNextSteamConfirmationDialog(): void {
    if (this.steamConfirmationDialogVisible || this.pendingSteamConfirmations.length === 0 ||
      !this.steamConfirmationHomeVisible()) {
      return;
    }
    const pending = this.pendingSteamConfirmations[0];
    this.steamConfirmationDialogVisible = true;
    this.getUIContext().showAlertDialog({
      title: this.t('Steam 交易确认'),
      message: this.steamConfirmationDialogMessage(pending),
      autoCancel: false,
      primaryButton: {
        value: this.t('拒绝'),
        fontColor: ERROR_RED,
        action: () => {
          this.handleSteamConfirmationDecision(pending, false);
        }
      },
      secondaryButton: {
        value: this.t('确认'),
        action: () => {
          this.handleSteamConfirmationDecision(pending, true);
        }
      }
    });
  }

  private steamConfirmationDialogMessage(pending: SteamPendingConfirmation): string {
    const item = pending.confirmation;
    const details = item.summary.length > 0 ? item.summary.join('\n') : this.t('Steam 请求确认此操作');
    return this.t('账号') + '：' + pending.tokenName + '\n' + this.t('类型') + '：' +
      this.steamConfirmationType(item.type) + '\n\n' + details;
  }

  private handleSteamConfirmationDecision(pending: SteamPendingConfirmation, allow: boolean): void {
    this.steamConfirmationDialogVisible = false;
    this.respondSteamConfirmation(pending, allow);
  }

  private async respondSteamConfirmation(pending: SteamPendingConfirmation, allow: boolean): Promise<void> {
    if (this.steamLoading) {
      return;
    }
    this.steamLoading = true;
    try {
      const token = this.tokens.find((current: TokenRecord) => current.id === pending.tokenId);
      if (!token) {
        throw new Error('Steam 令牌已不存在');
      }
      const data = parseSteamGuardData(token.steamData || '');
      await this.steamService().respond(data, [pending.confirmation], allow);
      await this.persistSteamGuardData(token, data);
      this.showToast(allow ? '已确认' : '已拒绝');
    } catch (error) {
      this.showToast((allow ? '确认失败：' : '拒绝失败：') + this.errorMessage(error));
    } finally {
      this.steamLoading = false;
      this.pendingSteamConfirmations = this.pendingSteamConfirmations.filter((current: SteamPendingConfirmation) => {
        return current.tokenId !== pending.tokenId || current.confirmation.id !== pending.confirmation.id;
      });
      setTimeout(() => {
        this.showNextSteamConfirmationDialog();
      }, 180);
    }
  }

  private async persistSteamGuardData(token: TokenRecord, data: SteamGuardData): Promise<void> {
    const serialized = serializeSteamGuardData(data);
    if (serialized === (token.steamData || '')) {
      return;
    }
    const nextTokens = this.tokens.map((current: TokenRecord) => {
      if (current.id !== token.id) {
        return current;
      }
      return {
        id: current.id,
        name: current.name,
        remark: current.remark,
        type: current.type,
        algorithm: current.algorithm,
        secret: current.secret,
        logoUri: current.logoUri,
        logoLightUri: current.logoLightUri,
        logoDarkUri: current.logoDarkUri,
        logoSource: current.logoSource,
        digits: current.digits,
        period: current.period,
        counter: current.counter,
        steamData: serialized,
        createdAt: current.createdAt,
        modifiedTime: Date.now()
      };
    });
    if (!await this.persistTokens(nextTokens, '')) {
      throw new Error('Steam 登录凭据保存失败');
    }
  }

  private steamConfirmationType(type: number): string {
    if (type === 2) {
      return this.t('Steam 交易');
    }
    if (type === 3) {
      return this.t('Steam 市场出售');
    }
    if (type === 9) {
      return this.t('Steam API 密钥');
    }
    return this.t('Steam 操作确认');
  }

  private errorMessage(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    try {
      const record = error as Record<string, Object>;
      const message = record['message'];
      const code = record['code'];
      if (typeof message === 'string' && message.length > 0) {
        return typeof code === 'number' || typeof code === 'string' ?
          message + '（' + code.toString() + '）' : message;
      }
      const data = record['data'];
      if (typeof data === 'string' && data.length > 0) {
        return data;
      }
      const serialized = JSON.stringify(error);
      if (serialized.length > 2) {
        return serialized;
      }
      return error.toString();
    } catch (ignored) {
      return '未知错误';
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
        maxSelectNumber: 2,
        fileSuffixFilters: ['2FA|.txt,.json,.csv,.tsv,.otpauth,.mafile,.2fas']
      });
      if (uris.length === 0) {
        return;
      }
      const selectedFiles: ImportFileContent[] = [];
      for (const uri of uris) {
        selectedFiles.push({
          uri: uri,
          fileName: this.importFileName(uri),
          content: await this.readImportFile(uri)
        });
      }
      const encryptedFile = selectedFiles.find((file: ImportFileContent) => {
        return SteamMaFile.isEncryptedContent(file.content);
      });
      if (encryptedFile) {
        let manifestFile = selectedFiles.find((file: ImportFileContent) => SteamMaFile.isManifest(file.content));
        if (!manifestFile) {
          manifestFile = await this.selectSteamManifestFile();
        }
        if (!manifestFile) {
          this.showToast('加密 maFile 需要同时选择 SDA 的 manifest.json');
          return;
        }
        SteamMaFile.encryptionParameters(manifestFile.content, encryptedFile.fileName);
        this.pendingSteamEncryptedContent = encryptedFile.content;
        this.pendingSteamManifestContent = manifestFile.content;
        this.pendingSteamFileName = encryptedFile.fileName;
        this.steamDecryptPassword = '';
        this.showSteamDecryptSheet = true;
        return;
      }
      const tokenFile = selectedFiles.find((file: ImportFileContent) => !SteamMaFile.isManifest(file.content));
      if (!tokenFile) {
        this.showToast('请选择 maFile，而不是只选择 manifest.json');
        return;
      }
      await this.importTokenContent(tokenFile.content);
    } catch (error) {
      this.showToast('导入失败：' + this.errorMessage(error));
      console.error(`Failed to import token file: ${JSON.stringify(error)}`);
    }
  }

  private async selectSteamManifestFile(): Promise<ImportFileContent | undefined> {
    const context = this.getAbilityContext();
    if (!context) {
      return undefined;
    }
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.select({
      maxSelectNumber: 1,
      fileSuffixFilters: ['SDA manifest|.json']
    });
    if (uris.length === 0) {
      return undefined;
    }
    const content = await this.readImportFile(uris[0]);
    if (!SteamMaFile.isManifest(content)) {
      throw new Error('所选文件不是有效的 SDA manifest.json');
    }
    return {
      uri: uris[0],
      fileName: this.importFileName(uris[0]),
      content: content
    };
  }

  private importFileName(uri: string): string {
    const queryIndex = uri.indexOf('?');
    const normalized = queryIndex >= 0 ? uri.substring(0, queryIndex) : uri;
    const slashIndex = normalized.lastIndexOf('/');
    const name = slashIndex >= 0 ? normalized.substring(slashIndex + 1) : normalized;
    try {
      return decodeURIComponent(name);
    } catch (error) {
      return name;
    }
  }

  private closeSteamDecryptSheet(): void {
    if (this.steamDecrypting) {
      return;
    }
    this.showSteamDecryptSheet = false;
    this.steamDecryptPassword = '';
    this.pendingSteamEncryptedContent = '';
    this.pendingSteamManifestContent = '';
    this.pendingSteamFileName = '';
  }

  private async confirmSteamMaFileDecryption(): Promise<void> {
    if (this.steamDecrypting || this.steamDecryptPassword.length === 0) {
      return;
    }
    this.steamDecrypting = true;
    try {
      await this.delay(30);
      const parameters = SteamMaFile.encryptionParameters(
        this.pendingSteamManifestContent,
        this.pendingSteamFileName
      );
      const content = await SteamMaFile.decrypt(
        this.pendingSteamEncryptedContent,
        this.steamDecryptPassword,
        parameters
      );
      if (await this.importTokenContent(content)) {
        this.showSteamDecryptSheet = false;
        this.steamDecryptPassword = '';
        this.pendingSteamEncryptedContent = '';
        this.pendingSteamManifestContent = '';
        this.pendingSteamFileName = '';
      }
    } catch (error) {
      this.showToast('解密失败，请检查 SDA 密码和 manifest.json');
      console.error('Failed to decrypt Steam maFile: ' + this.errorMessage(error));
    } finally {
      this.steamDecrypting = false;
    }
  }

  private async importTokenContent(content: string): Promise<boolean> {
    const records = this.parseImportedTokenContent(content);
    if (records.length === 0) {
      this.showToast(this.importRejectedCount > 0 ?
        this.tf('文件中有{0}条无效令牌', [`${this.importRejectedCount}`]) : '未识别到可导入的令牌');
      return false;
    }
    this.beginImportProgress(records.length, '正在导入令牌');
    const recordsWithLogos = await this.hydrateTokenLogos(records);
    const nextTokens = this.mergeImportedTokens(recordsWithLogos, this.tokens);
    const addedCount = nextTokens.length - this.tokens.length;
    const changedCount = addedCount + this.importUpdatedCount;
    const skippedCount = this.importRejectedCount +
      Math.max(0, recordsWithLogos.length - addedCount - this.importUpdatedCount);
    if (changedCount === 0) {
      this.finishImportProgress(0, skippedCount, '没有新增令牌');
      this.showToast('所选令牌已存在且凭据完整');
      return true;
    }
    let importMessage = this.tf('已导入{0}个令牌', [`${addedCount}`]);
    if (this.importUpdatedCount > 0 && addedCount > 0) {
      importMessage = this.tf('已导入{0}个，更新{1}个', [`${addedCount}`, `${this.importUpdatedCount}`]);
    } else if (this.importUpdatedCount > 0) {
      importMessage = this.tf('已更新{0}个 Steam 令牌凭据', [`${this.importUpdatedCount}`]);
    } else if (this.importRejectedCount > 0) {
      importMessage = this.tf('已导入{0}个，跳过{1}个无效令牌',
        [`${addedCount}`, `${this.importRejectedCount}`]);
    }
    if (!await this.persistTokens(nextTokens, importMessage)) {
      this.finishImportProgress(changedCount, skippedCount, '导入失败');
      return false;
    }
    this.finishImportProgress(changedCount, skippedCount, importMessage);
    this.searchText = '';
    this.pageMode = PageMode.Home;
    return true;
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

    const sdaData = parseSdaMaFile(trimmed);
    if (sdaData.sharedSecret.length > 0) {
      records.push(this.createImportedTokenRecord(
        sdaData.accountName || this.t('Steam 令牌'),
        'Steam',
        sdaData.sharedSecret,
        'Steam',
        'SHA1',
        5,
        30,
        0,
        serializeSteamGuardData(sdaData)
      ));
      return this.uniqueTokenRecordsWithValidation(records, true);
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
    const embeddedSteamData = this.firstString(source, ['steamData']);
    if (uri.length > 0 && embeddedSteamData.length === 0) {
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
    const steamSession = this.objectValue(this.importedJsonValue(source, 'Session')) ||
      this.objectValue(this.importedJsonValue(source, 'session'));
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
      let steamData = '';
      if (this.normalizeTokenType(jsonType) === 'Steam') {
        const storedSteamData = parseSteamGuardData(this.firstString(source, ['steamData']));
        const normalizedSteamData: SteamGuardData = {
          accountName: this.firstString(source, ['account_name', 'accountName', 'username', 'name']) ||
            storedSteamData.accountName,
          steamId: this.firstString(source, ['steamid', 'steamId', 'steamID']) ||
            (steamSession ? this.firstString(steamSession, ['SteamID', 'steamId', 'steamid']) : '') ||
            storedSteamData.steamId,
          sharedSecret: this.firstString(source, ['shared_secret', 'sharedSecret']) || secret ||
            storedSteamData.sharedSecret,
          identitySecret: this.firstString(source, ['identity_secret', 'identitySecret']) ||
            storedSteamData.identitySecret,
          deviceId: this.firstString(source, ['device_id', 'deviceId', 'deviceID']) || storedSteamData.deviceId,
          accessToken: this.firstString(source, ['access_token', 'accessToken']) ||
            (steamSession ? this.firstString(steamSession, ['AccessToken', 'accessToken']) : '') ||
            storedSteamData.accessToken,
          refreshToken: this.firstString(source, ['refresh_token', 'refreshToken']) ||
            (steamSession ? this.firstString(steamSession, ['RefreshToken', 'refreshToken']) : '') ||
            storedSteamData.refreshToken,
          sessionId: this.firstString(source, ['session_id', 'sessionId']) ||
            (steamSession ? this.firstString(steamSession, ['SessionID', 'sessionId']) : '') ||
            storedSteamData.sessionId,
          revocationCode: this.firstString(source, ['revocation_code', 'revocationCode']) ||
            storedSteamData.revocationCode,
          serialNumber: this.firstString(source, ['serial_number', 'serialNumber']) || storedSteamData.serialNumber,
          uri: this.firstString(source, ['steam_uri']) || storedSteamData.uri,
          serverTime: this.firstNumber(source, ['server_time', 'serverTime']) || storedSteamData.serverTime,
          tokenGid: this.firstString(source, ['token_gid', 'tokenGid']) || storedSteamData.tokenGid,
          secret1: this.firstString(source, ['secret_1', 'secret1']) || storedSteamData.secret1,
          status: this.firstNumber(source, ['status']) || storedSteamData.status,
          fullyEnrolled: this.importedJsonValue(source, 'fully_enrolled') === true || storedSteamData.fullyEnrolled,
          maFile: this.firstString(source, ['maFile']) || storedSteamData.maFile
        };
        steamData = serializeSteamGuardData(normalizedSteamData);
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
        this.firstNumber(source, ['counter']) || this.firstNumber(tokenSource, ['counter']),
        steamData
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
    counter: number,
    steamData: string = ''
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
      steamData: tokenType === 'Steam' ? steamData : '',
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
    this.importUpdatedCount = 0;
    const mergedTokens = currentTokens.slice();
    const addedTokens: TokenRecord[] = [];
    records.forEach((record: TokenRecord) => {
      const recordType = this.normalizeTokenType(record.type);
      const existingIndex = mergedTokens.findIndex((token: TokenRecord) => {
        if (token.secret !== record.secret || this.normalizeTokenType(token.type) !== recordType) {
          return false;
        }
        return recordType === 'Steam' || token.name === record.name;
      });
      if (existingIndex < 0) {
        addedTokens.push(record);
        return;
      }
      const current = mergedTokens[existingIndex];
      if (recordType !== 'Steam' || !record.steamData || record.steamData.length === 0 ||
        record.steamData === (current.steamData || '')) {
        return;
      }
      mergedTokens[existingIndex] = {
        id: current.id,
        name: record.name || current.name,
        remark: record.remark || current.remark,
        type: 'Steam',
        algorithm: 'SHA1',
        secret: record.secret,
        logoUri: current.logoSource === LOGO_SOURCE_MANUAL ? current.logoUri : record.logoUri || current.logoUri,
        logoLightUri: current.logoSource === LOGO_SOURCE_MANUAL ?
          current.logoLightUri : record.logoLightUri || current.logoLightUri,
        logoDarkUri: current.logoSource === LOGO_SOURCE_MANUAL ?
          current.logoDarkUri : record.logoDarkUri || current.logoDarkUri,
        logoSource: current.logoSource === LOGO_SOURCE_MANUAL ? current.logoSource : record.logoSource || current.logoSource,
        digits: 5,
        period: 30,
        counter: 0,
        steamData: record.steamData,
        createdAt: current.createdAt,
        modifiedTime: Date.now()
      };
      this.importUpdatedCount++;
    });
    return addedTokens.concat(mergedTokens);
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

  private async hydrateTokenLogos(records: TokenRecord[], refreshResolved: boolean = false): Promise<TokenRecord[]> {
    const context = this.getAbilityContext();
    if (!context) {
      return records;
    }
    const result: TokenRecord[] = [];
    for (let index = 0; index < records.length; index++) {
      const record = records[index];
      if (!this.needsLogoHydration(record, refreshResolved)) {
        result.push(record);
        if (this.importProgressVisible) {
          this.updateImportProgress(index + 1, index + 1, this.importRejectedCount, '正在导入令牌');
        }
        continue;
      }
      const source = record.logoSource || '';
      const lookupIssuer = this.logoLookupIssuer(record.type, record.remark);
      const lookupName = this.logoLookupName(record.type, record.name);
      const logo = !refreshResolved && source.indexOf('simple-icons-v2:') === 0 ?
        await LogoResolver.resolveMaintained(context, lookupIssuer, lookupName) :
        await LogoResolver.resolve(context, lookupIssuer, lookupName);
      result.push(logo ? this.withResolvedLogo(record, logo) : this.withoutUnavailableResolvedLogo(record, refreshResolved));
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
      steamData: record.steamData,
      createdAt: record.createdAt,
      modifiedTime: record.modifiedTime
    };
  }

  private withoutUnavailableResolvedLogo(record: TokenRecord, refreshResolved: boolean): TokenRecord {
    if (!refreshResolved || record.logoSource === LOGO_SOURCE_MANUAL) {
      return record;
    }
    const result = this.cloneTokenRecord(record);
    result.logoUri = '';
    result.logoLightUri = '';
    result.logoDarkUri = '';
    result.logoSource = '';
    return result;
  }

  private needsLogoHydration(record: TokenRecord, refreshResolved: boolean = false): boolean {
    if (this.normalizeTokenType(record.type) === 'Steam' && record.logoSource !== 'simple-icons-v2:steam') {
      return true;
    }
    if (record.logoSource === LOGO_SOURCE_MANUAL) {
      return false;
    }
    const source = record.logoSource || '';
    if (source.indexOf('gitcode-logo:') === 0) {
      return true;
    }
    if (source.indexOf('simple-icons-v2:') === 0) {
      return true;
    }
    if (this.localIssuerLogoKey(record.name, record.remark) === 'gitcode') {
      return source !== 'bundled:gitcode';
    }
    if (source.indexOf('bundled:') === 0) {
      return false;
    }
    if (refreshResolved) {
      return true;
    }
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
      if (this.isWatchLayout()) {
        this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 120);
      }
      this.updateWidgetCards();
      if (this.cloudBackupEnabled) {
        this.queueTokensForAutoCloudPush();
      }
    }
  }

  private async loadTokens(): Promise<void> {
    try {
      const context = this.getAbilityContext();
      if (!context) {
        return;
      }
      this.tokens = await TokenRepository.load(context);
      if (this.isWatchLayout()) {
        this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 120);
      }
      this.updateWidgetCards();
      this.hydrateMissingTokenLogos();
    } catch (error) {
      console.error(`Failed to load tokens: ${JSON.stringify(error)}`);
    } finally {
      this.tokenDataLoaded = true;
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
    this.bumpSheetSelectionRevision();
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
      this.pendingCardTokenIds = this.pendingCardTokenIds.filter((_: string, i: number) => i !== index);
    } else {
      if (this.pendingCardTokenIds.length >= CARD_TOKEN_LIMIT) {
        this.showToast(this.tf('最多选择{0}个令牌', [`${CARD_TOKEN_LIMIT}`]));
        return;
      }
      this.pendingCardTokenIds = [...this.pendingCardTokenIds, tokenId];
    }
    this.bumpSheetSelectionRevision();
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
        steamData: editingToken && type === 'Steam' ? editingToken.steamData : '',
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

  private async persistTokens(
    nextTokens: TokenRecord[],
    successMessage: string,
    syncCloud: boolean = true
  ): Promise<boolean> {
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
    if (this.isWatchLayout()) {
      this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 120);
    }
    this.logoRenderVersion += 1;
    this.updateWidgetCards();
    if (successMessage.length > 0) {
      this.showToast(successMessage);
    }
    if (syncCloud && this.cloudBackupEnabled) {
      this.queueTokensForAutoCloudPush();
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
