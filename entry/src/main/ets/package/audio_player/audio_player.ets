//
// 音频播放器
// 广播频段：7
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import emitter from '@ohos.events.emitter'
import { avSession } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
////////////////
import { av_player } from './by_av_player'
import { log, notice } from '../system_function'
import { get_image, get_meta } from '../meta_manager'

///////////
// 变量池 //
//////////
const root_path = getContext().filesDir   // 工作目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// string[]转json储存（覆盖） //
export async function array_to_json_save(data: string[], path: string): Promise<boolean> {

  try {fs.rmdirSync(path)} catch {}

  // 转换
  const packData = JSON.stringify(data)

  // 保存
  try {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, packData)
    fs.closeSync(file)
  } catch (e) {
    log(`保存文件失败: ${e}`, 'error')
    return false
  }

  return true

}
// json读取转string[] //
export function read_json_to_array(path: string): string[] {

  try {
    console.log(path)
    let json: string = fs.readTextSync(path)

    const parsed = JSON.parse(json) as string[]

    // 校验：必须是数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组")
    }

    const result: string[] = []

    // 遍历每个元素，确保是字符串
    for (let i = 0; i < parsed.length; i++) {
      const element = parsed[i]
      if (typeof element !== 'string') {
        throw new Error("JSON 格式错误：数组元素必须是字符串")
      }
      result.push(element)
    }

    return result

  } catch (e) {
    log(`读取文件失败: ${e}`, 'error')
    return []
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class audio_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //
  private play_list: string[] = []    // 播放列表
  private play_list_index: number = 0   // 播放列表指针
  private player_choice: number = 0   // 播放器使用 ( 0：avplayer播放器 1：ffmpeg播放器 )
  private play_mode: number = 2   // 播放模式 ( 0：单曲循环 1：列表循环 2：列表停止 3：随机 )
  private like_list: string[] = []    // 喜欢列表
  like_list_path: string[] = [] // 喜欢列表（路径备份）

  // 类 //
  private session: avSession.AVSession | null = null; // 元音频
  private av_player = new av_player()   // 官方av_player播放器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // av_session专用 //
  ///////////////////

  // 初始化 //
  async avs_start_up() {
    // 创建AVSession
    log('创建avs')
    this.session = await avSession.createAVSession(getContext(this), 'ArkMusic', 'audio')
    // 注册行为
    log('注册行为')
    this.session.on("play", () => {this.playing()})  // 播放
    this.session.on("pause", () => {this.pause()})  // 暂停
    this.session.on("setLoopMode", (position) => {console.log(`播放模式：${position}`); })
    this.session.on("playPrevious", () => {this.last_song()}) // 上一首
    this.session.on("playNext", () => {this.next_song()}) //下一首
    this.session.on("seek", (position) => {this.seek(position)})  // 跳转
    this.session.on("toggleFavorite", () => {this.toggle_like()})
    this.session.on("playFromAssetId", (position) => {console.log(`跳转第${position}首`)})
    this.session.on("answer", () => {console.log('avs:接听电话')})
    this.session.on("hangUp", () => {console.log('avs:挂断电话')})
    this.session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})
    // 初始化
    await this.session.setAVMetadata({
      assetId: '-1',
      title: '未知歌曲',
      artist: '未知歌手',
    })
    // 激活会话
    await this.session.activate()
    log('avs激活完成')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 元数据获取发送 //
  private async send_meta(path: string) {
    // 获取基础元数据
    const tmp = await get_meta(path)
    // 获取封面
    const tmp_img = await get_image(path)
    // 广播
    if (tmp) {emitter.emit({ eventId: 712 }, { data: {
      name: tmp[0][0],
      title: tmp[1][0],
      artist: tmp[1][1],
      image: tmp_img
    } })}
    // 同步av_session
    this.session?.setAVMetadata({ assetId: '0', title: tmp[1][0], artist: tmp[1][1] })
    this.session?.setAVMetadata({ assetId: '0', mediaImage: tmp_img })

  }

  // 喜欢检测 //
  private async check_like(path: string) {

    try {

      // 读取
      const tmp = `${fs.statSync(fs.openSync(path).fd).ino}`

      // 扫描判断
      const index = this.like_list.findIndex(item => item === tmp)
      if (index === -1) {
        emitter.emit({ eventId: 717 }, { data: { like: false } })
        this.session?.setAVPlaybackState({ isFavorite: false })
      } else {
        emitter.emit({ eventId: 717 }, { data: { like: true } })
        this.session?.setAVPlaybackState({ isFavorite: true })
      }

    } catch {}

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////

  // 播放器回调 //
  private player_callback() {

    // 播放状态更新 //
    const play_status_update = (status: string) => {
      // 广播状态
      emitter.emit({ eventId: 714 }, { data: { status: status } })
      // 更新AVSession
      if (status == 'playing') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
      } else if (status == 'pause') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
      } else if (status == 'complete') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
        // 如果不是末尾，那就下一首
        if (this.play_list_index < this.play_list.length - 1) {
          this.next_song()
        } else {
          notice('最后一首播放完了哦！ξ( ✿＞◡❛)')
        }
      }
    }
    // 总时长更新 //
    const duration_time_update = (duration: number) => {
      // 广播 //
      emitter.emit({ eventId: 715 }, { data: { duration_time: duration } })
      // 更新时长 //
      this.session?.setAVMetadata({ assetId: '0', duration: duration })
    }
    // 播放进度更新 //
    const current_time_update = (current: number) => {
      // 广播 //
      emitter.emit({ eventId: 716 }, { data: { current_time: current } })
      // 更新时长 //
      this.session?.setAVPlaybackState({ position: { elapsedTime: current, updateTime: new Date().getTime() } })
    }

    // av_player注册 //
    this.av_player.set_callback(play_status_update, duration_time_update, current_time_update)

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 播放歌曲 //
  async set_audio_play(song_index: number = this.play_list_index) {
    if (song_index != this.play_list_index) { this.play_list_index = song_index }
    // 广播序号
    emitter.emit({ eventId: 718 }, { data: { list: [], index: this.play_list_index } })
    // 使用官方播放器
    if (this.player_choice == 0) {
      console.log(this.play_list[this.play_list_index])
      const result = await this.av_player.audio_set(this.play_list[this.play_list_index])
      // 加载失败，报错
      if (!result[0]) {
        log(`歌曲加载失败：${result[1]}`, 'error')
        notice(`歌曲加载失败了 (੭ ᐕ)੭？ ：${result[1]}，3s后切换下一首.`)
        setTimeout(() => {
          emitter.emit({ eventId: 714 }, { data: { status: 'complete' } })
        }, 3000)
      } else {
        // 发送元数据
        this.send_meta(this.play_list[song_index])
        // 更改歌曲喜欢
        this.check_like(this.play_list[song_index])
      }
    }
  }

  // 设置播放列表（初始化） //
  set_play_list(list: string[], index: number) {
    // 设置
    this.play_list = list
    this.play_list_index = index
    // 广播列表
    emitter.emit({ eventId: 718 }, { data: { list: this.play_list, index: this.play_list_index } })
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
  // 跳转指定歌曲 //
  seek_song(index: number) {
    // 如果超出了那不管
    if (index < 0 || index >= this.play_list.length) { return }
    // 点歌
    this.set_audio_play(index)
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
  update_play_list_index(list_index: number[]) {}

  // 更改歌曲喜欢 //
  toggle_like() {

    try {

      // 读取
      const tmp = `${fs.statSync(fs.openSync(this.play_list[this.play_list_index]).fd).ino}`

      // 扫描判断
      const index = this.like_list.findIndex(item => item === tmp)
      if (index !== -1) {
        log('取消喜欢.')
        this.like_list.splice(index, 1)
        this.like_list_path.splice(index, 1)
        this.session?.setAVPlaybackState({ isFavorite: false })
        emitter.emit({ eventId: 717 }, { data: { like: false } })
      } else {
        log('喜欢❤~')
        this.like_list.push(tmp)
        this.like_list_path.push(this.play_list[this.play_list_index])
        this.session?.setAVPlaybackState({ isFavorite: true })
        emitter.emit({ eventId: 717 }, { data: { like: true } })
      }

      // 保存
      array_to_json_save(this.like_list_path, root_path + '/my_like.json')


    } catch {}

  }

  // 输出喜欢列表 //
  get_like_list_path(): string[] {return this.like_list_path}

  // 重置喜欢列表 //
  reset_like_list() {
    this.like_list = []
    this.like_list_path = []
    array_to_json_save([], root_path + '/my_like.json')
  }

  // 销毁 //
  drop_it() {
    // 销毁av_player
    this.av_player.drop_it()
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor() {
    // 注册回调
    this.player_callback()
    // 注册元音频
    this.avs_start_up()
    // 读取like列表
    const tmp = read_json_to_array(root_path + '/my_like.json')
    if (tmp.length != 0) {
      for (const i of tmp) {
        try {
          const tmp_ino = `${fs.statSync(fs.openSync(i).fd).ino}`
          this.like_list.push(tmp_ino)
          this.like_list_path.push(i)
        } catch {}
      }
    } else {this.reset_like_list()}
    // 就绪
    log('音频管理器就绪.')
  }

}