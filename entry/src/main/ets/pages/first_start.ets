//
// start界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 开始界面入口 //
///////////////
@Component
export default struct first_start {

  ///////////
  // 继承池 //
  //////////
  @Link first_start: boolean    // 环境准备指示器
  @State currentPage: number = 1

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      /////////////////
      // 第一页：告知 //
      /////////////////
      if (this.currentPage === 1) {
        Column() {
          Column() {
            Text('因HarmonyOS的限制')
              .fontSize('20fp')
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
            Text('请将歌曲文件放入')
              .fontSize('16fp')
              .fontColor('#666')
              .margin({ top: 12 })
            Text('Download / 铃音')
              .fontSize('18fp')
              .fontWeight(FontWeight.Bold)
              .fontColor('rgba(244, 198, 206, 1.0)')
              .margin({ top: 6 })
            Image($rawfile('first_start/lin_music_download_dir.jpg'))
              .width('80%')
              .objectFit(ImageFit.Contain)
              .borderRadius('16vp')
              .margin({ top: 24, bottom: 24 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          Button('下一步')
            .width('144vp')
            .height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .onClick(() => {
              this.currentPage = 2
            })
        }
        .width('100%').height('100%')
        .padding({ left: 32, right: 32 })
        .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.IDENTITY,
          TransitionEffect.translate({ x: -200 }).animation({ duration: 480, curve: Curve.FastOutSlowIn })
        ))
      }

      ///////////////////
      // 第二页：开始 //
      ///////////////////
      if (this.currentPage === 2) {
        Column() {
          Image($r('app.media.foreground_backup')).width('512px').height('512px')
          Button('开始使用')
            .width('144vp')
            .height('72vp')
            .backgroundColor('rgba(244, 198, 206, 1.0)')
            .borderRadius('36vp')
            .onClick(() => {
              this.first_start = false
            })
        }
        .width('100%').height('100%')
        .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.translate({ x: 200 }).animation({ duration: 480, curve: Curve.FastOutSlowIn }),
          TransitionEffect.IDENTITY
        ))
      }
    }
    .width('100%').height('100%')
    .clip(true)
  }
}
