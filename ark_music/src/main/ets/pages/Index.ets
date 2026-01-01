// 导入模块
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import media from '@ohos.multimedia.media';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { BusinessError} from '@kit.BasicServicesKit';
import util from '@ohos.util';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import promptAction from '@ohos.promptAction';


// 导入其他ets
import {
  getDownloadPathFromPicker, get_download, scan_all_files, all_music, scan_dir_songs
} from './files_manager'

// 变量池

// 主程序 //
@Entry
@Component
struct ArkMusic_Component {

  // 变量/类池
  private context = getContext(this) as common.UIAbilityContext;
  ark_music_ui: webview.WebviewController = new webview.WebviewController();
  @State allow_create_make_files: boolean = false;
  @State ark_create_download_ui: webview.WebviewController = new webview.WebviewController();
  ark_create_download_ui_delegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private avPlayer: media.AVPlayer | null = null; // audio播放
  private session: avSession.AVSession | null = null; // avs
  play_status: boolean = false  // 播放状态
  @State play_list: string[] = []  // 歌单
  @State play_list_index: number = -1 // 歌单序号（第x首）
  song_title: string = '未知歌曲' // 歌曲名
  song_artist: string = '未知艺术家' // 作者
  song_img: image.PixelMap | undefined = undefined; // 专辑封面
  @State show_volume: boolean = false;  // 显示自己定义的音量条
  @State volume_level: number = 0;  // 音量大小

  // 组件池 //
  // 初始化
  app_start() {
    // 扫描目录
    this.allow_create_make_files = get_download();
    // 如果没创建好那先退出
    if (this.allow_create_make_files) {return;}
    promptAction.showToast({ message: '歌曲扫描完成！', duration: 3000 });
  }

  // 监听系统音频
  listen_system_volume() {
    console.log('监听音频启动！')
    // 构建监听函数
    let audioManager = audio.getAudioManager();
    let audioVolumeManager = audioManager.getVolumeManager();
    // 传入初始音量
    this.volume_level = audioVolumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC);
    this.ark_music_ui.runJavaScript(`change_volume(${this.volume_level})`)
    // 监听
    audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, (streamVolumeEvent: audio.StreamVolumeEvent) => {
      console.info(`音量: ${streamVolumeEvent.volume} `);
      // 更新
      this.volume_level = streamVolumeEvent.volume
      this.ark_music_ui.runJavaScript(`change_volume(${this.volume_level})`)
    });
  }

  // 元数据获取
  async get_storage_metadata(path: string) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      let file_name = fs.openSync(path).name
      try {
        // 创建对象
        let avMetadataExtractor = await media.createAVMetadataExtractor();
        avMetadataExtractor.fdSrc = fs.openSync(path);

        // 获取元数据。
        let metadata = await avMetadataExtractor.fetchMetadata();
        console.log(`专辑名：“${metadata.title}”，作者：“${metadata.artist}” 文件名称：${file_name}`)
        // 加载名称
        if (metadata.title == "" || metadata.artist == "") {
          this.song_title = file_name;
          this.song_artist = '未知艺术家'
        } else {
          this.song_title = metadata.title ?? file_name
          this.song_artist = metadata.artist ?? '未知艺术家'
        }
        // 输出前端
        this.ark_music_ui.runJavaScript(`set_meta(['${file_name}', '${this.song_title}', '${this.song_artist}'])`)
        this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, title: this.song_title, artist: this.song_artist })

        // 获取图片
        try {
          // 获取专辑封面（promise模式）。
          this.song_img = await avMetadataExtractor.fetchAlbumCover();
          // 输出avs
          this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, mediaImage: this.song_img })

          // 转换为 ArrayBuffer
          let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 };
          let arrayBuffer = await image.createImagePacker().packing(this.song_img, packOpts);
          let uint8Array = new Uint8Array(arrayBuffer);
          // base64 二重编码
          let base64 = new util.Base64Helper();
          let base64Data = base64.encodeSync(uint8Array);
          let dataURL = `image/jpeg;base64,${base64Data}`;
          let text_encode = new util.TextEncoder()
          let encodedData = base64.encodeSync(text_encode.encodeInto(dataURL))
          // JS 调用
          this.ark_music_ui.runJavaScript(`set_meta_img('${encodedData}')`);
        } catch {
          // 获取失败，返回空
          await this.loadDefaultImage();
          this.ark_music_ui.runJavaScript(`set_meta_img('')`);
          this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, mediaImage: this.song_img })
        }
        // 释放
        avMetadataExtractor.release();
      } catch (e) {
        console.error(`专辑信息获取失败：${e}}`);
        // 返回空信息
        await this.loadDefaultImage();
        this.ark_music_ui.runJavaScript(`set_meta(['${file_name}', '${file_name}', '未知艺术家'])`)
        this.ark_music_ui.runJavaScript(`set_meta_img('')`);
        this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, mediaImage: this.song_img })
      }
    }
  }
  async loadDefaultImage(): Promise<image.PixelMap | undefined> {
    const context = getContext(this) as common.Context;
    const resourceManager = context.resourceManager;

    // 获取媒体资源内容
    const mediaData = await resourceManager.getMediaContent($r('app.media.CD'));

    // 创建图像源并生成 PixelMap
    const imageSource = image.createImageSource(mediaData.buffer);
    this.song_img = await imageSource.createPixelMap();
    return await imageSource.createPixelMap();
  }

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
      this.session.on("play", () => {this.avPlayer?.play()})
      this.session.on("pause", () => {this.avPlayer?.pause()})
      this.session.on("playPrevious", () => {this.ark_music_ui.runJavaScript('post_last_song()')})
      this.session.on("playNext", () => {this.ark_music_ui.runJavaScript('post_next_song()')})
      this.session.on("seek", (position) => {this.avPlayer?.seek(position)})
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

  // 注册长时任务
  async reg_bg_audio() {
    console.log('注册后台任务')
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.nekofoxpot.arkmusic",
          abilityName: "Ark_musicAbility"
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
      console.error(`后台注册失败：${e}}`);
    }
  }

  // 创建audio
  async audio_set(path: string) {

    // 获取元数据
    this.get_storage_metadata(path);

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
    const tmp_fd = fs.openSync(path).fd;
    let avFileDescriptor: media.AVFileDescriptor = {fd: tmp_fd, offset: 0, length: fs.statSync(tmp_fd).size}
    this.avPlayer.fdSrc = avFileDescriptor;

    // 进入等待状态
    console.log('装载')
    console.log('创建完成，等待播放.....')

  }
  // 注册audio监听
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
          this.ark_music_ui.runJavaScript(`change_play_status('play')`);
          break;
        case 'paused':  // audio暂停
          console.log('audio暂停了！')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          this.ark_music_ui.runJavaScript(`change_play_status('pause')`);
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.log('audio播放完了。')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          this.ark_music_ui.runJavaScript(`change_play_status('pause')`);
          // 如果不是结尾，则下一首
          console.log(`${this.play_list_index} / ${this.play_list.length}`)
          if (this.play_list_index < this.play_list.length - 1) {
            console.log('下一首')
            this.ark_music_ui.runJavaScript('post_next_song()');
          } else {
            promptAction.showToast({ message: '最后一首歌了哦！', duration: 3000 });
          }
          break;
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
      this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, duration: time })
      this.ark_music_ui.runJavaScript(`update_duration_time(${time})`)
    });
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })
      this.ark_music_ui.runJavaScript(`update_current_time(${time})`)
    });
  }

  // 注册webview函数
  reg_webview_js() {
    try {this.ark_music_ui.registerJavaScriptProxy(
      {

        // 扫描歌曲
        scan_songs: () => {
          console.log('准备扫描。')
          scan_all_files();
          promptAction.showToast({ message: '扫描完成！', duration: 3000 });
        },
        // 加载歌曲
        get_songs: (model: string, path: string = ''): string[][] => {
          // 判断是获取什么
          if (model == "get_all_songs") {
            // 返回数组表
            return all_music;
          } else {
            return [[]];
          }
        },
        // 点歌
        play_songs: (path: string, id: string, arg: string = '') => {
          console.log('点歌！');
          // 判断模式
          if (id == 'all_songs') {
            // 模式：所有歌曲
            // 导入列表
            this.play_list = []
            for (let i = 0; i < all_music.length; i++) {
              this.play_list.push(all_music[i][0]);
            }
            // 序号设置
            try {
              let tmp = this.play_list.indexOf(path);
              // 测试文件可用性
              fs.statSync(this.play_list[tmp])
              // 通过
              this.play_list_index = tmp;
              console.log('准备初始化audio');
              // 注册audio
              // 读取验证文件有效性
              try {
                fs.statSync(this.play_list[this.play_list_index])
                // 通过，重置audio
                this.audio_set(this.play_list[this.play_list_index]);
              } catch {
                // 无效 歌序归位
                this.play_list_index = -1;
              }
            } catch {
              promptAction.showToast({ message: '文件读取失败，请重试', duration: 3000 });
              this.play_list_index = -1;
            }
          }
        },
        // 播放 / 暂停
        play_change: () => {
          if (this.play_status) { this.avPlayer?.pause() } else { this.avPlayer?.play() }
        },
        // 上一首
        last_song: () => {
          // 非0判断
          console.log('上一首')
          if (this.play_list_index <= 0 ) {
            // 如果为0，则倒退到最后一首
            this.play_list_index = this.play_list.length - 1;
          } else {
            this.play_list_index -= 1
          }
          // 读取验证文件有效性
          try {
            fs.statSync(this.play_list[this.play_list_index])
            // 通过，重置audio
            this.audio_set(this.play_list[this.play_list_index]);
          } catch {
            // 无效 歌序归位
            this.play_list_index = -1;
          }
        },
        // 下一首
        next_song: () => {
          // 如果是最后一首，则从头开始
          if (this.play_list_index >= this.play_list.length - 1) {
            this.play_list_index = 0;
          } else {
            this.play_list_index += 1;
          }
          // 读取验证文件有效性
          try {
            fs.statSync(this.play_list[this.play_list_index])
            // 通过，重置audio
            this.audio_set(this.play_list[this.play_list_index]);
          } catch {
            // 无效 歌序归位
            this.play_list_index = -1;
          }
        },
        // 拖动进度条
        play_seek: (seek: string) => {
          try { this.avPlayer?.seek(parseInt(seek)) } catch {}
        },
        // 调节音量
        change_volume: (level: string) => {
          // level -1 = 打开面板，level -2 = 关闭面板
          if (level == '-1') {
            this.show_volume = true
          } else if (level == '-2') {
            this.show_volume = false
          } else {
            this.volume_level = parseInt(level)
          }
        },

        // 扫描文件夹（结构模式）
        scan_songs_dir: (path: string = '') => {
          // 根据传入的值扫描
          let tmp = scan_dir_songs(path)
          console.log('#0')
          console.log(`${tmp}`)
        },

      },
      "arkts",
      [
        "scan_songs", "get_songs", "play_songs", "play_change", "last_song", "next_song", "play_seek",
        "open_volume", "change_volume",
        "scan_songs_dir"
      ]
    )} catch (e) {
      console.error(`注册webview时出现了错误: ${e}.`)
    }
  }

  // UI界面构建 //
  build() {
    Row() {

      // ArkMusic主界面 //
      Web({ src: $rawfile("webview_gui/index.html"), controller: this.ark_music_ui, renderMode: RenderMode.ASYNC_RENDER })
        .width('100vw')
        .height('100vh')
        .position({ x: 0, y: 0})
        .zIndex(500)
        .zoomAccess(false)
        // 加载前
        .onControllerAttached(() => {

          // 初始化 //
          this.app_start();
          // 注册avs
          this.reg_bg_audio();
          this.avs_reg_session();
          // 注册webview行为
          this.reg_webview_js();

        })
        // 加载后
        .onPageEnd(() => {
          // 监听音量
          this.listen_system_volume();
        })

      // 下载目录创建 //
      if (this.allow_create_make_files) {
        Web({src: $rawfile("create_gui/index.html"), controller: this.ark_create_download_ui})
          .width('100vw')
          .height('100vh')
          .position({ x: 0, y: 0})
          .zIndex(900)
          .zoomAccess(false)
          .onPageEnd(async () => {
            console.log('创建页准备完成...')
            try {
              this.ark_create_download_ui_delegate.onBeforeDownload((webDownloadItem: webview.WebDownloadItem) => {
                console.info("正在创建...");
                getDownloadPathFromPicker().then((downloadPath) => {
                  webDownloadItem.start(downloadPath + '/' + webDownloadItem.getSuggestedFileName());
                });
              })
              this.ark_create_download_ui_delegate.onDownloadFinish(() => {
                console.info("创建完成！");
                this.app_start();
              })
              this.ark_create_download_ui.setDownloadDelegate(this.ark_create_download_ui_delegate);
            } catch (error) {
              console.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
            }
            this.ark_create_download_ui.runJavaScript('download()')
          })
      }

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