import { WidgetCountdownRing } from './WidgetCountdownRing';

const ND_YELLOW: string = '#EBC500';
const ND_TEXT: string = '#F2F2F2';
const ND_SUB: string = '#A8ABB2';
const ND_BG: string = '#191A1D';
let ND_STORAGE: LocalStorage = new LocalStorage();

@Entry(ND_STORAGE)
@Component
struct WidgetMinimumDarkCard {
  @LocalStorageProp('t1Name') t1Name: string = '暂无令牌';
  @LocalStorageProp('t1Remark') t1Remark: string = '';
  @LocalStorageProp('t1Code') t1Code: string = '';
  @LocalStorageProp('t1Remaining') t1Remaining: number = 0;
  @LocalStorageProp('t1Period') t1Period: number = 30;
  @LocalStorageProp('t1Progress') t1Progress: number = 0;
  @LocalStorageProp('t1Type') t1Type: string = '';

  private displayName(): string {
    const remark = this.t1Remark.trim();
    return remark.length > 0 ? `${this.t1Name}（${remark}）` : this.t1Name;
  }

  build() {
    Stack() {
      Row({ space: 10 }) {
        Column({ space: 1 }) {
          Text(this.displayName())
            .fontSize(10)
            .fontColor(ND_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.t1Code)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(ND_TEXT)
            .letterSpacing(1)
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.t1Type !== 'HOTP') {
          WidgetCountdownRing({
            initialRemaining: this.t1Remaining,
            period: this.t1Period,
            diameter: 24,
            strokeWidth: 3,
            fontSize: 9,
            accentColor: ND_YELLOW,
            inactiveColor: '#767A82',
            trackColor: '#34363B',
            textColor: ND_SUB,
            requestsRefresh: true
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ND_BG)
    .borderRadius(14)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
