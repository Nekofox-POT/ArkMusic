//
// 音频处理器
// 广播频段：8
// 81x:转发元数据
// 82x:播报播放列表和序号
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { common } from '@kit.AbilityKit'
import emitter from '@ohos.events.emitter'
import { avSession } from '@kit.AVSessionKit'

//////////////////
// 导入自创建模块 //
/////////////////
import { av_player } from './by_av_player'
import { log, notice } from '../system_function'

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class audio_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  ///////////
  // 变量池 //
  //////////
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext   // 身份证记录
  private play_list: string[] = []    // 播放列表
  private play_list_index: number = 0   // 播放列表指针
  private player_choice: number = 0   // 播放器使用 ( 0：avplayer播放器 )
  private play_mode: number = 2   // 播放模式 ( 0：单曲循环 1：列表循环 2：列表停止 3：随机 )
  private random_record: number[] = []    // 随机模式记录表
  private random_record_index: number = 0   // 随机模式记录表 - 指针

  ////////
  // 类 //
  ///////
  private av_player = new av_player()   // 官方av_player播放器
  private session: avSession.AVSession | null = null; // 元音频

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  /////////////
  // 广播监听 //
  ////////////
  private async listen_broadcast() {
    // 元数据监听 //
    emitter.on({ eventId: 710 }, (eventData: emitter.EventData) => {
      // 转发
      emitter.emit({ eventId: 810 }, { data: eventData.data })
      // 载入
      this.session?.setAVMetadata({
        assetId: `${this.play_list_index}`,
        title: eventData.data?.title,
        artist: eventData.data?.artist,
        mediaImage: eventData.data?.img
      })
    })
    // 播放状态监听 //
    emitter.on({ eventId: 712 }, (eventData: emitter.EventData) => {
      // 转发
      emitter.emit({ eventId: 812 }, { data: eventData.data })
      if (eventData.data?.status == 'playing') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
      } else if (eventData.data?.status == 'pause') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
      } else if (eventData.data?.status == 'complete') {
        // 如果不是末尾，那就下一首
        if (this.play_list_index < this.play_list.length - 1) {
          this.set_audio_play(this.play_list_index + 1)
        } else {
          notice('最后一首播放完了哦！ξ( ✿＞◡❛)')
        }
      }
    })
    // 音频总时长监听 //
    emitter.on({ eventId: 713 }, (eventData: emitter.EventData) => {
      // 转发
      emitter.emit({ eventId: 813 }, { data: eventData.data })
      this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, duration: eventData.data?.duration_time })
    })
    // 音频播放时长监听 //
    emitter.on({ eventId: 714 }, (eventData: emitter.EventData) => {
      // 转发
      emitter.emit({ eventId: 814 }, { data: eventData.data })
      this.session?.setAVPlaybackState({ position: { elapsedTime: eventData.data?.current_time, updateTime: new Date().getTime() } })
    })
  }

  /////////////
  // 广播列表 //
  ////////////
  private send_play_list(play_list: string[][] = [], play_number: number = 0) {
    // 发送广播
    emitter.emit(
      { eventId: 820 },
      { data: {
        play_list: play_list,
        play_number: play_number
      } }
    )
  }

  // 元音频 //
  private async reg_session() {
    // 创建session。
    this.session = await avSession.createAVSession(this.context, 'ArkMusic', 'audio')
    await this.session.activate()
    // 注册播放器行为
    this.session.on("play", () => {this.playing()})  // 播放
    this.session.on("pause", () => {this.pause()})  // 暂停
    this.session.on("playPrevious", () => {this.last_song()}) // 上一首
    this.session.on("playNext", () => {this.next_song()}) //下一首
    this.session.on("seek", (position) => {this.seek(position)})  // 跳转
    this.session.on("answer", () => {console.log('avs:接听电话')})
    this.session.on("hangUp", () => {console.log('avs:挂断电话')})
    this.session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})
    // 初始化
    await this.session.setAVMetadata({
      assetId: '-1',
      title: '未知歌曲',
      artist: '未知歌手',
    })
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 设置播放跳转 //
  async set_audio_play(song_index: number = this.play_list_index) {
    if (song_index != this.play_list_index) { this.play_list_index = song_index }
    // 使用官方播放器
    if (this.player_choice == 0) {
      const result = await this.av_player.audio_set(this.play_list[song_index])
      // 加载失败，报错
      if (!result[0]) {
        log(`歌曲加载失败：${result[1]}`, 'error')
        notice(`歌曲加载失败了 (੭ ᐕ)੭？ ：${result[1]}，3s后切换下一首`)
        setTimeout(() => {
          if (song_index == this.play_list_index) {
            emitter.emit({ eventId: 712 }, { data: { status: 'complete' } })
          }
        }, 3000)
      }
    }
  }

  // 设置播放列表（初始化） //
  set_play_list(list: string[][], index: number) {
    // 提取歌曲目录
    let tmp: string[] = []
    for (let i = 0; i < list.length; i++) {
      tmp.push(list[i][0])
    }
    // 设置
    this.play_list = tmp
    this.play_list_index = index
    this.random_record = []
    // 广播列表
    this.send_play_list(list, index)
    // 初始化（播放）
    this.set_audio_play()
  }

  // 播放 //
  playing() {
    if (this.play_list.length == 0) { return }
    this.av_player.set_play_status(true)
  }
  // 暂停 //
  pause() {
    if (this.play_list.length == 0) { return }
    this.av_player.set_play_status(false)
  }

  // 上一首 //
  last_song() {
    // 如果列表空直接不理
    if (this.play_list.length == 0) { return }
    // 单曲循环模式
    if (this.play_mode == 0) {
      // 直接继续播放
      this.set_audio_play()
    }
    // 随机模式
    else if (this.play_mode == 3) {
      // 随机抽取
      let random_index = 0
      while (true) {
        random_index = Math.floor(Math.random() * this.play_list.length)
        if (random_index == this.play_list_index) { continue } else { break }
      }
      // 播放
      this.set_audio_play(random_index)
    }
    // 其他两个
    else {
      // 末尾检查
      if (this.play_list_index == 0) {
        notice('重新回到末尾啦！(ゝ∀･)')
        this.set_audio_play(this.play_list.length - 1)
      } else {
        this.set_audio_play(this.play_list_index - 1)
      }
    }
  }
  // 下一首 //
  next_song() {
    // 如果列表空直接不理
    if (this.play_list.length == 0) { return }
    // 单曲循环模式
    if (this.play_mode == 0) {
      // 直接继续播放
      this.set_audio_play()
    }
    // 随机模式
    else if (this.play_mode == 3) {
      // 随机抽取
      let random_index = 0
      while (true) {
        random_index = Math.floor(Math.random() * this.play_list.length)
        if (random_index == this.play_list_index) { continue } else { break }
      }
      // 播放
      this.set_audio_play(random_index)
    }
    // 其他两个
    else {
      // 末尾检查
      if (this.play_list_index == this.play_list.length - 1) {
        this.set_audio_play(0)
        notice('回到开头啦！_(:3 ⌒ﾞ)_')
      } else {
        this.set_audio_play(this.play_list_index + 1)
      }
    }
  }

  // 更改播放进度 //
  seek(time: number) {
    this.av_player.audio_seek(time)
  }

  // 读取播放列表 //
  get_play_list(): [number, string[]] {
    return [this.play_list_index, this.play_list]
  }

  // 更新播放列表排序 //
  update_play_list_index(list_index: number[]): [number, string[]] {
    try {
      // 遍历循环 //
      let tmp: string[] = []
      list_index.forEach((item, index) => {
        tmp.push(this.play_list[item])
        if (item == this.play_list_index) {
          this.play_list_index = index
        }
      })
      this.play_list = tmp
    } catch {}
    return this.get_play_list()
  }

  // 销毁 //
  drop_it() {
    // 销毁av_player
    this.av_player.drop_it()
    // 销毁监听
    emitter.off(710)
    emitter.off(712)
    emitter.off(713)
    emitter.off(714)
  }


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor(context_input: common.UIAbilityContext) {
    log('音频管理器就绪.')
    // 记录身份证
    this.context = context_input
    // 注册元音频
    this.reg_session()
    // 设置广播监听
    this.listen_broadcast()
  }

}