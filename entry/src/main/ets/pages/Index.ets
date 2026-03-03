//
// ArkMusic主界面
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
import { common } from '@kit.AbilityKit';
import emitter from '@ohos.events.emitter'

import nativeModule from 'libentry.so';


//////////////////
// 导入自创建模块 //
/////////////////
import { notice, vib, reg_bg_run } from '../package/system_function'
import { audio_player } from '../package/audio_player/audio_player'

///////////
// 变量池 //
//////////
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path // 根目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

//////////////////
// 资源目录创建器 //
/////////////////
export function getDownloadPathFromPicker(): Promise<string> {
  return new Promise<string>(resolve => {
    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      const documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(documentSaveOptions).then(async (documentSaveResult: Array<string>) => {
        if (documentSaveResult.length <= 0) {
          resolve('');
          return;
        }
        const uriString = documentSaveResult[0];
        if (!uriString) {
          resolve('');
          return;
        }
        const uri = new fileUri.FileUri(uriString);
        resolve(uri.path);
      }).catch((err: BusinessError) => {
        console.error(`ErrorCode: ${err.code},  Message: ${err.message}`);
        resolve('');
      });
    } catch (error) {
      resolve('');
    }
  })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主页面入口 //
//////////////
@Entry
@Component
struct Index {
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ///////////
  // 变量池 //
  //////////
  private context = getContext(this) as common.UIAbilityContext   // 身份证
  status: Boolean = false   // 状态

  ///////////
  // 更新池 //
  //////////
  @State ui_ready: boolean = false    // 准备指示器
  @State dir_ready: boolean = false   // 目录初始化指示器
  @State show_volume: boolean = false;  // 显示音量条
  @State volume_level: number = 0;  // 音量大小

  ////////
  // 类 //
  ///////
  ark_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  dir_create_downloader: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();   // 下载器
  ark_music_player = new audio_player(this.context)   // 播放器核心

  ////////////////
  // web图片处理 //
  ///////////////
  async pixel_to_base(metadata: image.PixelMap) {

    // 2. 准备图片数据
    let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 };
    // 注意：packing 是耗时操作，这里得到 ArrayBuffer
    let arrayBuffer = await image.createImagePacker().packing(metadata, packOpts);

    // 3. 调用 C++ 进行 Base64 编码
    // C++ 返回的是完整的 "data:image/jpeg;base64,xxxx" 字符串
    let dataURL = nativeModule.encodeImageToBase64(arrayBuffer);

    // 4. 传入前端
    // 使用 JSON.stringify 防止字符串中的特殊字符（如换行）破坏 JS 语法
    this.ark_music_ui.runJavaScript(`set_meta_img(${JSON.stringify(dataURL)})`);

  }

  /////////////
  // 广播监听 //
  ////////////
  // 元数据监听程序 //
  metadata_broadcast: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    console.log(eventData.data?.song_name)
    console.log(eventData.data?.title)
    console.log(eventData.data?.artist)
    // 载入
    this.ark_music_ui.runJavaScript(`set_meta(['${eventData.data?.song_name}', '${eventData.data?.title}', '${eventData.data?.artist}'])`)
    // 图片编码
    this.pixel_to_base(eventData.data?.img)
  }
  play_status_broadcast: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    if (eventData.data?.status == 'playing') {
      this.ark_music_ui.runJavaScript(`set_play_status(true)`)
    } else {
      this.ark_music_ui.runJavaScript(`set_play_status(false)`)
    }
  }
  duration_time_broadcast: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    this.ark_music_ui.runJavaScript(`change_song_range_duration(${eventData.data?.duration_time})`)
  }
  current_time_broadcast: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    this.ark_music_ui.runJavaScript(`change_song_range(${eventData.data?.current_time})`)
  }
  // 启动器 //
  listen_broadcast() {
    emitter.on({ eventId: 710 }, this.metadata_broadcast)
    emitter.on({ eventId: 712 }, this.play_status_broadcast)
    emitter.on({ eventId: 713 }, this.duration_time_broadcast)
    emitter.on({ eventId: 714 }, this.current_time_broadcast)
  }

  /////////////
  // 音量监听 //
  ////////////
  listen_system_volume() {
    console.log('监听音频启动！')
    // 构建监听函数
    let audioManager = audio.getAudioManager()
    let audioVolumeManager = audioManager.getVolumeManager()
    // 传入初始音量
    this.volume_level = audioVolumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC)
    this.ark_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
    // 监听
    audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, (streamVolumeEvent: audio.StreamVolumeEvent) => {
      console.info(`音量: ${streamVolumeEvent.volume} `)
      // 更新
      this.volume_level = streamVolumeEvent.volume
      this.ark_music_ui.runJavaScript(`set_vol(${this.volume_level})`)
      vib()
    });
  }

  /////////////
  // 退出操作 //
  ////////////
  aboutToDisappear(): void {
    console.log('程序结束运行.')
    this.ark_music_player.drop_it()
    console.log('再见')
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
          this.ui_ready = true
          // 装载播放器
          this.ark_music_player.set_play_list([`${root_path}二乘 - 时之风.flac`, `${root_path}洛天依 - 秋之风.flac`], 0)
          this.ark_music_ui.runJavaScript('set_background_color(\'rgba(255, 255, 255, 0.8)\')')
        },
        // 播放 //
        play: () => {console.log('想播放.'); this.ark_music_player.set_play_status(true)},
        // 暂停 //
        pause: () => {console.log('想播放.'); this.ark_music_player.set_play_status(false)},
        // 更改播放进度 //
        seek: (time: string) => {this.ark_music_player.audio_seek(parseInt(time))},
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
        // 放歌 //
        play_song: (path: string) => {this.ark_music_player.last_next_songs(true)}
      },
      "ark",
      [
        'ready',
        'play', 'pause', 'seek',
        'set_vol',
        'play_song'
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
      if (!this.ui_ready) {
        Column() { Image($r('app.media.foreground_backup')).width('256px').height('256px') }
        .width('100%')
        .height('100%')
        .zIndex(990)
        .position({ x: 0, y: 0 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#fff')
        .transition(
          TransitionEffect.opacity(0)
            .animation({ duration: 500 })
        )
      }

      /////////////
      // web界面 //
      ////////////
      if (this.dir_ready) {
        Web({ src: $rawfile("webview_gui/play_taskbar_index.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .zoomAccess(false)
          .domStorageAccess(true) // 开启 DOM 存储
          .cacheMode(CacheMode.Default) // 默认模式，对本地文件无副作用，对网络资源有效
          .javaScriptAccess(true) // 确保 JS 开启
          .enableNativeEmbedMode(true) // 开启硬件加速渲染层
          .onControllerAttached(() => {
            this.reg_webview_js() // 注册web接口
            reg_bg_run(this.context) // 注册后台
          })
          .onPageEnd(() => {
            this.listen_system_volume()  // 开始监听音量
            this.listen_broadcast()  // 监听广播
            console.log('页面加载完成.')
          })
      }

      //////////////////
      // 目录初始化页面 //
      /////////////////
      if (!this.dir_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })
          .onPageEnd(async () => {
            // 尝试读取目录
            try {
              console.log('检测目录...')
              fs.listFileSync(root_path);
              this.dir_ready = true
            } catch (e) {   // 读取失败，创建目录
              console.log(`目录不存在：${e}`)
              console.log('准备创建...')
              try {
                // 调用创建器
                this.dir_create_downloader.onBeforeDownload((webDownloadItem: webview.WebDownloadItem) => {
                  getDownloadPathFromPicker().then((downloadPath) => {
                    webDownloadItem.start(downloadPath + '/' + webDownloadItem.getSuggestedFileName());
                  });
                })
                this.dir_create_downloader.onDownloadFinish(() => {
                  console.info("创建完成！")
                  // 检测
                  try {
                    fs.listFileSync(root_path);
                    console.log('初始化完成.')
                    notice('初始化完成.')
                    this.dir_ready = true
                  } catch (e) {
                    console.log(`检测失败：${e}`)
                    notice(`初始化失败：${e}`)
                  }
                })
                this.ark_music_ui.setDownloadDelegate(this.dir_create_downloader);
              } catch (error) {
                console.error(`创建出错: ${error}`);
              }
              this.ark_music_ui.runJavaScript('download()')

            }
          })
      }

      /////////////
      // 音量界面 //
      ////////////
      // 音量界面 //
      if (this.show_volume) {
        AVVolumePanel({
          volumeLevel: this.volume_level,
          volumeParameter: { position: { x: -1, y: -1 } }
        })
      }

    }
  }
}