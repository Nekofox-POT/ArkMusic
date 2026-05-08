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
import { make_music_cache } from '../package/file_manager_old'
import { files_manager } from '../package/files_manager'

///////////
// 变量池 //
//////////
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.arkmusic/').path // 根目录

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
export default struct ark_music_start {

  ///////////
  // 变量池 //
  //////////

  ///////////
  // 更新池 //
  //////////
  @State msg: string = '准备'    // 第一次启动
  @State @Watch('env_ready')dir_ready: boolean = false    // 环境指示器（下载目录是否初始化）
  @State @Watch('env_ready')version_ready: boolean = false  // 版本号校验完成器
  @State @Watch('env_ready')files_manager_ready: boolean = false  // 文件加载器完成

  ///////////
  // 继承池 //
  //////////
  @Link @Watch('env_ready')first_start: boolean  // 首次启动指示器
  @Link ready: boolean    // 环境准备指示器

  ////////
  // 类 //
  ///////
  private ark_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  private dir_create_downloader: webview.WebDownloadDelegate = new webview.WebDownloadDelegate()

  ///////////
  // 继承类 //
  //////////
  @ObjectLink files_manager: files_manager  // 类 文件管理器

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ////////////
  // 基础类 //
  //////////
  // 开始 //
  async env_load() {
    // 加载files_manager //
    this.reg_files_manager()
    // 版本号校验 //
    log('校验版本号')
    try {
      // 获取版本号
      let tmp = fs.readTextSync(getContext().filesDir + '/version.json')
    }
    // 获取失败，视为第一次启动
    catch {
      this.first_start = true
      // 写入版本号
      try {
        const file = fs.openSync(getContext().filesDir + '/version.json', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
        fs.writeSync(file.fd, '0.6.0')
        fs.closeSync(file)
      } catch (e) {
        log(`版本号保存失败: ${e}`, 'error')
      }
    }
    // 就绪
    this.version_ready = true
  }

  ////////////
  // 扩展类 //
  //////////
  // files_manager注册 //
  async reg_files_manager() {
    this.files_manager.load_data()
    this.files_manager_ready = true
  }

  // ready指示 //
  env_ready() {
    // 三样素集齐才能放行
    if (this.version_ready && this.dir_ready && this.files_manager_ready && !this.first_start) {
      this.ready = true
    }
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
      .position({ x: 0, y: 0 }).zIndex(900)
      .backgroundColor('#fff').justifyContent(FlexAlign.SpaceAround)
      .transition(TransitionEffect.opacity(0).animation({ duration: 500 }))

      ///////////////////////
      // 目录初始化页（函数） //
      /////////////////////
      if (!this.dir_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })
          .zIndex(100)
          .onPageEnd(async () => {
            // 加载加载程序
            this.env_load()
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