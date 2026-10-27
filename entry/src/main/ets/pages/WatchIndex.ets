import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';
import { vibrator } from '@kit.SensorServiceKit';
import { wearEngine } from '@kit.WearEngine';
import {
  LanWatchPairingInfo,
  LanWatchReceiver,
  LanWatchReceiverState
} from '../data/LanWatchSyncService';
import { Settings, SettingsRepository } from '../data/SettingsRepository';
import { TokenRepository } from '../data/TokenRepository';
import { sanitizeTokenRecord, TokenRecord } from '../model/TokenRecord';
import {
  LANGUAGE_SYSTEM,
  normalizeSelectedLanguage,
  translate
} from '../utils/LocaleText';
import { Totp } from '../utils/Totp';

const BRAND_YELLOW: string = '#EBC500';
const ERROR_RED: string = '#D93025';
const WATCH_PAGE_SIDE: number = 26;
const WATCH_CONTENT_SIDE: number = 18;
const WATCH_CONTENT_GAP: number = 10;
const WATCH_TOKEN_CARD_HEIGHT: number = 108;
const WATCH_TOKEN_CARD_RADIUS: number = 18;
const WATCH_TOKEN_CODE_SIZE: number = 28;
const WATCH_EMPTY_CARD_HEIGHT: number = 92;
const WATCH_FEATURE_CARD_HEIGHT: number = 152;
const WATCH_FEATURE_ICON_SIZE: number = 36;
const WATCH_PAGE_SWIPE_DISTANCE: number = 64;
const WATCH_LAN_QR_FRAME_SIZE: number = 120;
const WATCH_LAN_QR_SIZE: number = 112;
const WATCH_PRIVACY_QR_SIZE: number = 128;
const WATCH_PRIVACY_BUTTON_HEIGHT: number = 40;
const WATCH_TOKEN_FOCUS_KEY: string = 'watch-token-scroll';
const WATCH_FEATURE_FOCUS_KEY: string = 'watch-feature-scroll';
const WATCH_LAN_SYNC_FOCUS_KEY: string = 'watch-lan-sync-page';
const WATCH_SYNC_ACTION: string = 'tool2fa.watch.tokens.replace';
const CARD_PRESSED_SCALE: number = 0.97;
const CARD_PRESS_ANIMATION_DURATION: number = 160;

enum WatchHomePage {
  Tokens = 0,
  Features = 1
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

@Entry
@Component
struct WatchIndex {
  @State private startupReady: boolean = false;
  @State private tokens: TokenRecord[] = [];
  @State private currentTimeMs: number = Date.now();
  @State private pageWidth: number = 233;
  @State private pageHeight: number = 233;
  @State private languageInput: string = LANGUAGE_SYSTEM;
  @State private systemLanguage: string = 'zh-Hans';
  @State private globalImmersionEnabled: boolean = false;
  @State private watchHomePageIndex: WatchHomePage = WatchHomePage.Tokens;
  @State private watchLanSyncPageVisible: boolean = false;
  @State private watchLanQrText: string = '';
  @State private watchLanStatus: string = '';
  @State private watchLanReceiving: boolean = false;
  @State private watchLanExpiresAt: number = 0;
  @State private watchPrivacyAccepted: boolean = false;
  @State private watchPrivacyAccepting: boolean = false;
  @State private watchPrivacyError: string = '';
  @State private pressedCardId: string = '';
  @State private watchReceiverStatus: string = '';
  @StorageLink('tool2fa_systemDark') private systemDark: boolean = false;
  @StorageProp('tool2fa_statusBarHeight') private statusBarHeight: number = 0;
  @StorageProp('tool2fa_naviIndicatorHeight') private naviIndicatorHeight: number = 0;

  private watchScroller: Scroller = new Scroller();
  private watchFeatureScroller: Scroller = new Scroller();
  private timerId: number = -1;
  private watchCrownLastHapticAt: number = 0;
  private lanWatchReceiver: LanWatchReceiver | undefined = undefined;
  private wearMessageReceivers: WearMessageReceiver[] = [];
  private loadedSettings: Settings | undefined = undefined;

  aboutToAppear(): void {
    this.refreshSystemLanguage();
    this.initializeWatchData();
    this.timerId = setInterval((): void => {
      this.currentTimeMs = Date.now();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.unregisterWearSyncReceivers();
    this.stopLanWatchReceiver();
  }

  build() {
    Stack() {
      this.PageBackground()
      if (!this.startupReady) {
        this.WatchStartupLoading()
      } else if (!this.watchPrivacyAccepted || this.watchPrivacyAccepting) {
        this.WatchPrivacyConsent()
      } else if (this.watchLanSyncPageVisible) {
        this.WatchLanSyncPageContent()
      } else {
        this.WatchHomePageContent()
      }
    }
    .width('100%')
    .height('100%')
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .backgroundColor(this.pageBackgroundColor())
    .onDigitalCrown((event: CrownEvent): void => {
      this.handleWatchCrown(event);
    })
    .onAppear((): void => {
      if (this.watchPrivacyAccepted) {
        this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 80);
      }
    })
    .onAreaChange((oldValue: Area, newValue: Area): void => {
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private WatchStartupLoading() {
    Column() {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(this.accentColor())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.pageBackgroundColor())
  }

  @Builder
  private WatchPrivacyConsent() {
    Scroll() {
      Column({ space: WATCH_CONTENT_GAP }) {
        Text(this.t('隐私保护提示'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        Text(this.t('请使用手机扫描二维码阅读《隐私声明》，同意后方可继续使用。'))
          .fontSize(12)
          .lineHeight(17)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .width('100%')

        Image($rawfile('watch_privacy_qr.png'))
          .width(WATCH_PRIVACY_QR_SIZE)
          .height(WATCH_PRIVACY_QR_SIZE)
          .objectFit(ImageFit.Contain)
          .borderRadius(8)

        if (this.watchPrivacyError.length > 0) {
          Text(this.t(this.watchPrivacyError))
            .fontSize(10)
            .fontColor(ERROR_RED)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .width('100%')
        }

        Row({ space: WATCH_CONTENT_GAP }) {
          Button(this.t('不同意'))
            .height(WATCH_PRIVACY_BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.primaryTextColor())
            .backgroundColor(this.secondaryButtonColor())
            .borderRadius(WATCH_PRIVACY_BUTTON_HEIGHT / 2)
            .enabled(!this.watchPrivacyAccepting)
            .onClick((): void => {
              this.declineWatchPrivacy();
            })

          Button(this.t(this.watchPrivacyAccepting ? '正在保存' : '同意'))
            .height(WATCH_PRIVACY_BUTTON_HEIGHT)
            .layoutWeight(1)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentContrastColor())
            .backgroundColor(this.accentColor())
            .borderRadius(WATCH_PRIVACY_BUTTON_HEIGHT / 2)
            .enabled(!this.watchPrivacyAccepting)
            .onClick((): void => {
              this.acceptWatchPrivacy();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: WATCH_PAGE_SIDE,
        right: WATCH_PAGE_SIDE,
        top: this.statusBarHeight + 12,
        bottom: this.naviIndicatorHeight + 16
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .backgroundColor(this.pageBackgroundColor())
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
      .onActionEnd((event: GestureEvent): void => {
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
      Column({ space: WATCH_CONTENT_GAP }) {
        Text(this.t('令牌'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        if (this.tokens.length === 0) {
          this.WatchEmptyCard()
        } else {
          ForEach(this.tokens, (token: TokenRecord) => {
            this.WatchTokenCard(token)
          }, (token: TokenRecord): string => token.id)
        }
      }
      .width('100%')
      .padding({
        left: WATCH_CONTENT_SIDE,
        right: WATCH_CONTENT_SIDE,
        top: this.statusBarHeight + 12,
        bottom: this.naviIndicatorHeight + 18
      })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .id(WATCH_TOKEN_FOCUS_KEY)
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
    .align(Alignment.Top)
    .clip(false)
    .onAppear((): void => {
      this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 150);
    })
  }

  @Builder
  private WatchTokenCard(token: TokenRecord) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.globalImmersionEnabled) {
        this.WatchMaterialLayer(WATCH_TOKEN_CARD_HEIGHT, WATCH_TOKEN_CARD_RADIUS)
      }
      Column({ space: 4 }) {
        Text(token.name.trim().length > 0 ? token.name : this.t('令牌'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
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

        Row({ space: 8 }) {
          Text(this.tokenCode(token))
            .fontSize(WATCH_TOKEN_CODE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.tokenValueColor())
            .maxLines(1)
            .layoutWeight(1)

          Text(this.tokenCountdownText(token))
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(WATCH_TOKEN_CARD_HEIGHT)
      .padding({ left: 14, right: 14, top: 12, bottom: 10 })
      .justifyContent(FlexAlign.Center)
      .zIndex(2)
    }
    .width('100%')
    .height(WATCH_TOKEN_CARD_HEIGHT)
    .borderRadius(WATCH_TOKEN_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.globalImmersionEnabled ? Color.Transparent : this.cardBackgroundColor())
    .border({ width: this.globalImmersionEnabled ? 0.5 : 0, color: this.cardBorderColor() })
    .scale({
      x: this.cardScale('watch-token-' + token.id),
      y: this.cardScale('watch-token-' + token.id)
    })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent): void => {
      this.updateCardPressedState('watch-token-' + token.id, event);
    })
  }

  @Builder
  private WatchEmptyCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.globalImmersionEnabled) {
        this.WatchMaterialLayer(WATCH_EMPTY_CARD_HEIGHT, WATCH_TOKEN_CARD_RADIUS)
      }
      Column({ space: 6 }) {
        Text(this.t('暂无令牌'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .width('100%')

        Text(this.t('左滑进行手机端令牌同步'))
          .fontSize(11)
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
    .borderRadius(WATCH_TOKEN_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.globalImmersionEnabled ? Color.Transparent : this.cardBackgroundColor())
    .border({ width: this.globalImmersionEnabled ? 0.5 : 0, color: this.cardBorderColor() })
    .scale({ x: this.cardScale('watch-empty'), y: this.cardScale('watch-empty') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent): void => {
      this.updateCardPressedState('watch-empty', event);
    })
    .onClick((): void => {
      this.showWatchHomePage(WatchHomePage.Features);
    })
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

        if (this.watchReceiverStatus.length > 0) {
          Text(this.t(this.watchReceiverStatus))
            .fontSize(10)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')
        }

        Text(this.t('右滑返回令牌'))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .padding({
        left: WATCH_CONTENT_SIDE,
        right: WATCH_CONTENT_SIDE,
        top: this.statusBarHeight + 12,
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
    .onAppear((): void => {
      this.requestWatchFocus(WATCH_FEATURE_FOCUS_KEY, 80);
    })
  }

  @Builder
  private WatchFeatureActionCard() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.globalImmersionEnabled) {
        this.WatchMaterialLayer(WATCH_FEATURE_CARD_HEIGHT, WATCH_TOKEN_CARD_RADIUS)
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
          .maxLines(5)
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
    .borderRadius(WATCH_TOKEN_CARD_RADIUS)
    .clip(true)
    .backgroundColor(this.globalImmersionEnabled ? Color.Transparent : this.cardBackgroundColor())
    .border({ width: this.globalImmersionEnabled ? 0.5 : 0, color: this.cardBorderColor() })
    .scale({ x: this.cardScale('watch-phone-sync'), y: this.cardScale('watch-phone-sync') })
    .animation({ duration: CARD_PRESS_ANIMATION_DURATION, curve: Curve.Friction })
    .onTouch((event: TouchEvent): void => {
      this.updateCardPressedState('watch-phone-sync', event);
    })
    .onClick((): void => {
      this.openWatchLanSyncPage();
    })
  }

  @Builder
  private WatchLanSyncPageContent() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 10 }) {
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
          LoadingProgress()
            .width(34)
            .height(34)
            .color(this.accentColor())
        } else {
          Button(this.t('重新生成'))
            .height(40)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accentContrastColor())
            .backgroundColor(this.accentColor())
            .borderRadius(20)
            .onClick((): void => {
              this.startLanWatchReceiver();
            })
        }

        Text(this.t(this.watchLanStatus.length > 0 ? this.watchLanStatus : '正在创建配对码'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .width('100%')

        if (this.watchLanReceiving && this.watchLanQrText.length > 0) {
          Text(this.watchLanCountdownText())
            .fontSize(11)
            .fontColor(this.secondaryTextColor())
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')
        }

        Text(this.t('请在手机端扫描此配对码'))
          .fontSize(11)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .width('100%')

        Text(this.t('右滑返回'))
          .fontSize(10)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .padding({
        left: WATCH_PAGE_SIDE,
        right: WATCH_PAGE_SIDE,
        top: this.statusBarHeight + 12,
        bottom: this.naviIndicatorHeight + 12
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .id(WATCH_LAN_SYNC_FOCUS_KEY)
    .focusable(true)
    .focusOnTouch(true)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 12 })
      .onActionEnd((event: GestureEvent): void => {
        if (event.offsetX >= WATCH_PAGE_SWIPE_DISTANCE) {
          this.closeWatchLanSyncPage();
        }
      }))
  }

  @Builder
  private WatchMaterialLayer(cardHeight: number, cardRadius: number) {
    Stack()
    .width('100%')
    .height(cardHeight)
    .borderRadius(cardRadius)
    .clip(true)
    .backgroundColor(this.systemDark ? '#CC1C1C1E' : '#DDFFFFFF')
    .border({ width: 0.5, color: this.cardBorderColor() })
    .hitTestBehavior(HitTestMode.None)
    .zIndex(1)
  }

  private async initializeWatchData(): Promise<void> {
    try {
      const context = this.getAbilityContext();
      if (context === undefined) {
        return;
      }
      const settings = await SettingsRepository.load(context);
      this.loadedSettings = settings;
      this.languageInput = normalizeSelectedLanguage(settings.language);
      this.globalImmersionEnabled = settings.globalImmersionEnabled;
      this.applyColorMode(settings.themeMode);
      this.refreshSystemLanguage();
      this.watchPrivacyAccepted = await SettingsRepository.loadWatchPrivacyAccepted(context);
      this.tokens = await TokenRepository.load(context);
      if (this.watchPrivacyAccepted) {
        this.registerWearSyncReceivers();
      }
    } catch (error) {
      console.error('Failed to initialize watch page: ' + JSON.stringify(error));
    } finally {
      this.startupReady = true;
      if (this.watchPrivacyAccepted) {
        this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 120);
      }
    }
  }

  private applyColorMode(themeMode: string): void {
    const context = this.getAbilityContext();
    if (context === undefined) {
      return;
    }
    let colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (themeMode === '深色模式') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (themeMode === '浅色模式') {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    try {
      context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      console.error('Failed to apply watch color mode: ' + JSON.stringify(error));
    }
  }

  private async acceptWatchPrivacy(): Promise<void> {
    if (this.watchPrivacyAccepting) {
      return;
    }
    const context = this.getAbilityContext();
    if (context === undefined) {
      this.watchPrivacyError = '暂时无法保存，请稍后重试';
      return;
    }
    this.watchPrivacyAccepting = true;
    this.watchPrivacyError = '';
    try {
      await SettingsRepository.saveWatchPrivacyAccepted(context);
      this.watchPrivacyAccepted = true;
      this.registerWearSyncReceivers();
      this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 80);
    } catch (error) {
      this.watchPrivacyError = '暂时无法保存，请稍后重试';
      console.error('Failed to save watch privacy acceptance: ' + JSON.stringify(error));
    } finally {
      this.watchPrivacyAccepting = false;
    }
  }

  private declineWatchPrivacy(): void {
    this.terminateWatchApp();
  }

  private async terminateWatchApp(): Promise<void> {
    const context = this.getAbilityContext();
    if (context === undefined) {
      return;
    }
    try {
      await context.terminateSelf();
    } catch (error) {
      console.error('Failed to exit watch app: ' + JSON.stringify(error));
    }
  }

  private async exitWatchApp(): Promise<void> {
    if (this.watchLanSyncPageVisible || this.watchHomePageIndex !== WatchHomePage.Tokens) {
      return;
    }
    await this.terminateWatchApp();
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
    if (context === undefined) {
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
          return await this.applyIncomingTokens(records);
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
    if (receiver !== undefined) {
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

  private async registerWearSyncReceivers(): Promise<void> {
    if (this.wearMessageReceivers.length > 0) {
      return;
    }
    const context = this.getAbilityContext();
    if (context === undefined) {
      return;
    }
    try {
      const deviceClient = wearEngine.getDeviceClient(context);
      const devices = await deviceClient.getConnectedDevices();
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
        const receiver: WearMessageReceiver = {
          deviceId: device.randomId,
          appParam: appParam,
          callback: callback
        };
        this.wearMessageReceivers.push(receiver);
      }
      this.watchReceiverStatus = '已连接';
    } catch (error) {
      this.watchReceiverStatus = 'Wear Engine暂不可用';
      console.error('Failed to register watch sync receiver: ' + JSON.stringify(error));
    }
  }

  private async unregisterWearSyncReceivers(): Promise<void> {
    if (this.wearMessageReceivers.length === 0) {
      return;
    }
    const context = this.getAbilityContext();
    if (context === undefined) {
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

  private receiveWearSyncMessage(message: wearEngine.P2pMessage): void {
    try {
      const text = util.TextDecoder.create('utf-8').decodeToString(message.content);
      const payload = JSON.parse(text) as WatchSyncPayload;
      if (payload.action !== WATCH_SYNC_ACTION || !Array.isArray(payload.tokens)) {
        return;
      }
      this.applyIncomingTokens(payload.tokens);
    } catch (error) {
      this.watchReceiverStatus = '手表端接收失败';
      console.error('Failed to receive watch sync message: ' + JSON.stringify(error));
    }
  }

  private async applyIncomingTokens(records: TokenRecord[]): Promise<boolean> {
    const context = this.getAbilityContext();
    if (context === undefined) {
      return false;
    }
    const validRecords = this.validIncomingTokens(records);
    if (validRecords.length === 0) {
      return false;
    }
    if (!await TokenRepository.save(context, validRecords)) {
      return false;
    }
    this.tokens = validRecords;
    const settings = this.loadedSettings === undefined ? await SettingsRepository.load(context) : this.loadedSettings;
    settings.watchSelectedTokenIds = validRecords.map((token: TokenRecord): string => token.id);
    settings.watchPushStatus = '接收成功';
    settings.watchLastPushTime = Date.now();
    await SettingsRepository.save(context, settings);
    this.loadedSettings = settings;
    this.watchReceiverStatus = '接收成功';
    this.requestWatchFocus(WATCH_TOKEN_FOCUS_KEY, 120);
    return true;
  }

  private validIncomingTokens(records: TokenRecord[]): TokenRecord[] {
    const result: TokenRecord[] = [];
    for (let index = 0; index < records.length; index++) {
      const token = sanitizeTokenRecord(records[index]);
      if (token.id.length === 0 || token.secret.length === 0 || !Totp.isValidSecret(token.secret, token.type)) {
        continue;
      }
      if (result.some((existing: TokenRecord): boolean => existing.id === token.id)) {
        continue;
      }
      result.push(token);
    }
    return result;
  }

  private tokenCode(token: TokenRecord): string {
    return Totp.formatCode(Totp.generate(
      token.secret,
      this.currentTimeMs,
      token.algorithm,
      token.digits ?? 6,
      this.tokenPeriod(token),
      token.type,
      token.counter ?? 0
    ));
  }

  private tokenPeriod(token: TokenRecord): number {
    if (token.type.trim().toUpperCase() !== 'TOTP') {
      return 30;
    }
    return token.period === 60 ? 60 : 30;
  }

  private tokenCountdownText(token: TokenRecord): string {
    if (token.type.trim().toUpperCase() === 'HOTP') {
      return 'HOTP';
    }
    return Totp.remainingSeconds(this.currentTimeMs, this.tokenPeriod(token)).toString() + 's';
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
    const focusKey = index === WatchHomePage.Tokens ? WATCH_TOKEN_FOCUS_KEY : WATCH_FEATURE_FOCUS_KEY;
    this.requestWatchFocus(focusKey, 80);
  }

  private requestWatchFocus(key: string, delayMs: number): void {
    this.scheduleWatchFocusRequest(key, delayMs);
    this.scheduleWatchFocusRequest(key, delayMs + 240);
  }

  private scheduleWatchFocusRequest(key: string, delayMs: number): void {
    setTimeout((): void => {
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
    if (event.action !== CrownAction.UPDATE || this.watchLanSyncPageVisible || !this.watchPrivacyAccepted) {
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
      }, (): void => {
      });
    } catch (error) {
      console.warn('Failed to play watch crown haptic: ' + JSON.stringify(error));
    }
  }

  private cardScale(cardId: string): number {
    return this.pressedCardId === cardId ? CARD_PRESSED_SCALE : 1;
  }

  private updateCardPressedState(cardId: string, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.pressedCardId = cardId;
      return;
    }
    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.pressedCardId === cardId) {
      this.pressedCardId = '';
    }
  }

  private pageBackgroundColor(): string {
    return this.systemDark ? '#FF000000' : '#FFF2F3F5';
  }

  private cardBackgroundColor(): string {
    return this.systemDark ? '#FF1C1C1E' : '#FFFFFFFF';
  }

  private primaryTextColor(): string {
    return this.systemDark ? '#FFF5F5F5' : '#FF1A1A1A';
  }

  private secondaryTextColor(): string {
    return this.systemDark ? '#FFB8B8B8' : '#FF666666';
  }

  private tokenValueColor(): string {
    return this.systemDark ? '#FFFFFFFF' : '#FF000000';
  }

  private secondaryButtonColor(): string {
    return this.systemDark ? '#FF2F2F2F' : '#FFE7E8EA';
  }

  private cardBorderColor(): string {
    return this.systemDark ? '#44FFFFFF' : '#22000000';
  }

  private accentColor(): string {
    return BRAND_YELLOW;
  }

  private accentTintColor(): string {
    return this.systemDark ? '#33EBC500' : '#22EBC500';
  }

  private accentContrastColor(): string {
    return '#FF1A1A1A';
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
    values.forEach((value: string, index: number): void => {
      result = result.replace(`{${index}}`, value);
    });
    return result;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: this.t(message) });
    } catch (error) {
      console.error('Failed to show watch toast: ' + JSON.stringify(error));
    }
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

  private getAbilityContext(): common.UIAbilityContext | undefined {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      return undefined;
    }
    return hostContext as common.UIAbilityContext;
  }
}
