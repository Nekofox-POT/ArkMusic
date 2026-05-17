//
// ArkMusic主界面
// 频段：9
// 912：给webui的返回广播
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { common } from '@kit.AbilityKit'
import emitter from '@ohos.events.emitter'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import { class_files_manager } from '../package/class_files_manager'
import { log, notice, reg_bg_run } from '../package/system_function'
import { class_audio_player } from '../package/class_audio_player/class_audio_player'

// 导入类 //
import { class_global_config } from '../package/class_global_config'

// 导入页 //
import web_ui from './web_ui'
import ark_ui_index from './ark_ui/ark_ui_index'
import lin_music_start from './start'
import first_start from './first_start'

// 变量池 //

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
  // 环境准备 //
  ////////////

  // 变量池 //
  private context = getContext(this) as common.UIAbilityContext   // 身份证
  status: Boolean = false   // 状态

  // 更新池 //
  @State first_start: boolean = false // 首次启动
  @State version_ready: boolean = false // 版本检测
  @State ready: boolean = false   // 环境准备指示器
  @State ui_mode: boolean = true    // ui模式 ( false：arkui模式 true：webui模式 )
  @State volume_level: number = 0   // 音量大小

  // 类 //
  @State global_config: class_global_config = new class_global_config()   // 全局变量管理
  @State lin_music_player: class_audio_player = new class_audio_player(this.global_config)   // 播放器核心
  @State ark_file_manager: class_files_manager = new class_files_manager(this.global_config)   // 文件管理器核心

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入app操作 //
  aboutToAppear(): void {

    log('程序开始运行...')
    // 注册后台
    reg_bg_run(this.context)
    // 版本号校验
    log('校验版本号..')
    try {
      // 获取版本号
      let tmp = fs.readTextSync(getContext().filesDir + '/version.json')
    }
    // 获取失败，视为第一次启动
    catch {
      this.first_start = true
      // 写入版本号
      try {
        const file = fs.openSync(getContext().filesDir + '/version.json', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
        fs.writeSync(file.fd, '0.6.0')
        fs.closeSync(file)
      } catch (e) {
        log(`版本号保存失败: ${e}`, 'error')
        notice(`版本号保存失败: ${e}`)
        return
      }
    }
    // 就绪
    this.version_ready = true

  }

  // 退出app操作 //
  aboutToDisappear(): void {
    log('程序结束运行...')
    // 全局变量保存
    this.global_config.save()
    // 销毁播放器
    this.lin_music_player.drop_it()
    log('再见.')
  }

  // 返回操作 //
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

      ////////////////
      // 首次启动页面 //
      ///////////////
      if (this.first_start) {
        first_start({
          first_start: this.first_start
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .transition(
            TransitionEffect.opacity(0)
              .animation({ duration: 500 })
          )
      }

      /////////////
      // 开始页面 //
      ////////////
      if (!this.ready && this.version_ready && !this.first_start) {
        lin_music_start({
          ready: this.ready,
          files_manager: this.ark_file_manager,
          lin_music_player: this.lin_music_player
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(800)
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
          global_config: this.global_config,
          lin_music_player: this.lin_music_player,
          files_manager: this.ark_file_manager,
          volume_level: this.volume_level,
          start_ui: this.ready
        })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(700)
      }

      ///////////////
      // arkui界面 //
      //////////////
      // if (this.ready && !this.ui_mode) {
      if (!this.ui_mode) {
        ark_ui_index(
          // {
          // global_config: this.global_config,
          // lin_music_player: this.lin_music_player,
          // files_manager: this.ark_file_manager,
          // volume_level: this.volume_level,
          // start_ui: this.ready
        // }
        )
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(950)
      }

    }
  }
}