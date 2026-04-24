//
// 音乐扫描界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import emitter from '@ohos.events.emitter'

//////////////////
// 导入自创建模块 //
/////////////////
import { make_music_cache } from '../package/file_manager'

///////////
// 变量池 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 扫描界面入口 //
///////////////
@Component
export default struct ark_music_scan {

  ///////////
  // 变量池 //
  //////////

  ///////////
  // 更新池 //
  //////////
  @State msg: string = ''

  ///////////
  // 继承池 //
  //////////
  @Link scan_ui: boolean

  ////////
  // 类 //
  ///////
  // 载入界面 //
  async aboutToAppear() {
    // 监听 //
    emitter.on({ eventId: 1010 }, (eventData: emitter.EventData) => {this.msg = eventData.data?.msg})
    // 执行数据库创建 //
    await make_music_cache()
    // 退出 //
    setTimeout(() => {this.scan_ui = false}, 1000)
  }
  aboutToDisappear(): void {
    // 关闭监听 //
    emitter.off(1010)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {

    Column() {

      // logo
      Image($r('app.media.foreground_backup')).width('512px').height('512px')
      // 加载动画
      LoadingProgress().width('64vp').height('64vp').color('rgba(0, 0, 0, 0.4)')

      // 文字
      Column() {
        Text(this.msg).fontColor('rgba(0, 0, 0, 0.4)')
          .fontSize('15vp')
      }
      .width('100%')
      .position({ x: 0, y: '67%' })

    }
      .width('100%').height('100%')
      .position({ x: 0, y: 0 })
      .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
      .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
  }

}