//
// start界面 第二步
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 界面入口 //
////////////
@Component
export default struct step_b {

  ///////////
  // 继承池 //
  //////////
  @Link page: number   // 通过指示页

  // 教程状态 //
  @State @Watch('onStepChange') step: number = 0   // 0=询问 1=下载目录 2=外部导入 3=使用方法 4=排序删除

  // 动画状态 //
  @State showTitle: boolean = false
  @State showImage: boolean = false
  @State showButton: boolean = false
  @State exiting: boolean = false

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  aboutToAppear(): void {
    this.animateIn()
  }

  onStepChange(): void {
    this.animateIn()
  }

  animateIn(): void {
    this.exiting = false
    this.showTitle = false
    this.showImage = false
    this.showButton = false
    setTimeout(() => { this.showTitle = true }, 80)
    setTimeout(() => { this.showImage = true }, 360)
    setTimeout(() => { this.showButton = true }, 640)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Column() {

      ///////////////
      // 询问教程 //
      /////////////
      if (this.step === 0) {
        Column() {
          Text('是否查看使用教程？')
            .fontSize('22fp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .opacity(this.showTitle ? 1 : 0)
            .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Row() {
            Button('跳过')
              .width('120vp').height('72vp')
              .backgroundColor('#eee')
              .borderRadius('36vp')
              .fontColor('#666')
              .fontSize('18fp')
              .onClick(() => {
                this.exiting = true
                this.showTitle = false
                this.showButton = false
                setTimeout(() => { this.page = 3 }, 500)
              })
            Button('查看教程')
              .width('120vp').height('72vp')
              .backgroundColor('rgba(244, 198, 206, 1.0)')
              .borderRadius('36vp')
              .fontColor('#fff')
              .fontSize('18fp')
              .margin({ left: 24 })
              .onClick(() => {
                this.exiting = true
                this.showTitle = false
                this.showButton = false
                setTimeout(() => { this.step = 1 }, 500)
              })
          }
          .opacity(this.showButton ? 1 : 0)
          .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 500, curve: Curve.FastOutSlowIn })
          .justifyContent(FlexAlign.Center)
        }
        .width('100%').height('100%')
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(HorizontalAlign.Center)
      }

      /////////////////////////
      // 教程1：文件摆放(1) //
      /////////////////////////
      if (this.step === 1) {
        Column() {
          Column() {
            Text('因HarmonyOS权限限制')
              .fontSize('16fp').fontColor('#666')
            Text('建议将音频文件放置在')
              .fontSize('16fp').fontColor('#666')
              .margin({ top: 8 })
            Text('Download / 铃音')
              .fontSize('20fp')
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(244, 198, 206, 1.0)')
              .margin({ top: 8 })
            Text('目录下')
              .fontSize('16fp').fontColor('#666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.showTitle ? 1 : 0)
          .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Image($rawfile('first_start/lin_music_download_dir.jpg'))
            .width('80%')
            .objectFit(ImageFit.Contain)
            .borderRadius('16vp')
            .margin({ top: 24, bottom: 24 })
            .opacity(this.showImage ? 1 : 0)
            .translate({ y: this.showImage ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Button('下一步')
            .width('144vp').height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .fontSize('18fp')
            .opacity(this.showButton ? 1 : 0)
            .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              this.exiting = true
              this.showTitle = false
              this.showImage = false
              this.showButton = false
              setTimeout(() => { this.step = 2 }, 500)
            })
        }
        .width('100%').height('100%')
        .padding({ left: 32, right: 32 })
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(HorizontalAlign.Center)
      }

      /////////////////////////
      // 教程2：文件摆放(2) //
      /////////////////////////
      if (this.step === 2) {
        Column() {
          Column() {
            Text('您也可以使用')
              .fontSize('16fp').fontColor('#666')
            Text('"导入歌曲"')
              .fontSize('20fp')
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(244, 198, 206, 1.0)')
              .margin({ top: 8 })
            Text('来导入外部音乐使用')
              .fontSize('16fp').fontColor('#666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.showTitle ? 1 : 0)
          .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Image($rawfile('first_start/lin_music_external_dir.png'))
            .width('80%')
            .objectFit(ImageFit.Contain)
            .borderRadius('16vp')
            .margin({ top: 24, bottom: 24 })
            .opacity(this.showImage ? 1 : 0)
            .translate({ y: this.showImage ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Button('下一步')
            .width('144vp').height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .fontSize('18fp')
            .opacity(this.showButton ? 1 : 0)
            .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              this.exiting = true
              this.showTitle = false
              this.showImage = false
              this.showButton = false
              setTimeout(() => { this.step = 3 }, 500)
            })
        }
        .width('100%').height('100%')
        .padding({ left: 32, right: 32 })
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(HorizontalAlign.Center)
      }

      /////////////////////
      // 教程3：使用方法 //
      /////////////////////
      if (this.step === 3) {
        Column() {
          Column() {
            // 第一组：滑动切歌 //
            Column() {
              Text('左右滑动音乐栏，可切换歌曲')
                .fontSize('16fp').fontColor('#666')

              Image($rawfile('first_start/switch.gif'))
                .width('70%')
                .objectFit(ImageFit.Contain)
                .borderRadius('12vp')
                .margin({ top: 16, bottom: 24 })
            }
            .opacity(this.showTitle ? 1 : 0)
            .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })

            // 第二组：长按调进度 //
            Column() {
              Text('长按音乐栏，可调节歌曲进度')
                .fontSize('16fp').fontColor('#666')

              Image($rawfile('first_start/adjust.gif'))
                .width('70%')
                .objectFit(ImageFit.Contain)
                .borderRadius('12vp')
                .margin({ top: 16, bottom: 24 })
            }
            .opacity(this.showImage ? 1 : 0)
            .translate({ y: this.showImage ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          Button('下一步')
            .width('144vp').height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .fontSize('18fp')
            .opacity(this.showButton ? 1 : 0)
            .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              this.exiting = true
              this.showTitle = false
              this.showImage = false
              this.showButton = false
              setTimeout(() => { this.step = 4 }, 500)
            })
        }
        .width('100%').height('100%')
        .padding({ left: 32, right: 32 })
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(HorizontalAlign.Center)
      }

      /////////////////////
      // 教程4：排序删除 //
      /////////////////////
      if (this.step === 4) {
        Column() {
          Column() {
            Text('在播放列表页面')
              .fontSize('16fp').fontColor('#666')
            Text('可点击右边的 "双小点"')
              .fontSize('16fp').fontColor('#666')
              .margin({ top: 8 })
            Text('进行排序 / 删除操作')
              .fontSize('16fp').fontColor('#666')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .opacity(this.showTitle ? 1 : 0)
          .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Image($rawfile('first_start/sort_and_delete.gif'))
            .width('70%')
            .objectFit(ImageFit.Contain)
            .borderRadius('12vp')
            .margin({ top: 24, bottom: 24 })
            .opacity(this.showImage ? 1 : 0)
            .translate({ y: this.showImage ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })

          Button('下一步')
            .width('144vp').height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .fontSize('18fp')
            .opacity(this.showButton ? 1 : 0)
            .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
            .animation({ duration: 500, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              this.exiting = true
              this.showTitle = false
              this.showImage = false
              this.showButton = false
              setTimeout(() => { this.page = 3 }, 500)
            })
        }
        .width('100%').height('100%')
        .padding({ left: 32, right: 32 })
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .alignItems(HorizontalAlign.Center)
      }

    }
    .width('100%').height('100%')
    .clip(true)
  }
}
