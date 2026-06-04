//
// 音频播放器
// 广播频段：7
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 环境准备 //
////////////

// 导入第三方库 //
import emitter from '@ohos.events.emitter'
import { avSession } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice } from '../system_function'
import { save_array, load_array } from '../array_save_load'
import { get_image, get_meta } from '../meta_manager'

// 导入类 //
import { class_global_config } from '../class_global_config'
import { class_av_player } from './by_av_player'
import { class_ffmpeg_player } from './by_ffmpeg_player'

// 变量池 //
const audio_player_path = getContext().filesDir + '/audio_player/'    // 音频播放器目录
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']   // dsd格式集

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数集 //
//////////

// 毫秒 转化 分:秒
function ms_to_times(duration: number): string {
  const minutes = Math.floor(duration / 60)
  const seconds = Math.floor(duration % 60)
  const formattedDuration = `${minutes}:${seconds.toString().padStart(2, '0')}`
  return formattedDuration
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class class_audio_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //
  private player_ready = false
  player_mode: boolean = false    // 播放器使用 ( F：官方播放器 T：星铃播放器 )
  play_list: string[] = []    // 播放列表
  play_list_index: number = 0   // 播放列表指针
  play_status: string = 'pause'   // 播放状态
  current_time: number = 0    // 已播放时间
  play_mode: number = 2   // 播放模式 ( 0：单曲循环 1：列表循环 2：列表停止 3：随机 )
  private like_list: string[] = []    // 喜欢列表
  like_list_path: string[] = [] // 喜欢列表（路径备份）
  is_like: boolean = false    // 是否喜欢
  private failed_count: number = 0    // 播放失败计数
  private target_timed: number = 0    // 定时时间戳
  timed_mode: boolean = false // 定时模式（ T：最后一首歌放完模式 F：直接停止 ）
  private dsd_list = new Map<string, string>

  // 类 //
  global_config: class_global_config | null = null
  private av_session: avSession.AVSession | null = null; // 元音频
  private av_player = new class_av_player()   // 官方av_player播放器
  private ffmpeg_player = new class_ffmpeg_player()   // 星铃播放器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 播放完成 //
  private complete(next: boolean = true) {

    // 如果完成了说不放了那就不管 //
    if (!next) {return}

    // 计时器处理 //
    if ((this.timed_mode) && (this.target_timed != 0)) {

      // 计时到了 //
      if (this.target_timed <= Date.now()) {
        this.target_timed = 0
        notice('计时器暂停了音乐 ╮(′～‵〞)╭')
        return
      }

    }

    // 重复模式（单曲循环）
    if (this.play_mode == 0) {
      this.set_audio()
    }
    // 其他模式
    else {
      this.next()
    }

  }

  // 定时器（自动线程） //
  private async timing() {
    setInterval(() => {

      // 若有定时任务 //
      if ((!this.timed_mode) && (this.target_timed != 0)) {

        // 计时到了 //
        if (this.target_timed <= Date.now()) {
          this.target_timed = 0
          this.pause()
          notice('计时器暂停了音乐 ╮(′～‵〞)╭')
        }

      }

      // 计时器定时发送 //
      this.send_timing()

    }, 1)
  }

  // 保存配置文件 //
  save_data() {

    // 保存播放列表 //
    save_array(this.play_list, audio_player_path + '/play_list.json')

    // 保存其他数据 //
    save_array([
      `${this.player_mode}`,        // 播放器模式
      `${this.play_list_index}`,    // 播放指针
      `${this.current_time}`,  // 已播放时间
      `${this.play_mode}`,          // 播放模式
      `${this.timed_mode}`,         // 计时器模式
    ], audio_player_path + '/audio_player.json')

    log('数据保存完成.')

  }

  // 打开配置文件 //
  async load_data() {

    log('加载播放数据')

    // 载入播放列表 //
    for (const i of load_array(audio_player_path + '/play_list.json')) {
      // 有效性检查 //
      try {fs.openSync(i)} catch {continue}
      this.play_list.push(i)
    }

    // 载入喜欢列表 //
    for (const i of load_array(audio_player_path + '/like.json')) {
      // 有效性检查 //
      try {this.like_list.push(`${fs.statSync(fs.openSync(i).fd).ino}`)} catch {continue}
      this.like_list_path.push(i)
    }
    // 列表返载
    save_array(this.like_list_path, audio_player_path + '/like.json')

    // 打开其他数据 //
    const tmp = load_array(audio_player_path + '/audio_player.json')
    // 设置
    if (tmp.length != 0) {

      // 配置环境 //
      this.player_mode = (tmp[0] == 'true') ? true : false
      this.play_list_index = Number.parseInt(tmp[1])
      this.send_play_mode(Number.parseInt(tmp[3]))
      this.timed_mode = (tmp[4] == 'true') ? true : false

      // 载入歌曲 //
      this.set_audio()
      // 等待完成/超时1s强制进入
      let tmp_count = 0
      while ((!this.player_ready) && (tmp_count <= 1000)) {
        await new Promise<void>(resolve => setTimeout(resolve, 1))
        tmp_count++
      }

      // 跳转 //
      this.seek(Number.parseInt(tmp[2]))

    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////

  // 官方播放器回调 //
  private player_callback() {

    // 准备就绪提示 //
    const set_player_ready = () => {this.player_ready = true}
    // 播放状态更新 //
    const play_status_update = (status: string) => {this.send_play_status(status)}
    // 播放进度更新 //
    const current_time_update = (time: number) => {this.send_current_time(time)}

    // 官方播放器注册 //
    this.av_player.set_callback(set_player_ready, play_status_update, current_time_update)
    // 风铃播放器注册 //
    this.ffmpeg_player.set_callback(set_player_ready, play_status_update, current_time_update)

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 广播函数 //
  ////////////

  // 7x2 元数据广播 //
  private async send_metadata(path: string) {

    // 获取元数据 //
    const tmp = await get_meta(path)
    // 获取专辑封面 //
    const tmp_image = await get_image(path)

    if (tmp[0].length != 0) {

      // 广播 //
      emitter.emit({ eventId: 712 }, {data: {
        file_name: tmp[0][0],
        title: tmp[1][0],
        artist: tmp[1][1],
        duration: tmp[0][6],
        duration_format: tmp[0][7],
        image: tmp_image
      }})
      emitter.emit({ eventId: 722 }, {data: {
        file_name: tmp[0][0],
        title: tmp[1][0],
        artist: tmp[1][1],
        duration: tmp[0][6],
        duration_format: tmp[0][7],
        image: tmp_image
      }})

      // 更新元音频 //
      this.av_session?.setAVMetadata({
        assetId: '0',
        title: tmp[1][0],
        artist: tmp[1][1],
        mediaImage: tmp_image,
        duration: Number.parseInt(tmp[0][6])
      })

    }

  }

  // 7x3 播放时间广播 //
  private send_current_time(time: number) {

    // 更新本地数据 //
    this.current_time = time

    // 广播 //
    emitter.emit({ eventId: 713 }, { data: { current_time: time, current_time_format: ms_to_times(time) } })
    emitter.emit({ eventId: 723 }, { data: { current_time: time, current_time_format: ms_to_times(time) } })

    // 更新元音频 //
    this.av_session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })

  }

  // 7x4 列表广播 //
  private send_play_list() {
    emitter.emit({ eventId: 714 }, { data: { play_list: this.play_list, index: this.play_list_index } })
    emitter.emit({ eventId: 724 }, { data: { play_list: this.play_list, index: this.play_list_index } })
  }

  // 7x5 列表广播（单指针） //
  private send_play_list_index() {
    emitter.emit({ eventId: 714 }, { data: { index: this.play_list_index } })
    emitter.emit({ eventId: 724 }, { data: { index: this.play_list_index } })
  }

  // 7x6 播放状态广播 //
  private send_play_status(status: string) {

    // 更新数据 //
    this.play_status = status

    // 广播状态 //
    emitter.emit({ eventId: 716 }, { data: { status: status } })
    emitter.emit({ eventId: 726 }, { data: { status: status } })

    // 更新元音频 //
    if (status == 'playing') {
      this.av_session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
    } else if (status == 'pause') {
      this.av_session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
    } else if (status == 'complete') {
      this.av_session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
    }

  }

  // 7x7 喜欢状态广播 //
  private send_check_like(path: string) {
    try {

      // 读取检查 //
      const tmp = this.like_list.includes(`${fs.statSync(fs.openSync(path).fd).ino}`)

      // 更新 //
      this.is_like = tmp

      // 广播 //
      emitter.emit({ eventId: 717 }, { data: { like: tmp } })
      emitter.emit({ eventId: 727 }, { data: { like: tmp } })

      // 元音频更新 //
      this.av_session?.setAVPlaybackState({ isFavorite: tmp })

    } catch {}
  }

  // 7x8 完整歌词广播 //
  private send_lyric() {}

  // 7x9 单句歌词广播 //
  private send_lyric_row() {}

  // 7x0 定时广播 //
  private send_timing() {
    if (this.target_timed == 0) {return}
    emitter.emit({ eventId: 710 }, { data: { time: this.target_timed - Date.now() } })
  }

  // 7x1 播放模式广播 //
  private send_play_mode(mode: number) {
    this.play_mode = mode
    emitter.emit({ eventId: 711 }, { data: { play_mode: this.play_mode } })
    emitter.emit({ eventId: 721 }, { data: { play_mode: this.play_mode } })
    if (this.play_mode === 0) {
      log('播放模式切换：单曲循环.')
      this.av_session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SINGLE})
      if (this.player_ready) {notice('单曲循环')}
    }
    else if (this.play_mode === 1) {
      log('播放模式切换：列表循环')
      this.av_session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_LIST})
      if (this.player_ready) {notice('列表循环')}
    }
    else if (this.play_mode === 2) {
      log('播放模式切换：列表停止')
      this.av_session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SEQUENCE})
      if (this.player_ready) {notice('列表停止')}
    }
    else if (this.play_mode === 3) {
      log('播放模式切换：随机')
      this.av_session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SHUFFLE})
      if (this.player_ready) {notice('随机')}
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 点歌 //
  async set_audio(index: number = this.play_list_index, auto_start: boolean = this.player_ready): Promise<boolean> {

    // 修正指针 //
    this.play_list_index = index
    this.send_play_list_index()

    let tmp_path = ''
    // 获取路径（防溢出检测） //
    try {tmp_path = this.play_list[index]} catch {return false}

    // 载入播放 //
    let tmp_result: boolean
    // 星铃播放器
    if (this.player_mode) {tmp_result = await this.ffmpeg_player.set_audio(tmp_path, auto_start)}
    // 官方播放器
    else {tmp_result = await this.av_player.audio_set(tmp_path, auto_start)}

    // 成功处理 //
    if (tmp_result) {

      this.send_metadata(tmp_path)
      this.send_check_like(tmp_path)

    }
    // 未成功处理 //
    else {

      log(`${tmp_path} 播放失败.`, 'error')
      this.failed_count++
      // 超过3首停止
      if (this.failed_count >= 3) {
        this.failed_count = 0
        notice(`怎么失败这么多次 ΩДΩ 罢工了！`)
        if (index == this.play_list_index) {
          this.complete(false)
        }
      } else {
        notice(`歌曲加载失败了 (੭ ᐕ)੭？ 1s后切换下一首.`)
        setTimeout(() => {
          if (index == this.play_list_index) {
            this.complete()
          }
        }, 1000)
      }

    }

    // 返回结果 //
    return tmp_result

  }
  // 载入播放列表 //
  set_play_list(list: string[], index: number, auto_start: boolean = true) {

    // 载入 //
    this.play_list = list
    this.play_list_index = index

    // 广播 //
    this.send_play_list()

    // 载入歌曲 //
    this.set_audio(index, auto_start)

  }

  // 播放 //
  playing() {
    if (this.play_list.length == 0) {return}
    if (this.player_mode) {this.ffmpeg_player.playing()} else {this.av_player.set_play_status(true)}
  }
  // 暂停 //
  pause() {
    if (this.play_list.length == 0) {return}
    if (this.player_mode) {this.ffmpeg_player.pause()} else {this.av_player.set_play_status(false)}
  }
  // 上一首 //
  previous() {

    // 防0检测 //
    if (this.play_list.length == 0) {return}

    // 随机模式
    if (this.play_mode == 3) {

      // 防1死锁 //
      if (this.play_list.length == 1) {this.set_audio(); return}

      // 随机抽取 //
      let random_index = 0
      while (true) {
        random_index = Math.floor(Math.random() * this.play_list.length)
        if (random_index == this.play_list_index) { continue } else { break }
      }

      // 播放 //
      this.set_audio(random_index)

    }
    // 其他模式
    else {

      // 末尾检查
      if (this.play_list_index == 0) {
        notice('重新回到末尾啦！(ゝ∀･)')
        this.set_audio(this.play_list.length - 1)
      } else {
        this.set_audio(this.play_list_index - 1)
      }

    }


  }
  // 下一首 //
  next() {

    // 防0检测 //
    if (this.play_list.length == 0) {return}

    // 随机模式
    if (this.play_mode == 3) {

      // 防1死锁 //
      if (this.play_list.length == 1) {this.set_audio(); return}

      // 随机抽取 //
      let random_index = 0
      while (true) {
        random_index = Math.floor(Math.random() * this.play_list.length)
        if (random_index == this.play_list_index) { continue } else { break }
      }

      // 播放 //
      this.set_audio(random_index)

    }
    // 其他模式
    else {

      // 末尾检查
      if (this.play_list_index == this.play_list.length - 1) {
        this.set_audio(0)
        notice('回到开头啦！_(:3 ⌒ﾞ)_')
      } else {
        this.set_audio(this.play_list_index + 1)
      }

    }
  }
  // 更改进度 //
  seek(time: number) {
    if (this.play_list.length == 0) {return}
    if (this.player_mode) {this.ffmpeg_player.seek(time)} else {this.av_player.audio_seek(time)}
  }

  // 歌曲排序交换 //
  switch_songs(index_a: number, index_b: number) {

    // 防溢出检测 //
    try {
      this.play_list[index_a]
      this.play_list[index_b]
    } catch {return}

    // 交换两个位置的歌曲 //
    const tmp = this.play_list[index_a]
    this.play_list[index_a] = this.play_list[index_b]
    this.play_list[index_b] = tmp

    // 指针修正 //
    if (this.play_list_index === index_a) {
      this.play_list_index = index_b
    } else if (this.play_list_index === index_b) {
      this.play_list_index = index_a
    }

    // 广播 //
    this.send_play_list()

  }
  // 歌曲删除 //
  delete_songs(index: number) {

    // 防溢出检测 //
    try {this.play_list[index]} catch {return}

    // 移除歌曲 //
    this.play_list.splice(index, 1)

    // 指针修正 //
    if (index < this.play_list_index) {
      // 删除了当前指针之前的歌曲，指针前移 //
      this.play_list_index--
    } else if (index === this.play_list_index) {
      // 删除了正在播放的歌曲 //
      // 如果删除后指针超出列表，移到末尾 //
      if (this.play_list_index >= this.play_list.length) {
        this.play_list_index = this.play_list.length - 1
      }
      // 列表非空则切换播放 //
      if (this.play_list.length > 0) {
        this.set_audio()
        return
      }
    }

    // 广播 //
    this.send_play_list()

  }
  // 设置播放模式 //
  set_play_mode(index: number) {
    this.send_play_mode(index)
  }
  // 更改歌曲喜欢 //
  toggle_like() {
    try {

      // 获取ino //
      const tmp = `${fs.statSync(fs.openSync(this.play_list[this.play_list_index]).fd).ino}`

      // 扫描判断 //
      const index = this.like_list.findIndex(item => item === tmp)
      if (index !== -1) {
        log('取消喜欢.')
        this.like_list.splice(index, 1)
        this.like_list_path.splice(index, 1)
      } else {
        log('喜欢❤~')
        notice('(*´∀`)~♥')
        this.like_list.push(tmp)
        this.like_list_path.push(this.play_list[this.play_list_index])
      }

      // 广播 //
      this.send_check_like(this.play_list[this.play_list_index])

      // 保存 //
      save_array(this.like_list_path, audio_player_path + '/like.json')

    } catch {}
  }
  // 设置定时 //
  set_timing(time_ms: number) {this.target_timed = Date.now() + time_ms}
  // 设置播放器模式 //
  set_player_mode(mode: boolean) {

  }



  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////

  // av_session初始化 //
  async avs_start_up() {

    // 创建AVSession //
    log('创建av_session')
    this.av_session = await avSession.createAVSession(getContext(this), 'LinMusic', 'audio')

    // 注册行为 //
    log('av_session注册行为')
    this.av_session.on("play", () => {this.playing()})  // 播放
    this.av_session.on("pause", () => {this.pause()})  // 暂停
    this.av_session.on("setLoopMode", (position) => {
      if (position === 0) {this.set_play_mode(3)}
      else if (position === 1) {this.set_play_mode(2)}
      else if (position === 2) {this.set_play_mode(0)}
      else if (position === 3) {this.set_play_mode(1)}
    })  // 播放模式设置
    this.av_session.on("playPrevious", () => {this.previous()}) // 上一首
    this.av_session.on("playNext", () => {this.next()}) //下一首
    this.av_session.on("seek", (position) => {this.seek(position)})  // 跳转
    this.av_session.on("toggleFavorite", () => {this.toggle_like()})
    this.av_session.on("answer", () => {console.log('avs:接听电话')})
    this.av_session.on("hangUp", () => {console.log('avs:挂断电话')})
    this.av_session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})

    // 初始化 //
    await this.av_session.setAVMetadata({
      assetId: '0',
      title: '未知歌曲',
      artist: '未知歌手',
    })
    // 激活会话 //
    await this.av_session.activate()
    log('av_session激活完成')
  }

  constructor() {

    // 检测工作目录 //
    try {fs.statSync(audio_player_path)} catch {fs.mkdirSync(audio_player_path)}

    // 启动定时器 //
    this.timing()
    // 注册回调 //
    this.player_callback()
    // 注册元音频 //
    this.avs_start_up()
    // 加载数据 //
    this.load_data()
    // 就绪 //
    log('音频管理器就绪.')

  }

}