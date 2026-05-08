//
// 文件管理器
// 广播：10
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import media from '@ohos.multimedia.media'
import { image } from '@kit.ImageKit'
import { picker, fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import emitter from '@ohos.events.emitter'
import { HashMap } from '@kit.ArkTS'
import { taskpool } from '@kit.ArkTS'

//////////////////
// 导入自创建模块 //
/////////////////
import nativeModule from 'libentry.so'
import { log } from '../system_function'
import { read_json_to_array, batch_save_async, array_to_json_save_async, scan_songs_task, parse_scan_result } from './array_save_load'
import { img_save } from "../cache_image_save"
import { get_image, get_meta } from '../meta_manager'

///////////
// 变量池 //
//////////
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.arkmusic').path   // 文件目录
const root_path = getContext().filesDir + '/files_manager'

// 字符权重池（比较用）
enum CharType {
  PUNCTUATION = 0, // 符号（包含 '.'）
  DIGIT = 1,       // 数字
  LETTER = 2,      // 字母
  CHINESE = 3      // 中文
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 内部函数库 //
/////////////

// 扫描进度上报 //
function notice(msg: string) {
  emitter.emit({ eventId: 1010 }, { data: {
    msg: msg
  } })
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

// 缓存建立器（异步版） //
async function make_songs_cache_async() {

  log('初始化数据库目录...')

  // 初始化数据库目录（在主线程执行）
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

  log('开始多线程扫描歌曲...')

  // 在 taskpool 中执行扫描任务（不阻塞主线程）
  const task = new taskpool.Task(
    scan_songs_task,
    song_path,
    root_path,
    support_audio_format,
    support_dsd_format
  )
  const scanResultJson = await taskpool.execute(task) as string
  const scanResult = parse_scan_result(scanResultJson)

  // 从解析结果中获取数据
  const all_songs_list = scanResult['all_songs_list'] as string[]
  const play_list_data = scanResult['play_list_data'] as string[][]
  const play_list_names = scanResult['play_list_names'] as string[]
  const artist_composer_data = scanResult['artist_composer_data'] as string[][]
  const artist_composer_names = scanResult['artist_composer_names'] as string[]
  const album_data = scanResult['album_data'] as string[][]
  const album_names = scanResult['album_names'] as string[]
  const album_artist_data = scanResult['album_artist_data'] as string[][]
  const album_artist_names = scanResult['album_artist_names'] as string[]
  const genre_data = scanResult['genre_data'] as string[][]
  const genre_names = scanResult['genre_names'] as string[]

  log('扫描完成，开始保存...')

  // 保存数据（使用多线程批量保存）
  let save_data_list: Array<Array<string>> = new Array<Array<string>>()
  let save_path_list: Array<string> = new Array<string>()

  // 所有歌曲
  log('保存 所有歌曲')
  save_data_list.push(all_songs_list)
  save_path_list.push(root_path + '/all_songs.json')

  // 歌手 / 作曲家
  log('保存 歌手 / 作曲家')
  for (let i = 0; i < artist_composer_data.length; i++) {
    let tmp_values = artist_composer_data[i]
    tmp_values.push(artist_composer_names[i])
    save_data_list.push(tmp_values)
    save_path_list.push(root_path + '/artist_composer/' + i + '.json')
  }

  // 专辑
  log('保存 专辑')
  for (let i = 0; i < album_data.length; i++) {
    let tmp_values = album_data[i]
    tmp_values.push(album_names[i])
    save_data_list.push(tmp_values)
    save_path_list.push(root_path + '/album/' + i + '.json')
  }

  // 专辑作家
  log('保存 专辑作家')
  for (let i = 0; i < album_artist_data.length; i++) {
    let tmp_values = album_artist_data[i]
    tmp_values.push(album_artist_names[i])
    save_data_list.push(tmp_values)
    save_path_list.push(root_path + '/album_artist/' + i + '.json')
  }

  // 流派
  log('保存 流派')
  for (let i = 0; i < genre_data.length; i++) {
    let tmp_values = genre_data[i]
    tmp_values.push(genre_names[i])
    save_data_list.push(tmp_values)
    save_path_list.push(root_path + '/genre/' + i + '.json')
  }

  // 列表
  log('保存 列表')
  for (let i = 0; i < play_list_data.length; i++) {
    save_data_list.push(play_list_data[i])
    save_path_list.push(root_path + '/play_list/' + nativeModule.base64urlCode(play_list_names[i], true) + '.json')
  }

  // 批量多线程保存
  log('批量保存中...')
  await batch_save_async(save_data_list, save_path_list)
  log('保存完毕！')

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class files_manager {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 类 //

  // 共享变量池 //
  all_songs_list: string[] = []
  play_list = new Map<string, string[]>()
  artist_composer_list = new Map<string, string[]>()
  album_list = new Map<string, string[]>()
  album_artist_list = new Map<string, string[]>()
  genre_list = new Map<string, string[]>()
  dsd_list: string[] = []

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 歌曲信息缓存（重新缓存） //
  async reset_songs_cache() {

    // 重置 //
    log('重置数据库')
    try {fs.rmdirSync(root_path)} catch {}
    fs.mkdirSync(root_path)

    await make_songs_cache_async()

  }

  // 载入列表 //
  async load_data() {

    // 读取文件夹 //
    try {
      fs.statSync(root_path)

      // 临时测试加载
      await this.reset_songs_cache()
      return

      // 加载 //
      // 加载所有歌曲
      this.all_songs_list = read_json_to_array(root_path + '/all_songs.json')
      // 加载歌手 / 艺术家
      for (const i of fs.listFileSync(root_path + '/artist_composer/', { recursion: false })) {
        const tmp_path = root_path + '/artist_composer/' + i
        // 读取
        let tmp_list = read_json_to_array(tmp_path)
        // 获取文件名
        const tmp_name = tmp_list.pop() ?? ''
        // 载入
        this.artist_composer_list.set(tmp_name, tmp_list)
      }
      // 加载专辑
      for (const i of fs.listFileSync(root_path + '/album/', { recursion: false })) {
        const tmp_path = root_path + '/album/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_list.set(tmp_name, tmp_list)
      }
      // 加载专辑作家
      for (const i of fs.listFileSync(root_path + '/album_artist/', { recursion: false })) {
        const tmp_path = root_path + '/album_artist/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_artist_list.set(tmp_name, tmp_list)
      }
      // 加载流派
      for (const i of fs.listFileSync(root_path + '/genre/', { recursion: false })) {
        const tmp_path = root_path + '/genre/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.genre_list.set(tmp_name, tmp_list)
      }
      // 加载列表
      for (const i of fs.listFileSync(root_path + '/play_list/', { recursion: false })) {
        const tmp_path = root_path + '/play_list/' + i
        const tmp_name = nativeModule.extractFilename(tmp_path)
        this.genre_list.set(nativeModule.base64urlCode(tmp_name, false), read_json_to_array(tmp_path))
      }

    } catch (e) {
      // 没有文件夹，扫描
      await this.reset_songs_cache()
    }

  }

  // 读取文件夹 //
  get_dir(path: string = ''): string[][] {

    let dir_list: string[] = []
    let file_list: string[] = []

    // 文件夹扫描扫描
    for (const i of fs.listFileSync(song_path + '/' + path, { recursion: false })) {

      let tmp_path = song_path + '/' + path + '/' + i

      // 文件夹
      if(fs.statSync(tmp_path).isDirectory()) {
        // 如果里面没有文件
        if (!(
            fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_audio_format } }).length === 0
          &&
            fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_dsd_format } }).length === 0
          &&
            fs.listFileSync(song_path, { recursion: true, filter: { suffix: ['.m3u'] } }).length === 0
        )) {
          // 添加
          dir_list.push(i)
        }
      }

      // 文件
      else if (fs.statSync(tmp_path).isFile()) {
        // 判断类型
        let file_suffix = tmp_path.substring(tmp_path.lastIndexOf('.')).toLowerCase()
        // （普通音乐）
        if (support_audio_format.includes(file_suffix)) {
          // 添加
          file_list.push(tmp_path)
        }
        // （dsd音乐）
        else if (support_dsd_format.includes(file_suffix)) {
          console.log('有dsd音频！')
        }
        // 播放列表
        else if (file_suffix == '.m3u') {}

      }

    }

    // 排序
    dir_list.sort((a: string, b: string) => {return customCompare(a, b)})
    file_list.sort((a: string, b: string) => {return customCompare(a, b)})
    // 返回
    return [dir_list, file_list]

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor() {}

}