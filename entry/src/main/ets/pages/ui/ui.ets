//
// ui界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import emitter from '@ohos.events.emitter'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //

// 导入类 //
import class_global_config from '../../package/class_global_config'
import class_files_manager from "../../package/files_manager/class_files_manager"
import class_audio_player from '../../package/audio_player/class_audio_player'

// 导入页 //
import webui from './web_ui'
import web_ui from './web_ui'

// 变量池 //
const ui_path = getContext().filesDir + '/ui/'    // ui目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面入口 //
////////////
@Component
export default struct ui_index {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 更新池 //
  @State ui_mode: number = -1   // 页面更新指示 //

  // 类 //

  // 继承池 //
  @ObjectLink global_config: class_global_config
  @ObjectLink files_manager: class_files_manager
  @ObjectLink audio_player: class_audio_player
  @Link backup_occupy: boolean

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入app操作 //
  aboutToAppear(): void {

    // 检查配置文件 //
    try {fs.statSync(ui_path)} catch {fs.mkdir(ui_path)}

    // 开启广播 //
    this.emitter_status(true)

    // 配置放行 //
    this.ui_mode = this.global_config.ui_mode

  }

  // 退出app操作 //
  aboutToDisappear(): void {

    // 关闭广播 //
    this.emitter_status(false)

  }

  // 广播监听 //
  emitter_status(status: boolean) {

    // 开 //
    if (status) {

      // ui模式监听 //
      emitter.on({ eventId: 1012 }, () => {this.ui_mode = this.global_config.ui_mode})

    }

    // 关 //
    else {
      emitter.off(1012)
    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Stack() {

      // 0: 个性 (web) //
      if (this.ui_mode == 0) {
        web_ui({
          global_config: this.global_config,
          files_manager: this.files_manager,
          audio_player: this.audio_player,
          backup_occupy: this.backup_occupy
        })
          .width('100%').height('100%')
      }

      // 1: 简约 //
      if (this.ui_mode == 1) {}

      // 2: 灵动 //
      if (this.ui_mode == 2) {}

      // 3: 流态 //
      if (this.ui_mode == 3) {}

    }
  }
}