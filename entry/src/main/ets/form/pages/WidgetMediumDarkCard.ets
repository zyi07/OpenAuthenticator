import { WidgetCountdownRing } from './WidgetCountdownRing';

const MD_YELLOW: string = '#EBC500';
const MD_TEXT: string = '#F2F2F2';
const MD_SUB: string = '#A8ABB2';
const MD_DIV: string = '#34363B';
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

  private displayName(name: string, remark: string): string {
    const trimmed = remark.trim();
    return trimmed.length > 0 ? `${name}（${trimmed}）` : name;
  }

  @Builder
  private TokenRow(name: string, code: string, remaining: number, period: number,
    type: string, requestsRefresh: boolean) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(name)
          .fontSize(12)
          .fontColor(MD_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(code)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(MD_TEXT)
          .letterSpacing(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (type !== 'HOTP') {
        WidgetCountdownRing({
          initialRemaining: remaining,
          period: period,
          diameter: 24,
          strokeWidth: 2.5,
          fontSize: 9,
          accentColor: MD_YELLOW,
          inactiveColor: '#767A82',
          trackColor: MD_DIV,
          textColor: MD_SUB,
          requestsRefresh: requestsRefresh
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 14 }) {
          Column() {
            this.TokenRow(this.displayName(this.t1Name, this.t1Remark), this.t1Code,
              this.t1Remaining, this.t1Period, this.t1Type, true)
            this.TokenRow(this.displayName(this.t2Name, this.t2Remark), this.t2Code,
              this.t2Remaining, this.t2Period, this.t2Type, false)
          }
          .layoutWeight(1)
          .height('100%')

          Column() {
            this.TokenRow(this.displayName(this.t3Name, this.t3Remark), this.t3Code,
              this.t3Remaining, this.t3Period, this.t3Type, false)
            this.TokenRow(this.displayName(this.t4Name, this.t4Remark), this.t4Code,
              this.t4Remaining, this.t4Period, this.t4Type, false)
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MD_BG)
    .borderRadius(20)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
