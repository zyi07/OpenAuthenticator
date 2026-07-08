import { WidgetTokenItem } from './WidgetTokenItem';

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
    .offset({ x: -10, y: 12 })
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
          Column({ space: 6 }) {
            WidgetTokenItem({
              name: this.t1Name,
              remark: this.t1Remark,
              code: this.t1Code,
              nameSize: 12,
              codeSize: 24
            })
            .layoutWeight(1)

            WidgetTokenItem({
              name: this.t2Name,
              remark: this.t2Remark,
              code: this.t2Code,
              nameSize: 12,
              codeSize: 24
            })
            .layoutWeight(1)
            .visibility(this.t2Name.length > 0 ? Visibility.Visible : Visibility.Hidden)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 12, right: 4, top: 12, bottom: 12 })

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
      .borderRadius(22)
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
    .borderRadius(22)
  }
}
