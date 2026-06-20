import { WidgetCountdownRing } from './WidgetCountdownRing';

const N_YELLOW: string = '#EBC500';
const N_TEXT: string = '#111111';
const N_SUB: string = '#9A9A9E';
const N_BG: string = '#FFFFFF';
let N_STORAGE: LocalStorage = new LocalStorage();

@Entry(N_STORAGE)
@Component
struct WidgetMinimumCard {
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
          .fontColor(N_SUB)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.t1Code)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(N_TEXT)
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
          accentColor: N_YELLOW,
          inactiveColor: '#B8BBC1',
          trackColor: '#E8EAED',
          textColor: N_SUB,
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
    .backgroundColor(N_BG)
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
