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
import { log, notice, vib } from '../../package/system_function'
import { save_array, load_array } from '../../package/data_save_load'
import { get_image, get_meta, image_to_base64 } from '../../package/meta_manager'

// 导入类 //
import class_audio_player from '../../package/audio_player/class_audio_player'
import class_files_manager from '../../package/files_manager/class_files_manager'
import class_global_config from '../../package/class_global_config'

// 变量池 //
const web_ui_path = getContext().filesDir + '/ui/web/'    // web_ui目录
const web_ui_rom_path = web_ui_path + 'rom/'    // 皮肤固件目录
const web_ui_data_path = web_ui_path + 'data/'  // 皮肤工作目录

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
  @ObjectLink files_manager: class_files_manager    // 类 文件管理器
  @ObjectLink audio_player: class_audio_player  // 类 播放器

  // 变量池 //

  // 更新池 //
  @State @Watch('listen_system_volume') show_volume: boolean = false    // 显示音量条
  @State volume_level: number = 0    // 音量等级
  @State ready: boolean = false    // 页面准备指示器

  // 类池 //
  private web_ui_core: webview.WebviewController = new webview.WebviewController()   // web界面控制器
  private audio_volume_manager = audio.getAudioManager().getVolumeManager()   // 音量条监听控制

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入操作 //
  aboutToAppear() {

    // 检查目录 //
    try {fs.statSync(web_ui_path)} catch {fs.mkdirSync(web_ui_path)}
    try {fs.statSync(web_ui_rom_path)} catch {fs.mkdirSync(web_ui_rom_path)}
    try {fs.statSync(web_ui_data_path)} catch {fs.mkdirSync(web_ui_data_path)}

  }

  // 退出操作 //
  aboutToDisappear(): void {
    // 保存数据
    log('web_ui销毁.')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 监听函数 //
  ////////////

  // 开启 / 关闭 广播监听 //
  switch_emitter(status: boolean) {

    if (status) {}
    else {}

  }

  // 音量监听 //
  listen_system_volume() {

    // 打开音量条 //
    if (this.show_volume) {

      log('音量条打开')

      // 传入初始音量 //
      this.volume_level = this.audio_volume_manager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC)
      this.web_ui_core.runJavaScript(`set_vol(${this.volume_level})`)

      // 音量监听 //
      this.audio_volume_manager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, (tmp: audio.StreamVolumeEvent) => {

        // 更新 //
        this.volume_level = tmp.volume
        this.web_ui_core.runJavaScript(`set_vol(${tmp.volume})`)

      })

    }

    // 关闭音量条 //
    else {

      log('音量条关闭')

      this.audio_volume_manager.off('streamVolumeChange')

    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 设置沉浸颜色 //
  set_window_color(value: string) {
    window.getLastWindow(getContext(this)).then((win) => {
      win.setWindowSystemBarProperties({ statusBarContentColor: value })
    })
  }

  // 保存数据 //
  save_data() {}
  // 加载数据 //
  load_data() {}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.web_ui_core.registerJavaScriptProxy({

      //////////////
      // 基础功能类 //
      //////////////
      // ready //
      ready: () => {
        log('页面准备完成.')
        this.ready = true
      },
      // 震动 //
      vib: () => {vib()},
      // 音量设置 //
      set_vol: (level: number) => {
        if (level == -1) {
          this.show_volume = true
        } else if (level == -2) {
          this.show_volume = false
        } else {this.volume_level = level}
      },
      // 保存数据 //
      save_data: (data: string[]) => {save_array(data, web_ui_path + 'glass_ui.json')},
      // 打开数据 //
      load_data: () => {load_array(web_ui_path + 'glass_ui.json')},

      //////////////
      // 播控功能类 //
      //////////////
      // 设置播放器(载入播放列表) //
      set_play_list: async (play_list: string[], index: number) => {this.audio_player.set_play_list(play_list, index)},
      // 切歌 //
      switch_song: async (index: number) => {this.audio_player.set_audio(index)},
      // 播放 //
      playing: () => {this.audio_player.playing()},
      // 暂停 //
      pause: () => {this.audio_player.pause()},
      // 上一首 //
      previous: () => {this.audio_player.previous()},
      // 下一首 //
      next: () => {this.audio_player.next()},
      // 跳转时间 //
      seek: (time: number) => {this.audio_player.seek(time)},
      // 设置播放模式 //
      set_play_mode: (mode: number) => {this.audio_player.set_play_mode(mode)},
      // 喜欢切换 //
      toggle_like: () => {this.audio_player.toggle_like()},
      // 歌曲交换 //
      switch_songs: (index_a: number, index_b: number) => {this.audio_player.switch_songs(index_a, index_b)},
      // 歌曲删除 //
      delete_song: (index: number) => {this.audio_player.delete_song(index)},

      //////////////
      // 状态获取类 //
      //////////////
      // 获取当前播放歌曲元数据 //
      get_playing_meta: async (): Promise<string[][]> => {return await get_meta(this.audio_player.play_list[this.audio_player.play_list_index])},
      // 获取当前播放时间 //
      get_playing_time: (): number => {return this.audio_player.current_time},
      // 获取当前播放列表 //
      get_playing_play_list: (): string[] => {return this.audio_player.play_list},
      // 获取当前播放指针 //
      get_playing_index: (): number => {return this.audio_player.play_list_index},
      // 获取当前播放状态 //
      get_playing_status: (): string => {return this.audio_player.play_status},
      // 获取当前喜欢状态 //
      get_like: (): boolean => {return this.audio_player.is_like},
      // 获取当前播放模式 //
      get_play_mode: (): number => {return this.audio_player.play_mode},

      //////////////
      // 媒体管理类 //
      //////////////
      // 获取元数据 //
      get_meta: async (path: string): Promise<string[][]> => {return await get_meta(path)},
      // 获取专辑封面 //
      get_image: async (path: string): Promise<[boolean, string]> => {
        let tmp = await get_image(path)
        return [tmp[0], await image_to_base64(tmp[1])]
      },
      // 获取所有歌曲 //
      get_all_songs: (): string[] => {return this.files_manager.all_songs_list},
      // 获取导入歌曲 //
      get_external_songs: (): string[] => {return this.files_manager.external_songs_list},
      // 获取喜欢列表 //
      get_like_songs: (): string[] => {return this.audio_player.like_list_path},
      // 获取hi_res列表 //
      get_hr_songs: (): string[] => {return this.files_manager.hr_songs_list},
      // 获取dsd列表 //
      get_dsd_songs: (): string[] => {return this.files_manager.dsd_songs_list},

      // 获取download目录歌曲(文件夹模式) //
      get_dir_songs: (path: string = ''): string[][] => {return this.files_manager.get_dir(path)},
      // 获取 播放列表 //
      get_play_list_songs: (name: string = ''): string[] => {
        if (name == '') {
          return Array.from(this.files_manager.play_list.keys())
        } else {
          return this.files_manager.play_list.get(name) ?? []
        }
      },
      // 获取 歌手分类 //
      get_artist_songs: (name: string = ''): string[] => {
        if (name == '') {
          return Array.from(this.files_manager.artist_list.keys())
        } else {
          return this.files_manager.artist_list.get(name) ?? []
        }
      },
      // 获取 专辑分类 //
      get_album_songs: (name: string = ''): string[] => {
        if (name == '') {
          return Array.from(this.files_manager.album_list.keys())
        } else {
          return this.files_manager.album_list.get(name) ?? []
        }
      },
      // 获取 传记作者分类 //
      get_album_artist_songs: (name: string = ''): string[] => {
        if (name == '') {
          return Array.from(this.files_manager.album_artist_list.keys())
        } else {
          return this.files_manager.album_artist_list.get(name) ?? []
        }
      },
      // 获取 流派分类 //
      get_genre_songs: (name: string = ''): string[] => {
        if (name == '') {
          return Array.from(this.files_manager.genre_list.keys())
        } else {
          return this.files_manager.genre_list.get(name) ?? []
        }
      },

      ///////////
      // 设置类 //
      //////////


    },"ark",[

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
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 }).zIndex(900)
        .backgroundColor('#fff').justifyContent(FlexAlign.Center)
        .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
      }

      /////////////
      // web界面 //
      ////////////
      Web({ src: $rawfile("ui/web_ui/glass_ui/play_taskbar_index.html"), controller: this.web_ui_core })
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
          log('web_ui资源加载.')
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