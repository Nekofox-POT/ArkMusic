//
// 音频处理器
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { common } from '@kit.AbilityKit';
import emitter from '@ohos.events.emitter'

//////////////////
// 导入自创建模块 //
/////////////////
import { av_player } from './by_av_player'
import { notice } from '../system_function'

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
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
  private av_player = new av_player(this.context)   // 官方av_player播放器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 播放完成的监听订阅 //
  play_status_callback: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    // 如果是播放完成
    if (eventData.data?.status == 'complete') {
      // 如果不是末尾，那就下一首
      if (this.play_list_index < this.play_list.length - 1) {
        this.set_audio_play(this.play_list_index + 1)
      } else {
        notice('最后一首播放完了哦！ξ( ✿＞◡❛)')
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 设置播放跳转 //
  async set_audio_play(song_index: number = this.play_list_index) {
    console.log(`当前：${song_index}`)
    if (song_index != this.play_list_index) { this.play_list_index = song_index }
    // 使用官方播放器
    if (this.player_choice == 0) {
      const result = await this.av_player.audio_set(this.play_list[song_index], song_index)
      if (result[0]) {
        // 成功，广播媒体信息

      } else {
        // 失败，报错
        notice(`歌曲加载失败了 (੭ ᐕ)੭？ ：${result[1]}，3s后切换下一首`)
        setTimeout(() => {
          if (song_index == this.play_list_index) {
            this.set_play_status(true)
          }
        }, 3000)
      }
    }
  }

  // 设置播放列表（初始化） //
  set_play_list(list: string[], index: number) {
    // 设置
    this.play_list = list
    this.play_list_index = index
    this.random_record = []
    // 初始化（播放）
    this.set_audio_play()
  }

  // 设置播放状态 //
  set_play_status(status: boolean) {
    // 如果列表空直接不理
    if (this.play_list.length == 0) { return }
    if (this.player_choice == 0) {
      this.av_player.set_play_status(status)
    }
  }

  // 上下首 (上是false 下是true) //
  last_next_songs(choice: boolean) {
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
      // 下一首
      if (choice) {
        // 末尾检查
        if (this.play_list_index == this.play_list.length - 1) {
          this.set_audio_play(0)
          notice('回到开头啦！_(:3 ⌒ﾞ)_')
        } else {
          this.set_audio_play(this.play_list_index + 1)
        }
      }
      // 上一首
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
  }

  // 更改播放进度 //
  audio_seek(time: number) {
    this.av_player.audio_seek(time)
  }

  // 销毁 //
  drop_it() {
    this.av_player.drop_it()
  }


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor(context_input: common.UIAbilityContext) {
    // 记录身份证
    this.context = context_input
    // 监听广播
    emitter.on({ eventId: 712 }, this.play_status_callback)
  }

}