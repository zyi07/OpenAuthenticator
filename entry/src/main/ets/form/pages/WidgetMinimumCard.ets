import { WidgetTokenItem } from './WidgetTokenItem';

let N_STORAGE: LocalStorage = new LocalStorage();

@Entry(N_STORAGE)
@Component
struct WidgetMinimumCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';

  @Builder
  RefreshButton() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Image($r('app.media.ic_widget_refresh'))
        .width(12)
        .height(12)
        .objectFit(ImageFit.Contain)
    }
    .width(24)
    .height(24)
    .backgroundColor($r('app.color.widget_refresh_background'))
    .borderRadius(12)
    .padding(0)
    .offset({ x: -8, y: 6 })
    .onClick(() => {
      postCardAction(this, {
        'action': 'message',
        'params': {
          'msgTest': `refresh:${Date.now()}`
        }
      });
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($r('app.media.widget_pattern'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.46)

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          WidgetTokenItem({
            name: this.t1Name,
            remark: this.t1Remark,
            code: this.t1Code,
            nameSize: 12,
            codeSize: 24
          })
          .width('100%')
          .height('100%')
          .padding({ left: 10, right: 4, top: 6, bottom: 6 })

          Blank()
            .width(44)
            .height('100%')
        }
        .height('100%')
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(0)
      .borderRadius(18)
      .backgroundColor('#00000000')
      .onClick(() => {
        postCardAction(this, {
          'action': 'router',
          'abilityName': 'EntryAbility',
          'params': {}
        });
      })

      this.RefreshButton()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.widget_card_background'))
    .borderRadius(18)
  }
}
