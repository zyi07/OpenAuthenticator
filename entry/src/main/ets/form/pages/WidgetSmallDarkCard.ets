import { WidgetCountdownRing } from './WidgetCountdownRing';

const SD_YELLOW: string = '#EBC500';
const SD_TEXT: string = '#F2F2F2';
const SD_SUB: string = '#A8ABB2';
const SD_BG: string = '#191A1D';
let SD_STORAGE: LocalStorage = new LocalStorage();

@Entry(SD_STORAGE)
@Component
struct WidgetSmallDarkCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t1Remaining') t1Remaining: number = 0;
  @LocalStorageProp('t1Period') t1Period: number = 30;
  @LocalStorageProp('t1Type') t1Type: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';
  @LocalStorageProp('t2Remaining') t2Remaining: number = 0;
  @LocalStorageProp('t2Period') t2Period: number = 30;
  @LocalStorageProp('t2Type') t2Type: string = '';

  private dn(name: string, remark: string): string {
    const t = remark.trim();
    return t.length > 0 ? `${name}（${t}）` : name;
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 8 }) {
          Column({ space: 1 }) {
            Text(this.dn(this.t1Name, this.t1Remark))
              .fontSize(10).fontColor(SD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t1Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(SD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t1Type !== 'HOTP') {
            WidgetCountdownRing({
              initialRemaining: this.t1Remaining,
              period: this.t1Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: SD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: SD_SUB,
              requestsRefresh: true
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)

        Divider().color('#34363B').strokeWidth(1).width('100%')

        Row({ space: 8 }) {
          Column({ space: 1 }) {
            Text(this.dn(this.t2Name, this.t2Remark))
              .fontSize(10).fontColor(SD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t2Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(SD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t2Type !== 'HOTP' && this.t2Name.length > 0) {
            WidgetCountdownRing({
              initialRemaining: this.t2Remaining,
              period: this.t2Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: SD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: SD_SUB,
              requestsRefresh: false
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
      }
      .width('100%').height('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    }
    .width('100%').height('100%').backgroundColor(SD_BG).borderRadius(16)
    .onClick(() => {
      postCardAction(this, { 'action': 'router', 'abilityName': 'EntryAbility', 'params': {} });
    })
  }
}
