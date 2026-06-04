//
// ArkUI原生音乐播放器 - 主界面
// 包含底部导航栏和Mini播放器
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import emitter from '@ohos.events.emitter'
import { App, window } from '@kit.ArkUI'
import { fileIo as fs } from '@kit.CoreFileKit'
import { CircleShape, RectShape } from '@kit.ArkUI';

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice, vib } from '../../package/system_function'
import { get_image, get_meta, image_to_base64, check_meta_image } from '../../package/meta_manager'

// 导入类 //
import { class_audio_player } from '../../package/audio_player/class_audio_player'
import { class_files_manager } from '../../package/files_manager/download_manager'
import { class_global_config } from '../../package/class_global_config'

// 变量池 //
const ark_ui_path = getContext().filesDir + '/ark_ui/'    // web_ui目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ark_ui_index入口 //
//////////////////////
@Component
@Preview
export default struct ark_ui_index {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 更新池 //
  @State meta_image_rotate: number = 0

  // 继承池 //
  // @ObjectLink global_config: class_global_config    // 全局管理器
  // @ObjectLink lin_music_player: class_audio_player  // 类 播放器
  // @ObjectLink files_manager: class_files_manager    // 类 文件管理器
  // @Link volume_level: number    // 音量大小
  // @Link start_ui: boolean    // 环境准备指示器(为false就是重新扫描数据库)

  // 类 //

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入操作 //
  aboutToAppear(): void {
    // 检查目录 //
    try {fs.statSync(ark_ui_path)} catch {fs.mkdirSync(ark_ui_path)}

    this.set_rotate()

  }

  set_rotate() {
    this.meta_image_rotate += 1
    setTimeout(() => {this.set_rotate()}, 10)
  }

  // 退出操作 //
  aboutToDisappear(): void {
    // 保存数据
    log('ark_ui销毁.')
    // 销毁监听
    emitter.off(722)
    emitter.off(723)
    emitter.off(724)
    emitter.off(725)
    emitter.off(726)
    emitter.off(727)
    emitter.off(728)
    emitter.off(922)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 广播监听 //
  listen_broadcast() {
    // 元数据监听 //
    emitter.on({ eventId: 722 }, async (eventData: emitter.EventData) => {
    })
    // 设置播放模式
    emitter.on({ eventId: 723 }, async (eventData: emitter.EventData) => {
    })
    // 播放状态监听 //
    emitter.on({ eventId: 724 }, (eventData: emitter.EventData) => {
    })
    // 音频总时长监听 //
    emitter.on({ eventId: 725 }, (eventData: emitter.EventData) => {
    })
    // 音频播放时长监听 //
    emitter.on({ eventId: 726 }, (eventData: emitter.EventData) => {
    })
    // 喜欢监听 //
    emitter.on({eventId: 727}, (eventData: emitter.EventData) => {
    })
    // 播放列表监听 //
    emitter.on({eventId: 728}, (eventData: emitter.EventData) => {
    })
    // 返回手势监听 //
    emitter.on({eventId: 922}, async () => {
    })
  }

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

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Column() {

      // taskbar组件
      Stack() {

        // 旋转的背景框架
        Stack() {

          // 背景图
          Image($r('app.media.CD'))
            .width('1200%').height('1200%')
            .borderRadius('100%')

          // 模糊遮罩
          Row()
            .width('1200%').height('1200%')
            .borderRadius('100%').blur(100)

        }
        .width('10%').aspectRatio(1)
        .alignContent(Alignment.Center)
        .rotate({ centerX: '50%', centerY: '50%', angle: this.meta_image_rotate })

        // 功能栏
        Column() {

          // 上班音乐栏
          Row() {}
            .width('100%').height('50%')
            .backgroundColor('#ee0000')

          // 下半功能栏
          Row() {

          }
            .width('100%').height('50%')
            .background('#66ccff')
        }
        .width('100%').height('100%')
        .alignItems(HorizontalAlign.Center)


      }
      .backgroundColor('#ffffff')
      .width('80%').height('96vp')
      .margin({ bottom: '28vp' })
      .borderRadius('24vp').clip(true)
      .alignContent(Alignment.Center)

    }
    .backgroundImage($rawfile('example.jpg')).backgroundImageSize(ImageSize.Cover)
    .width('100%').height('100%')
    .position({ x: 0, y: 0 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.End)
  }

}
