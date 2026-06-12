import { common } from '@kit.AbilityKit';
import { CircleShape } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { TokenRepository } from '../data/TokenRepository';
import { TokenRecord } from '../model/TokenRecord';
import { Totp } from '../utils/Totp';

const PAGE_BACKGROUND: string = '#F1F2F4';
const CARD_BACKGROUND: string = '#FFFFFF';
const PRIMARY_TEXT: string = '#111111';
const SECONDARY_TEXT: string = '#6F7175';
const DIVIDER_COLOR: string = '#E2E2E2';
const BRAND_YELLOW: string = '#EBC500';
const ERROR_RED: string = '#D93025';
const TYPE_OPTIONS: SelectOption[] = [{ value: 'TOTP' }];
const ALGORITHM_OPTIONS: SelectOption[] = [
  { value: 'SHA1' },
  { value: 'SHA3' },
  { value: 'SHA224' },
  { value: 'SHA256' },
  { value: 'SHA384' },
  { value: 'SHA512' }
];
const FORM_TEXT_SIZE: number = 14;
const ADD_MENU_LABEL_SIZE: number = 16;
const HOME_HORIZONTAL_PADDING: number = 20;
const HOME_LAYOUT_GAP: number = 8;
const HOME_TITLE_HEIGHT: number = 64;
const HOME_SEARCH_HEIGHT: number = 52;
const HOME_SEARCH_HEADER_HEIGHT: number = HOME_SEARCH_HEIGHT;
const HOME_SEARCH_COLLAPSE_DISTANCE: number = HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP;
const HOME_LIST_CACHE_COUNT: number = 4;
const HOME_NAV_WIDTH: number = 210;
const HOME_NAV_HEIGHT: number = 68;
const HOME_NAV_ICON_SIZE: number = 28;
const TOP_BLUR_HEIGHT: number = 62;
const ADD_MENU_ANIMATION_DURATION: number = 1000;
const ADD_BUTTON_SIZE: number = 64;
const ADD_BUTTON_RIGHT: number = 36;
const ADD_BUTTON_BOTTOM: number = 142;
const ADD_BUTTON_ICON_SIZE: number = 30;
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
  @State private currentTimeMs: number = Date.now();
  @State private isSaving: boolean = false;
  @State private isAddMenuOpen: boolean = false;
  @State private isAddMenuVisible: boolean = false;
  @State private addMenuProgress: number = 0;
  @State private isScanning: boolean = false;
  @State private validationMessage: string = '';
  @State private pageWidth: number = 390;
  @State private pageHeight: number = 844;
  @State private editingTokenId: string = '';
  @State private selectedHomeTab: HomeTab = HomeTab.Token;
  @State private homeScrollY: number = 0;
  private homeScroller: Scroller = new Scroller();
  private timerId: number = -1;
  private addMenuCloseTimerId: number = -1;

  aboutToAppear(): void {
    this.loadTokens();
    this.timerId = setInterval(() => {
      this.currentTimeMs = Date.now();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.clearAddMenuCloseTimer();
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      this.PageBackground()

      if (this.pageMode === PageMode.Home) {
        this.HomePage()

        if (this.selectedHomeTab === HomeTab.Token && this.isAddMenuVisible) {
          this.BlurredHomePage()
          this.AddMethodOverlay()
        }

        if (this.selectedHomeTab === HomeTab.Token) {
          this.AddFloatingButton()
        }
      } else {
        this.AddTokenPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND)
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
      .backgroundColor(PAGE_BACKGROUND)
  }

  @Builder
  private HomePage() {
    Stack({ alignContent: Alignment.Top }) {
      this.HomePageContent()
      this.HomeTitleBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private HomeTitleBar() {
    Row() {
      Text(this.currentHomeTitle())
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(PRIMARY_TEXT)
        .layoutWeight(1)

      if (this.selectedHomeTab === HomeTab.Token) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_home_search'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)
        }
        .width(56)
        .height(56)
        .backgroundColor('#F7FFFFFF')
        .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
        .opacity(this.searchCollapseProgress())
        .hitTestBehavior(this.searchCollapseProgress() > 0.55 ? HitTestMode.Default : HitTestMode.None)
        .onClick(() => {
          this.scrollHomeSearchIntoView();
        })
      }
    }
    .width('100%')
    .height(HOME_TITLE_HEIGHT)
    .padding({ left: HOME_HORIZONTAL_PADDING, right: HOME_HORIZONTAL_PADDING })
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        ['#EAF1F2F4', 0.0],
        ['#C8F1F2F4', 0.62],
        ['#00F1F2F4', 1.0]
      ]
    })
    .zIndex(8)
  }

  @Builder
  private BlurredHomePage() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      this.HomePageContent()
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .blur(18)
    .opacity(this.addMenuProgress)
    .clipShape(new CircleShape({
      width: this.blurRevealDiameter(),
      height: this.blurRevealDiameter()
    }).position({
      x: this.blurRevealLeft(),
      y: this.blurRevealTop()
    }))
  }

  @Builder
  private HomePageContent() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.selectedHomeTab === HomeTab.Token) {
        List({ space: HOME_LAYOUT_GAP, scroller: this.homeScroller }) {
          ListItem() {
            this.HomeSearchListHeader()
          }
          .width('100%')

          ForEach(this.filteredTokens(), (token: TokenRecord) => {
            ListItem() {
              this.TokenCard(token)
            }
            .width('100%')
            .swipeAction({
              end: () => {
                this.TokenSwipeActions(token)
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (token: TokenRecord) => token.id)

          ListItem() {
            Text(`- 共${this.filteredTokens().length}个 -`)
              .fontSize(15)
              .fontColor('#B8BABF')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 28 })
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding({
          left: HOME_HORIZONTAL_PADDING,
          right: HOME_HORIZONTAL_PADDING
        })
        .contentStartOffset(HOME_TITLE_HEIGHT + HOME_LAYOUT_GAP)
        .contentEndOffset(HOME_NAV_HEIGHT + HOME_LAYOUT_GAP)
        .cachedCount(HOME_LIST_CACHE_COUNT, true)
        .scrollBar(BarState.Off)
        .clip(false)
        .onReachStart(() => {
          this.homeScrollY = 0;
        })
        .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
          this.updateHomeScroll(scrollOffset);
        })
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(PAGE_BACKGROUND)
      }

      this.HomeBottomNavigation()
    }
    .width('100%')
    .height('100%')
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
        .height(50)
        .width('100%')
        .borderRadius(27)
        .backgroundColor(Color.Transparent)
        .placeholderColor(SECONDARY_TEXT)
        .fontColor(PRIMARY_TEXT)
        .textFont({ size: 22 })
        .placeholderFont({ size: 22 })
        .onChange((value: string) => {
          this.searchText = value;
        })
    }
    .height(HOME_SEARCH_HEIGHT)
    .width('100%')
    .borderRadius(28)
    .clip(true)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: 1, color: '#FFFFFFFF' })
  }

  @Builder
  private HomeBottomNavigation() {
    Row() {
      Row({ space: 22 }) {
        this.TokenNavItem()
        this.MeNavItem()
      }
      .width(HOME_NAV_WIDTH)
      .height(HOME_NAV_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(HOME_NAV_HEIGHT / 2)
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
      .border({ width: 1, color: '#FFFFFFFF' })
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
    }
    .width('100%')
    .height(HOME_NAV_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .zIndex(9)
  }

  @Builder
  private TokenNavItem() {
    Column({ space: 2 }) {
      Image(this.selectedHomeTab === HomeTab.Token ? $r('app.media.ic_tab_token_selected') : $r('app.media.ic_tab_token_normal'))
        .width(HOME_NAV_ICON_SIZE)
        .height(HOME_NAV_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .renderMode(ImageRenderMode.Original)

      Text('令牌')
        .fontSize(16)
        .fontColor(this.selectedHomeTab === HomeTab.Token ? BRAND_YELLOW : PRIMARY_TEXT)
        .fontWeight(FontWeight.Medium)
    }
    .width(68)
    .height(58)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchHomeTab(HomeTab.Token);
    })
  }

  @Builder
  private MeNavItem() {
    Column({ space: 2 }) {
      Image(this.selectedHomeTab === HomeTab.Me ? $r('app.media.ic_tab_me_selected') : $r('app.media.ic_tab_me_normal'))
        .width(HOME_NAV_ICON_SIZE)
        .height(HOME_NAV_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .renderMode(ImageRenderMode.Original)

      Text('我的')
        .fontSize(16)
        .fontColor(this.selectedHomeTab === HomeTab.Me ? BRAND_YELLOW : PRIMARY_TEXT)
        .fontWeight(FontWeight.Medium)
    }
    .width(68)
    .height(58)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.switchHomeTab(HomeTab.Me);
    })
  }

  @Builder
  private AddFloatingButton() {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.ic_add_page'))
        .width(ADD_BUTTON_ICON_SIZE)
        .height(ADD_BUTTON_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .rotate({ angle: 45 * this.addMenuProgress })
    }
    .width(ADD_BUTTON_SIZE)
    .height(ADD_BUTTON_SIZE)
    .margin({ right: ADD_BUTTON_RIGHT, bottom: ADD_BUTTON_BOTTOM })
    .backgroundColor(BRAND_YELLOW)
    .onClick(() => {
      this.toggleAddMenu();
    })
    .zIndex(20)
  }

  @Builder
  private AddMethodOverlay() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column()
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .backgroundColor('#00000000')
        .onClick(() => {
          this.closeAddMenu();
        })

      Column({ space: 18 }) {
        this.AddMethodRow('扫描二维码', $r('app.media.ic_scan'), 24, 24, 0.18, () => {
          this.closeAddMenu(() => {
            this.scanTokenFromQrCode();
          });
        })

        this.AddMethodRow('输入密钥', $r('app.media.ic_add_secret'), 22, 25, 0.32, () => {
          this.closeAddMenu(() => {
            this.openAddPage();
          });
        })
      }
      .alignItems(HorizontalAlign.End)
      .margin({
        right: ADD_BUTTON_RIGHT,
        bottom: ADD_BUTTON_BOTTOM + ADD_BUTTON_SIZE + 22
      })
      .opacity(this.menuItemProgress(0.12))
      .translate({ y: (1 - this.menuItemProgress(0.12)) * 22 })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .zIndex(10)
  }

  @Builder
  private AddMethodRow(label: string, icon: Resource, iconWidth: number, iconHeight: number, delay: number, onClick: () => void) {
    Row({ space: 16 }) {
      Text(label)
        .fontSize(ADD_MENU_LABEL_SIZE)
        .fontColor(PRIMARY_TEXT)
        .fontWeight(FontWeight.Medium)

      Button({ type: ButtonType.Circle }) {
        Image(icon)
          .width(iconWidth)
          .height(iconHeight)
          .objectFit(ImageFit.Contain)
      }
      .width(56)
      .height(56)
      .backgroundColor(BRAND_YELLOW)
      .onClick(onClick)
    }
    .height(64)
    .opacity(this.menuItemProgress(delay))
    .translate({ y: (1 - this.menuItemProgress(delay)) * 16 })
  }

  @Builder
  private TokenCard(token: TokenRecord) {
    Row() {
      Column() {
        Text(token.name)
          .fontSize(19)
          .fontColor(PRIMARY_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(Totp.formatCode(Totp.generate(token.secret, this.currentTimeMs, token.algorithm)))
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(BRAND_YELLOW)
          .letterSpacing(0)
          .margin({ top: 12 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${Totp.remainingSeconds(this.currentTimeMs)} 秒`)
        .fontSize(18)
        .fontColor(PRIMARY_TEXT)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 1 })
    }
    .height(100)
    .width('100%')
    .padding({ left: 24, right: 26, top: 19, bottom: 19 })
    .borderRadius(15)
    .backgroundColor(CARD_BACKGROUND)
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
    .height(100)
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
  private AddTokenPage() {
    Stack({ alignContent: Alignment.Top }) {
      this.TopGradientBlur()

        Column() {
          Row() {
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_public_arrow_right'))
                .width(8)
                .height(13)
                .objectFit(ImageFit.Contain)
            }
            .width(40)
            .height(40)
          .backgroundColor('#E7E8EA')
          .onClick(() => {
            this.backHome();
          })

          Text(this.editingTokenId.length > 0 ? '编辑令牌' : '新增令牌')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT)
            .margin({ left: 10 })
        }
        .height(40)
        .width('100%')

        Column() {
          this.InputRow('名称', this.nameInput, '请输入', (value: string) => {
            this.nameInput = value;
            this.validationMessage = '';
          })
          this.Separator()
          this.InputRow('备注', this.remarkInput, '请输入', (value: string) => {
            this.remarkInput = value;
          })
        }
        .width('100%')
        .height(108)
        .padding({ left: 24, right: 20 })
        .borderRadius(15)
        .backgroundColor(CARD_BACKGROUND)
        .margin({ top: 21 })

        Column() {
          this.SelectRow('类型', this.typeInput, TYPE_OPTIONS, (value: string) => {
            this.typeInput = value;
          })
          this.Separator()
          this.SelectRow('算法', this.algorithmInput, ALGORITHM_OPTIONS, (value: string) => {
            this.algorithmInput = value;
          })
          this.Separator()
          this.InputRow('密钥', this.secretInput, '请输入', (value: string) => {
            this.secretInput = value;
            this.validationMessage = '';
          })
        }
        .width('100%')
        .height(160)
        .padding({ left: 24, right: 20 })
        .borderRadius(15)
        .backgroundColor(CARD_BACKGROUND)
        .margin({ top: 11 })

        if (this.validationMessage.length > 0) {
          Text(this.validationMessage)
            .fontSize(14)
            .fontColor(ERROR_RED)
            .width('100%')
            .margin({ top: 8, left: 8 })
        }

        Button() {
          Text(this.isSaving ? '保存中' : '确认')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(CARD_BACKGROUND)
        }
        .height(46)
        .width('100%')
        .borderRadius(24)
        .backgroundColor(BRAND_YELLOW)
        .margin({ top: this.validationMessage.length > 0 ? 8 : 11 })
        .onClick(() => {
          this.saveToken();
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 10 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private TopGradientBlur() {
    Column()
      .width('100%')
      .height(TOP_BLUR_HEIGHT)
      .alignSelf(ItemAlign.Start)
      .position({ x: 0, y: 0 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .backgroundColor(PAGE_BACKGROUND)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [
          [PAGE_BACKGROUND, 0.0],
          [PAGE_BACKGROUND, 0.38],
          [PAGE_BACKGROUND, 0.72],
          [PAGE_BACKGROUND, 1.0]
        ]
      })
  }

  @Builder
  private InputRow(label: string, value: string, placeholder: string, onChanged: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(PRIMARY_TEXT)
        .width(72)

      TextInput({ text: value, placeholder: placeholder })
        .height(52)
        .layoutWeight(1)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(PRIMARY_TEXT)
        .placeholderColor(SECONDARY_TEXT)
        .placeholderFont({ size: FORM_TEXT_SIZE })
        .backgroundColor(Color.Transparent)
        .textAlign(TextAlign.End)
        .padding({ left: 8, right: 0 })
        .onChange((text: string) => {
          onChanged(text);
        })
    }
    .width('100%')
    .height(53)
  }

  @Builder
  private SelectRow(label: string, selectedValue: string, values: SelectOption[], onSelected: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(FORM_TEXT_SIZE)
        .fontColor(PRIMARY_TEXT)
        .width(72)

      Row() {
        Select(values)
          .selected(0)
          .value(selectedValue)
          .font({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .fontColor(PRIMARY_TEXT)
          .selectedOptionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .optionFont({ size: FORM_TEXT_SIZE, weight: FontWeight.Regular })
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .onSelect((index: number, value: string) => {
            onSelected(value);
          })
      }
      .height(52)
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(53)
  }

  @Builder
  private Separator() {
    Divider()
      .strokeWidth(1)
      .color(DIVIDER_COLOR)
  }

  private currentHomeTitle(): string {
    return this.selectedHomeTab === HomeTab.Token ? '令牌' : '我的';
  }

  private switchHomeTab(tab: HomeTab): void {
    if (this.selectedHomeTab === tab) {
      return;
    }
    this.closeAddMenu();
    this.selectedHomeTab = tab;
  }

  private updateHomeScroll(scrollOffset: number): void {
    const nextScrollY = this.clamp(this.homeScrollY + scrollOffset, 0, HOME_SEARCH_COLLAPSE_DISTANCE);
    if (Math.abs(nextScrollY - this.homeScrollY) > 0.5) {
      this.homeScrollY = nextScrollY;
    }
  }

  private searchCollapseProgress(): number {
    return this.clamp(this.homeScrollY / HOME_SEARCH_COLLAPSE_DISTANCE);
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
    });
  }

  private toggleAddMenu(): void {
    if (this.isAddMenuOpen) {
      this.closeAddMenu();
    } else {
      this.openAddMenu();
    }
  }

  private openAddMenu(): void {
    this.clearAddMenuCloseTimer();
    this.isAddMenuOpen = true;
    this.isAddMenuVisible = true;
    this.getUIContext().animateTo({
      duration: ADD_MENU_ANIMATION_DURATION,
      curve: Curve.Smooth
    }, () => {
      this.addMenuProgress = 1;
    });
  }

  private closeAddMenu(afterClose?: () => void): void {
    this.clearAddMenuCloseTimer();
    this.isAddMenuOpen = false;
    this.getUIContext().animateTo({
      duration: ADD_MENU_ANIMATION_DURATION,
      curve: Curve.Smooth
    }, () => {
      this.addMenuProgress = 0;
    });
    this.addMenuCloseTimerId = setTimeout(() => {
      this.isAddMenuVisible = false;
      this.addMenuCloseTimerId = -1;
      if (afterClose) {
        afterClose();
      }
    }, ADD_MENU_ANIMATION_DURATION);
  }

  private clearAddMenuCloseTimer(): void {
    if (this.addMenuCloseTimerId >= 0) {
      clearTimeout(this.addMenuCloseTimerId);
      this.addMenuCloseTimerId = -1;
    }
  }

  private menuItemProgress(delay: number): number {
    if (!this.isAddMenuOpen) {
      return this.addMenuProgress;
    }
    return this.clamp((this.addMenuProgress - delay) / (1 - delay));
  }

  private blurRevealDiameter(): number {
    const minDiameter = ADD_BUTTON_SIZE;
    const maxDiameter = this.maxRevealDiameter();
    return minDiameter + (maxDiameter - minDiameter) * this.addMenuProgress;
  }

  private blurRevealLeft(): number {
    return this.addButtonCenterX() - this.blurRevealDiameter() / 2;
  }

  private blurRevealTop(): number {
    return this.addButtonCenterY() - this.blurRevealDiameter() / 2;
  }

  private maxRevealDiameter(): number {
    const centerX = this.addButtonCenterX();
    const centerY = this.addButtonCenterY();
    const maxRadius = Math.max(
      this.distance(centerX, centerY, 0, 0),
      this.distance(centerX, centerY, this.pageWidth, 0),
      this.distance(centerX, centerY, 0, this.pageHeight),
      this.distance(centerX, centerY, this.pageWidth, this.pageHeight)
    );
    return (maxRadius + 48) * 2;
  }

  private addButtonCenterX(): number {
    return this.pageWidth - ADD_BUTTON_RIGHT - ADD_BUTTON_SIZE / 2;
  }

  private addButtonCenterY(): number {
    return this.pageHeight - ADD_BUTTON_BOTTOM - ADD_BUTTON_SIZE / 2;
  }

  private distance(x1: number, y1: number, x2: number, y2: number): number {
    const dx = x1 - x2;
    const dy = y1 - y2;
    return Math.sqrt(dx * dx + dy * dy);
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
    this.isAddMenuVisible = false;
    this.addMenuProgress = 0;
    this.editingTokenId = '';
    this.nameInput = '';
    this.remarkInput = '';
    this.typeInput = 'TOTP';
    this.algorithmInput = 'SHA1';
    this.secretInput = '';
    this.validationMessage = '';
    this.pageMode = PageMode.AddToken;
  }

  private openEditPage(token: TokenRecord): void {
    this.isAddMenuOpen = false;
    this.isAddMenuVisible = false;
    this.addMenuProgress = 0;
    this.editingTokenId = token.id;
    this.nameInput = token.name;
    this.remarkInput = token.remark;
    this.typeInput = token.type;
    this.algorithmInput = this.normalizeAlgorithm(token.algorithm);
    this.secretInput = token.secret;
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
    this.isAddMenuVisible = false;
    this.addMenuProgress = 0;
    this.isScanning = true;

    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: false
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
    const record = this.createTokenFromScannedValue(scannedValue);
    if (!record) {
      this.showToast('未识别到有效密钥');
      return;
    }

    const context = this.getAbilityContext();
    if (!context) {
      this.showToast('保存失败，请重试');
      return;
    }

    const nextTokens = [record].concat(this.tokens);
    if (!await this.persistTokens(nextTokens, '已保存')) {
      return;
    }
    this.searchText = '';
    this.pageMode = PageMode.Home;
  }

  private createTokenFromScannedValue(scannedValue: string): TokenRecord | undefined {
    const rawValue = scannedValue.trim();
    if (rawValue.length === 0) {
      return undefined;
    }

    let name = '扫描令牌';
    let remark = '';
    let secret = rawValue;
    let algorithm = 'SHA1';
    const lowerValue = rawValue.toLowerCase();

    if (lowerValue.startsWith('otpauth://totp/')) {
      const payload = rawValue.substring('otpauth://totp/'.length);
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
      const issuer = (params.get('issuer') || '').trim();
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

    return {
      id: `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name,
      remark: remark,
      type: 'TOTP',
      algorithm: algorithm,
      secret: secret,
      createdAt: Date.now()
    };
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
    } catch (error) {
      console.error(`Failed to load tokens: ${JSON.stringify(error)}`);
    }
  }

  private async saveToken(): Promise<void> {
    if (this.isSaving) {
      return;
    }

    const name = this.nameInput.trim();
    const secret = this.secretInput.trim();

    if (name.length === 0 || secret.length === 0) {
      this.validationMessage = '请填写名称和密钥';
      return;
    }

    this.isSaving = true;
    const editingToken = this.tokens.find((token: TokenRecord) => token.id === this.editingTokenId);
    const record: TokenRecord = {
      id: editingToken ? editingToken.id : `${Date.now()}-${Math.floor(Math.random() * 1000000)}`,
      name: name,
      remark: this.remarkInput.trim(),
      type: this.typeInput,
      algorithm: this.algorithmInput,
      secret: secret,
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
