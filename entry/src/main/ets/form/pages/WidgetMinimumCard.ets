import { WidgetLoadingOverlay } from './WidgetLoadingOverlay';
import { WidgetTokenItem } from './WidgetTokenItem';
import {
  WIDGET_BUTTON_RADIUS,
  WIDGET_BUTTON_SIZE,
  WIDGET_CARD_PADDING,
  WIDGET_CARD_RADIUS,
  WIDGET_REFRESH_DELAY,
  WIDGET_REFRESH_ICON_SIZE
} from './WidgetMetrics';

let N_STORAGE: LocalStorage = new LocalStorage();

@Entry(N_STORAGE)
@Component
struct WidgetMinimumCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
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
    .offset({ x: -WIDGET_CARD_PADDING, y: 0 })
    .enabled(!this.isRefreshing)
    .onClick(() => {
      this.refresh();
    })
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        WidgetTokenItem({
          name: this.t1Name,
          remark: this.t1Remark,
          code: this.t1Code
        })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(WIDGET_CARD_PADDING)
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
