//
// 更多设置页面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //

// 导入自创建模块 //

// 导入类 //

// 变量池 //

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更多设置入口 //
//////////////
@Component
export default struct setting_more {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Column() {
      Scroll() {
        Column() {

          Blank('56vp')

          // ---- 提示文字 ----
          Text('还没想好设置什么')
            .fontSize('18fp')
            .fontWeight(FontWeight.Medium)
            .fontColor('#999999')

          Blank('24vp')

          // ---- ASCII art 框 ----
          Column() {
            Text('╱|、')
              .fontSize('14fp')
              .fontColor('#999999')
              .lineHeight('18fp')
            Text('(˚ˎ 。7  ')
              .fontSize('14fp')
              .fontColor('#999999')
              .lineHeight('18fp')
            Text('  |、˜〵')
              .fontSize('14fp')
              .fontColor('#999999')
              .lineHeight('18fp')
            Text('  じしˍ,)ノ')
              .fontSize('14fp')
              .fontColor('#999999')
              .lineHeight('18fp')
          }
          .alignItems(HorizontalAlign.Start)

        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor('#F1F3F5')
  }
}
