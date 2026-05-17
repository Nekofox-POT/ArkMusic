//
// 音频播放器（官方核心）
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import media from '@ohos.multimedia.media'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
/////////////////
import { log } from '../system_function'

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
  auto_play: boolean = false  // 载入后自动播放 (防止第一次打开自动播放)

  ////////
  // 类 //
  ///////
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
        case 'idle': // audio闲置
          console.log('audio闲置了')
          break
        case 'initialized': // audio初始化
          console.log('audio正在初始化')
          this.avPlayer.prepare()
          break;
        case 'prepared': // audio准备就绪
          console.log('audio准备就绪。')
          callback(this.avPlayer)
          this.avPlayer.seek(0)
          console.log('callback设置成功，等待audio播放。')
          this.set_player_ready?.()
          if (this.auto_play) {
            this.avPlayer.play()
          } else {
            this.auto_play = true
          }
          break;
        case 'playing': // audio播放
          console.log('audio正在播放~')
          this.play_status_update?.('playing')
          break
        case 'paused':  // audio暂停
          console.log('audio暂停了！')
          this.play_status_update?.('pause')
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.log('audio播放完了。')
          this.play_status_update?.('complete')
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
    })
    // 跳转处理
    this.avPlayer.on('seekDone', (seekDoneTime) => {
      console.log(`audio跳转了，跳转至"${seekDoneTime}"`)
    });
    // 音频焦点切换处理
    this.avPlayer.on('audioInterrupt', () => {
      console.log('audio被中断了！')
      this.play_status_update?.('pause')
    });
    // 错误处理
    this.avPlayer.on('error', (e) => {
      console.error(`audio发生错误：${e}`)
      // 重置
      this.avPlayer?.reset()
    })
    // 总时长更新
    this.avPlayer.on('durationUpdate', (time: number) => {
      this.duration_time_update?.(time)
    })
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.current_time_update?.(time)
    })
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 播放锁解锁 //
  unlock_auto_play() {this.auto_play = true}

  // 音频设置 //
  async audio_set(path: string): Promise<[boolean, string]> {
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
  // 回调函数 //
  ////////////
  // 函数头 //
  private set_player_ready?: () => void
  private play_status_update?: (status: string) => void
  private duration_time_update?: (duration: number) => void
  private current_time_update?: (position: number) => void

  // 注册机 //
  set_callback(
    set_player_ready?: () => void,
    play_status_update?: (status: string) => void,
    duration_time_update?: (duration: number) => void,
    current_time_update?: (position: number) => void
  ): void {
    this.set_player_ready = set_player_ready
    this.play_status_update = play_status_update
    this.duration_time_update = duration_time_update
    this.current_time_update = current_time_update
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor() {}

}