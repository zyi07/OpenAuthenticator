import { WidgetCountdownRing } from './WidgetCountdownRing';

const SD_YELLOW: string = '#EBC500';
const SD_TEXT: string = '#F2F2F2';
const SD_SUB: string = '#A8ABB2';
const SD_DIV: string = '#34363B';
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
  @LocalStorageProp('t1Progress') t1Progress: number = 0;
  @LocalStorageProp('t1Type') t1Type: string = '';
  @LocalStorageProp('t2Name') t2Name: string = '';
  @LocalStorageProp('t2Remark') t2Remark: string = '';
  @LocalStorageProp('t2Code') t2Code: string = '';
  @LocalStorageProp('t2Remaining') t2Remaining: number = 0;
  @LocalStorageProp('t2Period') t2Period: number = 30;
  @LocalStorageProp('t2Progress') t2Progress: number = 0;
  @LocalStorageProp('t2Type') t2Type: string = '';

  private displayName(name: string, remark: string): string {
    const trimmed = remark.trim();
    return trimmed.length > 0 ? `${name}（${trimmed}）` : name;
  }

  @Builder
  private TokenRow(name: string, code: string, remaining: number, period: number,
    type: string, requestsRefresh: boolean) {
    Row({ space: 8 }) {
      Column({ space: 1 }) {
        Text(name)
          .fontSize(11)
          .fontColor(SD_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(code)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(SD_TEXT)
          .letterSpacing(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (type !== 'HOTP') {
        WidgetCountdownRing({
          initialRemaining: remaining,
          period: period,
          diameter: 20,
          strokeWidth: 2.5,
          fontSize: 8,
          accentColor: SD_YELLOW,
          inactiveColor: '#767A82',
          trackColor: SD_DIV,
          textColor: SD_SUB,
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
        this.TokenRow(this.displayName(this.t1Name, this.t1Remark), this.t1Code,
          this.t1Remaining, this.t1Period, this.t1Type, true)
        this.TokenRow(this.displayName(this.t2Name, this.t2Remark), this.t2Code,
          this.t2Remaining, this.t2Period, this.t2Type, false)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SD_BG)
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
