import { WidgetTokenItem } from './WidgetTokenItem';

const ND_TEXT: string = '#F2F2F2';
const ND_BG: string = '#000000';
let ND_STORAGE: LocalStorage = new LocalStorage();

@Entry(ND_STORAGE)
@Component
struct WidgetMinimumDarkCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';

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
        WidgetTokenItem({
          name: this.t1Name,
          remark: this.t1Remark,
          code: this.t1Code,
          textColor: ND_TEXT,
          nameSize: 12,
          codeSize: 22
        })
        .width('100%')
        .height('100%')
        .padding({ left: 10, right: 42, top: 6, bottom: 6 })
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
      .offset({ x: -8, y: 6 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ND_BG)
    .borderRadius(18)
  }
}
