import { WidgetCountdownRing } from './WidgetCountdownRing';

const LD_YELLOW: string = '#EBC500';
const LD_TEXT: string = '#F2F2F2';
const LD_SUB: string = '#A8ABB2';
const LD_DIV: string = '#34363B';
const LD_BG: string = '#191A1D';
let LD_STORAGE: LocalStorage = new LocalStorage();

@Entry(LD_STORAGE)
@Component
struct WidgetLargeDarkCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t1Remaining') t1Remaining: number = 0;
  @LocalStorageProp('t1Period') t1Period: number = 30;
  @LocalStorageProp('t1Progress') t1Progress: number = 0;
  @LocalStorageProp('t1Type') t1Type: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';
  @LocalStorageProp('t2Remaining') t2Remaining: number = 0;
  @LocalStorageProp('t2Period') t2Period: number = 30;
  @LocalStorageProp('t2Progress') t2Progress: number = 0;
  @LocalStorageProp('t2Type') t2Type: string = '';
  @LocalStorageProp('t3Name') t3Name: string = '';
  @LocalStorageProp('t3Remark') t3Remark: string = '';
  @LocalStorageProp('t3Code') t3Code: string = '';
  @LocalStorageProp('t3Remaining') t3Remaining: number = 0;
  @LocalStorageProp('t3Period') t3Period: number = 30;
  @LocalStorageProp('t3Progress') t3Progress: number = 0;
  @LocalStorageProp('t3Type') t3Type: string = '';
  @LocalStorageProp('t4Name') t4Name: string = '';
  @LocalStorageProp('t4Remark') t4Remark: string = '';
  @LocalStorageProp('t4Code') t4Code: string = '';
  @LocalStorageProp('t4Remaining') t4Remaining: number = 0;
  @LocalStorageProp('t4Period') t4Period: number = 30;
  @LocalStorageProp('t4Progress') t4Progress: number = 0;
  @LocalStorageProp('t4Type') t4Type: string = '';
  @LocalStorageProp('t5Name') t5Name: string = '';
  @LocalStorageProp('t5Remark') t5Remark: string = '';
  @LocalStorageProp('t5Code') t5Code: string = '';
  @LocalStorageProp('t5Remaining') t5Remaining: number = 0;
  @LocalStorageProp('t5Period') t5Period: number = 30;
  @LocalStorageProp('t5Progress') t5Progress: number = 0;
  @LocalStorageProp('t5Type') t5Type: string = '';
  @LocalStorageProp('t6Name') t6Name: string = '';
  @LocalStorageProp('t6Remark') t6Remark: string = '';
  @LocalStorageProp('t6Code') t6Code: string = '';
  @LocalStorageProp('t6Remaining') t6Remaining: number = 0;
  @LocalStorageProp('t6Period') t6Period: number = 30;
  @LocalStorageProp('t6Progress') t6Progress: number = 0;
  @LocalStorageProp('t6Type') t6Type: string = '';
  @LocalStorageProp('t7Name') t7Name: string = '';
  @LocalStorageProp('t7Remark') t7Remark: string = '';
  @LocalStorageProp('t7Code') t7Code: string = '';
  @LocalStorageProp('t7Remaining') t7Remaining: number = 0;
  @LocalStorageProp('t7Period') t7Period: number = 30;
  @LocalStorageProp('t7Progress') t7Progress: number = 0;
  @LocalStorageProp('t7Type') t7Type: string = '';
  @LocalStorageProp('t8Name') t8Name: string = '';
  @LocalStorageProp('t8Remark') t8Remark: string = '';
  @LocalStorageProp('t8Code') t8Code: string = '';
  @LocalStorageProp('t8Remaining') t8Remaining: number = 0;
  @LocalStorageProp('t8Period') t8Period: number = 30;
  @LocalStorageProp('t8Progress') t8Progress: number = 0;
  @LocalStorageProp('t8Type') t8Type: string = '';

  private displayName(name: string, remark: string): string {
    const trimmed = remark.trim();
    return trimmed.length > 0 ? `${name}（${trimmed}）` : name;
  }

  @Builder
  private TokenRow(name: string, code: string, remaining: number, period: number,
    type: string, requestsRefresh: boolean) {
    if (name.length > 0) {
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text(name)
            .fontSize(12)
            .fontColor(LD_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(code)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(LD_TEXT)
            .letterSpacing(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (type !== 'HOTP') {
          WidgetCountdownRing({
            initialRemaining: remaining,
            period: period,
            diameter: 28,
            strokeWidth: 3,
            fontSize: 10,
            accentColor: LD_YELLOW,
            inactiveColor: '#767A82',
            trackColor: LD_DIV,
            textColor: LD_SUB,
            requestsRefresh: requestsRefresh
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
    } else {
      Row().width('100%').layoutWeight(1)
    }
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 16 }) {
          Column() {
            this.TokenRow(this.displayName(this.t1Name, this.t1Remark), this.t1Code,
              this.t1Remaining, this.t1Period, this.t1Type, true)
            this.TokenRow(this.displayName(this.t2Name, this.t2Remark), this.t2Code,
              this.t2Remaining, this.t2Period, this.t2Type, false)
            this.TokenRow(this.displayName(this.t3Name, this.t3Remark), this.t3Code,
              this.t3Remaining, this.t3Period, this.t3Type, false)
            this.TokenRow(this.displayName(this.t4Name, this.t4Remark), this.t4Code,
              this.t4Remaining, this.t4Period, this.t4Type, false)
          }
          .layoutWeight(1)
          .height('100%')

          Column() {
            this.TokenRow(this.displayName(this.t5Name, this.t5Remark), this.t5Code,
              this.t5Remaining, this.t5Period, this.t5Type, false)
            this.TokenRow(this.displayName(this.t6Name, this.t6Remark), this.t6Code,
              this.t6Remaining, this.t6Period, this.t6Type, false)
            this.TokenRow(this.displayName(this.t7Name, this.t7Remark), this.t7Code,
              this.t7Remaining, this.t7Period, this.t7Type, false)
            this.TokenRow(this.displayName(this.t8Name, this.t8Remark), this.t8Code,
              this.t8Remaining, this.t8Period, this.t8Type, false)
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 18 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LD_BG)
    .borderRadius(24)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
