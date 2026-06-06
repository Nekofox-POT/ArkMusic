//
// 铃音主界面
// 频段：9
// 912：给webui的返回广播
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import emitter from '@ohos.events.emitter'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import { log, notice, reg_bg_run } from '../package/system_function'

// 导入类 //
import class_global_config from '../package/class_global_config'
import class_files_manager from "../package/files_manager/class_files_manager"
import class_audio_player from '../package/audio_player/class_audio_player'

// 导入页 //
import version_update from './version_update'
import web_ui from './ui/web_ui'
import ark_ui_index from './ark_ui/ark_ui_index'
import lin_music_start from './start'
import first_start from './first_start/first_start'

// 变量池 //
const version_path = getContext().filesDir + '/version.cfg'   // 配置文件

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

  // 更新池 //
  @State @Watch('env_load') start_ready: boolean = false    // 首运检查完成
  @State @Watch('env_load') version_ready: boolean = false  // 版本更新完成
  @State env_ready: boolean = false                         // 环境准备完成
  @State start_ui: boolean = false                          // 启动界面
  @State controller_ui: boolean = false                     // 控制器界面


  // 类 //
  @State global_config: class_global_config = new class_global_config()   // 全局变量管理
  @State audio_player: class_audio_player = new class_audio_player(this.global_config)   // 播放器核心
  @State files_manager: class_files_manager = new class_files_manager(this.global_config)   // 文件管理器核心

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入app操作 //
  aboutToAppear(): void {

    // 注册后台任务 //
    reg_bg_run()

    // 版本号检查 //
    try {
      fs.openSync(version_path)
      this.start_ready = true
    } catch {
      // 版本号不存在，进入开始界面
    }

  }

  // 退出app操作 //
  aboutToDisappear(): void {}

  // 返回信号播控 //
  onBackPress(): boolean {
    emitter.emit({ eventId: 912 })
    return true
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 环境构建 //
  async env_load() {

    // 如果还没准备好就退出 //
    if (!(this.start_ready && this.version_ready)) {return}

    // 加载文件管理器 //
    await this.files_manager.load_data()

    // 加载音频播控器 //
    await this.audio_player.audio_player_start_up()

    // 就绪 //
    this.env_ready = true

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Stack() {

      // 更新弹窗页面 //
      version_update({
        version_ready: this.version_ready,
        global_config: this.global_config
      })
        .width('100%').height('100%').zIndex(800)

    }
  }
}