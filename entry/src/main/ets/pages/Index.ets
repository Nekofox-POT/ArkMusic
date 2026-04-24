//
// ArkMusic主界面
// 频段：9
// 912：给webui的返回广播
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { common } from '@kit.AbilityKit'
import router from '@ohos.router';
import emitter from '@ohos.events.emitter'

//////////////////
// 导入自创建模块 //
/////////////////
import web_ui from './web_ui'
import arkmusic_start from './start'
import ark_music_scan from './scan'

import { log, notice, vib, reg_bg_run } from '../package/system_function'
import { audio_player } from '../package/audio_player/audio_player'

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
  @State scan_ui: boolean = true   // 扫描界面控制

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
  }

  ////////////////
  // 退出app操作 //
  ///////////////
  aboutToDisappear(): void {
    log('程序结束运行...')
    this.ark_music_player.drop_it()
    log('再见.')
  }

  /////////////
  // 返回操作 //
  ////////////
  onBackPress(): boolean {

    // ---- 在这里执行你指定的任务 ----
    emitter.emit({ eventId: 912 })
    // --------------------------------

    // 返回 true：表示消费掉该返回事件，原生页面不退出，Web也不后退
    // 返回 false：表示放行，原生执行默认的退出页面动作
    return true
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
      // 扫描界面 //
      ////////////
      if (this.scan_ui) {
        ark_music_scan({
          scan_ui: this.scan_ui
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(950)
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