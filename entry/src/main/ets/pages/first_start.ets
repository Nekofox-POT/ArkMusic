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

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      ///////////////
      // 初始化向导 //
      /////////////
      Column() {
        Image($r('app.media.foreground_backup')).width('512px').height('512px')
        Button('开始使用')
          .width('144vp')
          .height('72vp')
          .backgroundColor('rgba(244, 198, 206, 1.0)')
          .onClick(() => {
            this.first_start = false
          })
      }
      .width('100%').height('100%')
      .position({ x: 0, y: 0 })
      .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
      .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
    }
  }
}