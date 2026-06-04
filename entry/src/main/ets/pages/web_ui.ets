//
// web_ui 界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { webview } from '@kit.ArkWeb'
import { AVVolumePanel } from '@kit.AudioKit'
import { audio } from '@kit.AudioKit'
import { image } from '@kit.ImageKit'
import emitter from '@ohos.events.emitter'
import { router } from '@kit.ArkUI'
import { window } from '@kit.ArkUI'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice, vib } from '../package/system_function'
import { save_array, load_array } from '../package/data_save_load'
import { get_image, get_meta, image_to_base64 } from '../package/meta_manager'

// 导入类 //
import { class_audio_player } from '../package/audio_player/class_audio_player'
import { class_files_manager } from '../package/files_manager/download_manager'
import { class_global_config } from '../package/class_global_config'

// 变量池 //
const web_ui_path = getContext().filesDir + '/web_ui/'    // web_ui目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// web图片色值计算 //
async function pixel_light_count(metadata: image.PixelMap): Promise<number> {

  // 获取图片尺寸
  const imageInfo = await metadata.getImageInfo()
  const width = imageInfo.size.width
  const height = imageInfo.size.height

  // 从 PixelMap 读取像素数据（RGBA格式，每个像素4字节）
  const pixelBufferSize = width * height * 4;
  const pixelBuffer = new ArrayBuffer(pixelBufferSize)
  const area: image.PositionArea = {
    pixels: pixelBuffer,
    offset: 0,
    stride: width * 4,
    region: { size: { width: width, height: height }, x: 0, y: 0 }
  };
  await metadata.readPixels(area);

  // 调用 C++ 计算亮度值
  return nativeModule.pixel_light_count(pixelBuffer, width, height)

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// web_ui入口 //
///////////////
@Component
export default struct web_ui {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 继承池 //
  @ObjectLink global_config: class_global_config    // 类 全局管理器
  @ObjectLink lin_music_player: class_audio_player  // 类 播放器
  @ObjectLink files_manager: class_files_manager    // 类 文件管理器
  @Link volume_level: number    // 音量大小
  @Link start_ui: boolean    // 环境准备指示器(为false就是重新扫描数据库)

  // 变量池 //
  private play_list: string[] = []  // 列表记录器

  // 更新池 //
  @State @Watch('listen_system_volume') show_volume: boolean = false    // 显示音量条
  @State ready: boolean = false    // 页面准备指示器

  // 类池 //
  private lin_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private audio_volume_manager = audio.getAudioManager().getVolumeManager()   // 音量条监听
  private volume_callback: ((streamVolumeEvent: audio.StreamVolumeEvent) => void) | null = null    // 音量条监听函数

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入操作 //
  aboutToAppear() {
    // 检查目录 //
    try {fs.statSync(web_ui_path)} catch {fs.mkdirSync(web_ui_path)}
  }

  // 退出操作 //
  aboutToDisappear(): void {
    // 保存数据
    log('web_ui销毁.')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 广播监听 //
  listen_broadcast() {}
  // 音量监听 //
  listen_system_volume() {}

  // 设置沉浸颜色 //
  set_window_color(value: boolean) {
    if (value) {
      window.getLastWindow(getContext(this)).then((win) => {
        let props: window.SystemBarProperties = {
          statusBarContentColor: '#ffffff' // 根据当前页面背景设置
        }
        win.setWindowSystemBarProperties(props)
      })
    } else {
      window.getLastWindow(getContext(this)).then((win) => {
        let props: window.SystemBarProperties = {
          statusBarContentColor: '#000000' // 根据当前页面背景设置
        }
        win.setWindowSystemBarProperties(props)
      })
    }
  }

  // 保存数据 //
  save_data() {}
  // 加载数据 //
  load_data() {}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.lin_music_ui.registerJavaScriptProxy({

      //////////////
      // 基础功能类 //
      //////////////
      // ready //
      ready: () => {
        log('页面准备完成.')
        // 注入数据 //

      },

    },"lin",[

      /////////////
      // 接口声明 //
      ////////////

    ])} catch (e) {log(`注册webview时出现了错误: ${e}.`, 'error')}}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      /////////////
      // 准备界面 //
      ////////////
      if (!this.ready) {
        Column() {
          Image($r('app.media.icon_white'))
            .width('256px').height('256px')
            .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 }).zIndex(900)
        .backgroundColor('#fff').justifyContent(FlexAlign.Center)
        .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
      }

      /////////////
      // web界面 //
      ////////////
      Web({ src: $rawfile("webview_gui/play_taskbar_index.html"), controller: this.lin_music_ui })
        .width('100%').height('100%')
        .position({ x: 0, y: 0 }).zIndex(500)
        .zoomAccess(false)

        .domStorageAccess(true) // 开启 DOM 存储
        .cacheMode(CacheMode.Default) // 默认模式，对本地文件无副作用，对网络资源有效
        .javaScriptAccess(true) // 确保 JS 开启
        .enableNativeEmbedMode(true) // 开启硬件加速渲染层

        .onControllerAttached(() => {
          this.reg_webview_js() // 注册web接口
        })

        .onPageEnd(() => {
          log('页面加载完成.')
        })

      /////////////
      // 音量界面 //
      ////////////
      if (this.show_volume) {
        AVVolumePanel({
          volumeLevel: this.volume_level,
          volumeParameter: { position: { x: -1, y: -1 } }
        })
      }

    }
  }

}