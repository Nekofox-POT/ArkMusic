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
import { save_array, load_array } from '../data_save_load'
import { get_image, get_meta } from '../meta_manager'

// 导入类 //
import class_global_config from '../class_global_config'
import { class_av_player } from './by_av_player'
import { class_ffmpeg_player } from './by_ffmpeg_player'

// 变量池 //
const audio_player_path = getContext().filesDir + '/audio_player/'    // 音频播放器目录
const dsd_cache_path = getContext().filesDir + '/audio_player/dsd_cache/'    // 音频播放器目录
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']   // dsd格式集

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数集 //
//////////

// 毫秒 转化 分:秒
function ms_to_times(duration: number): string {
  const minutes = Math.floor(duration / 60000)
  const seconds = Math.floor((duration % 60000) / 1000)
  const formattedDuration = `${minutes}:${seconds.toString().padStart(2, '0')}`
  return formattedDuration
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export default class class_audio_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //
  private player_ready = false
  private like_list: string[] = []    // 喜欢列表
  private failed_count: number = 0    // 播放失败计数
  private target_timed: number = 0    // 定时时间戳
  private writing: boolean = false    // 正在写入标识

  // 类 //
  global_config: class_global_config | null = null
  private av_session: avSession.AVSession | null = null; // 元音频
  private av_player = new class_av_player()   // 官方av_player播放器
  private ffmpeg_player = new class_ffmpeg_player()   // 星铃播放器

  // 共享变量池 //
  timed_mode: boolean = false // 定时模式（ T：最后一首歌放完模式 F：直接停止 ）
  play_list: string[] = []    // 播放列表
  play_list_index: number = 0   // 播放列表指针
  play_status: string = 'pause'   // 播放状态
  current_time: number = 0    // 已播放时间
  play_mode: number = 2   // 播放模式 ( 0：单曲循环 1：列表循环 2：列表停止 3：随机 )
  is_like: boolean = false    // 是否喜欢
  like_list_path: string[] = [] // 喜欢列表（路径备份）

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 歌曲初始化装载 //
  private async set_start_audio(list: string[], index: number, auto_start: boolean, time: number): Promise<boolean> {

    // 载入播放列表 //
    this.play_list = []
    for (const i of list) {

      // 有效性检查 //
      let tmp_ino: string = ''
      try {tmp_ino = `${fs.statSync(i).ino}`} catch {continue}

      // 官方播放器dsd检查 //
      if (support_dsd_format.includes(i.substring(i.lastIndexOf('.')).toLowerCase())) {
        if (this.global_config!.dsd_support) {
          // 检查是否有缓存
          try {fs.openSync(`${dsd_cache_path}/${tmp_ino}.wav`)} catch {
            // 没有，加入转码列表
            nativeModule.dsdToWav(i, `${dsd_cache_path}/${tmp_ino}.wav`)
          }
        } else {continue}
      }

      this.play_list.push(i)

    }

    // 载入歌曲 //
    if (this.play_list.length != 0) {

      // 载入指针 //
      if (list.length != 0) {this.play_list_index = (index >= this.play_list.length - 1) ? this.play_list.length - 1 : index}

      // 获取路径 //
      const tmp_path: string = this.play_list[index]
      const tmp_ino: string = `${fs.statSync(tmp_path).ino}`

      // 载入播放 //
      let tmp_result: boolean
      // 星铃播放器
      if (this.global_config!.player_mode) {tmp_result = await this.ffmpeg_player.set_audio(tmp_path, auto_start, time)}
      // 官方播放器
      else {
        // dsd检查
        if (support_dsd_format.includes(tmp_path.substring(tmp_path.lastIndexOf('.')).toLowerCase())) {
          if (this.global_config!.dsd_support) {
            // 检查是否有缓存
            try {fs.openSync(`${dsd_cache_path}/${tmp_ino}.wav`)} catch {
              // 没有，先转码
              notice('这首歌需要加载一下，请耐心等待^v^.')
              log('dsd 转码.')
              await nativeModule.dsdToWav(tmp_path, `${dsd_cache_path}/${tmp_ino}.wav`)
              log('转码完成')
              // 切歌了就退出
              if (index != this.play_list_index) {return false}
            }
            tmp_result = await this.av_player.audio_set(`${dsd_cache_path}/${tmp_ino}.wav`, auto_start, time)
          } else {tmp_result = false}
        }
        // 普通歌曲
        else {tmp_result = await this.av_player.audio_set(tmp_path, auto_start, time)}
      }

      // 成功处理 //
      if (tmp_result) {

        this.send_metadata()
        this.send_check_like()
        this.send_current_time(time)

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

    } else {return false}

  }

  // 播放完成处理 //
  private complete(next: boolean = true) {

    // 如果完成了说不放了那就不管 //log('播完了！')
    if (!next) {return}

    // 计时器处理 //
    if ((this.timed_mode) && (this.target_timed != 0)) {

      // 计时到了 //
      if (this.target_timed <= Date.now()) {
        this.target_timed = 0
        notice('计时器暂停了音乐 ╮(′～‵〞)╭')
        // 计时器定时发送 //
        this.send_timing()
        return
      }

    }

    // 重复模式（单曲循环）
    if (this.play_mode == 0) {
      this.set_audio()
    }
    // 列表停止模式
    else if (this.play_mode == 2) {
      if (this.play_list_index >= this.play_list.length - 1) {
        notice('最后一首播放完了哦！ξ( ✿＞◡❛)')
      } else {
        this.next()
      }
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
      if (this.target_timed != 0) {

        if (!this.timed_mode) {
          // 计时到了 //
          if (this.target_timed <= Date.now()) {
            this.target_timed = 0
            this.pause()
            notice('计时器暂停了音乐 ╮(′～‵〞)╭')
          }
        }

        // 计时器定时发送 //
        this.send_timing()

      }

    }, 1)
  }
  // 自动保存数据 //
  private async auto_save() {setInterval(async () => {this.save_data()}, 30000)}

  // 打开配置文件 //
  private async load_data(auto_start: boolean = false) {

    log('加载播放数据')

    // 打开播放列表 //
    const tmp_play_list = load_array(audio_player_path + '/play_list.json')

    // 载入喜欢列表 //
    for (const i of load_array(audio_player_path + '/like.json')) {
      // 有效性检查 //
      try {this.like_list.push(`${fs.statSync(i).ino}`)} catch {continue}
      this.like_list_path.push(i)
    }
    // 列表返载
    save_array(this.like_list_path, audio_player_path + '/like.json')

    // 打开其他数据 //
    const tmp = load_array(audio_player_path + '/audio_player.json')
    // 设置
    if (tmp.length != 0) {

      // 配置环境 //
      this.send_play_mode(Number.parseInt(tmp[2]))
      this.timed_mode = (tmp[3] == 'true') ? true : false

      // 载入歌曲 //
      this.set_start_audio(tmp_play_list, Number.parseInt(tmp[0]), auto_start, Number.parseInt(tmp[1]))
      // 等待完成/超时1s强制结束
      let tmp_count = 0
      while ((!this.player_ready) && (tmp_count <= 1000)) {
        await new Promise<void>(resolve => setTimeout(resolve, 1))
        tmp_count++
      }

    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////

  // 播放器回调 //
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
  private async send_metadata() {

    const path = this.play_list[this.play_list_index]

    // 获取元数据 //
    const tmp = await get_meta(path)
    // 获取专辑封面 //
    const tmp_image = await get_image(path)

    if (tmp[0].length != 0) {

      // 广播 //
      emitter.emit({ eventId: 712 }, { data: { meta: tmp, image: tmp_image } })
      emitter.emit({ eventId: 722 }, { data: { meta: tmp, image: tmp_image } })

      // 更新元音频 //
      this.av_session?.setAVMetadata({
        assetId: '0',
        title: tmp[1][0],
        artist: tmp[1][1],
        mediaImage: tmp_image[1],
        duration: Number.parseInt(tmp[0][7])
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
    emitter.emit({ eventId: 714 }, { data: { play_list: this.play_list } })
    emitter.emit({ eventId: 724 }, { data: { play_list: this.play_list } })
  }

  // 7x5 列表指针广播 //
  private send_play_list_index() {
    emitter.emit({ eventId: 715 }, { data: { index: (this.play_list.length == 0) ? 0 : this.play_list_index } })
    emitter.emit({ eventId: 725 }, { data: { index: (this.play_list.length == 0) ? 0 : this.play_list_index } })
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
      this.complete()
    }

  }

  // 7x7 播放模式广播 //
  private send_play_mode(mode: number) {
    this.play_mode = mode
    emitter.emit({ eventId: 717 }, { data: { play_mode: this.play_mode } })
    emitter.emit({ eventId: 727 }, { data: { play_mode: this.play_mode } })
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

  // 7x8 喜欢状态广播 //
  private send_check_like() {
    try {

      const path = this.play_list[this.play_list_index]

      // 读取检查 //
      const tmp = this.like_list.includes(`${fs.statSync(path).ino}`)

      // 更新 //
      this.is_like = tmp

      // 广播 //
      emitter.emit({ eventId: 718 }, { data: { like: tmp } })
      emitter.emit({ eventId: 728 }, { data: { like: tmp } })

      // 元音频更新 //
      this.av_session?.setAVPlaybackState({ isFavorite: tmp })

    } catch {}
  }

  // 7x9 定时广播 //
  private send_timing() {
    if (this.target_timed == 0) {
      emitter.emit({ eventId: 719 }, { data: { time: 0 } })
    } else {
      emitter.emit({ eventId: 719 }, { data: { time: this.target_timed - Date.now() } })
    }
  }

  // 7x0 完整歌词广播 //
  private send_lyric() {}

  // 7x1 单句歌词广播 //
  private send_lyric_row() {}



  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 保存配置文件 //
  save_data() {

    if (this.global_config!.reset) {return}
    if (this.writing) {return} else {this.writing = true}

    // 保存播放列表 //
    save_array(this.play_list, audio_player_path + '/play_list.json')

    // 保存其他数据 //
    save_array([
      `${this.play_list_index}`,  // 播放指针
      `${this.current_time}`,     // 已播放时间
      `${this.play_mode}`,        // 播放模式
      `${this.timed_mode}`,       // 计时器模式
    ], audio_player_path + '/audio_player.json')

    log('audio_player: 数据保存完成！')
    this.writing = false

  }

  // 重载配置文件 //
  async reset_data() {

    // 暂停 //
    this.pause(true)

    // 保存 //
    this.save_data()

    // 重新加载数据 //
    await this.load_data(true)

  }

  // 点歌 //
  async set_audio(index: number = this.play_list_index): Promise<boolean> {

    // 修正指针 //
    this.play_list_index = index
    this.send_play_list_index()

    let tmp_path: string = ''
    let tmp_ino: string = ''
    // 获取路径（防溢出检测） //
    try {
      tmp_path = this.play_list[index]
      tmp_ino = `${fs.statSync(tmp_path).ino}`
    } catch {return false}

    // 载入播放 //
    let tmp_result: boolean
    // 星铃播放器
    if (this.global_config!.player_mode) {tmp_result = await this.ffmpeg_player.set_audio(tmp_path)}
    // 官方播放器
    else {
      // dsd检查
      if (support_dsd_format.includes(tmp_path.substring(tmp_path.lastIndexOf('.')).toLowerCase())) {
        if (this.global_config!.dsd_support) {
          // 检查是否有缓存
          try {fs.openSync(`${dsd_cache_path}/${tmp_ino}.wav`)} catch {
            // 没有，先转码
            notice('这首歌需要加载一下，请耐心等待^v^.')
            log('dsd 转码.')
            await nativeModule.dsdToWav(tmp_path, `${dsd_cache_path}/${tmp_ino}.wav`)
            log('转码完成')
            // 切歌了就退出
            if (index != this.play_list_index) {return false}
          }
          tmp_result = await this.av_player.audio_set(`${dsd_cache_path}/${tmp_ino}.wav`)
        } else {tmp_result = false}
      }
      // 普通歌曲
      else {tmp_result = await this.av_player.audio_set(tmp_path)}
    }

    // 成功处理 //
    if (tmp_result) {

      this.send_metadata()
      this.send_check_like()

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
  async set_play_list(list: string[], index: number) {

    // 0溢事件 //
    if (list.length <= 0) {return}

    // 载入播放列表 //
    this.play_list = []
    for (const i of list) {

      // 有效性检查 //
      let tmp_ino: string = ''
      try {tmp_ino = `${fs.statSync(i).ino}`} catch {continue}

      // 官方播放器dsd检查 //
      if (support_dsd_format.includes(i.substring(i.lastIndexOf('.')).toLowerCase())) {
        if (this.global_config!.dsd_support) {
          // 检查是否有缓存
          try {fs.openSync(`${dsd_cache_path}/${tmp_ino}.wav`)} catch {
            // 没有，加入转码列表
            nativeModule.dsdToWav(i, `${dsd_cache_path}/${tmp_ino}.wav`)
          }
        } else {continue}
      }

      this.play_list.push(i)

    }

    // 载入指针 //
    this.play_list_index = (index >= this.play_list.length - 1) ? this.play_list.length - 1 : index

    // 广播 //
    this.send_play_list()

    // 载入歌曲 //
    await this.set_audio(index)

  }

  // 播放 //
  playing() {
    if (this.play_list.length == 0) {return}
    if (this.global_config!.player_mode) {this.ffmpeg_player.playing()} else {this.av_player.set_play_status(true)}
  }
  // 暂停 //
  pause(all: boolean = false) {
    if (this.play_list.length == 0) {return}
    if (all) {
      this.ffmpeg_player.pause()
      this.av_player.set_play_status(false)
    }
    if (this.global_config!.player_mode) {this.ffmpeg_player.pause()} else {this.av_player.set_play_status(false)}
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
    if (this.global_config!.player_mode) {this.ffmpeg_player.seek(time)} else {this.av_player.audio_seek(time)}
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
  delete_song(index: number) {

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
  set_play_mode(index: number) {this.send_play_mode(index)}
  // 更改歌曲喜欢 //
  toggle_like() {
    try {

      // 获取ino //
      const tmp = `${fs.statSync(this.play_list[this.play_list_index]).ino}`

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
      this.send_check_like()

      // 保存 //
      save_array(this.like_list_path, audio_player_path + '/like.json')

    } catch {}
  }
  // 设置定时 //
  set_timing(time_ms: number) {
    // 0 或负数 = 取消定时
    if (time_ms <= 0) {
      this.target_timed = 0
      this.send_timing()  // 通知前端定时已取消
      return
    }
    this.target_timed = Date.now() + time_ms
  }
  // 获取剩余时间 //
  get_timing() {return this.target_timed - Date.now()}

  // 设置播放器模式（重加载） //
  async set_player_mode(mode: boolean) {

    // 更改模式 //
    this.global_config!.player_mode = mode
    this.global_config?.save_data()

    // 重加载 //
    this.reset_data()

  }
  // 设置dsd支持（重加载） //
  async set_dsd(mode: boolean) {

    // 设置 //
    this.global_config!.dsd_support = mode
    this.global_config?.save_data()

    // 重加载 //
    this.reset_data()

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////

  // av_session初始化 //
  private async avs_start_up() {

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

  // audio_player初始化 //
  async audio_player_start_up() {

    // 检测工作目录 //
    try {fs.statSync(audio_player_path)} catch {fs.mkdirSync(audio_player_path)}
    try {fs.statSync(dsd_cache_path)} catch {fs.mkdirSync(dsd_cache_path)}

    // 注册回调 //
    this.player_callback()
    // 注册元音频 //
    await this.avs_start_up()
    // 加载数据 //
    this.load_data()
    // 启动定时器 //
    this.timing()
    this.auto_save()
    // 就绪 //
    log('音频管理器就绪.')

  }

  // 构建 //
  constructor(global_config: class_global_config) {

    // 导入全局配置文件 //
    this.global_config = global_config

  }

}