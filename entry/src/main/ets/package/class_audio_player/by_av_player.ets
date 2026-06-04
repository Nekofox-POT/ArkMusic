//
// 音频播放器（官方核心）
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 导入第三方库 //
import media from '@ohos.multimedia.media'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import { log } from '../system_function'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
export class class_av_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //
  auto_start: boolean = false  // 载入后自动播放 (防止第一次打开自动播放)
  start_time: number = 0  // 歌曲起始时间

  // 类 //
  private avPlayer: media.AVPlayer | null = null  // audio播放

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // audio监听回调 //
  private async set_av_player_callback(callback: (avPlayer: media.AVPlayer) => void) {
    // 添加保险
    if (!this.avPlayer) { return }
    // 状态机变化（主）
    this.avPlayer.on('stateChange', async (state: string) => {
      // 添加保险
      if (!this.avPlayer) { return }
      // 状态分类
      switch (state) {
        case 'initialized': // audio初始化
          log('av_player: 正在初始化.')
          this.avPlayer.prepare()
          break
        case 'prepared': // audio准备就绪
          callback(this.avPlayer)
          this.avPlayer.seek(this.start_time)
          log('av_player: audio准备就绪。')
          this.set_player_ready?.()
          if (this.auto_start) {this.avPlayer.play()}
          break
        case 'playing': // audio播放
          log('av_player: audio正在播放~')
          this.play_status_update?.('playing')
          break
        case 'paused':  // audio暂停
          log('av_player: audio暂停了！')
          this.play_status_update?.('pause')
          break;
        case 'completed': // 播放结束后触发该状态机上报
          log('av_player: audio播放完了。')
          this.play_status_update?.('complete')
        case 'released':
          log('av_player: 已被销毁.')
          break
        case 'error':
          log('av_player出现错误.', 'error')
          break
      }
    })
    // 跳转处理
    this.avPlayer.on('seekDone', (time) => {
      log(`av_player: 跳转至"${time}"`)
      this.current_time_update?.(time)
    })
    // 音频焦点切换处理
    this.avPlayer.on('audioInterrupt', () => {
      log('av_player: 被中断了！')
      this.play_status_update?.('pause')
    })
    // 错误处理
    this.avPlayer.on('error', (e) => {
      log(`av_player出现错误：${e}`, 'error')
      // 重置
      this.avPlayer?.reset()
    })
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.current_time_update?.(time)
    })
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 音频设置 //
  async audio_set(path: string, auto_start: boolean = true, time: number = 0): Promise<boolean> {
    this.auto_start = auto_start
    this.start_time = time
    try {
      // 销毁av_player
      if (this.avPlayer) {
        log('销毁av_player')
        this.play_status_update?.('pause')
        await this.avPlayer.release()
      }
      // 检查文件源
      const file = fs.openSync(path)
      // 创建av_player
      log('创建av_player')
      this.avPlayer = await media.createAVPlayer()
      // 设置回调
      await this.set_av_player_callback(() => {})
      // 设置播放源
      this.avPlayer.fdSrc = { fd: file.fd, offset: 0, length: fs.statSync(file.fd).size }
      // 返回
      return true
    } catch (e) {
      // 文件读取失败
      return false
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

  // 初始化 //
  reset() {
    this.avPlayer?.release()
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////
  // 函数头 //
  private set_player_ready?: () => void
  private play_status_update?: (status: string) => void
  private current_time_update?: (position: number) => void

  // 注册机 //
  set_callback(
    set_player_ready?: () => void,
    play_status_update?: (status: string) => void,
    current_time_update?: (position: number) => void
  ): void {
    this.set_player_ready = set_player_ready
    this.play_status_update = play_status_update
    this.current_time_update = current_time_update
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor() {}

}