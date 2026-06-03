//
// start界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { webview } from '@kit.ArkWeb'
import { picker, fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
/////////////////
import { log, notice } from '../package/system_function'
import { class_files_manager } from '../package/class_files_manager'
import { class_audio_player } from '../package/class_audio_player/class_audio_player'
import { emitter } from '@kit.BasicServicesKit'

///////////
// 变量池 //
//////////
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.linmusic/').path // 根目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// 资源目录创建器 //
export function getDownloadPathFromPicker(): Promise<string> {
  return new Promise<string>(resolve => {
    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      const documentPicker = new picker.DocumentViewPicker();
      documentPicker.save(documentSaveOptions).then(async (documentSaveResult: Array<string>) => {
        if (documentSaveResult.length <= 0) {
          resolve('');
          return;
        }
        const uriString = documentSaveResult[0];
        if (!uriString) {
          resolve('');
          return;
        }
        const uri = new fileUri.FileUri(uriString);
        resolve(uri.path);
      }).catch((err: BusinessError) => {
        console.error(`ErrorCode: ${err.code},  Message: ${err.message}`);
        resolve('');
      });
    } catch (error) {
      resolve('');
    }
  })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 开始界面入口 //
///////////////
@Component
export default struct lin_music_start {

  // 变量池 //

  // 更新池 //
  @State msg: string = '准备'    // 第一次启动
  @State @Watch('reg_files_manager')dir_ready: boolean = false    // 环境指示器（下载目录是否初始化）

  // 继承池 //
  @Link ready: boolean    // 环境准备指示器

  // 类 //
  private lin_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private dir_create_downloader: webview.WebDownloadDelegate = new webview.WebDownloadDelegate()

  // 继承类 //
  @ObjectLink files_manager: class_files_manager  // 类 文件管理器
  @ObjectLink lin_music_player: class_audio_player  // 播放器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ////////////
  // 基础类 //
  //////////
  aboutToAppear(): void {
    // 开启监听
    emitter.on({ eventId: 812 }, (eventData: emitter.EventData) => {this.msg = eventData.data?.msg})
  }
  aboutToDisappear(): void {
    // 关闭监听
    emitter.off(812)
  }

  ////////////
  // 扩展类 //
  //////////
  // files_manager注册 //
  async reg_files_manager() {
    await this.files_manager.load_data()
    this.ready = true
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      ///////////////
      // 初始化遮罩 //
      /////////////
      Column() {

        // logo
        Image($r('app.media.icon_white')).width('512px').height('512px')
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
      .position({ x: 0, y: 0 }).zIndex(900)
      .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
      .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))

      ///////////////////////
      // 目录初始化页（函数） //
      /////////////////////
      if (!this.dir_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: this.lin_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(100)
          .onPageEnd(async () => {
            // 尝试读取目录
            try {
              fs.listFileSync(root_path)
              this.dir_ready = true
            } catch (e) {   // 读取失败，创建目录
              log(`目录不存在：${e}`, 'error')
              try {
                // 调用创建器
                this.dir_create_downloader.onBeforeDownload((webDownloadItem: webview.WebDownloadItem) => {
                  getDownloadPathFromPicker().then((downloadPath) => {
                    webDownloadItem.start(downloadPath + '/' + webDownloadItem.getSuggestedFileName())
                  });
                })
                this.dir_create_downloader.onDownloadFinish( async () => {
                  // 检测
                  try {
                    fs.listFileSync(root_path)
                    log('download初始化完成.')
                    notice('初始化完成.')
                    this.dir_ready = true
                  } catch (e) {
                    log(`检测失败：${e}`, 'error')
                    notice(`初始化失败：${e}`)
                  }
                })
                this.lin_music_ui.setDownloadDelegate(this.dir_create_downloader)
              } catch (error) {
                console.error(`创建出错: ${error}`)
              }
              this.lin_music_ui.runJavaScript('download()')

            }
          })
      }

    }
  }
}