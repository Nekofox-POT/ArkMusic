import { webview } from '@kit.ArkWeb';
import display from '@ohos.display';
import emitter from '@ohos.events.emitter';
import { common } from '@kit.AbilityKit';
import media from '@ohos.multimedia.media';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';
import { AVVolumePanel } from '@kit.AudioKit';
import { BusinessError} from '@kit.BasicServicesKit';
import picker from '@ohos.file.picker';
import util from '@ohos.util';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';

const PROPORTION = 0.99; // 占屏幕比例
const SURFACE_W = 0.9; // 表面宽比例
const SURFACE_H = 1.78; // 表面高比例
const TIME_ONE = 60000;
const TIME_TWO = 1000;
let innerEventFalse: emitter.InnerEvent = {
  eventId: 1,
  priority: emitter.EventPriority.HIGH
};
let innerEventTrue: emitter.InnerEvent = {
  eventId: 2,
  priority: emitter.EventPriority.HIGH
};
let innerEventWH: emitter.InnerEvent = {
  eventId: 3,
  priority: emitter.EventPriority.HIGH
};
const TAG = 'MetadataDemo';

// 主程序
@Entry
@Component
struct WebComponent {

  // 自己创建的
  @State example_list: string[] = []
  @State list_reg: number = 0
  @State playing_mode: boolean = false  // false是内置音频，true是外置音频
  @State storage_list: string[] = []
  @State storage_list_name: string[] = []
  @State storage_list_reg: number = 0
  @State audio_volume: number = 0
  @State audio_volume_change: boolean = false // 如果是true的话隐藏音量条
  @State volume_panel_location: number = 1;
  @State song_title: string = '未知歌曲'
  @State song_artist: string = '未知艺术家'
  @State session: avSession.AVSession | null = null;
  private context = getContext(this) as common.UIAbilityContext;

  // 这一坨不知道什么变量不要动
  tag: string = 'AVPlayManager';
  private xComponentController: XComponentController = new XComponentController();
  private avPlayer: media.AVPlayer | null = null;
  private surfaceId: string = '';
  private intervalID: number = -1;
  private count: number = 0;
  @State title: Resource = $r('app.string.Ark_musicAbility_label');
  @State fileName: string = ''; // 播放的文件名
  @State isSwiping: boolean = false; // 用户滑动过程中
  @State isPaused: boolean = false; // 暂停播放
  @State XComponentFlag: boolean = false;
  @StorageLink('durationTime') durationTime: number = 0; // 视频总时长
  @StorageLink('currentTime') currentTime: number = 0; // 视频当前时间
  @State surfaceW: number | null = null;
  @State surfaceH: number | null = null;
  @State percent: number = 0;
  @State windowWidth: number = 300;
  @State windowHeight: number = 200;
  @State controller: webview.WebviewController = new webview.WebviewController();
  @State pixelMap: image.PixelMap | undefined = undefined;

  // AV Session创建 / 设置 / 获取状态
  async avs_reg_session() {
    try {
      if (!this.session) {
        let context = this.getUIContext().getHostContext() as Context;
        // 创建session。
        console.log('创建session');
        this.session = await avSession.createAVSession(context, 'SESSION_NAME', 'audio');
        await this.session.activate();
        console.log(`创建完成！id：${this.session.sessionId}`)

        // 注册播放器行为
        console.log('注册行为');
        this.session.on("play", async () => {this.isPaused = true; this.avPlay()})
        this.session.on("pause", async () => {this.isPaused = false; this.avPause()})
        this.session.on("playPrevious", async () => {await this.last_song()})
        this.session.on("playNext", async () => {await this.next_song()})
        this.session.on("seek", async (position) => {this.avSeek(position);})
        this.session.on("answer", async () => {this.isPaused = false; this.avPause()})
        this.session.on("hangUp", async () => {this.isPaused = true; this.avPlay()})
        console.log('注册完成！');

      } else {
        console.log('已经有一个了！')
      }

    } catch (e) {
      console.error(`未知错误：${e}`)
    }
  }
  async avs_get_metadata() {
    console.log('设置元数据');
    let metadata: avSession.AVMetadata = {
      assetId: '712', // 由应用指定，用于标识应用媒体库里的媒体。
      title: this.song_title,
      mediaImage: this.pixelMap ?? "",
      artist: this.song_artist,
      duration: this.durationTime,  // 资源的时长，以ms为单位。
    };
    await this.session?.setAVMetadata(metadata);
    console.log('元数据设置成功！');
  }
  async avs_get_playing() {
    let tmp: avSession.PlaybackState
    if (this.isPaused) {
      tmp = avSession.PlaybackState.PLAYBACK_STATE_PLAY
    } else {
      tmp = avSession.PlaybackState.PLAYBACK_STATE_PAUSE
    }
    let playbackState: avSession.AVPlaybackState = {
      state: tmp,
      position: {
        elapsedTime: this.currentTime, // 已经播放的位置，以ms为单位。
        updateTime: new Date().getTime(), // 应用更新当前位置时的时间戳，以ms为单位。
      },
      isFavorite: false
    };
    await this.session?.setAVPlaybackState(playbackState);
  }

  // 申请长时任务
  async reg_bg_audio() {
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: "com.nekofoxpot.arkmusic",
          abilityName: "MainAbility"
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      // 使用者自定义的一个私有值
      requestCode: 712,
      // 点击通知后，动作执行属性
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    try {
      let tmpWantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(this.context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, tmpWantAgent);
    } catch (error) {
      console.error(`Failed to Operation getWantAgent. Code is ${(error as BusinessError).code}, message is ${(error as BusinessError).message}`);
    }
  }

  // 监听系统音频
  listen_system_volume() {
    console.log('监听音频启动！')
    // 构建监听函数
    let audioManager = audio.getAudioManager();
    let audioVolumeManager = audioManager.getVolumeManager();
    // 传入初始音量
    this.audio_volume = audioVolumeManager.getVolumeByStream(audio.StreamUsage.STREAM_USAGE_MUSIC);
    this.controller.runJavaScript(`change_volume(${this.audio_volume})`)
    // 监听
    audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MUSIC, (streamVolumeEvent: audio.StreamVolumeEvent) => {
      console.info(`Volume level: ${streamVolumeEvent.volume} `);
      // 将改变的音量传入变量
      this.audio_volume = streamVolumeEvent.volume
      if (this.audio_volume_change) {
        // 如果音量面板打开了，则隐藏默认面板
        this.volume_panel_location = -1
      } else {
        // 如果音量面板关闭了，则显示默认面板
        this.volume_panel_location = 100
      }
      // UI更新
      this.controller.runJavaScript(`change_volume(${this.audio_volume})`)
    });
  }

  // 扫描更新示例音频
  scan_example_audio() {
    let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const resManager = context.resourceManager;
    resManager.getRawFileList("example_music", (error: BusinessError, files: Array<string>) => {
      if (error) {
        console.error(`扫描失败: ${error.code}, ${error.message}`);
        return;
      }
      // 修改文件列表
      this.example_list = files;

    });
  }

  // 播放时间更新 / 格式化
  getDurationTime(): number {
    return this.durationTime;
  }
  getCurrentTime(): number {
    return this.currentTime;
  }
  timeConvert(time: number): string {
    let min: number = Math.floor(time / TIME_ONE);
    let second: string = ((time % TIME_ONE) / TIME_TWO).toFixed(0);
    second = second.padStart(2, '0');
    return `${min}:${second}`;
  }

  // 加载内置图片
  async loadDefaultImage() {
    try {
      const context = getContext(this) as common.Context;
      const resourceManager = context.resourceManager;

      // 获取媒体资源内容
      const mediaData = await resourceManager.getMediaContent($r('app.media.CD'));

      // 创建图像源并生成 PixelMap
      const imageSource = image.createImageSource(mediaData.buffer);
      this.pixelMap = await imageSource.createPixelMap();
    } catch (error) {
      console.error("默认图片加载失败: " + JSON.stringify(error));
    }
  }
  // 获取元数据（外部音频）
  async get_storage_metadata() {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      try {
        // 创建AVMetadataExtractor对象。
        let avMetadataExtractor = await media.createAVMetadataExtractor();

        // 设置fdSrc。
        avMetadataExtractor.fdSrc = fs.openSync(this.fileName);
        let file_name = fs.openSync(this.fileName).name

        // 获取元数据（promise模式）。
        let metadata = await avMetadataExtractor.fetchMetadata();
        console.info(TAG, `get meta data, mimeType: ${metadata.mimeType}`);
        console.log(`专辑名：“${metadata.title}”，作者：“${metadata.artist}”\n文件名称：${file_name}}`)
        // 如果为空
        if (metadata.title == "" || metadata.artist == "") {
          // 加载默认名称
          this.song_title = this.fileName
          this.song_artist = '未知艺术家'
        } else {
          // 加载完成名称
          this.song_title = metadata.title ?? '未知歌曲'
          this.song_artist = metadata.artist ?? '未知艺术家'
        }
        // 返回
        this.controller.runJavaScript(`set_song_title(['${this.song_title}', '${this.song_artist}'])`)

        try {
          // 获取专辑封面（promise模式）。
          this.pixelMap = await avMetadataExtractor.fetchAlbumCover();
          // 转换为 ArrayBuffer
          let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 };
          let arrayBuffer = await image.createImagePacker().packing(this.pixelMap, packOpts);
          let uint8Array = new Uint8Array(arrayBuffer);
          // base64 二重编码
          let base64 = new util.Base64Helper();
          let base64Data = base64.encodeSync(uint8Array);
          let dataURL = `image/jpeg;base64,${base64Data}`;
          let text_encode = new util.TextEncoder()
          let encodedData = base64.encodeSync(text_encode.encodeInto(dataURL))
          // JS 调用
          this.controller.runJavaScript(`set_song_image('${encodedData}')`);
        } catch {
          await this.loadDefaultImage()
          // 获取失败，返回空
          this.controller.runJavaScript(`set_song_image('')`);
        }
        // 释放资源（promise模式）。
        avMetadataExtractor.release();
        console.info(TAG, `release data source success.`);
      } catch (e) {
        console.error(TAG + `FetchMetadataFromFdSrc, code is ${e.code}, message is ${e.message}`);
        // 返回空信息
        this.controller.runJavaScript(`set_song_title(['${this.fileName}', '未知艺术家'])`)
        this.controller.runJavaScript(`set_song_image('')`);
      }
    }
  }
  // 获取元数据（内置音频）
  async get_example_metadata() {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      try {
        // 创建AVMetadataExtractor对象。
        let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();

        // 设置fdSrc。
        let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        avMetadataExtractor.fdSrc = await context.resourceManager.getRawFd('example_music/' + this.fileName);

        // 获取元数据（promise模式）。
        let metadata = await avMetadataExtractor.fetchMetadata();
        console.log(`专辑名：“${metadata.title}”，作者：“${metadata.artist}”`)
        // 如果为空
        if (metadata.title == "" || metadata.artist == "") {
          // 加载默认名称
          this.song_title = this.fileName
          this.song_artist = '未知艺术家'
        } else {
          // 加载完成名称
          this.song_title = metadata.title ?? '未知歌曲'
          this.song_artist = metadata.artist ?? '未知艺术家'
        }
        // 返回
        this.controller.runJavaScript(`set_song_title(['${this.song_title}', '${this.song_artist}'])`)

        try {
          // 获取专辑封面（promise模式）。
          this.pixelMap = await avMetadataExtractor.fetchAlbumCover();

          // 转换为 ArrayBuffer
          let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 };
          let arrayBuffer = await image.createImagePacker().packing(this.pixelMap, packOpts);
          let uint8Array = new Uint8Array(arrayBuffer);
          // base64 二重编码
          let base64 = new util.Base64Helper();
          let base64Data = base64.encodeSync(uint8Array);
          let dataURL = `image/jpeg;base64,${base64Data}`;
          let text_encode = new util.TextEncoder()
          let encodedData = base64.encodeSync(text_encode.encodeInto(dataURL))
          // JS 调用
          this.controller.runJavaScript(`set_song_image('${encodedData}')`);
        } catch {
          await this.loadDefaultImage()
          // 获取失败，返回空
          this.controller.runJavaScript(`set_song_image('')`);
        }

        // 释放资源（promise模式）。
        avMetadataExtractor.release();
        console.info(TAG, `release success.`);
      } catch (e) {
        console.error(TAG + `FetchMetadataFromFdSrcByPromise, code is ${e.code}, message is ${e.message}`);
        // 返回空信息
        this.controller.runJavaScript(`set_song_title(['${this.fileName}', '未知艺术家'])`)
        this.controller.runJavaScript(`set_song_image('')`);
      }
    }
  }

  // audio注册 / 注销
  async avSetupAudio() {
    // 通过UIAbilityContext的resourceManager成员的getRawFd接口获取媒体资源播放地址。
    // 返回类型为{fd,offset,length},fd为HAP包fd地址，offset为媒体资源偏移量，length为播放长度。
    if (this.context == undefined) return;
    // 如果是外置模式
    let avFileDescriptor: media.AVFileDescriptor = { fd: 0 };
    try {
      if (this.playing_mode) {
        const tmp_fd = fs.openSync(this.fileName).fd;
        avFileDescriptor = {fd: tmp_fd, offset: 0, length: fs.statSync(tmp_fd).size}
      } else {
        // 内置模式
        let fileDescriptor = await this.context.resourceManager.getRawFd('example_music/' + this.fileName);
        avFileDescriptor = { fd: fileDescriptor.fd, offset: fileDescriptor.offset, length: fileDescriptor.length }
      }
    } catch (error) {
      console.error(`未知错误：${error}`)
    }

    if (this.avPlayer) {
      console.info(`${this.tag}: init avPlayer release2createNew`);
      await this.avPlayer.release();
      console.log("资源清除完成.")
    }
    // 创建avPlayer实例对象
    this.avPlayer = await media.createAVPlayer();

    // 更新元数据
    if (this.playing_mode) {
      await this.get_storage_metadata();
    } else {
      await this.get_example_metadata();
    }

    // 创建状态机变化回调函数
    await this.setAVPlayerCallback((avPlayer: media.AVPlayer) => {
      this.percent = avPlayer.width / avPlayer.height;
      this.setVideoWH();
      this.durationTime = this.getDurationTime();
    });

    // 为fdSrc赋值触发initialized状态机上报
    this.avPlayer.fdSrc = avFileDescriptor;

    // 创建av_session
    this.avs_reg_session();

  }
  async reset_all_setting() {
    if (this.avPlayer) {
      console.log('暂停')
      // 暂停
      try {
        await this.avPlayer.pause();
      } catch {}
      console.log('重置进度条')
      // 重置进度条
      await this.avPlayer.reset();
      console.log('完成！');
    }
    // 重设进度条
    this.durationTime = 0;
    this.currentTime = 0;
  }

  // 播放 / 暂停 / 跳转 / 上一首 / 下一首
  avPlay(): void {
    console.log('$接收播放')
    if (this.avPlayer) {
      try {
        this.avPlayer.play();
      } catch (e) {
        console.error(`${this.tag}: avPlay = ${JSON.stringify(e)}`);
      }
    }
  }
  avPause(): void {
    if (this.avPlayer) {
      try {
        this.avPlayer.pause();
        console.info(`${this.tag}: avPause==`);
      } catch (e) {
        console.error(`${this.tag}: avPause== ${JSON.stringify(e)}`);
      }
    }
  }
  async avSeek(seekTime: number): Promise<void> {
    if (this.avPlayer) {
      try {
        console.info(`${this.tag}: videoSeek  seekTime== ${seekTime}`);
        this.avPlayer.seek(seekTime, 2);
        this.currentTime = seekTime;
      } catch (e) {
        console.error(`${this.tag}: videoSeek== ${JSON.stringify(e)}`);
      }
    }
  }
  async last_song() {
    // 判断播放模式
    if (this.playing_mode) {
      // 外置模式
      console.log('外置模式')
      // 如果是头
      if (this.list_reg <= 0) {
        console.log('到达头端')
        // 跳转到末端
        this.list_reg = this.storage_list.length - 1
      } else {
        console.log('上一首')
        // -1
        this.list_reg -= 1
      }
      // 重置播放器
      console.log('重置播放器')
      await this.reset_all_setting()
      // 设置播放源
      console.log('注册播放器')
      this.fileName = this.storage_list[this.list_reg]
      // 注册新播放器
      await this.avSetupAudio();
      // 播放
      console.log('完成')
      this.avPlay()
    } else {
      // 内置模式
      console.log('内置模式')
      // 如果是头
      if (this.list_reg <= 0) {
        console.log('到达头端')
        // 跳转到末端
        this.list_reg = this.example_list.length - 1
      } else {
        console.log('上一首')
        // -1
        this.list_reg -= 1
      }
      // 重置播放器
      console.log('重置播放器')
      await this.reset_all_setting()
      // 设置播放源
      console.log('注册播放器')
      this.fileName = this.example_list[this.list_reg]
      // 注册新播放器
      await this.avSetupAudio();
      // 播放
      console.log('完成')
      this.avPlay()
    }
  }
  async next_song() {
    // 判断播放模式
    if (this.playing_mode) {
      // 外置模式
      console.log('外置模式')
      // 如果是末尾
      if (this.list_reg >= this.storage_list.length - 1) {
        console.log('到达末端')
        // 计数器重置0
        this.list_reg = 0
      } else {
        console.log('下一首')
        // +1
        this.list_reg += 1
      }
      // 重置播放器
      console.log('重置播放器')
      await this.reset_all_setting()
      // 设置播放源
      console.log('注册播放器')
      this.fileName = this.storage_list[this.list_reg]
      // 注册新播放器
      await this.avSetupAudio();
      // 播放
      console.log('完成')
      this.avPlay()
    } else {
      // 内置模式
      console.log('内置模式')
      // 如果是末尾
      if (this.list_reg >= this.example_list.length - 1) {
        console.log('到达末端')
        // 计数器重置0
        this.list_reg = 0
      } else {
        console.log('下一首')
        // +1
        this.list_reg += 1
      }
      // 重置播放器
      console.log('重置播放器')
      await this.reset_all_setting()
      // 设置播放源
      console.log('注册播放器')
      this.fileName = this.example_list[this.list_reg]
      // 注册新播放器
      await this.avSetupAudio();
      // 播放
      console.log('完成')
      this.avPlay()
    }
  }

  // 注册avplayer回调函数
  async setAVPlayerCallback(callback: (avPlayer: media.AVPlayer) => void, vType?: number): Promise<void> {
    // seek操作结果回调函数
    if (this.avPlayer == null) {
      console.error(`${this.tag}: avPlayer has not init!`);
      return;
    }
    this.avPlayer.on('seekDone', (seekDoneTime) => {
      console.info(`${this.tag}: setAVPlayerCallback AVPlayer seek succeeded, seek time is ${seekDoneTime}`);
    });
    this.avPlayer.on('speedDone', (speed) => {
      console.info(`${this.tag}: setAVPlayerCallback AVPlayer speedDone, speed is ${speed}`);
    });
    // error回调监听函数,当avPlayer在操作过程中出现错误时调用reset接口触发重置流程
    this.avPlayer.on('error', (err) => {
      console.error(`${this.tag}: setAVPlayerCallback Invoke avPlayer failed ${JSON.stringify(err)}`);
      if (this.avPlayer == null) {
        console.error(`${this.tag}: avPlayer has not init on error`);
        return;
      }
      this.avPlayer.reset();
    });
    // 状态机变化回调函数
    this.avPlayer.on('stateChange', async (state, reason) => {
      if (this.avPlayer == null) {
        console.info(`${this.tag}: avPlayer has not init on state change`);
        return;
      }
      switch (state) {
        case 'idle': // 成功调用reset接口后触发该状态机上报
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state idle called.`);
          break;
        case 'initialized': // avplayer 设置播放源后触发该状态上报
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state initialized called.`);
          if (this.surfaceId) {
            this.avPlayer.surfaceId = this.surfaceId; // 设置显示画面，当播放的资源为纯音频时无需设置
            console.info(`${this.tag}: setAVPlayerCallback this.avPlayer.surfaceId = ${this.avPlayer.surfaceId}`);
            this.avPlayer.prepare();
          }
          break;
        case 'prepared': // prepare调用成功后上报该状态机
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state prepared called.`);
          this.avPlayer.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
            console.info(`${this.tag}: bufferingUpdate called, infoType value: ${infoType}, value:${value}}`);
          })
          this.durationTime = this.avPlayer.duration;
          this.currentTime = this.avPlayer.currentTime;
          this.avPlayer.play(); // 调用播放接口开始播放
          callback(this.avPlayer);
          break;
        case 'playing': // play成功调用后触发该状态机上报
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state playing called.`);
          // 更新一次avs元数据
          this.avs_get_metadata();
          if (this.count !== 0) {
            if (this.intervalID != -1) {
              clearInterval(this.intervalID)
            }
            this.intervalID = setInterval(() => { // 更新当前时间
              AppStorage.setOrCreate('durationTime', this.durationTime);
              AppStorage.setOrCreate('currentTime', this.currentTime);
            }, 100);
            let eventDataTrue: emitter.EventData = {
              data: {
                'flag': true
              }
            };
            let innerEventTrue: emitter.InnerEvent = {
              eventId: 2,
              priority: emitter.EventPriority.HIGH
            };
            emitter.emit(innerEventTrue, eventDataTrue);
          } else {
            console.info('AVPlayer playing wait to pause');
            this.avPlayer?.pause(); // 播放3s后调用暂停接口暂停播放。
          }
          this.count++;
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state completed called.`);
          let eventDataFalse: emitter.EventData = {
            data: {
              'flag': false
            }
          };
          let innerEvent: emitter.InnerEvent = {
            eventId: 1,
            priority: emitter.EventPriority.HIGH
          };
          emitter.emit(innerEvent, eventDataFalse);
          if (this.intervalID != -1) {
            clearInterval(this.intervalID)
          }
          this.avPlayer.off('bufferingUpdate')
          AppStorage.setOrCreate('currentTime', this.durationTime);
          // 如果是最后一首，则暂停
          if (this.playing_mode) {
            // 如果未达到末端
            if (this.list_reg < this.storage_list.length - 1) {
              // 下一首
              this.controller.runJavaScript('click_next()')
            }
          } else {
            // 如果未达到末端
            if (this.list_reg < this.example_list.length - 1) {
              // 下一首
              this.controller.runJavaScript('click_next()')
            }
          }
          break;
        case 'released':
          console.info(`${this.tag}: setAVPlayerCallback released called.`);
          break
        case 'stopped':
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state stopped called.`);
          break
        case 'error':
          console.error(`${this.tag}: setAVPlayerCallback AVPlayer state error called.`);
          break
        case 'paused':
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state paused called.`);
          break
        default:
          console.info(`${this.tag}: setAVPlayerCallback AVPlayer state unknown called.`);
          break;
      }
    });
    // 时间上报监听函数
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.currentTime = time;
    });
  }

  // 界面类 进后台，进前台，被kill
  onPageHide() {
    console.log('进入后台了')
  }
  onPageShow() {
    console.log('进前台了！')
    emitter.on(innerEventTrue, (res: emitter.EventData) => {
      if (res.data) {
        this.isPaused = res.data.flag;
        this.controller.runJavaScript(`set_button_status(${this.isPaused})`)
        this.XComponentFlag = res.data.flag;
      }
    });
    emitter.on(innerEventFalse, (res: emitter.EventData) => {
      if (res.data) {
        this.isPaused = res.data.flag;
        this.controller.runJavaScript(`set_button_status(${this.isPaused})`)
      }
    });
    emitter.on(innerEventWH, (res: emitter.EventData) => {
      if (res.data) {
        this.windowWidth = res.data.width;
        this.windowHeight = res.data.height;
        this.setVideoWH();
      }
    });
  }
  aboutToDisappear() {
    if (this.avPlayer == null) {
      console.info(`${this.tag}: avPlayer has not init aboutToDisappear`);
      return;
    }
    this.avPlayer.release((err) => {
      if (err == null) {
        console.info(`${this.tag}: videoRelease release success`);
      } else {
        console.error(`${this.tag}: videoRelease release failed, error message is = ${JSON.stringify(err.message)}`);
      }
    });
    emitter.off(innerEventFalse.eventId);
  }

  // 音量面板UI组件
  @Builder
  CreateAVVolumePanel() {
    AVVolumePanel({
      volumeLevel: this.audio_volume,
      volumeParameter: {
        position: {
          x: this.volume_panel_location,
          y: this.volume_panel_location
        }
      }
    })
  }

  // 未研究的石山不要动
  aboutToAppear() {
    this.windowWidth = display.getDefaultDisplaySync().width;
    this.windowHeight = display.getDefaultDisplaySync().height;
    this.surfaceW = this.windowWidth * SURFACE_W;
    this.surfaceH = this.surfaceW / SURFACE_H;
    this.context = getContext(this) as common.UIAbilityContext;
  }
  setVideoWH(): void {
    if (this.percent >= 1) { // 横向视频
      this.surfaceW = Math.round(this.windowWidth * PROPORTION);
      this.surfaceH = Math.round(this.surfaceW / this.percent);
    } else { // 纵向视频
      this.surfaceH = Math.round(this.windowHeight * PROPORTION);
      this.surfaceW = Math.round(this.surfaceH * this.percent);
    }
  }
  @Builder
  CoverXComponent() {
    XComponent({
      // 装载视频容器
      id: 'xComponent',
      type: XComponentType.SURFACE,
      controller: this.xComponentController
    })
      .id('VideoView')
      .visibility(this.XComponentFlag ? Visibility.Visible : Visibility.Hidden)
      .height(`${this.surfaceH}px`)
      .width(`${this.surfaceW}px`)
  }

  // 这里开始是UI界面
  build() {
    Column() {
      Column() {
        this.CoverXComponent()
        this.CreateAVVolumePanel()
      }
      .width(0)
      .height(0)
      Web({
        src: $rawfile("webview_gui/index.html"),
        controller: this.controller
      })
      // 在这里添加构建
        .onControllerAttached(() => {

          // 注册长时任务
          this.reg_bg_audio();
          // 扫描示例歌曲
          this.scan_example_audio();

          // 注册框架
          this.surfaceId = this.xComponentController.getXComponentSurfaceId();
          // 注册webview
          try {
            // 注册js函数接口
            this.controller.registerJavaScriptProxy(
              {

                // 播放 / 暂停
                song_play: () => {
                  this.isPaused = !this.isPaused;
                  if (this.isPaused) {
                    console.log('手动修改：播放')
                    // 改变状态播放
                    this.avPlay();
                  } else{
                    // 改变状态暂停
                    console.log('手动修改：暂停')
                    this.avPause();
                  };
                  this.controller.runJavaScript(`set_button_status(${this.isPaused})`);
                },
                // 进度条更改
                change_times: (play_range: string) => {
                  this.avSeek(parseInt(play_range));
                },
                // 获取内置音乐列表
                get_example_audio: () => {
                  // 把列表丢过去
                  return this.example_list
                },
                // 更改播放音乐(内置音乐)
                change_example_songs: async (name: string) => {
                  // 更改模式
                  this.playing_mode = false
                  // 查询列表
                  try {
                    const tmp = this.example_list.indexOf(name);
                    // 设置序号
                    this.list_reg = tmp;
                  } catch {
                    // 找不到，那没办法了，自动调0
                    this.list_reg = 0;
                  }
                  console.log('重置播放器')
                  // 重置播放器
                  await this.reset_all_setting()
                  console.log('设置播放源头')
                  // 设置播放源
                  this.fileName = this.example_list[this.list_reg]
                  console.log('注册播放器')
                  // 注册新播放器
                  await this.avSetupAudio();
                  console.log('完成，跳转...')
                  // 跳转
                  this.controller.runJavaScript('back_to_play()');
                  // 播放
                  this.avPlay()
                },
                // 添加外部音频
                local_add: async () => {
                  // 创建选择容器
                  const audioSelectOptions = new picker.AudioSelectOptions();
                  const audioPicker = new picker.AudioViewPicker();
                  // 选择
                  await audioPicker.select(audioSelectOptions).then((audioSelectResult: Array<string>) => {
                    if (audioSelectResult.length != 0) {
                      console.log(`音频选择结果（路径）: ${audioSelectResult}`)
                      this.storage_list = audioSelectResult;
                    } else {
                      console.log('音频选择取消。')
                    }
                  })
                },
                // 获取外部音乐列表
                get_storage_audio: () => {
                  console.log('获取数据。')
                  console.log(`${this.storage_list}`)
                  try {
                    // 处理音频（获取音频名）
                    let tmp: string[] = [];
                    for (const i of this.storage_list) {
                      try {
                        tmp.push(fs.openSync(i).name)
                      } catch (e) {
                        console.log(`读取失败：${e}`)
                      }
                    }
                    // 列表存一份
                    this.storage_list_name = tmp;
                    // 检查如果长度不一肯定有问题
                    if (this.storage_list.length != this.storage_list_name.length) {
                      console.error("??列表长度不一高度不一")
                      console.error(`storage_list: ${this.storage_list}`)
                      console.error(`storage_list_name: ${this.storage_list_name}`)
                    }
                    // 把列表丢过去
                    return tmp;
                  } catch {
                    return [];
                  }
                },
                // 更改播放音乐(外部音乐)
                change_storage_songs: async (name: string) => {
                  // 更改模式
                  this.playing_mode = true
                  // 查询列表
                  try {
                    const tmp = this.storage_list_name.indexOf(name);
                    // 设置序号
                    this.list_reg = tmp;
                  } catch {
                    this.list_reg = 0;
                  }
                  console.log('重置播放器')
                  // 重置播放器
                  await this.reset_all_setting()
                  console.log('设置播放源头')
                  // 设置播放源
                  this.fileName = this.storage_list[this.list_reg]
                  console.log(`选择了：${this.list_reg}, ${this.fileName}`)
                  console.log('注册播放器')
                  // 注册新播放器
                  await this.avSetupAudio();
                  console.log('完成，跳转...')
                  // 跳转
                  this.controller.runJavaScript('back_to_play()');
                  // 播放
                  this.avPlay()
                },
                // 上一首
                last_song: async () => {
                  await this.last_song();
                },
                // 下一首
                next_song: async () => {
                  await this.next_song();
                },
                // 我要更改音量了
                change_voice_frame: (status: boolean) => {
                  this.audio_volume_change = status;
                },
                // 更改音量
                change_voice_volume: (volume: string) => {
                  let tmp = parseInt(volume);
                  console.log(`音量: ${tmp}`);
                  this.audio_volume = tmp;
                  this.CreateAVVolumePanel();
                },

              },
              "arkts",
              [
                "song_play", "change_times", 'get_example_audio', 'change_example_songs', 'last_song', 'next_song',
                "local_add", "get_storage_audio", "change_storage_songs", "change_voice_frame", "change_voice_volume",
              ]
            )

            // 控制js函数
            setInterval(() => {
              this.controller.runJavaScript(`set_song_playing(['${this.timeConvert(this.currentTime)}', '${this.timeConvert(this.durationTime)}', ${this.currentTime}, ${this.durationTime}])`)
            }, 50);
            // 更新avs
            setInterval(() => {
              this.avs_get_playing()
            }, 500)

          } catch (error) {
            console.error(`Error Code: ${error}.`)
          }
        })
        .onPageBegin(event => {
          console.log("Page loading started.");
        })
        .onPageEnd(() => {
          // 监听音量
          this.listen_system_volume();
          // 载入0号内置歌曲
          this.fileName = this.example_list[0]
          this.avSetupAudio();
          console.log("Page loading end. Welcome!");
        })
        .zoomAccess(false)
    }
  }
}
