//
// ArkMusic主界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { common } from '@kit.AbilityKit'

//////////////////
// 导入自创建模块 //
/////////////////
import web_ui from './web_ui'
import arkmusic_start from './start'
import { log, notice, vib, reg_bg_run } from '../package/system_function'
import { audio_player } from '../package/audio_player/audio_player'

import { make_music_cache } from '../package/file_manager'

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主页面入口 //
//////////////
@Entry
@Component
struct Index {
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ///////////
  // 变量池 //
  //////////
  private context = getContext(this) as common.UIAbilityContext   // 身份证
  status: Boolean = false   // 状态

  ///////////
  // 更新池 //
  //////////
  @State ready: boolean = false   // 环境准备指示器
  @State ui_mode: boolean = true    // ui模式 ( false：arkui模式 true：webui模式 )
  @State volume_level: number = 0   // 音量大小

  ////////
  // 类 //
  ///////
  @State ark_music_player: audio_player = new audio_player(this.context)   // 播放器核心

  ///////////
  // 初始化 //
  //////////

  ////////////////
  // 进入app操作 //
  ///////////////
  aboutToAppear(): void {
    log('程序开始运行...')
    reg_bg_run(this.context) // 注册后台
    make_music_cache()
  }

  ////////////////
  // 退出app操作 //
  ///////////////
  aboutToDisappear(): void {
    log('程序结束运行...')
    this.ark_music_player.drop_it()
    log('再见.')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      /////////////
      // 开始页面 //
      ////////////
      if (!this.ready) {
        arkmusic_start({
          context: this.context,
          ready: this.ready
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .transition(
            TransitionEffect.opacity(0)
              .animation({ duration: 500 })
          )
      }

      /////////////
      // web界面 //
      ////////////
      if (this.ready && this.ui_mode) {
        web_ui({
          context: this.context,
          ark_music_player: this.ark_music_player,
          volume_level: this.volume_level
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(500)
      }

    }
  }
}