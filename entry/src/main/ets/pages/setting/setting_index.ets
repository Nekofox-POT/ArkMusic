//
// 设置页（半模态面板）
// 广播频段：10
// 1012：ui_mode状态切换
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { common } from '@kit.AbilityKit'

// 导入自创建模块 //
import { log } from '../../package/system_function'

// 导入类 //
import class_global_config from '../../package/class_global_config'
import class_files_manager from "../../package/files_manager/class_files_manager"
import class_audio_player from '../../package/audio_player/class_audio_player'

// 导入页 //
import setting_about from './setting_about'
import setting_more from './setting_more'

// 变量池 //


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 设置页入口 //
//////////////
@Component
export default struct setting_index {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 更新池 //
  @State show_sheet: boolean = false   // 半模态显隐
  @State item_count: number = 0        // 选项逐出计数
  @State press_idx: number = -1        // 按压项索引
  @State set_page: number = 1          // 内部页码（1=主页, 2=音频设置, 3=播放器切换, 4=关于, 5=更多设置）
  @State about_emoji: boolean = false   // 关于页颜文字模式
  @State player_selected: number = -1    // 播放器选中（0=系统, 1=风铃, -1=未选）
  @State player_show_title: boolean = false
  @State player_show_options: boolean = false
  @State player_show_button: boolean = false
  @State player_exiting: boolean = false

  // 类 //
  @ObjectLink global_config: class_global_config  // 全局变量管理
  @ObjectLink audio_player: class_audio_player    // 播放器核心
  @ObjectLink files_manager: class_files_manager  // 文件管理器核心

  // 继承池 //
  @Link setting_page: number                       // 自身页面开关

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 页面挂载操作 //
  aboutToAppear(): void {
    // 等待宿主节点挂载完成后拉取半模态 //
    setTimeout(() => { this.show_sheet = true }, 50)
    // 选项逐出动画 //
    for (let i = 0; i < 5; i++) {
      setTimeout(() => { this.item_count = i + 1 }, 200 + i * 80)
    }
  }

  // 页面卸载操作 //
  aboutToDisappear(): void {}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 按压回弹 //
  trigger_press(idx: number) {
    this.press_idx = idx
    setTimeout(() => { this.press_idx = -1 }, 150)
  }

  // 播放器模式名称 //
  player_mode_name(): string {
    return this.global_config.player_mode ? '星铃播放器' : '官方播放器'
  }

  // 菜单项构建器 //
  @Builder
  build_menu_item(icon: string, label: string, callback: () => void) {
    Row() {
      Image($rawfile(icon))
        .width('24vp').height('24vp')

      Blank('12vp')

      Text(label)
        .fontSize('16fp').fontColor('#1A1A1A')
        .layoutWeight(1)

      Image($rawfile('setting/chevron_right.svg'))
        .width('16vp').height('16vp')
    }
    .width('100%').height('64vp')
    .padding({ left: '16vp', right: '16vp' })
    .alignItems(VerticalAlign.Center)
    .onClick(callback)
  }

  // 标签+值行 //
  @Builder
  build_value_row(label: string, value: string, callback: () => void) {
    Row() {
      Text(label)
        .fontSize('16fp').fontColor('#1A1A1A')
        .layoutWeight(1)

      Text(value)
        .fontSize('14fp').fontColor('#999999')

      Blank('8vp')

      Image($rawfile('setting/chevron_right.svg'))
        .width('12vp').height('12vp')
    }
    .width('100%').height('64vp')
    .padding({ left: '16vp', right: '16vp' })
    .alignItems(VerticalAlign.Center)
    .onClick(callback)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 页面内容 //
  ////////////

  // 主页 //
  @Builder
  main_page() {
    Column() {
      Scroll() {
        Column({ space: '12vp' }) {

          // 音频设置 //
          if (this.item_count >= 1) {
            Column() {
              this.build_menu_item('setting/play.svg', '音频设置', () => {
                this.trigger_press(0)
                this.set_page = 2
              })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius('16vp')
            .scale({ x: this.press_idx == 0 ? 0.96 : 1, y: this.press_idx == 0 ? 0.96 : 1 })
            .animation({ duration: 300, curve: Curve.Friction })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: '24vp' }))
                .animation({ duration: 350, curve: Curve.EaseOut }),
              TransitionEffect.OPACITY
                .animation({ duration: 150 })
            ))
          }

          // 更多设置 //
          if (this.item_count >= 2) {
            Column() {
              this.build_menu_item('setting/more.svg', '更多设置', () => {
                this.trigger_press(1)
                this.set_page = 5
              })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius('16vp')
            .scale({ x: this.press_idx == 1 ? 0.96 : 1, y: this.press_idx == 1 ? 0.96 : 1 })
            .animation({ duration: 300, curve: Curve.Friction })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: '24vp' }))
                .animation({ duration: 350, curve: Curve.EaseOut }),
              TransitionEffect.OPACITY
                .animation({ duration: 150 })
            ))
          }

          // 关于 //
          if (this.item_count >= 3) {
            Column() {
              this.build_menu_item('setting/about.svg', this.about_emoji ? 'ヽ(=^･ω･^=)丿' : '关于', () => {
                this.trigger_press(2)
                this.about_emoji = true
                this.set_page = 4
              })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius('16vp')
            .scale({ x: this.press_idx == 2 ? 0.96 : 1, y: this.press_idx == 2 ? 0.96 : 1 })
            .animation({ duration: 300, curve: Curve.Friction })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: '24vp' }))
                .animation({ duration: 350, curve: Curve.EaseOut }),
              TransitionEffect.OPACITY
                .animation({ duration: 150 })
            ))
          }

          // 加入唠嗑组织 //
          if (this.item_count >= 4) {
            Column() {
              this.build_menu_item('setting/join.svg', '加入唠嗑组织', () => {
                this.trigger_press(3)
                try {
                  let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
                  context.startAbility({
                    uri: 'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=1062329769&card_type=group'
                  })
                } catch (err) {
                  log('打开QQ群失败', 'error')
                }
              })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius('16vp')
            .scale({ x: this.press_idx == 3 ? 0.96 : 1, y: this.press_idx == 3 ? 0.96 : 1 })
            .animation({ duration: 300, curve: Curve.Friction })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: '24vp' }))
                .animation({ duration: 350, curve: Curve.EaseOut }),
              TransitionEffect.OPACITY
                .animation({ duration: 150 })
            ))
          }

          // 访问项目github //
          if (this.item_count >= 5) {
            Column() {
              this.build_menu_item('setting/github.gif', '访问项目Github', () => {
                this.trigger_press(4)
                try {
                  let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
                  context.startAbility({ uri: 'https://github.com/Nekofox-POT/LinMusic' })
                } catch (err) {
                  log('打开GitHub链接失败', 'error')
                }
              })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius('16vp')
            .scale({ x: this.press_idx == 4 ? 0.96 : 1, y: this.press_idx == 4 ? 0.96 : 1 })
            .animation({ duration: 300, curve: Curve.Friction })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: '24vp' }))
                .animation({ duration: 350, curve: Curve.EaseOut }),
              TransitionEffect.OPACITY
                .animation({ duration: 150 })
            ))
          }

        }
        .width('100%')
        .padding({ left: '16vp', right: '16vp', top: '24vp', bottom: '24vp' })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .backgroundColor('#F1F3F5')
  }

  // 音频设置子页 //
  @Builder
  audio_settings_page() {
    Scroll() {
      Column({ space: '12vp' }) {

        // 音频播放器切换 //
        Column() {
          this.build_value_row('音频播放器切换', this.player_mode_name(), () => {
            this.player_selected = this.global_config.player_mode ? 1 : 0
            this.player_show_title = false
            this.player_show_options = false
            this.player_show_button = false
            this.player_exiting = false
            this.set_page = 3
            setTimeout(() => { this.player_show_title = true }, 80)
            setTimeout(() => { this.player_show_options = true }, 360)
            setTimeout(() => { this.player_show_button = true }, 640)
          })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius('16vp')

        // DSD 支持（仅官方播放器模式下显示） //
        if (!this.global_config.player_mode) {
          Column() {
            Row() {
              Text('开启 DSD 支持')
                .fontSize('16fp').fontColor('#1A1A1A')
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.global_config.dsd_support })
                .selectedColor('rgba(244, 198, 206, 1.0)')
                .onChange((value: boolean) => {
                  this.audio_player.set_dsd(value)
                })
            }
            .width('100%').height('64vp')
            .padding({ left: '16vp', right: '16vp' })
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius('16vp')
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 1 }))
              .animation({ duration: 300, curve: Curve.FastOutSlowIn }),
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 1 }))
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })
          ))
        }

      }
      .width('100%')
      .padding({ left: '16vp', right: '16vp', top: '24vp', bottom: '24vp' })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .backgroundColor('#F1F3F5')
  }

  // 自定义标题（随页码切换） //
  @Builder
  sheet_title() {
    Row() {
      if (this.set_page == 5) {
        Text('更多设置')
          .fontSize('22fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      } else if (this.set_page == 4) {
        Text('关于')
          .fontSize('22fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      } else if (this.set_page == 3) {
        Text('音频播放器切换')
          .fontSize('22fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      } else if (this.set_page == 2) {
        Text('音频设置')
          .fontSize('22fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      } else {
        Text('设置')
          .fontSize('22fp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
    }
    .width('100%')
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 半模态内容 //
  //////////////
  // 三级页面：播放器切换（照抄 step_a） //
  @Builder
  player_switch_page() {
    Column() {

      // 标题 //
      Text('请选择播放器内核：')
        .fontSize('22fp')
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .opacity(this.player_show_title ? 1 : 0)
        .translate({ y: this.player_show_title ? 0 : (this.player_exiting ? -60 : 60) })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      // 内核选项区 //
      Row() {

        // 系统内核 //
        Column() {
          Column() {
            Image($rawfile('setting/official_player.svg'))
              .width('48vp').height('48vp')
          }
          .width('80vp').height('80vp')
          .borderRadius('40vp')
          .backgroundColor('#f5f5f5')
          .justifyContent(FlexAlign.Center)

          Text('').height('8vp')

          Text('系统')
            .fontSize('18fp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          Text('').height('4vp')

          Text('官方出品，更稳定')
            .fontSize('12fp')
            .fontColor('#999')
        }
        .width('40%')
        .padding('12vp')
        .borderRadius('12vp')
        .backgroundColor(this.player_selected === 0 ? 'rgba(244, 198, 206, 0.12)' : '#00000000')
        .border({ width: this.player_selected === 0 ? '1.5vp' : '0', color: 'rgba(244, 198, 206, 1.0)' })
        .scale({ x: this.player_selected === 0 ? 1.08 : 1.0, y: this.player_selected === 0 ? 1.08 : 1.0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => { this.player_selected = 0 })

        Text('').width('24vp')

        // 风铃内核 //
        Column() {
          Column() {
            Image($rawfile('setting/lin_player.svg'))
              .width('48vp').height('48vp')
          }
          .width('80vp').height('80vp')
          .borderRadius('40vp')
          .backgroundColor('#f5f5f5')
          .justifyContent(FlexAlign.Center)

          Text('').height('8vp')

          Text('风铃')
            .fontSize('18fp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          Text('').height('4vp')

          Text('自研内核，支持更多格式。')
            .fontSize('12fp')
            .fontColor('#999')
        }
        .width('40%')
        .padding('12vp')
        .borderRadius('12vp')
        .backgroundColor(this.player_selected === 1 ? 'rgba(244, 198, 206, 0.12)' : '#00000000')
        .border({ width: this.player_selected === 1 ? '1.5vp' : '0', color: 'rgba(244, 198, 206, 1.0)' })
        .scale({ x: this.player_selected === 1 ? 1.08 : 1.0, y: this.player_selected === 1 ? 1.08 : 1.0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => { this.player_selected = 1 })

      }
      .width('100%')
      .opacity(this.player_show_options ? 1 : 0)
      .translate({ y: this.player_show_options ? 0 : (this.player_exiting ? -60 : 60) })
      .animation({ duration: 500, curve: Curve.FastOutSlowIn })
      .justifyContent(FlexAlign.Center)

      // 确定按钮 //
      Button('确定')
        .width('144vp')
        .height('72vp')
        .backgroundColor(this.player_selected !== -1 ? 'rgba(244, 198, 206, 1.0)' : '#eee')
        .borderRadius('36vp')
        .fontSize('20fp')
        .fontColor(this.player_selected !== -1 ? '#ffffff' : '#999')
        .opacity(this.player_show_button ? 1 : 0)
        .translate({ y: this.player_show_button ? 0 : (this.player_exiting ? -60 : 60) })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })
        .onClick(() => {
          if (this.player_selected === -1) {return}
          this.global_config.player_mode = (this.player_selected === 1)
          this.audio_player.set_player_mode(this.player_selected === 1)
          this.player_exiting = true
          this.player_show_title = false
          this.player_show_options = false
          this.player_show_button = false
          setTimeout(() => { this.set_page = 2 }, 500)
        })

    }
    .width('100%').height('100%')
    .padding({ left: '32vp', right: '32vp', top: '56vp', bottom: '24vp' })
    .backgroundColor('#F1F3F5')
    .justifyContent(FlexAlign.SpaceAround)
  }

  @Builder
  setting_content() {

    if (this.set_page == 5) {
      Column() {
        setting_more()
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 420, curve: Curve.FastOutSlowIn }),
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 200, curve: Curve.Linear })
      ))
    } else if (this.set_page == 4) {
      Column() {
        setting_about({ global_config: this.global_config })
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 420, curve: Curve.FastOutSlowIn }),
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 200, curve: Curve.Linear })
      ))
    } else if (this.set_page == 3) {
      Column() {
        this.player_switch_page()
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 420, curve: Curve.FastOutSlowIn }),
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 200, curve: Curve.Linear })
      ))
    } else if (this.set_page == 2) {
      Column() {
        this.audio_settings_page()
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 420, curve: Curve.FastOutSlowIn }),
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 200, curve: Curve.Linear })
      ))
    } else {
      Column() {
        this.main_page()
      }
      .width('100%').height('100%')
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 280, curve: Curve.FastOutSlowIn }),
        TransitionEffect.OPACITY
          .animation({ duration: 180, curve: Curve.Linear })
      ))
    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Column() {
      // 透明空页面——半模态宿主 //
    }
    .width('100%').height('100%')
    .backgroundColor(Color.Transparent)
    .bindSheet($$this.show_sheet, this.setting_content(), {
      detents: ['87%', SheetSize.LARGE],
      showClose: true,
      dragBar: true,
      preferType: SheetType.BOTTOM,
      backgroundColor: '#F1F3F5',
      title: this.sheet_title(),
      onWillDismiss: ((action: DismissSheetAction) => {
        // 逐级回退：关于页/更多设置→主页，其他逐级递减 //
        if (this.set_page == 4 || this.set_page == 5) {
          this.set_page = 1
        } else if (this.set_page > 1) {
          this.set_page = this.set_page - 1
        } else {
          action.dismiss()
        }
      }),
      onDisappear: () => {
        // 半模态关闭后卸载自身页面 //
        this.set_page = 1
        this.setting_page = 0
        this.about_emoji = false
      }
    })
  }
}