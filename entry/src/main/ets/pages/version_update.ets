//
// 版本更新页
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //

// 导入类 //
import class_global_config from '../package/class_global_config'

// 导入页 //

// 变量池 //
const version_path = getContext().filesDir + '/version.cfg'   // 配置文件
const old_version_path = getContext().filesDir + '/version.json'   // 配置文件

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主页面入口 //
//////////////
@Component
@Preview
export default struct version_update {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //
  @State update_0p8: boolean = false

  // 继承池 //
  @Link version_ready: boolean
  @ObjectLink global_config: class_global_config

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 基础函数 //
  ////////////

  // 进入app操作（） //
  aboutToAppear(): void {this.version_check()}

  // 退出app操作 //
  aboutToDisappear(): void {}

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 扩展函数 //
  ////////////

  // 版本号检查 //
  version_check() {

    // 检查文件是否存在 //
    try {let tmp = fs.readTextSync(version_path)
      // 文件存在

      // 检查版本号 //（下一次施工）

      // 完成 //
      this.version_ready = true

    } catch {
      // 文件不存在

      // 0.7版本修复(正式版该移除了) //
      try {
        fs.readTextSync(old_version_path)
        this.update_0p8 = true
      } catch {} // 真没有版本号，那就不管

      // 创建配置文件 //
      // const file = fs.openSync(version_path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      // fs.writeSync(file.fd, '0.8')
      // fs.closeSync(file)

      // 完成 //
      this.version_ready = true

    }

  }


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Stack() {

      // 0.7 → 0.8 更新简介 //
      if (this.update_0p8) {

        // 遮罩层 //
        Column() {

          // 更新说明卡 //
          Column() {

            // 标题（顶层） //
            Text('Version 0.8 更新内容：')
              .fontSize('18vp').fontColor('#000000')
              .fontWeight(FontWeight.Bold)
              .width('100%').textAlign(TextAlign.Start)

            // 间隔 //
            Text('').height('12vp')

            // 内容区（凹陷灰底，中间层） //
            Column() {

              // 更新内容 //
              Text('内核进行系统性重构。')
                .fontSize('14vp').fontColor('#333333')
                .width('100%').textAlign(TextAlign.Start)

              Text('添加全新"铃音"播放内核')
                .fontSize('14vp').fontColor('#333333')
                .width('100%').textAlign(TextAlign.Start)

              // 分割间隔 //
              Text('').height('12vp')

              // 警告文字（红） //
              Text('因内核进行系统性重构，现需要重置数据库，点击"确定"来进行重置。')
                .fontSize('14vp').fontColor('#e60012')
                .width('100%').textAlign(TextAlign.Start)

              Text('').height('4vp')

              // 小字提示（红） //
              Text('重置后程序会退出，请您再手动重新打开程序。')
                .fontSize('11vp').fontColor('#c00010')
                .width('100%').textAlign(TextAlign.Start)

            }
            .width('100%')
            .backgroundColor('#f2f2f2')
            .borderRadius('8vp')
            .padding('12vp')

            // 间隔 //
            Text('').height('16vp')

            // 重置按钮（胶囊形，底层） //
            Button('重置')
              .fontSize('15vp').fontColor('#e60012')
              .backgroundColor('rgba(244, 198, 206, 1.0)')
              .borderRadius('22vp')
              .height('44vp')
              .onClick(() => {this.global_config.reset_app()})

          }
          .width('80%')
          .backgroundColor('#ffffff')
          .borderRadius('12vp')
          .padding('16vp')

        }
        .zIndex(990)
        .width('100%').height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.4)').backdropBlur(8)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

      }

    }
    .width('100%').height('100%')
  }
}