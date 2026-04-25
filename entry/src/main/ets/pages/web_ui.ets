//
// web_ui 界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { webview } from '@kit.ArkWeb';
import { picker, fileUri } from  '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { audio } from '@kit.AudioKit';
import { image } from '@kit.ImageKit';
import { common, FailureCode } from '@kit.AbilityKit';
import emitter from '@ohos.events.emitter'
import { router } from '@kit.ArkUI';
import nativeModule from 'libentry.so';


//////////////////
// 导入自创建模块 //
/////////////////
import { log, notice, vib, reg_bg_run } from '../package/system_function'
import { audio_player } from '../package/audio_player/audio_player'
import {
  read_all_songs, read_dir_songs, read_play_list,
  get_my_like, set_my_like, search_my_like
} from '../package/file_manager'

///////////
// 变量池 //
//////////
const root_path = getContext().filesDir
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path // 根目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

///////////////////
// web图片色值计算 //
//////////////////
async function pixel_light_count(metadata: image.PixelMap): Promise<number> {

  // 调用 C++ 计算颜色
  const imageInfo = await metadata.getImageInfo()
  const width = imageInfo.size.width
  const height = imageInfo.size.height

  // 从 PixelMap 获取实际像素数据（RGBA格式，每个像素4字节）
  const pixelBufferSize = width * height * 4;
  const pixelBuffer = new ArrayBuffer(pixelBufferSize)
  const area: image.PositionArea = {
    pixels: pixelBuffer,
    offset: 0,
    stride: width * 4,  // 每一行的字节数（宽度 * 4字节）
    region: { size: { width: width, height: height }, x: 0, y: 0 }
  };
  await metadata.readPixels(area);  // 读取像素数据到 buffer
  const colorValue = nativeModule.getImageAverageColor(pixelBuffer, width, height)
  log(`计算出的颜色值: ${colorValue}`)

  return colorValue

}

////////////////
// web图片处理 //
///////////////
async function pixel_to_base(metadata: image.PixelMap): Promise<string> {

  // 1. 准备图片数据
  let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 }
  // 注意：packing 是耗时操作，这里得到 ArrayBuffer
  let arrayBuffer = await image.createImagePacker().packing(metadata, packOpts)

  // 2. 调用 C++ 进行 Base64 编码
  // C++ 返回的是完整的 "data:image/jpeg;base64,xxxx" 字符串
  let dataURL = nativeModule.encodeImageToBase64(arrayBuffer)

  return dataURL

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// web_ui入口 //
///////////////
@Component
export default struct web_ui {

  ///////////
  // 变量池 //
  //////////

  ///////////
  // 更新池 //
  //////////
  @State @Watch('listen_system_volume') show_volume: boolean = false    // 显示音量条
  @State ready:boolean = false    // 页面准备指示器

  ///////////
  // 继承池 //
  //////////
  @Prop context: common.UIAbilityContext    // 身份证
  @ObjectLink ark_music_player: audio_player  // 类
  @Link volume_level: number    // 音量大小

  ////////
  // 类 //
  ///////
  private ark_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private audioVolumeManager = audio.getAudioManager().getVolumeManager()   // 音量条监听
  private volumeCallback: ((streamVolumeEvent: audio.StreamVolumeEvent) => void) | null = null    // 音量条监听函数

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /////////////
  // 广播监听 //
  ////////////
  listen_broadcast() {
    // 元数据监听 //
    emitter.on({ eventId: 810 }, async (eventData: emitter.EventData) => {
      // 载入
      this.ark_music_ui.runJavaScript(`set_meta(${JSON.stringify([eventData.data?.song_name, eventData.data?.title, eventData.data?.artist])})`)
      // 图片编码发送
      const base_img: string = await pixel_to_base(eventData.data?.img)
      this.ark_music_ui.runJavaScript(`set_meta_img(${JSON.stringify(base_img)})`)
      // 颜色值调整
      if (await pixel_light_count(eventData.data?.img) > 128) {
        this.ark_music_ui.runJavaScript(`set_background_color('rgba(0, 0, 0, 0.4)')`)
      } else {
        this.ark_music_ui.runJavaScript(`set_background_color('rgba(255, 255, 255, 0.6)')`)
      }
    })
    // 播放状态监听 //
    emitter.on({ eventId: 812 }, (eventData: emitter.EventData) => {
      if (eventData.data?.status == 'playing') {
        this.ark_music_ui.runJavaScript(`set_play_status(true)`)
      } else {
        this.ark_music_ui.runJavaScript(`set_play_status(false)`)
      }
    })
    // 音频总时长监听 //
    emitter.on({ eventId: 813 }, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`change_song_range_duration(${eventData.data?.duration_time})`)
    })
    // 音频播放时长监听 //
    emitter.on({ eventId: 814 }, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`change_song_range(${eventData.data?.current_time})`)
    })
    // 播放列表监听 //
    emitter.on({eventId: 820}, (eventData: emitter.EventData) => {
      // 转发js
      this.ark_music_ui.runJavaScript(`playing_update(${JSON.stringify(eventData.data?.play_list)}, ${eventData.data?.play_number})`)
    })
    // 返回手势监听 //
    emitter.on({eventId: 912}, async () => {
      // 转发js
      const tmp = await this.ark_music_ui.runJavaScript(`back_gesture()`)
      console.log(`${tmp}`)
      if (tmp === '"back"') {
        router.back()
      }
    })
  }

  /////////////
  // 音量监听 //
  ////////////
  listen_system_volume() {
    if (this.show_volume) {
      log('音量条打开')
      // 传入初始音量
      this.volume_level = this.audioVolumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC)
      this.ark_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
      // 【关键步骤】将回调函数赋值给定义好的变量
      this.volumeCallback = (streamVolumeEvent: audio.StreamVolumeEvent) => {
        log(`音量: ${streamVolumeEvent.volume} `)
        // 更新
        this.volume_level = streamVolumeEvent.volume
        this.ark_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
        vib()
      }
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, this.volumeCallback)
    } else {
      log('音量条关闭')
      this.audioVolumeManager.off('streamVolumeChange', this.volumeCallback)
    }
  }

  /////////////
  // 退出操作 //
  ////////////
  aboutToDisappear(): void {
    log('web_ui销毁.')
    // 销毁监听
    emitter.off(810)
    emitter.off(812)
    emitter.off(813)
    emitter.off(814)
    emitter.off(820)
    emitter.off(912)
  }

  ////////////////////
  // webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.ark_music_ui.registerJavaScriptProxy(
      {
        // ready //
        ready: () => {
          console.log('页面准备完成')
          this.listen_broadcast()  // 监听广播
          this.ready = true
        },

        // 播放 //
        play: () => {this.ark_music_player.playing()},
        // 暂停 //
        pause: () => {this.ark_music_player.pause()},
        // 上一首 //
        last_song: () => {this.ark_music_player.last_song()},
        // 下一首
        next_song: () => {this.ark_music_player.next_song()},
        // 更改播放进度 //
        seek: (time: string) => {this.ark_music_player.seek(parseInt(time))},
        // 跳转歌曲 //
        seek_song: (index: number) => {this.ark_music_player.seek_song(index)},

        // 更改音量 (-1打开面板 -2关闭面板) //
        set_vol: (level: string) => {
          if (level == '-1') {
            this.show_volume = true
          } else if (level == '-2') {
            this.show_volume = false
          } else {
            this.volume_level = parseInt(level)
          }
        },
        // 获取图片编码
        get_song_image: async (path: string) => {
          // 打开图片
          let meta_img: image.PixelMap | null = null
          try {
            const imageSource = image.createImageSource(root_path + '/' + path)
            meta_img = await imageSource.createPixelMap()
            imageSource.release()
            return await pixel_to_base(meta_img)
          } catch (e) {
            console.log(`获取图片 ${path} 失败：${e}`)
            return ''
          }
        },
        // 跳转到主页面
        back_to_player: () => {this.ark_music_ui.runJavaScript('taskbar_page_update(1)')},

        // 获取所有歌曲信息
        get_all_songs: () => {
          // 获取所有歌曲
          const tmp = read_all_songs()
          if (tmp) {
            // 更新歌曲
            this.ark_music_ui.runJavaScript(`songs_update('update_all_songs', ${JSON.stringify(tmp)})`)
          }
          console.log('扫描完成')
        },
        // 在所有歌曲中播放
        play_with_all_songs: (tmp: number) => {
          // 获取所有歌曲
          this.ark_music_player.set_play_list(read_all_songs(), tmp)
        },
        // 获取文件夹模式的歌曲信息
        get_dir_songs: (path: string) => {
          // 回传
          return read_dir_songs(path)
        },
        // 在文件夹模式中播放
        play_with_dir_mode: (path: string, index: number) => {
          // 读取播放
          this.ark_music_player.set_play_list(read_dir_songs(path)[1], index)
        },
        // 获取播放列表
        get_play_list_songs: (name: string) => {
          // 回调
          return read_play_list(name)
        },
        // 在播放列表模式中播放
        play_with_play_list_mode: (name: string, index: number) => {
          this.ark_music_player.set_play_list(read_play_list(name), index)
        },
        // 查询我喜欢的列表
        get_my_like_song_list: () => {
          return get_my_like()
        },
        // 查询这首歌是否喜欢
        get_my_like_song: (match: string) => {
          return search_my_like(match)
        },
        // 修改我的最爱
        set_my_like_song: (match: string, mode: boolean) => {
          set_my_like(match, mode)
        }


      },
      "ark",
      [
        'ready',
        'play', 'pause', 'seek', 'last_song', 'next_song', 'seek_song',
        'set_vol', 'get_song_image', 'back_to_player',
        'get_all_songs', 'play_with_all_songs', 'get_dir_songs', 'play_with_dir_mode',
        'get_play_list_songs', 'play_with_play_list_mode',
        'get_my_like_song_list', 'get_my_like_song', 'set_my_like_song'
      ]
    )} catch (e) {
      console.error(`注册webview时出现了错误: ${e}.`)
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      /////////////
      // 准备界面 //
      ////////////
      if (!this.ready) {
        Column() { Image($r('app.media.foreground_backup')).width('256px').height('256px') }
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .backgroundColor('#fff').justifyContent(FlexAlign.Center)
          .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
      }

      /////////////
      // web界面 //
      ////////////
      Web({ src: $rawfile("webview_gui/play_taskbar_index.html"), controller: this.ark_music_ui })
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
          console.log('页面加载完成.')
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