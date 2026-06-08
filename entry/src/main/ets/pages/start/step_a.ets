//
// start界面 第一步 — 播放器内核选择
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入类 //
import class_global_config from '../../package/class_global_config'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 界面入口 //
////////////
@Component
export default struct step_a {

  // 继承池 //
  @Link page: number   // 通过指示页
  @ObjectLink global_config: class_global_config

  // 选择状态 //
  @State @Watch('onSelectedChange') selected: number = -1   // 0=系统 1=风铃 -1=未选

  // 动画状态 //
  @State showTitle: boolean = false
  @State showOptions: boolean = false
  @State showDsaOption: boolean = false   // DSD选项行（transition自动处理出入场）
  @State showDsaChildren: boolean = false // DSD复选框/图标入场延迟
  @State showDsaInfo: boolean = false     // DSD详细信息弹窗
  @State showDsaOverlay: boolean = false  // DSD弹窗渐变动画
  @State showButton: boolean = false
  @State exiting: boolean = false

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  aboutToAppear(): void {
    // 标题先渐变进入
    setTimeout(() => { this.showTitle = true }, 80)
    // 选项跟随
    setTimeout(() => { this.showOptions = true }, 360)
    // 按钮最后
    setTimeout(() => { this.showButton = true }, 640)
  }

  // 选中变更监听 //
  onSelectedChange(): void {
    if (this.selected === 0) {
      // 入场：创建行 → transition播放展开动画 → 子元素延迟弹出 //
      this.showDsaOption = true
      this.showDsaChildren = false
      setTimeout(() => { this.showDsaChildren = true }, 220)
    } else {
      // 退场：transition自动播放退出动画，动画结束后DOM自动移除 //
      this.showDsaChildren = false
      this.showDsaOption = false
      // 关闭可能打开的信息弹窗 //
      this.closeDsaOverlay()
    }
  }

  // DSD弹窗关闭动画 //
  closeDsaOverlay(): void {
    this.showDsaOverlay = false
    setTimeout(() => { this.showDsaInfo = false }, 310)   // 等待动画完成再销毁
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Stack() {

      ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // 主内容层 //
      ////////////
      Column() {

        //////////////////
        // 播放器内核标题 //
        ////////////////
      Text('请选择播放器内核：')
        .fontSize('22fp')
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .opacity(this.showTitle ? 1 : 0)
        .translate({ y: this.showTitle ? 0 : (this.exiting ? -60 : 60) })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      ///////////////
      // 内核选项区 //
      /////////////
      Row() {

        /////////////
        // 系统内核 //
        ////////////
        Column() {

          // 圆形底罩 + 图标 //
          Column() {
            Image($rawfile('start/官方.svg'))
              .width('48vp').height('48vp')
          }
          .width('80vp').height('80vp')
          .borderRadius('40vp')
          .backgroundColor('#f5f5f5')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Text('').height('8vp')

          // 内核名称 //
          Text('系统')
            .fontSize('18fp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          Text('').height('4vp')

          // 描述 //
          Text('官方出品，更稳定')
            .fontSize('12fp')
            .fontColor('#999')

        }
        .width('40%')
        .padding('12vp')
        .borderRadius('12vp')
        .backgroundColor(this.selected === 0 ? 'rgba(244, 198, 206, 0.12)' : '#00000000')
        .border({ width: this.selected === 0 ? '1.5vp' : '0', color: 'rgba(244, 198, 206, 1.0)' })
        .scale({ x: this.selected === 0 ? 1.08 : 1.0, y: this.selected === 0 ? 1.08 : 1.0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => { this.selected = 0 })

        // 间隔 //
        Text('').width('24vp')

        /////////////
        // 风铃内核 //
        ////////////
        Column() {

          // 圆形底罩 + 图标 //
          Column() {
            Image($rawfile('start/风铃.svg'))
              .width('48vp').height('48vp')
          }
          .width('80vp').height('80vp')
          .borderRadius('40vp')
          .backgroundColor('#f5f5f5')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Text('').height('8vp')

          // 内核名称 //
          Text('风铃')
            .fontSize('18fp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          Text('').height('4vp')

          // 描述 //
          Text('自研内核，支持更多格式，支持dsd播放。')
            .fontSize('12fp')
            .fontColor('#999')

        }
        .width('40%')
        .padding('12vp')
        .borderRadius('12vp')
        .backgroundColor(this.selected === 1 ? 'rgba(244, 198, 206, 0.12)' : '#00000000')
        .border({ width: this.selected === 1 ? '1.5vp' : '0', color: 'rgba(244, 198, 206, 1.0)' })
        .scale({ x: this.selected === 1 ? 1.08 : 1.0, y: this.selected === 1 ? 1.08 : 1.0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => { this.selected = 1 })

      }
      .width('100%')
      .opacity(this.showOptions ? 1 : 0)
      .translate({ y: this.showOptions ? 0 : (this.exiting ? -60 : 60) })
      .animation({ duration: 500, curve: Curve.FastOutSlowIn })
      .justifyContent(FlexAlign.Center)

      /////////////////////////
      // DSD转码选项（固定高度容器，不参与布局流变化） //
      /////////////////////////
      Column() {

        if (this.showDsaOption) {
          Row() {

            // 复选框 //
            Toggle({ type: ToggleType.Checkbox, isOn: this.global_config.dsd_support })
              .width('20vp').height('20vp')
              .selectedColor('rgba(244, 198, 206, 1.0)')
              .scale({ x: this.showDsaChildren ? 1 : 0, y: this.showDsaChildren ? 1 : 0 })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              .onChange((value: boolean) => { this.global_config.dsd_support = value })

            Text('').width('8vp')

            // 说明文字 //
            Text('开启dsd文件转码播放支持。')
              .fontSize('14fp')
              .fontColor('#666')

            Text('').width('4vp')

            // 详细信息按钮 //
            Image($rawfile('start/详细信息按钮.svg'))
              .width('18vp').height('18vp')
              .scale({ x: this.showDsaChildren ? 1 : 0, y: this.showDsaChildren ? 1 : 0 })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              .onClick(() => {
                this.showDsaInfo = true
                setTimeout(() => { this.showDsaOverlay = true }, 30)
              })

          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .transition(TransitionEffect.asymmetric(
            // 入场：左右横向铺开 //
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 1 }))
              .animation({ duration: 300, curve: Curve.FastOutSlowIn }),
            // 退场：左右横向收窄（切换内核时） //
            TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0, y: 1 }))
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })
          ))
          // 点击确定后的退出：向上渐变消失（由 exiting 状态驱动） //
          .opacity(this.exiting ? 0 : 1)
          .translate({ y: this.exiting ? -60 : 0 })
          .animation(this.exiting ? { duration: 400, curve: Curve.FastOutSlowIn } : { duration: 0 })

        }

      }
      .width('100%').height('36vp')
      .justifyContent(FlexAlign.Center)

      /////////////
      // 确定按钮 //
      ////////////
      Button('确定')
        .width('144vp')
        .height('72vp')
        .backgroundColor(this.selected !== -1 ? 'rgba(244, 198, 206, 1.0)' : '#eee')
        .borderRadius('36vp')
        .fontSize('20fp')
        .fontColor(this.selected !== -1 ? '#ffffff' : '#999')
        .opacity(this.showButton ? 1 : 0)
        .translate({ y: this.showButton ? 0 : (this.exiting ? -60 : 60) })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })
        .onClick(() => {
          if (this.selected === -1) {return}

          if (this.selected == 0) {this.global_config!.player_mode = false}
          if (this.selected == 1) {this.global_config!.player_mode = true}

          // 关闭可能打开的 DSD 弹窗 //
          this.closeDsaOverlay()

          // DSD 选项行跟随页面一起向上渐变退出（由 exiting 驱动） //
          this.exiting = true
          this.showTitle = false
          this.showOptions = false
          this.showButton = false
          setTimeout(() => { this.page = 999 }, 500)
        })

      }
      .width('100%').height('100%')
      .padding({ left: 32, right: 32, top: 56, bottom: 24 })
      .backgroundColor('#fff')
      .justifyContent(FlexAlign.SpaceAround)

      ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
      // DSD详细信息弹窗 //
      //////////////////
      if (this.showDsaInfo) {

        // 模糊遮罩层 //
        Column() {

          // 信息卡 //
          Column() {

            // 标题 //
            Text('DSD 转码说明')
              .fontSize('16vp')
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .width('100%').textAlign(TextAlign.Start)

            Text('').height('10vp')

            // 内容 //
            Text('将dsd音频转码成352.8khz 32bit wav文件进行播放。')
              .fontSize('14vp')
              .fontColor('#666')
              .width('100%').textAlign(TextAlign.Start)

            Text('').height('16vp')

            // 关闭按钮 //
            Button('我知道了')
              .width('100%').height('40vp')
              .fontSize('15vp').fontColor('#ffffff')
              .backgroundColor('rgba(244, 198, 206, 1.0)')
              .borderRadius('20vp')
              .onClick(() => { this.closeDsaOverlay() })

          }
          .width('72%')
          .backgroundColor('#ffffff')
          .borderRadius('12vp')
          .padding('16vp')
          .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.15)', offsetY: 4 })
          .opacity(this.showDsaOverlay ? 1 : 0)
          .scale({ x: this.showDsaOverlay ? 1 : 0.92, y: this.showDsaOverlay ? 1 : 0.92 })
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })

        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .backdropBlur(8)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .zIndex(999)
        .opacity(this.showDsaOverlay ? 1 : 0)
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => { this.closeDsaOverlay() })

      }

    }
    .width('100%').height('100%')
  }
}
