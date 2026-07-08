@Component
export struct WidgetTokenItem {
  @Prop name: string = '';
  @Prop remark: string = '';
  @Prop code: string = '';
  @Prop textColor: ResourceColor = $r('app.color.widget_text_primary');
  @Prop nameSize: number = 14;
  @Prop codeSize: number = 26;

  private displayName(): string {
    const tokenName = this.name.length > 0 ? this.name : '暂无令牌';
    const issuer = this.remark.trim();
    return issuer.length > 0 ? `${tokenName}(${issuer})` : tokenName;
  }

  private displayCode(): string {
    return this.code.split(' ').join('');
  }

  build() {
    Column({ space: 2 }) {
      Text(this.displayName())
        .fontSize(this.nameSize)
        .fontColor(this.textColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.displayCode())
        .fontSize(this.codeSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .letterSpacing(1)
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
