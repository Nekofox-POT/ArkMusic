//
// 设置页
// 广播频段：10
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { window } from '@kit.ArkUI'

// 导入自创建模块 //

// 导入类 //
import class_global_config from '../../package/class_global_config'
import class_files_manager from "../../package/files_manager/class_files_manager"
import class_audio_player from '../../package/audio_player/class_audio_player'

// 导入页 //

// 变量池 //


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主页面入口 //
//////////////
@Component
export default struct setting_index {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 更新池 //

  // 类 //
  @ObjectLink global_config: class_global_config  // 全局变量管理
  @ObjectLink audio_player: class_audio_player    // 播放器核心
  @ObjectLink files_manager: class_files_manager  // 文件管理器核心
  @Link setting_on: boolean                       // 设置页

  // 继承类 //


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 页面启动操作 //
  aboutToAppear(): void {
    this.setImmersiveBarStyle()
  }

  // 页面退出操作 //
  aboutToDisappear(): void {}

  // 沉浸式系统栏样式 //
  setImmersiveBarStyle(): void {
    try {
      window.getLastWindow(getContext(this), (err, win) => {
        if (!err) {
          const props: window.SystemBarProperties = {
            statusBarContentColor: '#333333',   // 状态栏图标深色
            navigationBarContentColor: '#333333' // 导航栏图标深色
          }
          win.setWindowSystemBarProperties(props)
        }
      })
    } catch {}
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 菜单项构建器 //
  @Builder
  buildMenuItem(icon: string, label: string, callback: () => void) {
    Row() {
      Image($rawfile(icon))
        .width(24).height(24)

      Blank(12)

      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .fontWeight(400)
        .layoutWeight(1)

      Text('〉')
        .fontSize(16)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(callback)
  }

  // 内容区构建器 //
  @Builder
  buildContent() {
    List({ space: 12 }) {

      ////////////////////////////
      // 第一组：音频设置、更多设置 //
      ////////////////////////////
      ListItem() {
        Column() {
          this.buildMenuItem('setting/play.svg', '音频设置', () => {
            // 进入音频设置子页 //
          })

          Divider()
            .width('calc(100% - 52vp)')
            .color('#F5F5F5')
            .strokeWidth(0.5)

          this.buildMenuItem('setting/more.svg', '更多设置', () => {
            // 进入更多设置子页 //
          })
        }
        .width('100%')
        .borderRadius(12)
        .backgroundColor(Color.White)
      }

      //////////////////////////////
      // 第二组：关于、加入唠嗑组织 //
      //////////////////////////////
      ListItem() {
        Column() {
          this.buildMenuItem('setting/about.svg', '关于', () => {
            // 进入关于页 //
          })

          Divider()
            .width('calc(100% - 52vp)')
            .color('#F5F5F5')
            .strokeWidth(0.5)

          this.buildMenuItem('setting/join.svg', '加入唠嗑组织', () => {
            // 加入唠嗑组织 //
          })
        }
        .width('100%')
        .borderRadius(12)
        .backgroundColor(Color.White)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 48 })
    .divider(null)
    .scrollBar(BarState.Off)
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Stack({ alignContent: Alignment.Bottom }) {

      //////////////////////////////////////////////
      // 主内容区                               //
      //////////////////////////////////////////////
      Column() {

        // ---- 状态栏避让（36vp）：玻璃背景，与标题栏视觉一体 ----
        Row()
          .width('100%')
          .height(36)
          .backgroundColor('rgba(255, 255, 255, 0.76)')
          .backdropBlur(12)

        // ---- 顶部渐变模糊条：标题栏 → 内容区平滑过渡 ----
        Row()
          .width('100%')
          .height(16)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [
              ['rgba(255, 255, 255, 0.76)', 0],
              ['rgba(255, 255, 255, 0.00)', 1]
            ]
          })
          .backdropBlur(8)

        // ---- HdsNavigation 导航 + 自定义模糊返回按钮 ----
        Stack({ alignContent: Alignment.TopStart }) {
          HdsNavigation() {
            this.buildContent()
          }
          .titleBar({
            content: {
              title: { mainTitle: '设置' }
            },
            style: {
              scrollEffectOpts: {
                enableScrollEffect: true,
                scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
                blurEffectiveStartOffset: LengthMetrics.vp(0),
                blurEffectiveEndOffset: LengthMetrics.vp(40)
              },
              systemMaterialEffect: {
                materialType: hdsMaterial.MaterialType.ADAPTIVE,
                materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
              },
              originalStyle: {
                backgroundStyle: {
                  backgroundColor: 'rgba(255, 255, 255, 0.76)'
                },
                contentStyle: {
                  titleStyle: {
                    mainTitleColor: '#333333'
                  },
                  backIconStyle: {
                    backgroundColor: 'rgba(0, 0, 0, 0.05)',
                    iconColor: '#333333'
                  }
                }
              },
              scrollEffectStyle: {
                backgroundStyle: {
                  backgroundColor: 'rgba(255, 255, 255, 0.94)'
                },
                contentStyle: {
                  titleStyle: {
                    mainTitleColor: '#333333'
                  },
                  backIconStyle: {
                    backgroundColor: 'rgba(0, 0, 0, 0.05)',
                    iconColor: '#333333'
                  }
                }
              }
            }
          })
          .titleMode(HdsNavigationTitleMode.MINI)
          .hideBackButton(true)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#f5f5f5')

          // ---- 自定义模糊返回按钮（覆盖在标题栏左上角） ----
          Row()
            .width(36).height(36)
            .borderRadius(18)
            .backgroundColor('rgba(255, 255, 255, 0.30)')
            .backdropBlur(24)
            .shadow({
              radius: 4,
              color: 'rgba(0, 0, 0, 0.06)',
              offsetY: 1
            })
            .justifyContent(FlexAlign.Center)
            .position({ x: 16, y: 10 })
            .onClick(() => { this.setting_on = false })
            .zIndex(10)

          Image($r('sys.symbol.chevron_left'))
            .width(24).height(24)
            .fillColor('#333333')
            .position({ x: 22, y: 16 })
            .zIndex(11)
            .onClick(() => { this.setting_on = false })

        }
        .width('100%')
        .layoutWeight(1)

      }
      .width('100%').height('100%')

      //////////////////////////////////////
      // 底部渐变模糊条（沉浸式底部过渡） //
      //////////////////////////////////////
      Column()
        .width('100%')
        .height(32)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            ['rgba(245, 245, 245, 0.00)', 0],
            ['rgba(245, 245, 245, 0.55)', 0.35],
            ['rgba(245, 245, 245, 0.88)', 1]
          ]
        })
        .backdropBlur(12)
        .hitTestBehavior(HitTestMode.None)

    }
    .width('100%').height('100%')
    .backgroundColor('#f5f5f5')
  }
}