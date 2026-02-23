//
// ArkMusic主界面
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { webview } from '@kit.ArkWeb';
import { picker, fileUri } from  '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import media from '@ohos.multimedia.media';
import { avSession } from '@kit.AVSessionKit';

//////////////////
// 导入自创建模块 //
/////////////////
import { notice, vib } from '../background_pages/system_function'

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
// 主页面入口 //
//////////////
@Entry
@Component
struct Index {
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  ///////////
  // 变量池 //
  //////////
  status: Boolean = false   // 状态
  play_status: boolean = false  // 播放状态

  ///////////
  // 更新池 //
  //////////
  @State ui_ready: boolean = false    // 准备指示器
  @State dir_ready: boolean = false   // 目录初始化指示器

  ////////
  // 类 //
  ///////
  ark_music_ui: webview.WebviewController = new webview.WebviewController()   // web界面
  dir_create_downloader: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();   // 下载器
  avPlayer: media.AVPlayer | null = null; // audio播放
  session: avSession.AVSession | null = null; // 状态栏

  ///////////////
  // audio模块 //
  //////////////
  async audio_set(path: string) {
    try {
      // 检查文件源
      const tmp_fd = fs.openSync(path).fd;
      const tmp_size = fs.statSync(tmp_fd).size;
      // 检查对象
      if (this.avPlayer) {
        console.log(`已存在对象，进行销毁`);
        // 销毁audio
        await this.avPlayer.release();
        // 重置播放状态
        this.play_status = false;
        console.log("资源销毁完成.");
      }
      // 创建avPlayer。
      console.log('创建audio.');
      this.avPlayer = await media.createAVPlayer();
      // 注册回调函数
      console.log('注册回调')
      await this.setAVPlayerCallback((avPlayer: media.AVPlayer) => {});
      // 设置播放源
      console.log('设置播放源')
      this.avPlayer.fdSrc = {fd: tmp_fd, offset: 0, length: tmp_size};
    } catch (e) {
      console.log(`装载失败：${e}`)
      notice(`文件读取失败：${e}`)
    }
  }
  async setAVPlayerCallback(callback: (avPlayer: media.AVPlayer) => void) {

    // 添加保险
    if (!this.avPlayer) { return; }

    // 状态机变化（主）
    this.avPlayer.on('stateChange', async (state: string, reason: media.StateChangeReason) => {
      // 添加保险
      if (!this.avPlayer) { return; }
      // 状态分类
      switch (state) {
        case 'idle': // audio闲置
          console.log('audio闲置了');
          break;
        case 'initialized': // audio初始化
          console.log('audio正在初始化');
          this.avPlayer.prepare();
          break;
        case 'prepared': // audio准备就绪
          console.log('audio准备就绪。')
          callback(this.avPlayer);
          console.log('callback设置成功，等待audio播放。')
          this.avPlayer.play();
          break;
        case 'playing': // audio播放
          console.log('audio正在播放~')
          this.play_status = true;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PLAY })
          this.ark_music_ui.runJavaScript(`change_play_status('play')`);
          break;
        case 'paused':  // audio暂停
          console.log('audio暂停了！')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
          this.ark_music_ui.runJavaScript(`change_play_status('pause')`);
          break;
        case 'completed': // 播放结束后触发该状态机上报
          console.log('audio播放完了。')
          this.play_status = false;
          this.session?.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE })
        case 'stopped':
          console.log('audio已结束工作，等待销毁...')
          break
        case 'released':
          console.log('audio被销毁了！')
          break
        case 'error':
          console.error(`audio call出现了错误。`);
          break
      }
    });

    // 跳转处理
    this.avPlayer.on('seekDone', (seekDoneTime) => {
      console.log(`audio跳转了，跳转至"${seekDoneTime}"`);
    });
    // 音频焦点切换处理
    this.avPlayer.on('audioInterrupt', () => {
      console.log('audio被中断了！')
      if (!this.play_status) {
        this.avPlayer?.play();
      }
    });
    // 错误处理
    this.avPlayer.on('error', (e) => {
      console.error(`audio发生错误：${e}`);
      // 重置
      this.avPlayer?.reset();
    });
    // 总时长更新
    this.avPlayer.on('durationUpdate', (time: number) => {
      // this.session?.setAVMetadata({ assetId: `${this.play_list_index}`, duration: time })
      this.ark_music_ui.runJavaScript(`update_duration_time(${time})`)
    });
    // 进度条时长更新
    this.avPlayer.on('timeUpdate', (time: number) => {
      this.session?.setAVPlaybackState({ position: { elapsedTime: time, updateTime: new Date().getTime() } })
      this.ark_music_ui.runJavaScript(`update_current_time(${time})`)
    });
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // UI构建 //
  ///////////
  build() {
    Row() {


      /////////////
      // 准备界面 //
      ////////////
      if (!this.ui_ready) {
        Column() { Image($r('app.media.foreground_backup')).width('256px').height('256px') }
        .width('100%')
        .height('100%')
        .zIndex(990)
        .position({ x: 0, y: 0 })
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#fff')
        .transition(
          TransitionEffect.opacity(0)
            .animation({ duration: 500 })
        )
      }

      /////////////
      // web界面 //
      ////////////
      if (this.dir_ready) {
        Web({ src: $rawfile("webview_gui/index.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 }).zIndex(900)
          .zoomAccess(false)
          .onPageEnd( () => {
            this.ui_ready = true
          })
      }

      //////////////////
      // 目录初始化页面 //
      /////////////////
      if (!this.dir_ready) {
        Web({ src: $rawfile("download_dir_create.html"), controller: this.ark_music_ui })
          .width('100%').height('100%')
          .position({ x: 0, y: 0 })
          .onPageEnd(async () => {
            // 尝试读取目录
            try {
              console.log('检测目录...')
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
                  console.info("创建完成！")
                  // 检测
                  try {
                    fs.listFileSync(root_path);
                    console.log('初始化完成.')
                    notice('初始化完成.')
                    this.dir_ready = true
                  } catch (e) {
                    console.log(`检测失败：${e}`)
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


      /////////////
      // 测试按钮 //
      ////////////
      // Button()
      //   .width('200vp')
      //   .height('100vp')
      //   .onClick(() => {
      //     if (this.status) {
      //       this.status = false
      //       this.ark_music_ui.runJavaScript('taskbar_double(false)')
      //     } else {
      //       this.status = true
      //       this.ark_music_ui.runJavaScript('taskbar_double(true)')
      //     }
      //   })
      //   .zIndex(999)
      //   .position({ x: 0, y: 0 })

    }
  }
}