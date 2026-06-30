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
import { get_image, get_meta, image_to_base64, get_pixel_light, get_pixel_color, get_pixel_dominant } from '../../package/meta_manager'

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
  @ObjectLink audio_player: class_audio_player      // 类 播放器
  @Link backup_occupy: boolean                      // 手势占用
  @Link setting_on: boolean                       // 设置页

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
    try {fs.statSync(web_ui_data_path + 'glass_ui')} catch {fs.mkdirSync(web_ui_data_path + 'glass_ui')}

    // 霸占手势 //
    this.backup_occupy = true

  }

  // 退出操作 //
  aboutToDisappear(): void {
    log('web_ui销毁.')

    // 解锁手势 //
    this.backup_occupy = false

    // 关闭监听 //
    try {this.switch_emitter(false)} catch {}

    // 保存数据 //

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 监听函数 //
  ////////////

  // 开启 / 关闭 广播监听 //
  switch_emitter(status: boolean) {

    // 开启 //
    if (status) {

      // 元数据 //
      emitter.on({ eventId: 712 }, async (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_meta(${JSON.stringify(data.data!.meta)})`)
        const img_base64: string = await image_to_base64(data.data!.image[1])
        this.web_ui_core.runJavaScript(`set_image(${JSON.stringify(img_base64)})`)
      })
      // 播放时间 //
      emitter.on({ eventId: 713 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_current_time(${data.data!.current_time})`)
        this.web_ui_core.runJavaScript(`set_current_time_format("${data.data!.current_time_format}")`)
      })
      // 列表更新 //
      emitter.on({ eventId: 714 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_playing_list(${JSON.stringify(data.data!.play_list)})`)
      })
      // 指针更新 //
      emitter.on({ eventId: 715 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_playing_index(${data.data!.index})`)
      })
      // 播放状态更新 //
      emitter.on({ eventId: 716 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_play_status("${data.data!.status}")`)
      })
      // 播放模式更新 //
      emitter.on({ eventId: 717 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_play_mode(${data.data!.play_mode})`)
      })
      // 喜欢状态更新 //
      emitter.on({ eventId: 718 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_like(${data.data!.like})`)
      })
      // 定时剩余 //
      emitter.on({ eventId: 719 }, (data: emitter.EventData) => {
        this.web_ui_core.runJavaScript(`set_timing_time(${data.data!.time})`)
      })
      // // 完整歌词广播 //
      // emitter.on({ eventId: 710 }, (data: emitter.EventData) => {})
      // // 单句歌词广播 //
      // emitter.on({ eventId: 711 }, (data: emitter.EventData) => {})
      // 数据库更新 //
      emitter.on({ eventId: 812 }, () => {
        this.web_ui_core.runJavaScript(`songs_update()`)
      })
      // 手势监听 //
      emitter.on({ eventId: 912 }, () => {
        this.web_ui_core.runJavaScript(`back_gesture_signal()`)
      })

    }

    // 关闭 //
    else {
      emitter.off(712)
      emitter.off(713)
      emitter.off(714)
      emitter.off(715)
      emitter.off(716)
      emitter.off(717)
      emitter.off(718)
      emitter.off(719)
      // emitter.off(710)
      // emitter.off(711)
      emitter.off(812)
      emitter.off(912)
    }

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
        // this.volume_level = tmp.volume
        this.web_ui_core.runJavaScript(`set_vol(${tmp.volume})`)
        vib()

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
        // 开启监听 //
        this.switch_emitter(true)
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
        } else {
          if ((level >= 0) && (level <= 15)) {
            this.volume_level = level
          }
        }
      },
      // 保存数据 //
      save_data: (data: string[], name: string) => {save_array(data, `${web_ui_data_path}glass_ui/${name}.json`)},
      // 打开数据 //
      load_data: (name: string): string[] => {return load_array(`${web_ui_data_path}glass_ui/${name}.json`)},
      // 返回桌面 //
      back_desktop: () => {router.back()},

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
      get_playing_index: (): number => {
        if (this.audio_player.play_list.length == 0) {
          return 0
        } else {
          return this.audio_player.play_list_index
        }
      },
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
      // 打开更多设置页 //
      open_setting: () => {this.setting_on = true},
      // 外部歌曲导入 //
      add_external_songs: () => {this.files_manager.add_external_songs()},
      // 删除外部歌曲 //
      del_external_songs: (list: string[]) => {this.files_manager.del_external_songs(list)},
      // 扫描数据库 //
      scan_data: async (fast: boolean = true) => {this.files_manager.scan_data(fast)},
      // 设置定时 //
      set_timing: (time: number) => {this.audio_player.set_timing(time)},
      // 设置定时模式 //
      set_timed_mode: (status: boolean) => {this.audio_player.timed_mode = status},
      // 获取定时剩余时间 //
      get_timing: (): number => {return this.audio_player.get_timing()},
      // 获取定时模式 //
      get_timed_mode: (): boolean => {return this.audio_player.timed_mode},

      ///////////
      // 工具类 //
      //////////
      // 获取图片亮度 //
      get_pixel_light: async (path: string): Promise<number> => {return await get_pixel_light((await get_image(path))[1])},
      // 获取图片主题色 //
      get_pixel_color: async (path: string): Promise<string> => {return await get_pixel_color((await get_image(path))[1])},
      // 获取图片三分主色 //
      get_pixel_dominant: async (path: string): Promise<string[]> => {return await get_pixel_dominant((await get_image(path))[1])},
      // 更改沉浸色 //
      set_window_color: async (value: string) => {
        // 校验十六进制颜色格式
        if (/^#[0-9a-fA-F]{6}$/.test(value)) {
          this.set_window_color(value)
        }
      },

    },"ark",[

      /////////////
      // 接口声明 //
      ////////////
      'ready', 'vib', 'set_vol', 'save_data', 'load_data', 'back_desktop',
      'set_play_list', 'switch_song', 'playing', 'pause', 'previous', 'next',
      'seek', 'set_play_mode', 'toggle_like', 'switch_songs', 'delete_song',
      'get_playing_meta', 'get_playing_time', 'get_playing_play_list',
      'get_playing_index', 'get_playing_status', 'get_like', 'get_play_mode',
      'get_meta', 'get_image',
      'get_all_songs', 'get_external_songs', 'get_like_songs',
      'get_hr_songs', 'get_dsd_songs',
      'get_dir_songs', 'get_play_list_songs',
      'get_artist_songs', 'get_album_songs',
      'get_album_artist_songs', 'get_genre_songs',
      'open_setting', 'add_external_songs', 'del_external_songs', 'scan_data',
      'set_timing', 'set_timed_mode', 'get_timing', 'get_timed_mode',
      'get_pixel_light', 'get_pixel_color', 'get_pixel_dominant',
      'set_window_color',

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