//
// start界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { picker, fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
/////////////////
import { log, notice, vib } from '../package/system_function'
import { make_music_cache } from '../package/file_manager'

///////////
// 变量池 //
//////////
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path // 根目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

//////////////////
// 资源目录创建器 //
/////////////////
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
export default struct arkmusic_start {

  ///////////
  // 变量池 //
  //////////

  ///////////
  // 更新池 //
  //////////
  @State is_first: boolean = false    // 第一次启动
  @State dir_ready: boolean = false    // 环境指示器（是否初始化）

  @State cache_ready: boolean = false   // 临时！目录准备指示器

  ///////////
  // 继承池 //
  //////////
  @Prop context: common.UIAbilityContext    // 身份证
  @Link ready: boolean    // 环境准备指示器

  ////////
  // 类 //
  ///////
  private ark_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private dir_create_downloader: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();   // 下载器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //////////
  // 开始 //
  /////////
  async aboutToAppear() {
    // 扫描工作目录
    try {
      fs.openSync(getContext().filesDir + '/version.json', fs.OpenMode.READ_ONLY)
      this.ready = true
    } catch {
      // 没有，进入向导
      log('目录没有文件。')
      this.is_first = true
      // 扫描目录
      await make_music_cache()
      // 创建version
      const file = fs.openSync(getContext().filesDir + '/version.json', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, '')
      fs.closeSync(file)
      // 结束，放行
      this.cache_ready = true
    }
  }


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {

      //////////////
      // 初始化遮罩 //
      //////////////
      Column() { Image($r('app.media.foreground_backup')).width('256px').height('256px') }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 }).zIndex(500)
        .backgroundColor('#fff').justifyContent(FlexAlign.Center)
        .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))

      //////////////
      // 初始化向导 //
      //////////////
      if (this.is_first) {
        Column() {
          Image($r('app.media.foreground_backup')).width('512px').height('512px')
          if (this.cache_ready) {
            Button('开始使用')
              .width('144vp')
              .height('72vp')
              .backgroundColor('rgba(244, 198, 206, 1.0)')
              .onClick(() => {
                this.ready = true
              })
          }
        }
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
          .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))
      }

      ///////////////////////
      // 目录初始化页（函数） //
      /////////////////////
      if (!this.dir_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(100)
          .onPageEnd(async () => {
            // 尝试读取目录
            try {
              fs.listFileSync(root_path);
              this.dir_ready = true
            } catch (e) {   // 读取失败，创建目录
              console.log(`目录不存在：${e}`)
              console.log('准备创建...')
              try {
                // 调用创建器
                this.dir_create_downloader.onBeforeDownload((webDownloadItem: webview.WebDownloadItem) => {
                  getDownloadPathFromPicker().then((downloadPath) => {
                    webDownloadItem.start(downloadPath + '/' + webDownloadItem.getSuggestedFileName());
                  });
                })
                this.dir_create_downloader.onDownloadFinish(() => {
                  // 检测
                  try {
                    fs.listFileSync(root_path);
                    log('download初始化完成.')
                    notice('初始化完成.')
                    this.dir_ready = true
                  } catch (e) {
                    log(`检测失败：${e}`, 'error')
                    notice(`初始化失败：${e}`)
                  }
                })
                this.ark_music_ui.setDownloadDelegate(this.dir_create_downloader);
              } catch (error) {
                console.error(`创建出错: ${error}`);
              }
              this.ark_music_ui.runJavaScript('download()')

            }
          })
      }

    }
  }
}