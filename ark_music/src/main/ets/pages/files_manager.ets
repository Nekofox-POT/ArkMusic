// 模块池 //
import { bundleManager } from '@kit.AbilityKit';
import { picker, fileUri } from  '@kit.CoreFileKit';
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit';

// 变量池 //
const support_audio_Format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path
export let all_music: string[][] = []

// 函数块 //
// 文件夹加载器
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

// 检测是否有download目录
export function get_download(): boolean {
  console.log('正在扫描目录...')
  try {
    // 尝试读取目录
    fs.listFileSync(root_path);
    // 目录可用，扫描歌曲
    console.log('目录存在。')
    scan_all_files();
    // 关闭加载页
    return false;
  } catch (e) {
    console.log(`目录不存在：“${e}”`)
    console.log('请求创建...')
    return true;
  }
}

// 扫描download里的歌曲（全覆盖模式）
export function scan_all_files() {
  // 创建临时map列表
  scan_all_songs()
}

// 扫描歌曲（模式1：所有）
export function scan_all_songs() {

  console.log('正在扫描所有歌曲')
  // 创建临时列表
  let tmp_all_music: string[][] = [];
  // 扫描当前地址目录
  let filenames = fs.listFileSync(root_path, { recursion: true });

  // 处理识别音频是否有效，如果有效则添加
  for (const i of filenames) {
    const tmp = root_path + i;
    if (fs.statSync(tmp).isFile()) {
      // 获取后缀
      let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase();
      // 解析后缀
      if (support_audio_Format.includes(file_suffix)) {
        // 添加
        try { tmp_all_music.push([tmp, fs.openSync(tmp).name]) } catch {}
      }
    }
  }
  // 覆盖原表
  all_music = tmp_all_music;
  console.log('所有歌曲更新完成！')

}

// 扫面歌曲（模式2：分层次结构）
export function scan_dir_songs(path: string = ''): string[][] {

  let tmp_dir: string[][] = [];
  let tmp_file: string[][] = [];

  // 扫描
  console.log(root_path + path)
  let filenames = fs.listFileSync(root_path + path);
  console.log('#1')
  console.log(`${filenames}`)
  // 分类判断
  for (const i of filenames) {
    let tmp = root_path + path + '/' + i;
    console.log('#2')
    console.log(tmp)
    // 如果是文件夹
    if (fs.statSync(tmp).isDirectory()) {
      // 导入
      try { tmp_dir.push(['true', tmp, fs.openSync(tmp).name]) } catch {}
    } else {
      // 如果不是
      // 获取后缀
      let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase();
      // 解析后缀如果为音频文件
      if (support_audio_Format.includes(file_suffix)) {
        // 添加
        try { tmp_file.push(['true', tmp, fs.openSync(tmp).name]) } catch {}
      } else if (file_suffix == '.m3u') {
        // 如果文件后缀是m3u
        // 作为文件夹导入
        try { tmp_dir.push(['true', tmp, fs.openSync(tmp).name]) } catch {}
      }
    }
  }
  // 合并数组
  let tmp_list: string[][] = [...tmp_dir, ...tmp_file];
  // 返回
  return tmp_list;
}