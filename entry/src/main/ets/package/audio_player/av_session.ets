//
// AV Session框架
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { avSession } from '@kit.AVSessionKit'
import { log } from '../system_function';

//////////////////
// 导入自创建模块 //
////////////////

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
export class av_session {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  ///////////
  // 变量池 //
  //////////

  ////////
  // 类 //
  ///////
  private session: avSession.AVSession | null = null; // 元音频

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////
  // 函数头 //
  private seek?: (position: number) => void
  private change_play_mode?: (type: string) => void
  private last_song?: () => void
  private play?: (status: boolean) => void
  private next_song?: () => void
  private like?: () => void

  // 注册机 //
  set_callback(
    seek?: (position: number) => void,
    change_play_mode?: (type: string) => void,
    last_song?: () => void,
    play?: (status: boolean) => void,
    next_song?: () => void,
    like?: () => void
  ) {
    this.seek = seek
    this.change_play_mode = change_play_mode
    this.last_song = last_song
    this.play = play
    this.next_song = next_song
    this.like = like
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 初始化 //
  async start_up() {
    // 创建AVSession
    log('创建avs')
    this.session = await avSession.createAVSession(getContext(this), 'ArkMusic', 'audio')
    // 注册行为
    log('注册行为')
    this.session.on("play", () => {this.play?.(true)})  // 播放
    this.session.on("pause", () => {this.play?.(false)})  // 暂停
    this.session.on("setLoopMode", (position) => {console.log(`播放模式：${position}`)})
    this.session.on("playPrevious", () => {console.log('0'); this.last_song?.()}) // 上一首
    this.session.on("playNext", () => {this.next_song?.()}) //下一首
    this.session.on("seek", (position) => {this.seek?.(position)})  // 跳转
    this.session.on("toggleFavorite", () => {this.like?.()})
    // this.session.on("playFromAssetId", (position) => {console.log(`跳转第${position}首`)})
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

  // 设置标题 / 歌手 //
  set_title(id: number, title: string, artist: string) {
    this.session?.setAVMetadata({ assetId: `${id}`, title: title, artist: artist })
  }
  // 设置封面 //
  set_image(id: number, image: PixelMap) {
    this.session?.setAVMetadata({ assetId: `${id}`, mediaImage: image })
  }
  // 设置歌词 //
  set_lrc(id: number, lrc: string) {
    this.session?.setAVMetadata({ assetId: `${id}`, lyric: lrc })
  }
  // 更新总时长 //
  set_duration_time(id: number, time: number) {
    this.session?.setAVMetadata({ assetId: `${id}`, duration: time })
  }
  // 更新播放时间 //
  set_current_time(time: number) {
    this.session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })
  }

  // 设置播放状态 //
  set_play_status(status: boolean) {
    if (status) {
      this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
    } else {
      this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
    }
  }
  // 设置喜欢 //
  set_like(status: boolean) {
    this.session?.setAVPlaybackState({ isFavorite: status })
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor() {}


}