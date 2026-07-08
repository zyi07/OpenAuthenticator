import { WidgetTokenItem } from './WidgetTokenItem';

const SD_TEXT: string = '#F2F2F2';
const SD_BG: string = '#000000';
let SD_STORAGE: LocalStorage = new LocalStorage();

@Entry(SD_STORAGE)
@Component
struct WidgetSmallDarkCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($r('app.media.widget_pattern_dark'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.16)

      FormLink({
        action: 'router',
        abilityName: 'EntryAbility',
        params: {}
      }) {
        Column({ space: 6 }) {
          WidgetTokenItem({
            name: this.t1Name,
            remark: this.t1Remark,
            code: this.t1Code,
            textColor: SD_TEXT,
            nameSize: 12,
            codeSize: 22
          })
          .layoutWeight(1)

          WidgetTokenItem({
            name: this.t2Name,
            remark: this.t2Remark,
            code: this.t2Code,
            textColor: SD_TEXT,
            nameSize: 12,
            codeSize: 22
          })
          .layoutWeight(1)
          .visibility(this.t2Name.length > 0 ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 40, top: 12, bottom: 12 })
      }
      .width('100%')
      .height('100%')

      FormLink({
        action: 'message',
        params: { 'type': 'refresh' }
      }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(24)
            .height(24)
            .fill('#66888888')
          Image($r('app.media.ic_widget_refresh_white'))
            .width(12)
            .height(12)
            .objectFit(ImageFit.Contain)
        }
        .width(24)
        .height(24)
      }
      .width(24)
      .height(24)
      .offset({ x: -10, y: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SD_BG)
    .borderRadius(22)
  }
}
