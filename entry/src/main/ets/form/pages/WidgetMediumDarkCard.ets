import { WidgetTokenItem } from './WidgetTokenItem';

const MD_TEXT: string = '#F2F2F2';
const MD_BG: string = '#000000';
let MD_STORAGE: LocalStorage = new LocalStorage();

@Entry(MD_STORAGE)
@Component
struct WidgetMediumDarkCard {
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
        Column({ space: 10 }) {
          Row({ space: 14 }) {
            WidgetTokenItem({
              name: this.t1Name,
              remark: this.t1Remark,
              code: this.t1Code,
              textColor: MD_TEXT,
              nameSize: 12,
              codeSize: 21
            })
            .layoutWeight(1)

            WidgetTokenItem({
              name: this.t2Name,
              remark: this.t2Remark,
              code: this.t2Code,
              textColor: MD_TEXT,
              nameSize: 12,
              codeSize: 21
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
              textColor: MD_TEXT,
              nameSize: 12,
              codeSize: 21
            })
            .layoutWeight(1)
            .visibility(this.t3Name.length > 0 ? Visibility.Visible : Visibility.Hidden)

            WidgetTokenItem({
              name: this.t4Name,
              remark: this.t4Remark,
              code: this.t4Code,
              textColor: MD_TEXT,
              nameSize: 12,
              codeSize: 21
            })
            .layoutWeight(1)
            .visibility(this.t4Name.length > 0 ? Visibility.Visible : Visibility.Hidden)
          }
          .width('100%')
          .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 14, right: 42, top: 14, bottom: 14 })
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
      .offset({ x: -12, y: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD_BG)
    .borderRadius(22)
  }
}
