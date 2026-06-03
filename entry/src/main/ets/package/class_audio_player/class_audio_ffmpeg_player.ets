//
// 音频播放器（ffmpeg_player 核心）
// 广播频段：7
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 导入第三方库 //
/////////////////
import emitter from '@ohos.events.emitter'
import { avSession } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
/////////////////
import nativeModule from 'libentry.so'
import { log, notice } from '../system_function'
import { array_to_json_save, load_json_to_array } from '../array_save_load'
import { get_image, get_meta } from '../meta_manager'

////////////
// 导入类 //
///////////
import { class_global_config } from '../class_global_config'

////////////
// 变量池 //
//////////
const audio_player_path = getContext().filesDir + '/audio_player/'    // 音频播放器目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class class_audio_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  ///////////
  // 变量池 //
  //////////
  private player_ready = false
  private failed_count = 0  // 失败计数
  play_list: string[] = []    // 播放列表
  play_list_index: number = 0   // 播放列表指针
  private play_mode: number = 2   // 播放模式 ( 0：单曲循环 1：列表循环 2：列表停止 3：随机 )
  private current_backup: number = 0  // 播放时长备份
  private like_list: string[] = []    // 喜欢列表
  like_list_path: string[] = [] // 喜欢列表（路径备份）
  timed: number = 0   // 目标时间戳（毫秒）
  is_timed: boolean = false // 是否开启定时
  private wait_end: boolean = false // 是否等待当前歌曲播放完再停止
  private timer_interval: number = -1 // 定时器轮询ID

  ////////
  // 类 //
  ///////
  global_config: class_global_config | null = null
  private session: avSession.AVSession | null = null; // 元音频

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
    this.session.on("setLoopMode", (position) => {
      if (position === 0) {this.set_play_mode(3)}
      else if (position === 1) {this.set_play_mode(2)}
      else if (position === 2) {this.set_play_mode(0)}
      else if (position === 3) {this.set_play_mode(1)}
    })  // 播放模式设置
    this.session.on("playPrevious", () => {this.last_song()}) // 上一首
    this.session.on("playNext", () => {this.next_song()}) //下一首
    this.session.on("seek", (position) => {this.seek(position)})  // 跳转
    this.session.on("toggleFavorite", () => {this.toggle_like()})
    this.session.on("answer", () => {console.log('avs:接听电话')})
    this.session.on("hangUp", () => {console.log('avs:挂断电话')})
    this.session.on("toggleCallMute", async () => {console.log('通话静音或解除静音')})
    // 初始化
    await this.session.setAVMetadata({
      assetId: '0',
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
    // tmp[0] = [文件名, 文件类型, 声道, 采样率, 位深, 比特率, 时长(分:秒), 时长(毫秒)]
    // tmp[1] = [标题, 歌手, 专辑, 专辑作家, 流派]
    const tmp = await get_meta(path)
    // 获取封面
    const tmp_img = await get_image(path)
    // 广播元数据
    if (tmp && tmp[0].length > 0) {emitter.emit({ eventId: 712 }, { data: {
      name: tmp[0][0],
      title: tmp[1][0],
      artist: tmp[1][1],
      image: tmp_img
    } })}
    // 同步av_session
    this.session?.setAVMetadata({ assetId: '0', title: tmp[1][0], artist: tmp[1][1] })
    this.session?.setAVMetadata({ assetId: '0', mediaImage: tmp_img })
    // 广播时长（毫秒取自 tmp[0][7]）
    const duration_ms = Number.parseInt(tmp[0][7])
    emitter.emit({ eventId: 715 }, { data: { duration_time: duration_ms } })
    this.session?.setAVMetadata({ assetId: '0', duration: duration_ms })
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

  // 播放器回调（注册到 ffmpeg_player 原生层） //
  private player_callback() {

    // 准备就绪回调
    nativeModule.register_ready_callback(() => {
      this.player_ready = true
    })
    // 播放状态回调
    nativeModule.register_status_callback((status: string) => {
      // 广播状态
      emitter.emit({ eventId: 714 }, { data: { status: status } })
      // 更新AVSession
      if (status == 'playing') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
      } else if (status == 'pause') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
      } else if (status == 'complete') {
        this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
        // 定时检查：等待播放完再停止
        if (this.is_timed && this.wait_end) {
          this.pause()
          this.end_timing()
          notice('当前歌曲播放完毕，睡眠定时结束。')
          return
        }
        // 如果不是末尾，那就下一首
        if ((this.play_list_index >= this.play_list.length - 1) && (this.play_mode === 2)) {
          notice('最后一首播放完了哦！ξ( ✿＞◡❛)')
        } else {
          this.next_song()
        }
      }
    })
    // 播放进度回调
    nativeModule.register_time_callback((current: number) => {
      // 定时检查（非等待播放完模式）
      if (this.is_timed && !this.wait_end && Date.now() >= this.timed) {
        this.pause()
        this.end_timing()
        notice('睡眠定时结束，已暂停播放。')
        return
      }
      // 广播
      emitter.emit({ eventId: 716 }, { data: { current_time: current } })
      // 更新时长
      this.session?.setAVPlaybackState({ position: { elapsedTime: current, updateTime: new Date().getTime() } })
      this.current_backup = current
    })

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 播放歌曲 //
  async set_audio_play(song_index: number = this.play_list_index) {
    if (song_index != this.play_list_index) { this.play_list_index = song_index }
    // 非0检测
    if (this.play_list.length == 0) { return }
    // 广播序号
    emitter.emit({ eventId: 718 }, { data: { list: [], index: this.play_list_index } })
    // 使用 ffmpeg_player 加载音频
    const result = await nativeModule.set_audio(this.play_list[this.play_list_index])
    // 加载失败，报错
    if (!result) {
      log(`歌曲加载失败: ${this.play_list[this.play_list_index]}`, 'error')
      notice(`歌曲加载失败了 (੭ ᐕ)੭？，切换下一首.`)
      this.failed_count += 1
      if (this.failed_count >= 3) {
        this.failed_count = 0
        notice(`失败太多次了，罢工了！ (੭ ᐕ)੭？`)
        this.pause()
        return
      } else {
        this.next_song()
      }
    } else {
      // 重置失败计数
      this.failed_count = 0
      // 发送元数据
      this.send_meta(this.play_list[song_index])
      // 更改歌曲喜欢
      this.check_like(this.play_list[song_index])
    }
  }

  // 设置播放列表（初始化） //
  async set_play_list(list: string[], index: number) {
    // 设置
    this.play_list = list
    this.play_list_index = index
    // 广播列表
    emitter.emit({ eventId: 718 }, { data: { list: this.play_list, index: this.play_list_index } })
    // 初始化（播放）
    await this.set_audio_play()
  }

  // 播放 //
  playing() {
    if (this.play_list.length == 0) { return }
    nativeModule.playing()
  }
  // 暂停 //
  pause() {
    if (this.play_list.length == 0) { return }
    nativeModule.pause()
  }
  // 跳转指定歌曲 //
  seek_song(index: number) {
    // 如果超出了那不管
    if (index < 0 || index >= this.play_list.length) { return }
    // 点歌
    this.set_audio_play(index)
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
    nativeModule.seek(time)
  }
  // 更改播放模式 //
  set_play_mode(index: number) {
    emitter.emit({ eventId: 713 }, { data: { play_mode: index } })
    this.play_mode = index
    if (index === 0) {
      log('单曲循环')
      this.session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SINGLE})
      if (this.player_ready) {notice('单曲循环')}
    }
    else if (index === 1) {
      log('列表循环')
      this.session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_LIST})
      if (this.player_ready) {notice('列表循环')}
    }
    else if (index === 2) {
      log('列表停止')
      this.session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SEQUENCE})
      if (this.player_ready) {notice('列表停止')}
    }
    else if (index === 3) {
      log('随机')
      this.session?.setAVPlaybackState({loopMode: avSession.LoopMode.LOOP_MODE_SHUFFLE})
      if (this.player_ready) {notice('随机')}
    }
  }

  // dsd缓存加载（ffmpeg_player 原生支持 DSD，此方法保留兼容） //
  load_dsd() {
    // ffmpeg_player 可直接解码 DSD，无需预转换缓存
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
      array_to_json_save(this.like_list_path, audio_player_path + '/my_like.json')


    } catch {}

  }
  // 重置喜欢列表 //
  reset_like_list() {
    this.like_list = []
    this.like_list_path = []
    array_to_json_save([], audio_player_path + '/my_like.json')
  }

  // 播放数据注入 //
  async play_data_load() {

    log('加载播放数据')
    // 打开配置文件
    let tmp = load_json_to_array(audio_player_path + '/playing_data_other.json')

    // 打开检查播放列表
    let tmp_list: string[] = []
    for (const i of load_json_to_array(audio_player_path + '/playing_data_list.json')) {
      try {
        fs.openSync(i)
        tmp_list.push(i)
      } catch {}
    }

    // 启动时设为不自动播放（等待手动播放或恢复位置）
    nativeModule.set_start_ready(false)

    // 加载基础数据
    this.set_play_mode(Number.parseInt(tmp[2] ?? '2'))
    // 加载播放列表
    if (tmp_list.length != 0) {
      // 防溢出
      if (Number.parseInt(tmp[0] ?? `${tmp_list.length}`) + 1 >= tmp_list.length) {
        await this.set_play_list(tmp_list, 0)
      } else {
        await this.set_play_list(tmp_list, Number.parseInt(tmp[0] ?? '0'))
        // set_audio 完成后 seek 到上次位置
        this.seek(Number.parseInt(tmp[1] ?? '0'))
      }
    } else {
      // 加载默认值
      await this.set_play_list([], 0)
    }
    // 之后的 set_audio 自动播放
    nativeModule.set_start_ready(true)
    // 设置每分钟保存数据定时
    setInterval(() => {this.play_data_save()}, 60000)

  }
  // 播放数据保存 //
  play_data_save() {
    if (!this.global_config?.reset) {
      // 保存播放列表
      array_to_json_save(this.play_list, audio_player_path + '/playing_data_list.json')
      // 保存其他元数据
      let tmp: string[] = [
        `${this.play_list_index}`,
        `${this.current_backup}`,
        `${this.play_mode}`
      ]
      array_to_json_save(tmp, audio_player_path + '/playing_data_other.json')
      log('数据保存完成.')
    }
  }

  // 销毁 //
  drop_it() {
    // 保存数据
    this.play_data_save()
    // 清除定时器
    this.clear_timer_interval()
    // ffmpeg_player 原生层会在 set_audio 新文件时自动清理旧资源，
    // 或在进程退出时由系统回收
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 定时功能 //
  /////////////

  // 设置定时 //
  start_timing(hours: number, minutes: number, waitEnd: boolean) {
    // 先清除旧定时器
    this.clear_timer_interval()
    const now = Date.now()
    this.timed = now + (hours * 60 + minutes) * 60 * 1000
    this.wait_end = waitEnd
    this.is_timed = true
    const totalSeconds = hours * 3600 + minutes * 60
    if (totalSeconds <= 0) {
      // 时间为 0 则立即停止
      this.pause()
      this.end_timing()
      notice('睡眠定时结束，已暂停播放。')
      return
    }
    if (waitEnd) {
      notice(`睡眠定时已开启，将在当前歌曲播放完毕后停止。`)
    } else {
      const h = Math.floor(totalSeconds / 3600)
      const m = Math.floor((totalSeconds % 3600) / 60)
      if (h > 0) {
        notice(`睡眠定时已开启：${h} 小时 ${m} 分钟后停止。`)
      } else {
        notice(`睡眠定时已开启：${m} 分钟后停止。`)
      }
      // 启动独立轮询定时器（不依赖播放回调，暂停时也能到点触发）
      this.timer_interval = setInterval(() => {
        if (!this.is_timed || this.wait_end) {
          this.clear_timer_interval()
          return
        }
        if (Date.now() >= this.timed) {
          this.pause()
          this.end_timing()
          notice('睡眠定时结束，已暂停播放。')
        }
      }, 1000)
    }
    // 广播定时状态到前端
    emitter.emit({ eventId: 719 }, { data: {
      timed: this.timed,
      is_timed: this.is_timed,
      wait_end: this.wait_end
    } })
  }

  // 清除轮询定时器 //
  private clear_timer_interval() {
    if (this.timer_interval !== -1) {
      clearInterval(this.timer_interval)
      this.timer_interval = -1
    }
  }

  // 取消定时 //
  end_timing() {
    if (this.is_timed) {
      notice('睡眠定时已取消。')
    }
    this.is_timed = false
    this.wait_end = false
    this.timed = 0
    this.clear_timer_interval()
    // 广播定时状态到前端
    emitter.emit({ eventId: 719 }, { data: {
      timed: 0,
      is_timed: false,
      wait_end: false
    } })
  }

  // 获取当前定时信息 //
  get_timing(): [number, number, number, boolean] {
    if (!this.is_timed) {
      return [0, 0, 0, false]
    }
    const remaining = Math.max(0, this.timed - Date.now())
    const totalSeconds = Math.floor(remaining / 1000)
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60
    return [hours, minutes, seconds, this.wait_end]
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // EQ/PEQ 接口 //
  ////////////////

  // 设置 EQ 模式（0=OFF, 1=GEQ, 2=PEQ）
  switch_eq(mode: number): void {
    nativeModule.switch_eq(mode)
  }

  // 获取当前 EQ 模式
  // 返回 0/1/2
  get_eq_mode(): number {
    return nativeModule.get_eq_mode()
  }

  // 设置 10 段 GEQ 增益（-12 ~ 12 dB）
  set_eq(gains: number[]): void {
    nativeModule.set_eq(gains)
  }

  // 设置 10 段 PEQ 参数 [[enabled, freq, gain, q, type], ...]
  set_peq(params: [boolean, number, number, number, number][]): void {
    nativeModule.set_peq(params)
  }

  // 获取当前 GEQ 增益值
  get_eq(): number[] {
    return nativeModule.get_eq()
  }

  // 获取当前 PEQ 参数
  get_peq(): [boolean, number, number, number, number][] {
    return nativeModule.get_peq()
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor(import_global_config: class_global_config) {

    // 导入类
    this.global_config = import_global_config

    // 检测工作目录
    try {fs.statSync(audio_player_path)} catch {fs.mkdirSync(audio_player_path)}

    // 注册回调（ffmpeg_player 原生层）
    this.player_callback()
    // 注册元音频
    this.avs_start_up()
    // 加载like表
    const tmp_like = load_json_to_array(audio_player_path + '/my_like.json')
    if (tmp_like.length != 0) {
      for (const i of tmp_like) {
        try {
          const tmp_ino = `${fs.statSync(fs.openSync(i).fd).ino}`
          this.like_list.push(tmp_ino)
          this.like_list_path.push(i)
        } catch {}
      }
    } else {this.reset_like_list()}
    // 就绪
    log('音频管理器就绪（ffmpeg_player）.')
  }

}