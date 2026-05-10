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
import { log, notice, vib } from '../package/system_function'
import { audio_player } from '../package/audio_player/audio_player'
import { files_manager } from '../package/files_manager'
import { get_image, get_meta, image_to_base64, check_meta_image } from '../package/meta_manager'

///////////
// 变量池 //
//////////

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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// web_ui入口 //
///////////////
@Component
export default struct web_ui {

  ///////////
  // 变量池 //
  //////////
  private play_list: string[] = []  // 列表记录器
  private file_mode: string = ''    // 文件页记录

  ///////////
  // 更新池 //
  //////////
  @State @Watch('listen_system_volume') show_volume: boolean = false    // 显示音量条
  @State ready: boolean = false    // 页面准备指示器

  ///////////
  // 继承池 //
  //////////
  @ObjectLink ark_music_player: audio_player  // 类 播放器
  @ObjectLink files_manager: files_manager    // 类 文件管理器
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
    emitter.on({ eventId: 712 }, async (eventData: emitter.EventData) => {
      // 载入
      this.ark_music_ui.runJavaScript(`set_meta(${JSON.stringify([eventData.data?.name, eventData.data?.title, eventData.data?.artist])})`)
      // 图片编码发送
      const base_img: string = await image_to_base64(eventData.data?.image)
      this.ark_music_ui.runJavaScript(`set_meta_img(${JSON.stringify(base_img)})`)
      // 颜色值调整
      if (await pixel_light_count(eventData.data?.image) > 128) {
        this.ark_music_ui.runJavaScript(`set_background_color('rgba(0, 0, 0, 0.4)')`)
      } else {
        this.ark_music_ui.runJavaScript(`set_background_color('rgba(255, 255, 255, 0.6)')`)
      }
    })
    // 播放状态监听 //
    emitter.on({ eventId: 714 }, (eventData: emitter.EventData) => {
      if (eventData.data?.status == 'playing') {
        this.ark_music_ui.runJavaScript(`set_play_status(true)`)
      } else {
        this.ark_music_ui.runJavaScript(`set_play_status(false)`)
      }
    })
    // 音频总时长监听 //
    emitter.on({ eventId: 715 }, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`change_song_range_duration(${eventData.data?.duration_time})`)
    })
    // 音频播放时长监听 //
    emitter.on({ eventId: 716 }, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`change_song_range(${eventData.data?.current_time})`)
    })
    // 喜欢监听 //
    emitter.on({eventId: 717}, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`set_like(${eventData.data?.like})`)
    })
    // 播放列表监听 //
    emitter.on({eventId: 718}, (eventData: emitter.EventData) => {
      this.ark_music_ui.runJavaScript(`playing_update(${JSON.stringify(eventData.data?.list)}, ${eventData.data?.index})`)
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
  // 载入操作 //
  ////////////
  aboutToAppear(): void {
  }

  /////////////
  // 退出操作 //
  ////////////
  aboutToDisappear(): void {
    log('web_ui销毁.')
    // 销毁监听
    emitter.off(712)
    emitter.off(714)
    emitter.off(715)
    emitter.off(716)
    emitter.off(717)
    emitter.off(912)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.ark_music_ui.registerJavaScriptProxy({

      ////////////
      // ready //
      //////////
      ready: () => {
        console.log('页面准备完成')
        this.listen_broadcast()  // 监听广播
        this.ready = true
        // 加载audio
        this.ark_music_player.play_data_load()
      },

      ///////////////
      // 基础功能类 //
      /////////////
      // 播放 //
      play: () => {this.ark_music_player.playing()},
      // 暂停 //
      pause: () => {this.ark_music_player.pause()},
      // 上一首 //
      last_song: () => {this.ark_music_player.last_song()},
      // 下一首 //
      next_song: () => {this.ark_music_player.next_song()},
      // 更改播放进度 //
      seek: (time: string) => {this.ark_music_player.seek(parseInt(time))},
      // 跳转歌曲 //
      seek_song: (index: number) => {this.ark_music_player.seek_song(index)},
      // 喜欢切换 //
      toggle_like: () => {this.ark_music_player.toggle_like()},

      ///////////////
      // 扩展功能类 //
      /////////////
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
      // 跳转到主页面 //
      back_to_player: () => {this.ark_music_ui.runJavaScript('taskbar_page_update(1)')},

      // 获取元数据 //
      get_song_meta: async (path: string) => {
        let tmp = [await get_meta(path), await image_to_base64(await get_image(path))]
        console.log(`[${tmp[0][0]}]`)
        console.log(`[${tmp[0][1]}]`)
        return tmp
      },
      // 制作图片框 //
      get_meta_list_image: async (mode_name: string, meta_name: string): Promise<string> => {

        // 分类
        let tmp_map: Map<string, string[]>
        if (mode_name === '歌手') {
          tmp_map = this.files_manager.artist_composer_list
        } else if (mode_name === '专辑') {
          tmp_map = this.files_manager.album_list
        } else if (mode_name === '专辑作者') {
          tmp_map = this.files_manager.album_artist_list
        } else if (mode_name === '歌流派') {
          tmp_map = this.files_manager.genre_list
        } else {
          // 直接返回默认封面
          return await image_to_base64(await get_image())
        }

        // 查找
        let tmp_image = ''
        for (const i of tmp_map.get(meta_name) ?? []) {
          // 查询是否有专辑
          if (await check_meta_image(i)) {
            // 有，返回
            tmp_image = await image_to_base64(await get_image(i))
            break
          }
        }
        // 如果有封面则返回
        if (tmp_image) {return tmp_image} else {return await image_to_base64(await get_image())}

      },

      // 点歌 //
      play_song: (tmp: number) => {this.ark_music_player.set_play_list(this.play_list, tmp)},

      ///////////////
      // files页用 //
      /////////////

      // 获取所有歌曲 //
      get_all_songs: () => {
        this.play_list = this.files_manager.all_songs_list
        return this.play_list
      },
      // 获取文件夹歌曲 //
      get_folder_songs: (path: string) => {
        const tmp = this.files_manager.get_dir(path)
        this.play_list = tmp[1]
        return tmp
      },
      // 获取播放列表歌曲 //
      get_play_list_songs: (name: string) => {
        // 如果没有传歌单名称，返回歌单列表
        if (!name) {
          return Array.from(this.files_manager.play_list.keys())
        } else {
          // 传了歌单名称，返回该歌单的歌曲路径
          this.play_list = this.files_manager.play_list.get(name) ?? []
          return this.play_list
        }
      },
      // 获取喜欢的歌曲 //
      get_like_songs: () => {
        this.play_list = this.ark_music_player.like_list_path
        return this.play_list
      },
      // 获取 歌手/艺术家 分类
      get_artist_composer_list: (name: string) => {
        // 如果有传入歌手参数
        if (name) {
          // 获取歌手的歌曲列表
          this.play_list = this.files_manager.artist_composer_list.get(name)
          return this.play_list
        }
        // 是来查询歌手列表的
        else {
          return Array.from(this.files_manager.artist_composer_list.keys())
        }
      },
      // 获取 专辑 分类
      get_album_list: (name: string) => {
        // 如果有传入歌手参数
        if (name) {
          // 获取歌手的歌曲列表
          this.play_list = this.files_manager.album_list.get(name)
          return this.play_list
        }
        // 是来查询歌手列表的
        else {
          return Array.from(this.files_manager.album_list.keys())
        }
      },
      // 获取 专辑作者 分类
      get_album_artist_list: (name: string) => {
        // 如果有传入歌手参数
        if (name) {
          // 获取歌手的歌曲列表
          this.play_list = this.files_manager.album_artist_list.get(name)
          return this.play_list
        }
        // 是来查询歌手列表的
        else {
          return Array.from(this.files_manager.album_artist_list.keys())
        }
      },
      // 获取 流派 分类
      get_genre_list: (name: string) => {
        // 如果有传入歌手参数
        if (name) {
          // 获取歌手的歌曲列表
          this.play_list = this.files_manager.genre_list.get(name)
          return this.play_list
        }
        // 是来查询歌手列表的
        else {
          return Array.from(this.files_manager.genre_list.keys())
        }
      }

    },
      /////////////
      // 接口声明 //
      ////////////
      "ark",
      [
        'ready',
        'play', 'pause', 'last_song', 'next_song', 'seek', 'seek_song', 'toggle_like',
        'set_vol', 'back_to_player', 'get_song_meta', 'get_meta_list_image', 'play_song',
        'get_all_songs', 'get_folder_songs', 'get_play_list_songs', 'get_like_songs',
        'get_artist_composer_list', 'get_album_list', 'get_album_artist_list', 'get_genre_list'
      ]

    )} catch (e) {console.error(`注册webview时出现了错误: ${e}.`)}
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