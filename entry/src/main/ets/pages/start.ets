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
import nativeModule from 'libentry.so'
import { log, notice, vib } from '../package/system_function'
import { make_music_cache } from '../package/file_manager_old'
import { files_manager } from '../package/files_manager/files_manager'
import { get_image, get_meta } from '../package/meta_manager'

///////////
// 变量池 //
//////////
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.arkmusic/').path // 根目录
const root_path = getContext().filesDir + '/files_manager'
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']

// 字符权重池（比较用）
enum CharType {
  PUNCTUATION = 0, // 符号（包含 '.'）
  DIGIT = 1,       // 数字
  LETTER = 2,      // 字母
  CHINESE = 3      // 中文
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

//////////////////
// 资源目录创建器 //
/////////////////
function getDownloadPathFromPicker(): Promise<string> {
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

// 字符比较器 //
function getCharWeight(char: string): number {

  enum CharType {
    PUNCTUATION = 0, // 符号（包含 '.'）
    DIGIT = 1,       // 数字
    LETTER = 2,      // 字母
    CHINESE = 3      // 中文
  }

  if (!char) return CharType.CHINESE; // 兜底空字符串

  const code = char.charCodeAt(0);

  // 1. 符号 (ASCII 0-47, 58-64, 91-96, 123-127 等)
  // 这里把所有非字母数字中文的常见字符都归为符号
  if ((code >= 33 && code <= 47) ||
    (code >= 58 && code <= 64) ||
    (code >= 91 && code <= 96) ||
    (code >= 123 && code <= 126)) {
    return CharType.PUNCTUATION;
  }

  // 2. 数字 (0-9)
  if (code >= 48 && code <= 57) {
    return CharType.DIGIT;
  }

  // 3. 字母 (A-Z, a-z)
  if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
    return CharType.LETTER;
  }

  // 4. 中文 (按照 Unicode 范围，基本涵盖了常用汉字)
  if ((code >= 0x4E00 && code <= 0x9FFF) ||
    (code >= 0x3400 && code <= 0x4DBF) ||
    (code >= 0x20000 && code <= 0x2A6DF)) {
    return CharType.CHINESE;
  }

  // 其他未知的罕见字符也当做符号处理，排在前面
  return CharType.PUNCTUATION;
}
// 列表排序器 //
function customCompare(strA: string, strB: string): number {
  const lenA = strA.length;
  const lenB = strB.length;
  const minLen = Math.min(lenA, lenB);

  // 逐个字符进行比较
  for (let i = 0; i < minLen; i++) {
    const charA = strA.charAt(i);
    const charB = strB.charAt(i);

    const weightA = getCharWeight(charA);
    const weightB = getCharWeight(charB);

    // 如果类型不同，直接按类型权重排序（符号->数字->字母->中文）
    if (weightA !== weightB) {
      return weightA - weightB;
    }

    // 如果类型相同，进行组内比较
    if (weightA === CharType.LETTER) {
      // 字母组：不区分大小写比较
      const lowerA = charA.toLowerCase();
      const lowerB = charB.toLowerCase();
      if (lowerA < lowerB) return -1;
      if (lowerA > lowerB) return 1;
    } else if (weightA === CharType.CHINESE) {
      // 中文组：使用手机系统的本地化排序（通常是拼音排序）
      // 注意：ArkTS 中使用 Intl.Collator 是安全的
      const collator = new Intl.Collator('zh-CN');
      const cmp = collator.compare(charA, charB);
      if (cmp !== 0) return cmp;
    } else {
      // 符号组和数字组：直接按 Unicode 码点比较（符号按ASCII表，数字按0-9）
      if (charA < charB) return -1;
      if (charA > charB) return 1;
    }
  }

  // 如果前面字符都一样，短的排在前面 (例如 ".txt" 排在 ".txta" 前面)
  return lenA - lenB;
}

// 环境注册 //
async function make_files_env(): Promise<[
  string[],
  Map<string, string[]>,
  Map<string, string[]>,
  Map<string, string[]>,
  Map<string, string[]>,
  Map<string, string[]>
]> {

  // 初始化变量
  let all_songs_list: string[] = []
  let play_list = new Map<string, string[]>()
  let artist_composer_list = new Map<string, string[]>()
  let album_list = new Map<string, string[]>()
  let album_artist_list = new Map<string, string[]>()
  let genre_list = new Map<string, string[]>()
  let dsd_list: string[] = []

  // 初始化数据库
  try {fs.rmdirSync(root_path + '/play_list')} catch {}
  fs.mkdirSync(root_path + '/play_list')
  try {fs.rmdirSync(root_path + '/artist_composer')} catch {}
  fs.mkdirSync(root_path + '/artist_composer')
  try {fs.rmdirSync(root_path + '/album')} catch {}
  fs.mkdirSync(root_path + '/album')
  try {fs.rmdirSync(root_path + '/album_artist')} catch {}
  fs.mkdirSync(root_path + '/album_artist')
  try {fs.rmdirSync(root_path + '/genre')} catch {}
  fs.mkdirSync(root_path + '/genre')
  try {fs.rmdirSync(root_path + '/dsd_cache')} catch {}
  fs.mkdirSync(root_path + '/dsd_cache')

  // 扫描歌曲(普通歌曲) //
  log('扫描普通歌曲')
  const raw_audio_list = fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_audio_format } })
  for (let i = 0; i < raw_audio_list.length; i++) {

    const full_path = song_path + '/' + raw_audio_list[i]

    // 添加所有歌曲列
    log(`正在处理：${raw_audio_list[i]}`)
    all_songs_list.push(full_path)

    // 获取元数据
    const tmp_meta = await get_meta(full_path)
    if (!tmp_meta[1] || tmp_meta[1].length === 0) { continue }
    // 分类 歌手 / 作曲家
    if (!artist_composer_list.has(tmp_meta[1][1])) { artist_composer_list.set(tmp_meta[1][1], [])}
    artist_composer_list.get(tmp_meta[1][1])?.push(full_path)
    // 分类 专辑
    if (!album_list.has(tmp_meta[1][2])) { album_list.set(tmp_meta[1][2], [])}
    album_list.get(tmp_meta[1][2])?.push(full_path)
    // 分类 专辑作家
    if (!album_artist_list.has(tmp_meta[1][3])) { album_artist_list.set(tmp_meta[1][3], [])}
    album_artist_list.get(tmp_meta[1][3])?.push(full_path)
    // 分类 流派
    if (!genre_list.has(tmp_meta[1][4])) { genre_list.set(tmp_meta[1][4], [])}
    genre_list.get(tmp_meta[1][4])?.push(full_path)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < raw_audio_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }
  for (let i = 0; i < raw_audio_list.length; i++) {

    const full_path = song_path + '/' + raw_audio_list[i]

    // 添加所有歌曲列
    log(`正在处理：${raw_audio_list[i]}`)
    all_songs_list.push(full_path)

    // 获取元数据
    const tmp_meta = await get_meta(full_path)
    if (!tmp_meta[1] || tmp_meta[1].length === 0) { continue }
    // 分类 歌手 / 作曲家
    if (!artist_composer_list.has(tmp_meta[1][1])) { artist_composer_list.set(tmp_meta[1][1], [])}
    artist_composer_list.get(tmp_meta[1][1])?.push(full_path)
    // 分类 专辑
    if (!album_list.has(tmp_meta[1][2])) { album_list.set(tmp_meta[1][2], [])}
    album_list.get(tmp_meta[1][2])?.push(full_path)
    // 分类 专辑作家
    if (!album_artist_list.has(tmp_meta[1][3])) { album_artist_list.set(tmp_meta[1][3], [])}
    album_artist_list.get(tmp_meta[1][3])?.push(full_path)
    // 分类 流派
    if (!genre_list.has(tmp_meta[1][4])) { genre_list.set(tmp_meta[1][4], [])}
    genre_list.get(tmp_meta[1][4])?.push(full_path)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < raw_audio_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }
  for (let i = 0; i < raw_audio_list.length; i++) {

    const full_path = song_path + '/' + raw_audio_list[i]

    // 添加所有歌曲列
    log(`正在处理：${raw_audio_list[i]}`)
    all_songs_list.push(full_path)

    // 获取元数据
    const tmp_meta = await get_meta(full_path)
    if (!tmp_meta[1] || tmp_meta[1].length === 0) { continue }
    // 分类 歌手 / 作曲家
    if (!artist_composer_list.has(tmp_meta[1][1])) { artist_composer_list.set(tmp_meta[1][1], [])}
    artist_composer_list.get(tmp_meta[1][1])?.push(full_path)
    // 分类 专辑
    if (!album_list.has(tmp_meta[1][2])) { album_list.set(tmp_meta[1][2], [])}
    album_list.get(tmp_meta[1][2])?.push(full_path)
    // 分类 专辑作家
    if (!album_artist_list.has(tmp_meta[1][3])) { album_artist_list.set(tmp_meta[1][3], [])}
    album_artist_list.get(tmp_meta[1][3])?.push(full_path)
    // 分类 流派
    if (!genre_list.has(tmp_meta[1][4])) { genre_list.set(tmp_meta[1][4], [])}
    genre_list.get(tmp_meta[1][4])?.push(full_path)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < raw_audio_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }
  for (let i = 0; i < raw_audio_list.length; i++) {

    const full_path = song_path + '/' + raw_audio_list[i]

    // 添加所有歌曲列
    log(`正在处理：${raw_audio_list[i]}`)
    all_songs_list.push(full_path)

    // 获取元数据
    const tmp_meta = await get_meta(full_path)
    if (!tmp_meta[1] || tmp_meta[1].length === 0) { continue }
    // 分类 歌手 / 作曲家
    if (!artist_composer_list.has(tmp_meta[1][1])) { artist_composer_list.set(tmp_meta[1][1], [])}
    artist_composer_list.get(tmp_meta[1][1])?.push(full_path)
    // 分类 专辑
    if (!album_list.has(tmp_meta[1][2])) { album_list.set(tmp_meta[1][2], [])}
    album_list.get(tmp_meta[1][2])?.push(full_path)
    // 分类 专辑作家
    if (!album_artist_list.has(tmp_meta[1][3])) { album_artist_list.set(tmp_meta[1][3], [])}
    album_artist_list.get(tmp_meta[1][3])?.push(full_path)
    // 分类 流派
    if (!genre_list.has(tmp_meta[1][4])) { genre_list.set(tmp_meta[1][4], [])}
    genre_list.get(tmp_meta[1][4])?.push(full_path)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < raw_audio_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }
  for (let i = 0; i < raw_audio_list.length; i++) {

    const full_path = song_path + '/' + raw_audio_list[i]

    // 添加所有歌曲列
    log(`正在处理：${raw_audio_list[i]}`)
    all_songs_list.push(full_path)

    // 获取元数据
    const tmp_meta = await get_meta(full_path)
    if (!tmp_meta[1] || tmp_meta[1].length === 0) { continue }
    // 分类 歌手 / 作曲家
    if (!artist_composer_list.has(tmp_meta[1][1])) { artist_composer_list.set(tmp_meta[1][1], [])}
    artist_composer_list.get(tmp_meta[1][1])?.push(full_path)
    // 分类 专辑
    if (!album_list.has(tmp_meta[1][2])) { album_list.set(tmp_meta[1][2], [])}
    album_list.get(tmp_meta[1][2])?.push(full_path)
    // 分类 专辑作家
    if (!album_artist_list.has(tmp_meta[1][3])) { album_artist_list.set(tmp_meta[1][3], [])}
    album_artist_list.get(tmp_meta[1][3])?.push(full_path)
    // 分类 流派
    if (!genre_list.has(tmp_meta[1][4])) { genre_list.set(tmp_meta[1][4], [])}
    genre_list.get(tmp_meta[1][4])?.push(full_path)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < raw_audio_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }

  // 防kill
  await new Promise<void>(r => setTimeout(r, 500))

  // 扫描歌曲(dsd) //
  log('扫描dsd')
  for (const i of fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_dsd_format } })) {
    console.log('有dsd音频！')
  }

  // 防kill
  console.log('休息！')
  await new Promise<void>(r => setTimeout(r, 500))

  // 扫描歌单(m3u) //
  log('扫描m3u列表')
  const raw_song_list = fs.listFileSync(song_path, { recursion: true, filter: { suffix: ['.m3u'] } })
  for (let i = 0; i < raw_song_list.length; i++) {

    // 尝试读取
    try {fs.readTextSync(song_path + raw_song_list[i])} catch {continue}

    // 注册环境
    let tmp_play_list: string[] = []
    const tmp_path = song_path + raw_song_list[i]
    const tmp_env = tmp_path.substring(0, tmp_path.lastIndexOf('/') + 1)
    let tmp_name = nativeModule.extractFilename(tmp_path)
    const tmp_list = fs.readTextSync(tmp_path).replace(/\r\n/g, '\n').split('\n').filter(Boolean)

    // 读取
    for (let e = 0; e < tmp_list.length; e++) {

      // 格式化
      const tmp = tmp_env + '/' + tmp_list[e].replaceAll('\\', '/')

      console.log(`处理 ${i} 的 ${tmp}`)

      // 配置环境
      try {

        // 后缀解析
        let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
        // （普通音乐）
        if (support_audio_format.includes(file_suffix)) {
          // 添加
          tmp_play_list.push(tmp)
        }
        // （dsd音乐）
        else if (support_dsd_format.includes(file_suffix)) {
          console.log('有dsd音频！')
        }

      } catch (e) {log(e, 'error')}

      // 分批处理，让主线程喘息
      if ((e + 1) % 10 === 0 && e + 1 < tmp_list.length) {
        console.log('休息！')
        await new Promise<void>(r => setTimeout(r, 1))
      }

    }

    // 载入
    while (true) {
      if (play_list.has(tmp_name)) {tmp_name = tmp_name + ' '} else {break}
    }
    play_list.set(tmp_name, tmp_play_list)

    // 分批处理，让主线程喘息
    if ((i + 1) % 10 === 0 && i + 1 < tmp_list.length) {
      await new Promise<void>(r => setTimeout(r, 1))
    }

  }

  log('扫描完成！')

  // 防kill
  console.log('休息！')
  await new Promise<void>(r => setTimeout(r, 500))

  // 排序
  all_songs_list.sort((a: string, b: string) => {return customCompare(a, b)})

  // 防kill
  console.log('休息！')
  await new Promise<void>(r => setTimeout(r, 500))

  // 输出数据
  return [all_songs_list, play_list, artist_composer_list, album_list, album_artist_list, genre_list]

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
  @State @Watch('reg_files_manager')dir_ready: boolean = false    // 环境指示器（下载目录是否初始化）

  ///////////
  // 继承池 //
  //////////
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
  async aboutToAppear() {
  }

  ////////////
  // 扩展类 //
  //////////
  // files_manager注册 //
  async reg_files_manager() {

    let tmp: [
      string[],
      Map<string, string[]>,
      Map<string, string[]>,
      Map<string, string[]>,
      Map<string, string[]>,
      Map<string, string[]>
    ]

    // 检测文件夹是否存在
    try {
      fs.statSync(root_path)
      tmp = await make_files_env()
    } catch {
      // 不存在，扫描文件
      tmp = await make_files_env()
    }

    // 载入
    this.files_manager.load_data(tmp)

    // 准备完成
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
            // 尝试读取目录
            try {
              fs.listFileSync(song_path);
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
                    fs.listFileSync(song_path);
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