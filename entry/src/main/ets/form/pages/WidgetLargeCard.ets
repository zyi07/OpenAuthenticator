import { WidgetCountdownRing } from './WidgetCountdownRing';

const L_YELLOW: string = '#EBC500';
const L_TEXT: string = '#111111';
const L_SUB: string = '#9A9A9E';
const L_BG: string = '#FFFFFF';
let L_STORAGE: LocalStorage = new LocalStorage();

@Entry(L_STORAGE)
@Component
struct WidgetLargeCard {
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
  @LocalStorageProp('t5Name') t5Name: string = '';
  @LocalStorageProp('t5Remark') t5Remark: string = '';
  @LocalStorageProp('t5Code') t5Code: string = '';
  @LocalStorageProp('t5Remaining') t5Remaining: number = 0;
  @LocalStorageProp('t5Period') t5Period: number = 30;
  @LocalStorageProp('t5Type') t5Type: string = '';
  @LocalStorageProp('t6Name') t6Name: string = '';
  @LocalStorageProp('t6Remark') t6Remark: string = '';
  @LocalStorageProp('t6Code') t6Code: string = '';
  @LocalStorageProp('t6Remaining') t6Remaining: number = 0;
  @LocalStorageProp('t6Period') t6Period: number = 30;
  @LocalStorageProp('t6Type') t6Type: string = '';
  @LocalStorageProp('t7Name') t7Name: string = '';
  @LocalStorageProp('t7Remark') t7Remark: string = '';
  @LocalStorageProp('t7Code') t7Code: string = '';
  @LocalStorageProp('t7Remaining') t7Remaining: number = 0;
  @LocalStorageProp('t7Period') t7Period: number = 30;
  @LocalStorageProp('t7Type') t7Type: string = '';
  @LocalStorageProp('t8Name') t8Name: string = '';
  @LocalStorageProp('t8Remark') t8Remark: string = '';
  @LocalStorageProp('t8Code') t8Code: string = '';
  @LocalStorageProp('t8Remaining') t8Remaining: number = 0;
  @LocalStorageProp('t8Period') t8Period: number = 30;
  @LocalStorageProp('t8Type') t8Type: string = '';

  private dn(name: string, remark: string): string {
    const t = remark.trim();
    return t.length > 0 ? `${name}（${t}）` : name;
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 14 }) {
          Column() {
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t1Name, this.t1Remark)).fontSize(11).fontColor(L_SUB).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t1Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t1Type !== 'HOTP') {
                WidgetCountdownRing({ initialRemaining: this.t1Remaining, period: this.t1Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t2Name, this.t2Remark)).fontSize(11).fontColor(L_SUB).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t2Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t2Type !== 'HOTP' && this.t2Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t2Remaining, period: this.t2Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t3Name, this.t3Remark)).fontSize(11).fontColor(L_SUB).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t3Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t3Type !== 'HOTP' && this.t3Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t3Remaining, period: this.t3Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t4Name, this.t4Remark)).fontSize(11).fontColor(L_SUB).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t4Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t4Type !== 'HOTP' && this.t4Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t4Remaining, period: this.t4Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
          }.layoutWeight(1).height('100%')

          Column() {
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t5Name, this.t5Remark)).fontSize(11).fontColor(L_SUB).maxLines(1
                  ).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t5Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t5Type !== 'HOTP' && this.t5Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t5Remaining, period: this.t5Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t6Name, this.t6Remark)).fontSize(11).fontColor(L_SUB).maxLines(1
                  ).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t6Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t6Type !== 'HOTP' && this.t6Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t6Remaining, period: this.t6Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t7Name, this.t7Remark)).fontSize(11).fontColor(L_SUB).maxLines(1
                  ).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t7Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t7Type !== 'HOTP' && this.t7Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t7Remaining, period: this.t7Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
            Divider().color('#F0F0F0').strokeWidth(1).width('100%')
            Row({ space: 8 }) {
              Column({ space: 1 }) {
                Text(this.dn(this.t8Name, this.t8Remark)).fontSize(11).fontColor(L_SUB).maxLines(1
                  ).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                Text(this.t8Code).fontSize(20).fontWeight(FontWeight.Medium).fontColor(L_TEXT)
                  .letterSpacing(1).maxLines(1).width('100%').textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.t8Type !== 'HOTP' && this.t8Name.length > 0) {
                WidgetCountdownRing({ initialRemaining: this.t8Remaining, period: this.t8Period,
                  diameter: 22, strokeWidth: 2.5, fontSize: 9, accentColor: L_YELLOW,
                  inactiveColor: '#B8BBC1', trackColor: '#E8EAED', textColor: L_SUB })
              }
            }.width('100%').layoutWeight(1).alignItems(VerticalAlign.Center)
          }.layoutWeight(1).height('100%')
        }.width('100%').layoutWeight(1)
      }
      .width('100%').height('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    }
    .width('100%').height('100%').backgroundColor(L_BG).borderRadius(24)
    .onClick(() => {
      postCardAction(this, { 'action': 'router', 'abilityName': 'EntryAbility', 'params': {} });
    })
  }
}
