//
// 文件管理器
// 广播：8
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

//////////////////
// 导入自创建模块 //
/////////////////
import nativeModule from 'libentry.so'
import { log } from '../system_function'
import { read_json_to_array, array_to_json_save } from './array_save_load'
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
  emitter.emit({ eventId: 812 }, { data: {
    msg: msg
  } })
}

// 字符权重 //
function getCharWeight(char: string): number {

  if (!char) return CharType.CHINESE

  const code = char.charCodeAt(0)

  if ((code >= 33 && code <= 47) ||
    (code >= 58 && code <= 64) ||
    (code >= 91 && code <= 96) ||
    (code >= 123 && code <= 126)) {
    return CharType.PUNCTUATION
  }

  if (code >= 48 && code <= 57) {
    return CharType.DIGIT
  }

  if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
    return CharType.LETTER
  }

  if ((code >= 0x4E00 && code <= 0x9FFF) ||
    (code >= 0x3400 && code <= 0x4DBF) ||
    (code >= 0x20000 && code <= 0x2A6DF)) {
    return CharType.CHINESE
  }

  return CharType.PUNCTUATION
}
// 字符比较器 //
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

  // 建立歌曲缓存 //
  async make_songs_cache() {

    // 重置 //
    log('重置数据库')
    try {fs.rmdirSync(root_path)} catch {}
    fs.mkdirSync(root_path)

    // 初始化数据库
    log('初始化数据库...')
    notice('初始化数据库...')
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
    let tmp_audio = fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_audio_format } })
    for (let i = 0; i < tmp_audio.length; i++) {

      // 建立路径缓存
      let tmp_path = song_path + '/' + tmp_audio[i]

      // 添加所有歌曲列
      this.all_songs_list.push(tmp_path)

      // 获取元数据
      const tmp_meta = get_meta(tmp_path)
      // 分类 歌手 / 作曲家
      if (!this.artist_composer_list.has(tmp_meta[1][1])) { this.artist_composer_list.set(tmp_meta[1][1], [])}
      this.artist_composer_list.get(tmp_meta[1][1])?.push(tmp_path)
      // 分类 专辑
      if (!this.album_list.has(tmp_meta[1][2])) { this.album_list.set(tmp_meta[1][2], [])}
      this.album_list.get(tmp_meta[1][2])?.push(tmp_path)
      // 分类 专辑作家
      if (!this.album_artist_list.has(tmp_meta[1][3])) { this.album_artist_list.set(tmp_meta[1][3], [])}
      this.album_artist_list.get(tmp_meta[1][3])?.push(tmp_path)
      // 分类 流派
      if (!this.genre_list.has(tmp_meta[1][4])) { this.genre_list.set(tmp_meta[1][4], [])}
      this.genre_list.get(tmp_meta[1][4])?.push(tmp_path)

      // 防kill
      if (i % 200 === 0) {
        notice(`正在扫描: ${tmp_audio[i]}`)
        await new Promise<void>(r => setTimeout(r, 1))
      }

    }

    // 防kill
    await new Promise<void>(r => setTimeout(r, 100))
    // 扫描歌曲(dsd) //
    log('扫描dsd')
    let tmp_dsd = fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_dsd_format } })
    for (let i = 0; i < tmp_dsd.length; i++) {
      console.log('有dsd音频！')
      // 防kill
      if (i % 10 === 0) {await new Promise<void>(r => setTimeout(r, 1))}
    }
    // 防kill
    await new Promise<void>(r => setTimeout(r, 100))
    // 扫描歌单(m3u) //
    log('扫描m3u列表')
    let tmp_m3u_list = fs.listFileSync(song_path, { recursion: true, filter: { suffix: ['.m3u'] } })
    for (let i = 0; i < tmp_m3u_list.length; i++) {

      // 尝试读取
      notice(`正在处理: ${tmp_m3u_list[i]}`)
      try {fs.readTextSync(song_path + tmp_m3u_list[i])} catch {continue}

      // 注册环境
      let tmp_play_list: string[] = []
      const tmp_path = song_path + tmp_m3u_list[i]
      const tmp_env = tmp_path.substring(0, tmp_path.lastIndexOf('/') + 1)
      let tmp_name = nativeModule.extractFilename(tmp_path)
      const tmp_list = fs.readTextSync(tmp_path).replace(/\r\n/g, '\n').split('\n').filter(Boolean)

      // 读取
      for (let e = 0; e < tmp_list.length; e++) {

        // 格式化
        const tmp = tmp_env + '/' + tmp_list[e].replaceAll('\\', '/')

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

        // 防kill
        if (i % 50 === 0) {await new Promise<void>(r => setTimeout(r, 1))}

      }

      // 载入
      while (true) {
        if (this.play_list.has(tmp_name)) {tmp_name = tmp_name + ' '} else {break}
      }
      this.play_list.set(tmp_name, tmp_play_list)

      // 防kill
      await new Promise<void>(r => setTimeout(r, 1))

    }

    // 保存 //
    let tmp_keys: string[] = []
    let tmp_values: string[] = []
    let tick: number = 0
    // 所有歌曲
    log('保存 所有歌曲')
    this.all_songs_list = await this.list_sort(this.all_songs_list)
    array_to_json_save(this.all_songs_list, root_path + '/all_songs.json')
    // 歌手 / 作曲家
    log('保存 歌手 / 作曲家')
    tick = 0
    tmp_keys = await this.list_sort(Array.from(this.artist_composer_list.keys()))
    for (let i = 0; i < tmp_keys.length; i++) {
      // 防kill
      if (i % 200 === 0) { await new Promise<void>(r => setTimeout(r, 1)) }
      tmp_values = await this.list_sort(this.artist_composer_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, root_path + '/artist_composer/' + tick++ + '.json')
    }
    // 专辑
    log('保存 专辑')
    tick = 0
    tmp_keys = await this.list_sort(Array.from(this.album_list.keys()))
    for (let i = 0; i < tmp_keys.length; i++) {
      // 防kill
      if (i % 200 === 0) { await new Promise<void>(r => setTimeout(r, 1)) }
      tmp_values = await this.list_sort(this.album_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, root_path + '/album/' + tick++ + '.json')
    }
    // 专辑作家
    log('保存 专辑作家')
    tick = 0
    tmp_keys = await this.list_sort(Array.from(this.album_artist_list.keys()))
    for (let i = 0; i < tmp_keys.length; i++) {
      // 防kill
      if (i % 200 === 0) { await new Promise<void>(r => setTimeout(r, 1)) }
      tmp_values = await this.list_sort(this.album_artist_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, root_path + '/album_artist/' + tick++ + '.json')
    }
    // 流派
    log('保存 流派')
    tick = 0
    tmp_keys = await this.list_sort(Array.from(this.genre_list.keys()))
    for (let i = 0; i < tmp_keys.length; i++) {
      // 防kill
      if (i % 200 === 0) { await new Promise<void>(r => setTimeout(r, 1)) }
      tmp_values = await this.list_sort(this.genre_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, root_path + '/genre/' + tick++ + '.json')
    }
    // 列表
    log('保存 列表')
    tmp_keys = await this.list_sort(Array.from(this.play_list.keys()))
    for (const i of tmp_keys) {
      array_to_json_save(this.play_list.get(i) ?? [], root_path + '/play_list/' + nativeModule.base64urlCode(i, true) + '.json')
    }
    log('保存完毕！')
    notice('完成！')

  }

  // 排序（C++ 快速排序，带进度提示）//
  async list_sort(arr: string[]): Promise<string[]> {
    const total = arr.length
    notice(`正在排序 (0 / ${total})`)
    await new Promise<void>(r => setTimeout(r, 1))

    const result = nativeModule.sortStringArray(arr)

    notice(`正在排序 (${total} / ${total})`)
    return result
  }

  // 载入列表 //
  async load_data() {

    // 读取文件夹 //
    try {
      fs.statSync(root_path)

      // 加载 //
      // 加载所有歌曲
      notice('读取 所有歌曲')
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
      notice('读取 专辑')
      for (const i of fs.listFileSync(root_path + '/album/', { recursion: false })) {
        const tmp_path = root_path + '/album/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_list.set(tmp_name, read_json_to_array(tmp_path))
      }
      // 加载专辑作家
      notice('读取 专辑作家')
      for (const i of fs.listFileSync(root_path + '/album_artist/', { recursion: false })) {
        const tmp_path = root_path + '/album_artist/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_artist_list.set(tmp_name, read_json_to_array(tmp_path))
      }
      // 加载流派
      notice('读取 流派')
      for (const i of fs.listFileSync(root_path + '/genre/', { recursion: false })) {
        const tmp_path = root_path + '/genre/' + i
        let tmp_list = read_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.genre_list.set(tmp_name, read_json_to_array(tmp_path))
      }
      // 加载列表
      notice('读取 列表')
      for (const i of fs.listFileSync(root_path + '/play_list/', { recursion: false })) {
        const tmp_path = root_path + '/play_list/' + i
        const tmp_name = nativeModule.extractFilename(tmp_path)
        this.genre_list.set(nativeModule.base64urlCode(tmp_name, false), read_json_to_array(tmp_path))
      }

      notice('完成.')

    } catch (e) {
      // 没有文件夹，扫描
      await this.make_songs_cache()
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