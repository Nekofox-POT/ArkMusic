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
import { get_image, get_meta, image_to_base64, check_meta_image } from '../package/meta_manager'

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

  // 变量池 //
  private play_list: string[] = []  // 列表记录器
  private active_color: string = 'rgba(244, 198, 206, 1.0)'   // 默认高亮色
  private enable_active_color: boolean = true  // 是否支持按钮高亮色
  private setting_head_image: string = ''   // 设置头像的base64

  // 更新池 //
  @State @Watch('listen_system_volume') show_volume: boolean = false    // 显示音量条
  @State ready: boolean = false    // 页面准备指示器

  // 继承池 //
  @ObjectLink global_config: class_global_config    // 全局管理器
  @ObjectLink lin_music_player: class_audio_player  // 类 播放器
  @ObjectLink files_manager: class_files_manager    // 类 文件管理器
  @Link volume_level: number    // 音量大小
  @Link start_ui: boolean    // 环境准备指示器(为false就是重新扫描数据库)

  // 类 //
  private lin_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private audioVolumeManager = audio.getAudioManager().getVolumeManager()   // 音量条监听
  private volumeCallback: ((streamVolumeEvent: audio.StreamVolumeEvent) => void) | null = null    // 音量条监听函数

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入操作 //
  aboutToAppear(): void {
    // 检查目录 //
    try {fs.statSync(web_ui_path)} catch {fs.mkdirSync(web_ui_path)}
  }

  // 退出操作 //
  aboutToDisappear(): void {
    // 保存数据
    this.save_data()
    log('web_ui销毁.')
    // 销毁监听
    emitter.off(712)
    emitter.off(713)
    emitter.off(714)
    emitter.off(715)
    emitter.off(716)
    emitter.off(717)
    emitter.off(718)
    emitter.off(719)
    emitter.off(912)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 广播监听 //
  listen_broadcast() {
    // 元数据监听 //
    emitter.on({ eventId: 712 }, async (eventData: emitter.EventData) => {
      // 载入
      this.lin_music_ui.runJavaScript(`set_meta(${JSON.stringify([eventData.data?.name, eventData.data?.title, eventData.data?.artist])})`)
      // 时间载入
      this.lin_music_ui.runJavaScript(`change_song_range_duration(${eventData.data?.duration})`)
      // 图片编码发送
      const base_img: string = await image_to_base64(eventData.data?.image)
      this.lin_music_ui.runJavaScript(`set_meta_img(${JSON.stringify(base_img)})`)
      // 颜色值调整
      if (await pixel_light_count(eventData.data?.image) > 128) {
        this.lin_music_ui.runJavaScript(`set_background_color('rgba(0, 0, 0, 0.4)')`)
        this.set_window_color(false)
      } else {
        this.lin_music_ui.runJavaScript(`set_background_color('rgba(255, 255, 255, 0.6)')`)
        this.set_window_color(true)
      }
    })
    // 设置播放模式
    emitter.on({ eventId: 711 }, async (eventData: emitter.EventData) => {
      this.lin_music_ui.runJavaScript(`set_play_mode(${eventData.data?.play_mode})`)
    })
    // 播放状态监听 //
    emitter.on({ eventId: 716 }, (eventData: emitter.EventData) => {
      if (eventData.data?.status == 'playing') {
        this.lin_music_ui.runJavaScript(`set_play_status(true)`)
      } else {
        this.lin_music_ui.runJavaScript(`set_play_status(false)`)
      }
    })
    // 音频播放时长监听 //
    emitter.on({ eventId: 713 }, (eventData: emitter.EventData) => {
      this.lin_music_ui.runJavaScript(`change_song_range(${eventData.data?.current_time})`)
    })
    // 喜欢监听 //
    emitter.on({eventId: 717}, (eventData: emitter.EventData) => {
      this.lin_music_ui.runJavaScript(`set_like(${eventData.data?.status})`)
    })
    // 播放列表监听 //
    emitter.on({eventId: 714}, (eventData: emitter.EventData) => {
      this.lin_music_ui.runJavaScript(`playing_update(${JSON.stringify(eventData.data?.list)}, ${eventData.data?.index})`)
    })
    // 指针监听 //
    emitter.on({eventId: 715}, (eventData: emitter.EventData) => {
      this.lin_music_ui.runJavaScript(`playing_update([], ${eventData.data?.index})`)
    })
    // 返回手势监听 //
    emitter.on({eventId: 912}, async () => {
      // 转发js
      const tmp = await this.lin_music_ui.runJavaScript(`back_gesture()`)
      if (tmp === '"back"') {
        router.back()
      }
    })
  }
  // 音量监听 //
  listen_system_volume() {
    if (this.show_volume) {
      log('音量条打开')
      // 传入初始音量
      this.volume_level = this.audioVolumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC)
      this.lin_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
      // 【关键步骤】将回调函数赋值给定义好的变量
      this.volumeCallback = (streamVolumeEvent: audio.StreamVolumeEvent) => {
        log(`音量: ${streamVolumeEvent.volume} `)
        // 更新
        this.volume_level = streamVolumeEvent.volume
        this.lin_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
        vib()
      }
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, this.volumeCallback)
    } else {
      log('音量条关闭')
      this.audioVolumeManager.off('streamVolumeChange', this.volumeCallback)
    }
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

  // 加载数据 //
  load_data() {

    // 加载设置 //
    let tmp = load_array(web_ui_path + '/' + 'web_ui.json')
    if (tmp.length != 0) {
      this.active_color = tmp[0]
      this.enable_active_color = (tmp[1] === '1') ? true : false
    }
    // console.log(`${this.active_color} ${this.enable_active_color} ${this.global_config.dsd_support}`)
    this.lin_music_ui.runJavaScript(`set_active_color('${this.active_color}')`)
    this.lin_music_ui.runJavaScript(`set_button_enable_active_color(${this.enable_active_color})`)
    this.lin_music_ui.runJavaScript(`set_dsd(${this.global_config.dsd_support})`)

    // 加载歌曲 //
    this.play_list = this.files_manager.all_songs_list
    this.lin_music_ui.runJavaScript(`set_all_songs(${JSON.stringify(this.files_manager.all_songs_list.concat(this.files_manager.external_songs_list))})`)
    this.lin_music_ui.runJavaScript(`set_external_songs(${JSON.stringify(this.files_manager.external_songs_list)})`)

  }
  // 保存数据 //
  save_data() {
    if (!this.global_config.reset) {
      let tmp = [
        this.active_color,
        (this.enable_active_color) ? '1' : '0',
        this.setting_head_image,
      ]
      save_array(tmp, web_ui_path + '/' + 'web_ui.json')
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // Webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.lin_music_ui.registerJavaScriptProxy({

      ////////////
      // ready //
      //////////
      ready: async () => {
        log('页面准备完成')
        this.listen_broadcast()  // 监听广播
        // 加载audio
        // try {this.lin_music_player.load_data()} catch {}
        // 加载数据
        this.load_data()
        this.ready = true
      },

      ///////////////
      // 基础功能类 //
      /////////////
      // 播放 //
      play: () => {this.lin_music_player.playing()},
      // 暂停 //
      pause: () => {this.lin_music_player.pause()},
      // 上一首 //
      last_song: () => {this.lin_music_player.previous()},
      // 下一首 //
      next_song: () => {this.lin_music_player.next()},
      // 更改播放进度 //
      seek: (time: string) => {this.lin_music_player.seek(parseInt(time))},
      // 跳转歌曲 //
      seek_song: (index: number) => {this.lin_music_player.seek(index)},
      // 喜欢切换 //
      toggle_like: () => {this.lin_music_player.toggle_like()},
      // 设置播放模式 //
      set_play_mode: (index: number) => {
        this.lin_music_player.set_play_mode(index)
      },

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
      // 震动一下 //
      vib: () => {vib()},
      // 跳转到主页面 //
      back_to_player: () => {this.lin_music_ui.runJavaScript('taskbar_page_update(1)')},

      // 获取元数据 //
      get_song_meta: async (path: string) => {
        let tmp = [await get_meta(path), await image_to_base64(await get_image(path))]
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
      play_song: (tmp: number) => {this.lin_music_player.set_play_list(this.play_list, tmp)},

      // 删除歌曲 //
      delete_song: (tmp: number) => {
        if (tmp < 0 || tmp >= this.lin_music_player.play_list.length) return
        this.lin_music_player.play_list.splice(tmp, 1)
        if (tmp < this.lin_music_player.play_list_index) {
          this.lin_music_player.play_list_index--
        }
      },
      // 歌曲之间交换
      exchange_song: (from: number, to: number) => {
        const list = this.lin_music_player.play_list
        if (from < 0 || from >= list.length || to < 0 || to >= list.length) return
        const tmp = list[from]
        list[from] = list[to]
        list[to] = tmp
        if (this.lin_music_player.play_list_index === from) {
          this.lin_music_player.play_list_index = to
        } else if (this.lin_music_player.play_list_index === to) {
          this.lin_music_player.play_list_index = from
        }
      },

      ///////////////
      // files页用 //
      /////////////
      // 所有歌曲 列表添加 //
      set_play_list_with_all_songs: () => {
        this.play_list = this.files_manager.all_songs_list.concat(this.files_manager.external_songs_list)
      },
      // 外部歌曲 列表添加 //
      set_play_list_with_external_songs: () => {
        this.play_list = this.files_manager.external_songs_list
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
        this.play_list = this.lin_music_player.like_list_path
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
      },
      // 添加 外部歌曲
      get_external_song: async () => {
        // 添加
        await this.files_manager.get_external_song()
        // 加载
        this.play_list = this.files_manager.external_songs_list
        this.lin_music_ui.runJavaScript(`set_all_songs(${JSON.stringify(this.files_manager.all_songs_list.concat(this.files_manager.external_songs_list))})`)
        this.lin_music_ui.runJavaScript(`set_external_songs(${JSON.stringify(this.files_manager.external_songs_list)})`)
      },
      // 删除 外部歌曲
      del_external_song: (index: number) => {
        this.files_manager.del_external_song(index)
        // 更新表
        this.lin_music_ui.runJavaScript(`set_all_songs(${JSON.stringify(this.files_manager.all_songs_list.concat(this.files_manager.external_songs_list))})`)
      },

      /////////////////
      // setting页用 //
      ///////////////
      // 更改头像(目前是进群) //
      set_head_photo: async () => {
        notice('进qq群聊聊天：1062329769 / 1080024537')
      },
      // 打开收起taskbar //
      toggle_taskbar: (status: boolean) => {
        // true是screen，false是hide
        if (status) {
          this.lin_music_ui.runJavaScript(`taskbar_double('double')`)
        } else {
          this.lin_music_ui.runJavaScript(`taskbar_double('hidden')`)
        }
      },
      // 更改主题色 //
      set_active_color: (color: string) => {
        this.active_color = color
        this.lin_music_ui.runJavaScript(`set_active_color('${color}')`)
      },
      // 允许点击按钮主题色提示 //
      set_enable_active_color: (status: boolean) => {
        this.enable_active_color = status
        this.lin_music_ui.runJavaScript(`set_button_enable_active_color(${status})`)
      },
      // 允许加载dsd歌曲 //
      enable_dsd_play: (status: boolean) => {
        this.global_config.dsd_support = status
        this.lin_music_ui.runJavaScript(`set_dsd(${status})`)
        if (status) {
          this.lin_music_player.pause()
          this.lin_music_player.save_data()
          this.files_manager.reset_song_data()
          this.start_ui = false
        }
      },
      // 重新扫描媒体库 //
      rescan_data: () => {
        log('重新扫描')
        this.lin_music_player.pause()
        this.lin_music_player.save_data()
        this.files_manager.reset_song_data()
        this.start_ui = false
      },
      // 重置软件 //
      reset_app: () => {
        log('软件重置')
        this.global_config.reset_app()
      },

      // 保存web_ui的配置文件 //
      save_data: (name: string, data: string[]) => {
        return save_array(data, web_ui_path + '/' + name + '.json')
      },
      // 打开web_ui的配置文件 //
      load_data: (name: string) => {
        return load_array(web_ui_path + '/' + name + '.json')
      },

    },
      /////////////
      // 接口声明 //
      ////////////
      "ark",
      [
        'ready',
        'play', 'pause', 'last_song', 'next_song', 'seek', 'seek_song', 'toggle_like', 'set_play_mode',
        'set_vol', 'back_to_player', 'get_song_meta', 'get_meta_list_image', 'play_song',
        'set_play_list_with_all_songs', 'set_play_list_with_external_songs',
        'get_folder_songs', 'get_play_list_songs', 'get_like_songs',
        'get_artist_composer_list', 'get_album_list', 'get_album_artist_list', 'get_genre_list',
        'set_head_photo', 'toggle_taskbar', 'set_active_color', 'set_enable_active_color',
        'rescan_data', 'reset_app', 'enable_dsd_play',
        'vib', 'delete_song', 'exchange_song', 'get_external_song', 'del_external_song',
        'save_data', 'load_data',
        'start_sleep_timer', 'cancel_sleep_timer', 'get_sleep_timer'
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
      Web({ src: $rawfile("ui/web_ui/glass_ui/play_taskbar_index.html"), controller: this.lin_music_ui })
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