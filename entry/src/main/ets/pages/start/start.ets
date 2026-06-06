//
// start界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入类 //
import class_global_config from '../../package/class_global_config'

// 导入页 //
import step_z from './step_z'
import step_a from './step_a'
import step_x from './step_x'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 开始界面入口 //
///////////////
@Component
@Preview
export default struct start_index {

  ///////////
  // 继承池 //
  //////////
  @Link start_ready: boolean                      // 环境准备指示器
  @Link start_ui: boolean                         // 开始界面开关
  @ObjectLink global_config: class_global_config  // 全局配置管理器
  @State page: number = 0

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      // 欢迎页 //
      if (this.page == 0) {
        step_z({
          page: this.page
        })
          .width('100%').height('100%')
      }

      // 第1页：播放器选择 //
      if (this.page == 1) {
        step_a({
          page: this.page,
          global_config: this.global_config
        })
          .width('100%').height('100%')
      }

      // 开始使用页 //
      if (this.page == 999) {
        step_x({
          start_ready: this.start_ready,
          start_ui: this.start_ui
        })
          .width('100%').height('100%')
      }

    }
    .width('100%').height('100%')
  }
}
