//
// 音频处理器
// 广播频段：7
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import media from '@ohos.multimedia.media'
import { avSession } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import emitter from '@ohos.events.emitter'

//////////////////
// 导入自创建模块 //
/////////////////

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
export class av_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  ///////////
  // 变量池 //
  //////////
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext   // 身份证记录
  private allow_auto_play: boolean = false  // 载入后自动播放 (防止第一次打开自动播放)
  private song_id: string = '0'   // 歌曲id

  ////////
  // 类 //
  ///////
  private avPlayer: media.AVPlayer | null = null; // audio播放
  private session: avSession.AVSession | null = null; // 元音频

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 广播元数据 //
  private send_metadata(song_name: string, title: string, artist: string, img: image.PixelMap | null) {
    // 发送广播
    emitter.emit(
      { eventId: 710 },
      { data: {
        song_name: song_name,
        title: title,
        artist: artist,
        img: img
      } }
    )
  }
  // 广播播放状态 //
  private send_play_status(msg: string) {
    // 发送广播
    emitter.emit(
      { eventId: 712 },
      { data: {
        status: msg
      } }
    )
  }
  // 广播歌曲时长 //
  private send_duration_time(duration_time: number) {
    emitter.emit(
      { eventId: 713 },
      { data: {
        duration_time: duration_time
      } }
    )
  }
  // 广播播放时长 //
  private send_current_time(current_time: number) {
    // 发送广播
    emitter.emit(
      { eventId: 714 },
      { data: {
        current_time: current_time
      } }
    )
  }

  // 设置元音频 //
  private async reg_session() {
    // 创建session。
    this.session = await avSession.createAVSession(this.context, 'ArkMusic', 'audio')
    await this.session.activate()
    // 注册播放器行为
    this.session.on("play", () => {this.avPlayer?.play()})  // 播放
    this.session.on("pause", () => {this.avPlayer?.pause()})  // 暂停
    // this.session.on("playPrevious", () => {this.ark_music_ui.runJavaScript('post_last_song()')}) // 上一首
    // this.session.on("playNext", () => {this.ark_music_ui.runJavaScript('post_next_song()')}) //下一首
    this.session.on("seek", (position) => {this.avPlayer?.seek(position)})  // 跳转
    this.session.on("answer", () => {console.log('avs:接听电话')})
    this.session.on("hangUp", () => {console.log('avs:挂断电话')})
    this.session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})
    // 初始化
    await this.session.setAVMetadata({
      assetId: '-1',
      title: '未知歌曲',
      artist: '未知歌手',
    });
  }

  // 获取音频元数据 //
  private async get_meta(file: fs.File): Promise<[string, string, image.PixelMap | null]> {
    // 创建对象
    let avMetadataExtractor = await media.createAVMetadataExtractor();
    avMetadataExtractor.fdSrc = file;
    // 获取元数据。
    let meta_data = await avMetadataExtractor.fetchMetadata();
    let song_title = meta_data.title ?? file.name
    let song_artist = meta_data.artist ?? '未知艺术家'
    // 获取专辑封面
    let meta_img: image.PixelMap | null = null
    try {
      meta_img = await avMetadataExtractor.fetchAlbumCover()
    } catch {
      // 使用默认封面
      const resourceManager = getContext(this).resourceManager
      const mediaData = await resourceManager.getMediaContent($r('app.media.CD'))
      const imageSource = image.createImageSource(mediaData.buffer)
      meta_img = await imageSource.createPixelMap()
    }
    // 释放
    avMetadataExtractor.release();
    // 输出
    return [song_title, song_artist, meta_img]
  }

  // audio监听回调 //
  private async set_av_player_callback(callback: (avPlayer: media.AVPlayer) => void) {
    // 添加保险
    if (!this.avPlayer) { return; }
    // 状态机变化（主）
    this.avPlayer.on('stateChange', async (state: string) => {
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
          this.avPlayer.seek(0);
          if (this.allow_auto_play) {
            this.avPlayer.play();
          } else {
            this.allow_auto_play = true
          }
          break;
        case 'playing': // audio播放
          console.log('audio正在播放~')
          this.send_play_status('playing')
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
          break;
        case 'paused':  // audio暂停
          console.log('audio暂停了！')
          this.send_play_status('pause')
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.log('audio播放完了。')
          this.send_play_status('complete')
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
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
      this.send_play_status('pause')
    });
    // 错误处理
    this.avPlayer.on('error', (e) => {
      console.error(`audio发生错误：${e}`);
      // 重置
      this.avPlayer?.reset();
    });
    // 总时长更新
    this.avPlayer.on('durationUpdate', (time: number) => {
      this.session?.setAVMetadata({ assetId: this.song_id, duration: time })
      this.send_duration_time(time)
    });
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })
      this.send_current_time(time)
    });
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 音频设置 //
  async audio_set(path: string, index: number): Promise<[boolean, string]> {
    try {
      // 检查文件源
      const file = fs.openSync(path)
      // 更新id
      this.song_id = `${index}`
      // 创建av_player
      if (this.avPlayer) { await this.avPlayer.release() }
      this.avPlayer = await media.createAVPlayer()
      // 获取音频元数据
      const meta = await this.get_meta(file)
      // 设置元音频
      this.session?.setAVMetadata({ assetId: this.song_id, title: meta[0], artist: meta[1], mediaImage: meta[2] })
      // 设置回调
      await this.set_av_player_callback(() => {})
      // 设置播放源
      this.avPlayer.fdSrc = { fd: file.fd, offset: 0, length: fs.statSync(file.fd).size }
      // 广播
      this.send_metadata(file.name, meta[0], meta[1], meta[2])
      // 返回
      return [true, '']
    } catch (e) {
      // 文件读取失败
      return [false, `${e}`]
    }
  }

  // 播放/暂停 //
  set_play_status(status: boolean) {
    if (status) {
      this.avPlayer?.play()
    } else {
      this.avPlayer?.pause()
    }
  }

  // 调节时间 //
  audio_seek(time: number) {
    this.avPlayer?.seek(time)
  }

  // 销毁 //
  drop_it() {
    this.avPlayer?.release()
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor(context_input: common.UIAbilityContext) {
    // 记录身份证
    this.context = context_input
    // 注册音频
    this.reg_session()
  }

}