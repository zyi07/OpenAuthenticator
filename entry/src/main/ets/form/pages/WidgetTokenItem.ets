import { WIDGET_CODE_SIZE, WIDGET_NAME_SIZE, WIDGET_TEXT_GAP } from './WidgetMetrics';

@Component
export struct WidgetTokenItem {
  @Prop name: string = '';
  @Prop remark: string = '';
  @Prop code: string = '';
  @Prop nameColor: ResourceColor = $r('app.color.widget_text_secondary');
  @Prop codeColor: ResourceColor = $r('app.color.widget_code');
  @Prop nameSize: number = WIDGET_NAME_SIZE;
  @Prop codeSize: number = WIDGET_CODE_SIZE;

  private displayName(): string {
    const tokenName = this.name.length > 0 ? this.name : '暂无令牌';
    const issuer = this.remark.trim();
    return issuer.length > 0 ? tokenName + ' (' + issuer + ')' : tokenName;
  }

  private displayCode(): string {
    return this.code.split(' ').join('');
  }

  build() {
    Column({ space: WIDGET_TEXT_GAP }) {
      Text(this.displayName())
        .fontSize(this.nameSize)
        .fontColor(this.nameColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.displayCode())
        .fontSize(this.codeSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.codeColor)
        .maxLines(1)
        .width('100%')
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .contentTransition(new NumericTextTransition({
          flipDirection: FlipDirection.UP,
          enableBlur: true
        }))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }
}
