//
// 铃音主界面
// 频段：9
// 912：给webui的返回广播
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import emitter from '@ohos.events.emitter'
import { fileIo as fs } from '@kit.CoreFileKit'
import { webview } from '@kit.ArkWeb'
import { picker, fileUri } from  '@kit.CoreFileKit'

// 导入自创建模块 //
import { log, notice, reg_bg_run } from '../package/system_function'

// 导入类 //
import class_global_config from '../package/class_global_config'
import class_files_manager from "../package/files_manager/class_files_manager"
import class_audio_player from '../package/audio_player/class_audio_player'

// 导入页 //
import version_update from './version_update'
import start_index from './start/start'
import ui_index from './ui/ui'

// 变量池 //
const version_path = getContext().filesDir + '/version.cfg'   // 配置文件
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.linmusic').path   // 下载资源目录

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
  @State @Watch('env_load') download_ready: boolean = false // 目录检测完成
  @State env_ready: boolean = false                         // 环境准备完成
  @State start_ui: boolean = false                          // 启动界面
  @State controller_ui: boolean = false                     // 控制器界面
  @State backup_occupy: boolean = false                     // 返回键占用指示


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
      this.start_ui = true
    }

  }

  // 退出app操作 //
  aboutToDisappear(): void {}

  // 返回信号播控 //
  onBackPress(): boolean {
    if (this.backup_occupy) {emitter.emit({ eventId: 912 })}
    return this.backup_occupy
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 环境构建 //
  async env_load() {

    // 如果还没准备好就退出 //
    if (!(this.start_ready && this.version_ready && this.download_ready)) {return}

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
      if (!this.version_ready) {
        version_update({
          version_ready: this.version_ready,
          global_config: this.global_config
        })
          .width('100%').height('100%').zIndex(900)
      }

      // 开始页面 //
      if (this.start_ui) {
        start_index({
          start_ready: this.start_ready,
          start_ui: this.start_ui,
          global_config: this.global_config
        })
          .width('100%').height('100%').zIndex(800)
      }

      // ui页面 //
      if (this.env_ready) {
        ui_index({
          global_config: this.global_config,
          files_manager: this.files_manager,
          audio_player: this.audio_player,
          backup_occupy: this.backup_occupy
        })
          .width('100%').height('100%').zIndex(500)
      }

      // download创建器 //
      if (!this.download_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: new webview.WebviewController()})
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(100)
          .onPageEnd(async () => {

            // 目录检查 //
            try {
              fs.listFileSync(song_path)
              this.download_ready = true
            } catch {

              // 不存在，需要创建目录 //
              log(`Download目录不存在，创建.`, 'error')

              // 创建目录 //
              const options = new picker.DocumentSaveOptions()
              options.pickerMode = picker.DocumentPickerMode.DOWNLOAD
              await new picker.DocumentViewPicker().save(options)

              // 加载提示 //

              // 完成 //
              this.download_ready = true

            }

          })
      }

    }
  }
}