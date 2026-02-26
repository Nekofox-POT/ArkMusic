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
import media from '@ohos.multimedia.media';
import { avSession } from '@kit.AVSessionKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { audio } from '@kit.AudioKit';
import { image } from '@kit.ImageKit';
import util from '@ohos.util';
import { common } from '@kit.AbilityKit';
import { wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';


//////////////////
// 导入自创建模块 //
/////////////////
import { notice, vib, reg_bg_run } from '../background_pages/system_function'

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
  play_status: boolean = false  // 播放状态

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
  avPlayer: media.AVPlayer | null = null; // audio播放
  session: avSession.AVSession | null = null; // 元音频

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
  // 后台注册 //
  ////////////
  async reg_bg_run() {
    console.log('注册后台任务')
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.nekofoxpot.arkmusic",
          abilityName: "EntryAbility"
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 712,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    try {
      let tmpWantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(this.context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, tmpWantAgent);
    } catch (e) {
      console.error(`后台注册失败：${e.message}`);
    }
  }

  ///////////////
  // 元数据获取 //
  /////////////
  async get_meta(file: fs.File) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      let file_name = file.name
      try {
        // 创建对象
        let avMetadataExtractor = await media.createAVMetadataExtractor();
        avMetadataExtractor.fdSrc = file  ;
        // 获取元数据。
        let metadata = await avMetadataExtractor.fetchMetadata();
        // 获取专辑封面
        try {
          this.get_meta_img(await avMetadataExtractor.fetchAlbumCover())
        } catch {
          const resourceManager = getContext(this).resourceManager;
          // 获取媒体资源内容
          const mediaData = await resourceManager.getMediaContent($r('app.media.CD'));
          // 创建图像源并生成 PixelMap
          const imageSource = image.createImageSource(mediaData.buffer);
          this.get_meta_img(await imageSource.createPixelMap())
        }
        // 释放
        avMetadataExtractor.release();
        console.log(`专辑名：“${metadata.title}”，作者：“${metadata.artist}” 文件名称：${file_name}`)
        // 加载名称
        let song_title = metadata.title ?? file_name
        let song_artist = metadata.artist ?? '未知艺术家'
        // 输出
        this.session?.setAVMetadata({ assetId: '0', title: song_title, artist: song_artist })
        this.ark_music_ui.runJavaScript(`set_meta(['${file_name}', '${song_title}', '${song_artist}'])`)

      } catch (e) {
        console.error(`专辑信息获取失败：${e}}`);
        // 返回空信息
        this.session?.setAVMetadata({ assetId: '0', title: file_name, artist: '未知艺术家' })
        this.ark_music_ui.runJavaScript(`set_meta(['${file_name}', '${file_name}', '未知艺术家'])`)
      }
    }
  }
  async get_meta_img(metadata: image.PixelMap) {

    // 输出元音频
    this.session?.setAVMetadata({ assetId: '0', mediaImage: metadata })

    // 转换为 ArrayBuffer
    let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 };
    let arrayBuffer = await image.createImagePacker().packing(metadata, packOpts);
    let uint8Array = new Uint8Array(arrayBuffer);
    // base64 二重编码
    let base64 = new util.Base64Helper();
    let base64Data = base64.encodeSync(uint8Array);
    let dataURL = `image/jpeg;base64,${base64Data}`;
    let text_encode = new util.TextEncoder()
    let encodedData = base64.encodeSync(text_encode.encodeInto(dataURL))
    // 传入前端
    this.ark_music_ui.runJavaScript(`set_meta_img('${encodedData}')`);

  }

  ///////////////
  // 元音频创建 //
  /////////////
  // AV Session创建
  async avs_reg_session() {
    try {

      let context = this.getUIContext().getHostContext() as Context;
      // 创建session。
      console.log('创建session...');
      this.session = await avSession.createAVSession(context, 'SESSION_NAME', 'audio');
      await this.session.activate();

      // 注册播放器行为
      console.log('注册行为...');
      this.session.on("play", () => {this.avPlayer?.play()})  // 播放
      this.session.on("pause", () => {this.avPlayer?.pause()})  // 暂停
      // this.session.on("playPrevious", () => {this.ark_music_ui.runJavaScript('post_last_song()')}) // 上一首
      // this.session.on("playNext", () => {this.ark_music_ui.runJavaScript('post_next_song()')}) //下一首
      this.session.on("seek", (position) => {this.avPlayer?.seek(position)})  // 跳转
      this.session.on("answer", () => {console.log('avs:接听电话')})
      this.session.on("hangUp", () => {console.log('avs:挂断电话')})
      this.session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})
      console.log('注册完成！');

      // 初始化
      await this.session.setAVMetadata({
        assetId: '-1',
        title: '未知歌曲',
        artist: '未知歌手',
      });

    } catch (e) {
      console.error(`avs未知错误：${e}`)
    }
  }

  ///////////////
  // audio模块 //
  //////////////
  async audio_set(path: string) {
    try {
      // 检查文件源
      const file_sync = fs.openSync(path)
      // 丢给meta
      this.get_meta(file_sync)
      const tmp_fd = file_sync.fd;
      const tmp_size = fs.statSync(tmp_fd).size;
      // 检查对象
      if (this.avPlayer) {
        console.log(`已存在对象，进行销毁`);
        // 销毁audio
        await this.avPlayer.release();
        // 重置播放状态
        this.play_status = false;
        console.log("资源销毁完成.");
      }
      // 创建avPlayer。
      console.log('创建audio.');
      this.avPlayer = await media.createAVPlayer();
      // 注册回调函数
      console.log('注册回调')
      await this.setAVPlayerCallback((avPlayer: media.AVPlayer) => {});
      // 设置播放源
      console.log('设置播放源')
      this.avPlayer.fdSrc = {fd: tmp_fd, offset: 0, length: tmp_size};
    } catch (e) {
      console.log(`装载失败：${e}`)
      notice(`文件读取失败：${e}`)
    }
  }
  async setAVPlayerCallback(callback: (avPlayer: media.AVPlayer) => void) {

    // 添加保险
    if (!this.avPlayer) { return; }

    // 状态机变化（主）
    this.avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      // 添加保险
      if (!this.avPlayer) { return; }
      // 状态分类
      switch (state) {
        case 'idle': // audio闲置
          console.log('audio闲置了');
          break;
        case 'initialized': // audio初始化
          console.log('audio正在初始化');
          this.avPlayer.prepare();
          break;
        case 'prepared': // audio准备就绪
          console.log('audio准备就绪。')
          callback(this.avPlayer);
          console.log('callback设置成功，等待audio播放。')
          this.avPlayer.play();
          break;
        case 'playing': // audio播放
          console.log('audio正在播放~')
          this.play_status = true;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
          this.ark_music_ui.runJavaScript(`set_play_status(true)`);
          break;
        case 'paused':  // audio暂停
          console.log('audio暂停了！')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          this.ark_music_ui.runJavaScript(`set_play_status(false)`);
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.log('audio播放完了。')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          this.ark_music_ui.runJavaScript(`set_play_status(false)`);
        case 'stopped':
          console.log('audio已结束工作，等待销毁...')
          break
        case 'released':
          console.log('audio被销毁了！')
          break
        case 'error':
          console.error(`audio call出现了错误。`);
          break
      }
    });

    // 跳转处理
    this.avPlayer.on('seekDone', (seekDoneTime) => {
      console.log(`audio跳转了，跳转至"${seekDoneTime}"`);
    });
    // 音频焦点切换处理
    this.avPlayer.on('audioInterrupt', () => {
      console.log('audio被中断了！')
      if (!this.play_status) {
        this.avPlayer?.play();
      }
    });
    // 错误处理
    this.avPlayer.on('error', (e) => {
      console.error(`audio发生错误：${e}`);
      // 重置
      this.avPlayer?.reset();
    });
    // 总时长更新
    this.avPlayer.on('durationUpdate', (time: number) => {
      this.session?.setAVMetadata({ assetId: `0`, duration: time })
      this.ark_music_ui.runJavaScript(`change_song_range_duration(${time})`)
    });
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })
      this.ark_music_ui.runJavaScript(`change_song_range(${time})`)
    });
  }

  ////////////////////
  // webview功能注册 //
  ///////////////////
  reg_webview_js() {
    try {this.ark_music_ui.registerJavaScriptProxy(
      {
        // ready //
        ready: () => {this.ui_ready = true},
        // 播放 //
        play: () => {console.log('想播放.');this.avPlayer?.play()},
        // 暂停 //
        pause: () => {console.log('想播放.');this.avPlayer?.pause()},
        // 更改播放进度 //
        seek: (time: string) => {this.avPlayer?.seek(parseInt(time))},
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
      },
      "ark",
      [
        'ready',
        'play', 'pause', 'seek',
        'set_vol',
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
            this.avs_reg_session(); // 注册元音频
          })
          .onPageEnd(() => {
            this.listen_system_volume()  // 开始监听音量
            console.log('页面加载完成.')
            this.audio_set(root_path + '二乘 - 时之风.flac')
            // this.audio_set(root_path + '洛天依 - 秋之风.flac')
            this.ark_music_ui.runJavaScript('set_background_color(\'rgba(255, 255, 255, 0.8)\')')
            this.avPlayer?.seek(0)
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