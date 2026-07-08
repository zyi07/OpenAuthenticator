import { WidgetTokenItem } from './WidgetTokenItem';

let M_STORAGE: LocalStorage = new LocalStorage();

@Entry(M_STORAGE)
@Component
struct WidgetMediumCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';
  @LocalStorageProp('t3Name') t3Name: string = '';
  @LocalStorageProp('t3Remark') t3Remark: string = '';
  @LocalStorageProp('t3Code') t3Code: string = '';
  @LocalStorageProp('t4Name') t4Name: string = '';
  @LocalStorageProp('t4Remark') t4Remark: string = '';
  @LocalStorageProp('t4Code') t4Code: string = '';

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
    .offset({ x: -12, y: 14 })
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
          Column({ space: 10 }) {
            Row({ space: 14 }) {
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
            .layoutWeight(1)

            Row({ space: 14 }) {
              WidgetTokenItem({
                name: this.t3Name,
                remark: this.t3Remark,
                code: this.t3Code,
                nameSize: 12,
                codeSize: 24
              })
              .layoutWeight(1)
              .visibility(this.t3Name.length > 0 ? Visibility.Visible : Visibility.Hidden)

              WidgetTokenItem({
                name: this.t4Name,
                remark: this.t4Remark,
                code: this.t4Code,
                nameSize: 12,
                codeSize: 24
              })
              .layoutWeight(1)
              .visibility(this.t4Name.length > 0 ? Visibility.Visible : Visibility.Hidden)
            }
            .width('100%')
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 14, right: 4, top: 14, bottom: 14 })

          Blank()
            .width(46)
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
