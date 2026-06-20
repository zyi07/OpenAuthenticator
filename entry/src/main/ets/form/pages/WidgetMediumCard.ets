import { WidgetCountdownRing } from './WidgetCountdownRing';

const M_YELLOW: string = '#EBC500';
const M_TEXT: string = '#111111';
const M_SUB: string = '#9A9A9E';
const M_DIV: string = '#F0F0F0';
const M_BG: string = '#FFFFFF';
let M_STORAGE: LocalStorage = new LocalStorage();

@Entry(M_STORAGE)
@Component
struct WidgetMediumCard {
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

  private displayName1(): string {
    const remark = this.t1Remark.trim();
    return remark.length > 0 ? `${this.t1Name}（${remark}）` : this.t1Name;
  }

  private displayName2(): string {
    const remark = this.t2Remark.trim();
    return remark.length > 0 ? `${this.t2Name}（${remark}）` : this.t2Name;
  }

  private displayName3(): string {
    const remark = this.t3Remark.trim();
    return remark.length > 0 ? `${this.t3Name}（${remark}）` : this.t3Name;
  }

  private displayName4(): string {
    const remark = this.t4Remark.trim();
    return remark.length > 0 ? `${this.t4Name}（${remark}）` : this.t4Name;
  }

  @Builder
  TokenRow(name: string, code: string, remaining: number, period: number,
    type: string, requestsRefresh: boolean) {
    Row() {
      Column() {
        Text(name)
          .fontSize(12)
          .fontColor(M_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(code)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(M_TEXT)
          .letterSpacing(1)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (type !== 'HOTP') {
        WidgetCountdownRing({
          initialRemaining: remaining,
          period: period,
          diameter: 24,
          strokeWidth: 2.5,
          fontSize: 9,
          accentColor: M_YELLOW,
          inactiveColor: '#B8BBC1',
          trackColor: '#E8EAED',
          textColor: M_SUB,
          requestsRefresh: requestsRefresh
        })
          .margin({ left: 10 })
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
            this.TokenRow(this.displayName1(), this.t1Code, this.t1Remaining, this.t1Period, this.t1Type, true)
            this.TokenRow(this.displayName2(), this.t2Code, this.t2Remaining, this.t2Period, this.t2Type, false)
          }
          .layoutWeight(1)
          .height('100%')

          Column() {
            this.TokenRow(this.displayName3(), this.t3Code, this.t3Remaining, this.t3Period, this.t3Type, false)
            this.TokenRow(this.displayName4(), this.t4Code, this.t4Remaining, this.t4Period, this.t4Type, false)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(M_BG)
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
