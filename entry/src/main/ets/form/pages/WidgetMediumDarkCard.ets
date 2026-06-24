import { WidgetCountdownRing } from './WidgetCountdownRing';

const MD_YELLOW: string = '#EBC500';
const MD_TEXT: string = '#F2F2F2';
const MD_SUB: string = '#A8ABB2';
const MD_BG: string = '#191A1D';
let MD_STORAGE: LocalStorage = new LocalStorage();

@Entry(MD_STORAGE)
@Component
struct WidgetMediumDarkCard {
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
  @LocalStorageProp('t3Name') t3Name: string = '';
  @LocalStorageProp('t3Remark') t3Remark: string = '';
  @LocalStorageProp('t3Code') t3Code: string = '';
  @LocalStorageProp('t3Remaining') t3Remaining: number = 0;
  @LocalStorageProp('t3Period') t3Period: number = 30;
  @LocalStorageProp('t3Type') t3Type: string = '';
  @LocalStorageProp('t4Name') t4Name: string = '';
  @LocalStorageProp('t4Remark') t4Remark: string = '';
  @LocalStorageProp('t4Code') t4Code: string = '';
  @LocalStorageProp('t4Remaining') t4Remaining: number = 0;
  @LocalStorageProp('t4Period') t4Period: number = 30;
  @LocalStorageProp('t4Type') t4Type: string = '';

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
              .fontSize(11).fontColor(MD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t1Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(MD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t1Type !== 'HOTP') {
            WidgetCountdownRing({
              initialRemaining: this.t1Remaining, period: this.t1Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: MD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: MD_SUB, requestsRefresh: true
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)

        Divider().color('#34363B').strokeWidth(1).width('100%')

        Row({ space: 8 }) {
          Column({ space: 1 }) {
            Text(this.dn(this.t2Name, this.t2Remark))
              .fontSize(11).fontColor(MD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t2Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(MD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t2Type !== 'HOTP' && this.t2Name.length > 0) {
            WidgetCountdownRing({
              initialRemaining: this.t2Remaining, period: this.t2Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: MD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: MD_SUB, requestsRefresh: false
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)

        Divider().color('#34363B').strokeWidth(1).width('100%')

        Row({ space: 8 }) {
          Column({ space: 1 }) {
            Text(this.dn(this.t3Name, this.t3Remark))
              .fontSize(11).fontColor(MD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t3Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(MD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t3Type !== 'HOTP' && this.t3Name.length > 0) {
            WidgetCountdownRing({
              initialRemaining: this.t3Remaining, period: this.t3Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: MD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: MD_SUB, requestsRefresh: false
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)

        Divider().color('#34363B').strokeWidth(1).width('100%')

        Row({ space: 8 }) {
          Column({ space: 1 }) {
            Text(this.dn(this.t4Name, this.t4Remark))
              .fontSize(11).fontColor(MD_SUB).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            Text(this.t4Code)
              .fontSize(18).fontWeight(FontWeight.Medium).fontColor(MD_TEXT)
              .letterSpacing(1).maxLines(1)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.t4Type !== 'HOTP' && this.t4Name.length > 0) {
            WidgetCountdownRing({
              initialRemaining: this.t4Remaining, period: this.t4Period,
              diameter: 20, strokeWidth: 2.5, fontSize: 8,
              accentColor: MD_YELLOW, inactiveColor: '#767A82',
              trackColor: '#34363B', textColor: MD_SUB, requestsRefresh: false
            })
          }
        }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
      }
      .width('100%').height('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    }
    .width('100%').height('100%').backgroundColor(MD_BG).borderRadius(20)
    .onClick(() => {
      postCardAction(this, { 'action': 'router', 'abilityName': 'EntryAbility', 'params': {} });
    })
  }
}
