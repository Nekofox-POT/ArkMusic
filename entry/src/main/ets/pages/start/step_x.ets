//
// start界面 开始使用
//

// 导入类 //
import class_global_config from '../../package/class_global_config'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 界面入口 //
////////////
@Component
export default struct step_x {

  ///////////
  // 继承池 //
  //////////
  @Link start_ready: boolean   // 就绪指示
  @Link start_ui: boolean
  @ObjectLink global_config: class_global_config  // 全局配置管理器

  // 动画状态 //
  @State showIcon: boolean = false
  @State showButton: boolean = false
  @State exiting: boolean = false

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  aboutToAppear(): void {
    this.start_ready = true
    // 图标先从下往上渐变进入
    setTimeout(() => {
      this.showIcon = true
    }, 120)
    // 按钮延迟跟随
    setTimeout(() => {
      this.showButton = true
    }, 560)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Column() {

      /////////////
      // 完成图标 //
      ////////////
      Image($r('app.media.icon_white'))
        .width('512px').height('512px')
        .opacity(this.showIcon ? 1 : 0)
        .translate({ y: this.showIcon ? 0 : (this.exiting ? -60 : 60) })
        .animation({ duration: 560, curve: Curve.FastOutSlowIn })

      ////////////////
      // 开始使用按钮 //
      ///////////////
      Button('开始使用')
        .width('144vp')
        .height('72vp')
        .backgroundColor('rgba(244, 198, 206, 1.0)')
        .borderRadius('36vp')
        .fontSize('20fp')
        .opacity(this.showButton ? 1 : 0)
        .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
        .animation({ duration: 560, curve: Curve.FastOutSlowIn })
        .onClick(() => {
          this.global_config.save_data()
          this.exiting = true
          this.showIcon = false
          this.showButton = false
          setTimeout(() => {
            this.start_ui = false
          }, 560)
        })

    }
    .width('100%').height('100%')
    .padding({ left: 32, right: 32 })
    .backgroundColor('#fff')
    .justifyContent(FlexAlign.SpaceAround)
  }
}
