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
import nativeModule from 'libentry.so'

//////////////////
// 导入自创建模块 //
/////////////////
import { log } from './system_function'
import { read_json_to_array, array_to_json_save } from './hashmap_save_load'
import { img_save } from "./cache_image_save"


///////////
// 变量池 //
//////////
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic').path   // 文件目录
const root_path = getContext().filesDir
let img_number = 0    // img缓存编号
let m3u_cache = []    // m3u文件缓存

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

// 获取元数据 //
async function get_meta(path: string, name: string, file: fs.File): Promise<[string, string, string, string, string, string, string, string, string, string]> {
  // 创建对象
  let avMetadataExtractor = await media.createAVMetadataExtractor();
  avMetadataExtractor.fdSrc = file;
  // 获取元数据。
  let meta_data = await avMetadataExtractor.fetchMetadata();


  let song_title = ''   // 标题
  let song_artist = ''    // 歌手
  let album = ''    // 专辑
  let album_artist = ''   // 专辑作家
  let author = ''   // 作者
  let composer = ''   // 作曲家
  let sample_rate = meta_data.sampleRate + 'hz'   // 采样率

  if (meta_data.title) {song_title = meta_data.title} else {song_title = name}
  if (meta_data.artist) {song_artist = meta_data.artist} else {song_artist = '未知歌手'}
  if (meta_data.album) {album = meta_data.album} else {album = '未知专辑'}
  if (meta_data.albumArtist) {album_artist = meta_data.albumArtist} else {album_artist = '未知专辑艺术家'}
  if (meta_data.author) {author = meta_data.author} else {author = '未知作者'}
  if (meta_data.composer) {composer = meta_data.composer} else {composer = '未知作曲家'}

  // 获取专辑封面
  let meta_img: image.PixelMap | null = null
  let img_path: string = ''
  notice(`正在处理：${name}`)
  try {
    // 获取
    meta_img = await avMetadataExtractor.fetchAlbumCover()
    // 保存
    img_path = `cache_img/${img_number++}.png`
    img_save(meta_img, img_path)
  } catch {
    // 使用默认封面
    img_path = 'cache_img/0.png'
  }
  // 释放
  avMetadataExtractor.release();
  // 输出
  return [path, name, song_title, song_artist, album, album_artist, author, composer, img_path, sample_rate]
}

// 文件递归扫描（兼文件夹模式缓存） //
async function scan_download_dir(path: string = ''): Promise<string[][]> {

  // 扫描
  notice(`正在扫描：/${path}}`)
  let files = fs.listFileSync(song_path + '/' + path, { recursion: false })
  let data: string[][] = []
  let dir_data: string[][] = []

  // 分类
  for (const i of files) {
    let stat = fs.statSync(song_path + '/' + path + '/' + i)
    if (stat.isFile()) {

      // 文件 //
      const tmp = song_path + '/' + path + '/' + i
      try {
        // 获取后缀
        let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
        // 后缀解析（普通音乐）
        if (support_audio_format.includes(file_suffix)) {

          // 获取元数据
          let meta = await get_meta(tmp, nativeModule.extractFilename(tmp), fs.openSync(tmp))
          // 添加
          data.push(meta)
        }
        // 解析后缀（dsd音乐）
        else if (support_dsd_format.includes(file_suffix)) {
          console.log('有dsd音频！')
        }
      } catch (e) {log(e, 'error')}

    } else if (stat.isDirectory()) {

      // 文件夹 //
      // 创建文件夹
      fs.mkdirSync(root_path + '/dir_mode/' + path + '/' + i)
      // 递归添加扫描
      let tmp: string[][] = await scan_download_dir(path + '/' + i)
      // 如果没有
      if (tmp.length === 0) {
        // 删掉文件夹
        fs.rmdirSync(root_path + '/dir_mode/' + path + '/' + i)
      } else {
        // 递归写入
        for (const e of tmp) {
          dir_data.push(e)
        }
      }

    }
  }
  // 保存目录 //
  array_to_json_save(data, '/dir_mode/' + path + '/songs.json')
  // 合并扫描结果 //
  for (const i of dir_data) {
    data.push(i)
  }
  return data

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 外部函数库 //
/////////////

/////////////////////
// 文件夹扫描创建缓存 //
////////////////////
export async function make_music_cache() {

  ///////////
  // 变量集 //
  //////////
  let cache_list: string[][] = []

  /////////////
  // 初始化集 //
  ////////////
  notice('初始化数据库...')
  // 初始化cache_img //
  // 初始化img文件号
  img_number = 0
  // 初始化img文件夹
  try {fs.rmdirSync(root_path + '/cache_img')} catch {}
  fs.mkdirSync(root_path + '/cache_img')
  // 载入头部数据
  const resourceManager = getContext().resourceManager
  const mediaData = await resourceManager.getMediaContent($r('app.media.CD'))
  const imageSource = image.createImageSource(mediaData.buffer)
  const meta_img = await imageSource.createPixelMap()
  img_save(meta_img, `cache_img/${img_number++}.png`)

  // 删除all_songs //
  try {fs.unlinkSync(root_path + '/all_songs.json')} catch {}

  // 初始化dir_mode //
  try {fs.rmdirSync(root_path + '/dir_mode')} catch {}
  fs.mkdirSync(root_path + '/dir_mode')

  ////////////////
  // 正常程序流程 //
  ///////////////
  // 扫描download的所有曲库 //
  cache_list = await scan_download_dir()

  // 排序 //
  notice('正在排序')
  cache_list.sort((a: string[], b: string[]) => {
    return customCompare(a[0], b[0]);
  })

  // 保存 //
  // 所有歌曲保存
  notice('写入数据库')
  array_to_json_save(cache_list, 'all_songs.json')
  console.log(`配置文件保存完成！`)
  notice(`配置文件保存完成！`)

}

// 读取所有歌曲 //
export function read_all_songs(): string[][] {
  return read_json_to_array('all_songs.json')
}

// 读取文件夹的歌曲 //
export function read_dir_songs(path: string = ''): string[][][] {

  let dir_data: string[][] = []

  // 读取文件夹 //
  console.log('读取文件夹：')
  console.log(root_path + '/dir_mode/' + path)
  for (const i of fs.listFileSync(root_path + '/dir_mode/' + path, { recursion: false })) {
    if (fs.statSync(root_path + '/dir_mode/' + path + '/' + i).isDirectory()) {
      dir_data.push([i])
    }
  }

  // 读取json（如果有） //
  let songs_data: string[][] = []
  try {
    fs.statSync(root_path + '/dir_mode/' + path + '/songs.json')
    songs_data = read_json_to_array('/dir_mode/' + path + '/songs.json')
  } catch {}

  // 排序 //
  dir_data.sort((a: string[], b: string[]) => {
    return customCompare(a[0], b[0]);
  })
  songs_data.sort((a: string[], b: string[]) => {
    return customCompare(a[0], b[0]);
  })

  // 返回 //
  return [dir_data, songs_data]

}