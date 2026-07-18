import { WidgetLoadingOverlay } from './WidgetLoadingOverlay';
import { WidgetTokenItem } from './WidgetTokenItem';
import {
  WIDGET_BUTTON_RADIUS,
  WIDGET_BUTTON_SIZE,
  WIDGET_CARD_PADDING,
  WIDGET_CARD_RADIUS,
  WIDGET_CONTENT_GAP,
  WIDGET_REFRESH_DELAY,
  WIDGET_REFRESH_ICON_SIZE,
  WIDGET_TITLE_SIZE,
  WIDGET_TITLE_TRAILING_SPACE
} from './WidgetMetrics';

let S_STORAGE: LocalStorage = new LocalStorage();

@Entry(S_STORAGE)
@Component
struct WidgetSmallCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';
  @State private isRefreshing: boolean = false;
  @State private loadingOpacity: number = 0;

  private refresh(): void {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    animateTo({
      duration: WIDGET_REFRESH_DELAY,
      curve: Curve.Linear,
      onFinish: (): void => {
        postCardAction(this, {
          'action': 'message',
          'params': {
            'msgTest': 'refresh:' + Date.now().toString()
          }
        });
        this.loadingOpacity = 0;
        this.isRefreshing = false;
      }
    }, (): void => {
      this.loadingOpacity = 1;
    });
  }

  @Builder
  RefreshButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
        .fontSize(WIDGET_REFRESH_ICON_SIZE)
        .fontWeight(FontWeight.Regular)
        .fontColor([$r('app.color.widget_refresh_icon')])
    }
    .width(WIDGET_BUTTON_SIZE)
    .height(WIDGET_BUTTON_SIZE)
    .backgroundColor($r('app.color.widget_refresh_background'))
    .borderRadius(WIDGET_BUTTON_RADIUS)
    .padding(0)
    .offset({ x: -WIDGET_CARD_PADDING, y: WIDGET_CARD_PADDING })
    .enabled(!this.isRefreshing)
    .onClick(() => {
      this.refresh();
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: WIDGET_CONTENT_GAP }) {
          Text($r('app.string.FormAbility_label'))
            .fontSize(WIDGET_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.widget_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ right: WIDGET_TITLE_TRAILING_SPACE })
            .layoutWeight(1)

          WidgetTokenItem({
            name: this.t1Name,
            remark: this.t1Remark,
            code: this.t1Code
          })
          .width('100%')
          .layoutWeight(2)

          Divider()
            .strokeWidth(1)
            .color($r('app.color.widget_divider'))
            .width('100%')

          WidgetTokenItem({
            name: this.t2Name,
            remark: this.t2Remark,
            code: this.t2Code
          })
          .width('100%')
          .layoutWeight(2)
          .visibility(this.t2Name.length > 0 ? Visibility.Visible : Visibility.Hidden)
        }
        .height('100%')
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(WIDGET_CARD_PADDING)
      }
      .width('100%')
      .height('100%')
      .padding(0)
      .borderRadius(WIDGET_CARD_RADIUS)
      .backgroundColor('#00000000')
      .enabled(!this.isRefreshing)
      .onClick(() => {
        postCardAction(this, {
          'action': 'router',
          'abilityName': 'EntryAbility',
          'params': {}
        });
      })

      this.RefreshButton()

      if (this.isRefreshing) {
        WidgetLoadingOverlay({ overlayOpacity: this.loadingOpacity })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.widget_card_background'))
    .borderRadius(WIDGET_CARD_RADIUS)
  }
}
