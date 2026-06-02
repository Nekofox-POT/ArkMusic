//
// 音频播放器（星铃核心）
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 导入第三方库 //
import media from '@ohos.multimedia.media'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log } from '../system_function'

// 变量池 //

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
export class ffmpeg_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 回调函数 //
  ////////////

  // 准备就绪回调 //
  private ffmpeg_callback() {

    // 准备就绪回调 //
    nativeModule.register_ready_callback(() => {
      this.set_player_ready?.()
    })

    // 播放状态回调 //
    nativeModule.register_status_callback((status: string) => {
      // log(status)
      this.play_status_update?.(status)
    })

    // 播放进度回调 //
    nativeModule.register_time_callback((time: number) => {
      this.current_time_update?.(time)
    })

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 装载播放歌曲 //
  async set_audio(path: string): Promise<boolean> {return await nativeModule.set_audio(path)}

  // 播放 //
  playing() {nativeModule.playing()}

  // 暂停 //
  pause() {nativeModule.pause()}

  // 跳转 //
  seek(time: number) {nativeModule.seek(time)}

  // 自动播放设置 //
  set_auto_play(status: boolean) {
    log(`设置自动播放：${status}`)
    nativeModule.set_start_ready(status)
  }

  // 切换 EQ 模式（循环: OFF → GEQ → PEQ → OFF）
  // 返回当前模式 0/1/2
  switch_eq(): number {
    return nativeModule.switch_eq()
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
  constructor() {
    // 注册回调 //
    this.ffmpeg_callback()
  }

}