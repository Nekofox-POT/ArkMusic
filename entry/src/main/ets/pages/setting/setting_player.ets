//
// 音频设置页（二级 / 三级页面）
// 广播频段：10
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //

// 导入自创建模块 //
import { log } from '../../package/system_function'

// 导入类 //
import class_global_config from '../../package/class_global_config'
import class_files_manager from "../../package/files_manager/class_files_manager"
import class_audio_player from '../../package/audio_player/class_audio_player'

// 导入页 //

// 变量池 //


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面入口 //
////////////
@Component
export default struct setting_player {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 更新池 //
  @State page: number = 2                    // 内部页码（2=二级菜单, 3=三级切换页）
  @State show_icon: boolean = false          // 图标进场
  @State show_button: boolean = false        // 按钮进场
  @State exiting: boolean = false            // 退场控制

  // 类 //
  @ObjectLink global_config: class_global_config  // 全局变量管理
  @ObjectLink audio_player: class_audio_player    // 播放器核心
  @ObjectLink files_manager: class_files_manager  // 文件管理器核心

  // 继承池 //
  @Link set_page: number                           // 内部页码（由 setting_index 控制）

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 页面挂载操作 //
  aboutToAppear(): void {}

  // 页面卸载操作 //
  aboutToDisappear(): void {}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 菜单项构建器 //
  @Builder
  build_menu_item(label: string, value: string, callback: () => void) {
    Row() {
      Text(label)
        .fontSize('16fp').fontColor('#1A1A1A')
        .layoutWeight(1)

      Text(value)
        .fontSize('14fp').fontColor('#999999')

      Text(' 〉')
        .fontSize('14fp').fontColor('#CCCCCC')
    }
    .width('100%').height('64vp')
    .padding({ left: '16vp', right: '16vp' })
    .alignItems(VerticalAlign.Center)
    .onClick(callback)
  }

  // 播放器模式名称 //
  player_mode_name(): string {
    return this.global_config.player_mode ? '星铃播放器' : '官方播放器'
  }

  // 切换播放器 //
  switch_player(mode: boolean) {
    this.audio_player.set_player_mode(mode)
    this.exiting = true
    this.show_icon = false
    this.show_button = false
    setTimeout(() => { this.page = 2 }, 560)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 页面内容构建 //
  ////////////////

  // 三级页面：播放器切换 //
  @Builder
  player_switch_page() {
    Column() {

      // 顶部返回栏 //
      Row() {
        Image($r('sys.symbol.chevron_left'))
          .width('24vp').height('24vp')
          .fillColor('#333333')
          .onClick(() => {
            this.exiting = true
            this.show_icon = false
            this.show_button = false
            setTimeout(() => { this.page = 2 }, 560)
          })

        Blank('8vp')

        Text('音频播放器切换')
          .fontSize('18fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '16vp', bottom: '12vp' })

      Divider()
        .strokeWidth('0.5vp').color('#E5E5E5')

      // step_x 风格内容区 //
      Column() {

        // 图标 //
        Image($r('app.media.icon_white'))
          .width('128vp').height('128vp')
          .opacity(this.show_icon ? 1 : 0)
          .translate({ y: this.show_icon ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 560, curve: Curve.FastOutSlowIn })

        // 选项区 //
        Column({ space: '12vp' }) {

          // 官方播放器 //
          Button() {
            Row() {
              Text('官方播放器')
                .fontSize('16fp').fontColor('#1A1A1A')
                .layoutWeight(1)

              if (!this.global_config.player_mode) {
                Image($r('sys.symbol.checkmark'))
                  .width('20vp').height('20vp')
                  .fillColor('#007AFF')
              }
            }
            .width('100%')
            .padding({ left: '16vp', right: '16vp' })
          }
          .width('80%')
          .height('56vp')
          .backgroundColor(this.global_config.player_mode ? '#F5F5F5' : '#FFFFFF')
          .borderRadius('12vp')
          .border({
            width: this.global_config.player_mode ? 0 : '1vp',
            color: this.global_config.player_mode ? Color.Transparent : '#007AFF'
          })
          .opacity(this.show_button ? 1 : 0)
          .translate({ y: this.show_button ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 560, curve: Curve.FastOutSlowIn, delay: 120 })
          .onClick(() => { this.switch_player(false) })

          // 星铃播放器 //
          Button() {
            Row() {
              Text('星铃播放器')
                .fontSize('16fp').fontColor('#1A1A1A')
                .layoutWeight(1)

              if (this.global_config.player_mode) {
                Image($r('sys.symbol.checkmark'))
                  .width('20vp').height('20vp')
                  .fillColor('#007AFF')
              }
            }
            .width('100%')
            .padding({ left: '16vp', right: '16vp' })
          }
          .width('80%')
          .height('56vp')
          .backgroundColor(this.global_config.player_mode ? '#FFFFFF' : '#F5F5F5')
          .borderRadius('12vp')
          .border({
            width: this.global_config.player_mode ? '1vp' : 0,
            color: this.global_config.player_mode ? '#007AFF' : Color.Transparent
          })
          .opacity(this.show_button ? 1 : 0)
          .translate({ y: this.show_button ? 0 : (this.exiting ? -60 : 60) })
          .animation({ duration: 560, curve: Curve.FastOutSlowIn, delay: 240 })
          .onClick(() => { this.switch_player(true) })

        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.SpaceAround)

    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
    .onAppear(() => {
      // 重置并触发动画 //
      this.exiting = false
      this.show_icon = false
      this.show_button = false
      setTimeout(() => { this.show_icon = true }, 120)
      setTimeout(() => { this.show_button = true }, 400)
    })
  }

  // 二级页面：音频设置菜单 //
  @Builder
  audio_settings_page() {
    Column() {

      // 顶部返回栏 //
      Row() {
        Image($r('sys.symbol.chevron_left'))
          .width('24vp').height('24vp')
          .fillColor('#333333')
          .onClick(() => { this.set_page = 1 })

        Blank('8vp')

        Text('音频设置')
          .fontSize('18fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '16vp', bottom: '12vp' })

      Divider()
        .strokeWidth('0.5vp').color('#E5E5E5')

      // 选项区 //
      Scroll() {
        Column({ space: '12vp' }) {

          // 音频播放器切换 //
          Column() {
            this.build_menu_item('音频播放器切换', this.player_mode_name(), () => {
              this.page = 3
            })
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius('16vp')

        }
        .width('100%')
        .padding({ left: '16vp', right: '16vp', top: '24vp', bottom: '24vp' })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

    }
    .width('100%').height('100%')
    .backgroundColor('#F1F3F5')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {

    if (this.page == 3) {
      this.player_switch_page()
    } else {
      this.audio_settings_page()
    }

  }
}