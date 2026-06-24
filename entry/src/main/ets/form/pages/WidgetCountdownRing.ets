@Component
export struct WidgetCountdownRing {
  @Prop @Watch('onRemainingUpdate') initialRemaining: number = 0;
  @Prop period: number = 30;
  @Prop diameter: number = 24;
  @Prop strokeWidth: number = 3;
  @Prop fontSize: number = 9;
  @Prop accentColor: string = '#EBC500';
  @Prop inactiveColor: string = '#B8BBC1';
  @Prop trackColor: string = '#E8EAED';
  @Prop textColor: string = '#9A9A9E';
  @Prop requestsRefresh: boolean = false;
  @State private liveRemaining: number = 0;
  @State private liveProgress: number = 0;
  @State private refreshRequested: boolean = false;
  private controller: TextTimerController = new TextTimerController();

  aboutToAppear(): void {
    this.liveRemaining = this.initialRemaining;
    this.liveProgress = this.period > 0 ? this.initialRemaining / this.period * 100 : 0;
  }

  private onRemainingUpdate(): void {
    this.refreshRequested = false;
    this.liveRemaining = this.initialRemaining;
    this.liveProgress = this.period > 0 ? this.initialRemaining / this.period * 100 : 0;
    try {
      this.controller.reset();
      this.controller.start();
    } catch (e) {
    }
  }

  build() {
    Stack() {
      Progress({ value: this.liveProgress, total: 100, type: ProgressType.Ring })
        .width(this.diameter)
        .height(this.diameter)
        .color(this.liveRemaining <= 5 ? this.accentColor : this.inactiveColor)
        .style({ strokeWidth: this.strokeWidth, enableSmoothEffect: true })
        .backgroundColor(this.trackColor)

      TextTimer({
        isCountDown: true,
        count: Math.max(0, this.initialRemaining) * 1000,
        controller: this.controller
      })
        .format('ss')
        .fontSize(this.fontSize)
        .fontColor(this.textColor)
        .onAppear(() => {
          this.controller.start();
        })
        .onTimer((utc: number, elapsedTime: number) => {
          this.liveRemaining = Math.max(0, this.initialRemaining - Math.floor(elapsedTime / 1000));
          this.liveProgress = this.period > 0 ? this.liveRemaining / this.period * 100 : 0;
          if (this.requestsRefresh && this.liveRemaining === 0 && !this.refreshRequested) {
            this.refreshRequested = true;
            postCardAction(this, {
              'action': 'message',
              'params': 'refresh'
            });
          }
        })
    }
    .width(this.diameter)
    .height(this.diameter)
    .alignContent(Alignment.Center)
  }
}
