//
// 文件管理器
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import media from '@ohos.multimedia.media'
import { image } from '@kit.ImageKit'
import { picker, fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'

import nativeModule from 'libentry.so'

//////////////////
// 导入自创建模块 //
/////////////////
import { log } from './system_function'
import { read_json_to_array, array_to_json_save } from './hashmap_save_load';



///////////
// 变量池 //
//////////
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path   // 文件目录
const root_path = getContext().filesDir
let img_number = 0    // img缓存编号

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 内部函数库 //
/////////////

// 图片储存 //
async function img_save(pixelMap: image.PixelMap): Promise<string> {
  
  // 创建图片打包器
  const imagePackerApi = image.createImagePacker()
  
  // 设置打包参数
  const packOpts: image.PackingOption = {
    format: 'image/png',
    quality: 100
  }
  
  // 打包 PixelMap 为 PNG 数据
  const packData = await imagePackerApi.packing(pixelMap, packOpts)
  
  // 写入文件
  const file = fs.openSync(root_path + `cache_img/${img_number}.png`, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
  fs.writeSync(file.fd, packData)
  fs.closeSync(file)
  
  // 释放打包器
  imagePackerApi.release()
  
  return `cache_img/${img_number++}.png`

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
  try {
    meta_img = await avMetadataExtractor.fetchAlbumCover()
    img_path = await img_save(meta_img)
  } catch {
    // 使用默认封面
    img_path = 'cache_img/0.png'
  }
  // 释放
  avMetadataExtractor.release();
  // 输出
  return [path, name, song_title, song_artist, album, album_artist, author, composer, img_path, sample_rate]
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
  
  // 初始化cache_img //
  try {
    fs.rmdirSync(root_path + 'cache_img')
    throw new Error()
  } catch {
    fs.mkdirSync(root_path + 'cache_img')
  }
  img_number = 0
  const resourceManager = getContext().resourceManager
  const mediaData = await resourceManager.getMediaContent($r('app.media.CD'))
  const imageSource = image.createImageSource(mediaData.buffer)
  const meta_img = await imageSource.createPixelMap()
  await img_save(meta_img)


  // 扫描download的所有曲库 //
  let filenames = fs.listFileSync(song_path, { recursion: true })

  // 处理识别音频是否有效，如果有效则添加 //
  for (const i of filenames) {
    const tmp = song_path + i
    try {
      // 如果音频有效
      if (fs.statSync(tmp).isFile()) {
        // 获取后缀
        let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
        // 解析后缀（普通音乐）
        if (support_audio_format.includes(file_suffix)) {

          // 获取元数据
          console.log(tmp)
          let meta = await get_meta(tmp, nativeModule.extractFilename(tmp), fs.openSync(tmp))
          // 添加
          cache_list.push(meta)
        }
        // 解析后缀（dsd音乐）
        else if (support_dsd_format.includes(file_suffix)) {
          console.log('有dsd音频！')
        }
      }
    } catch (e) {log(e, 'error')}
  }

  // 保存读取list
  if (array_to_json_save(cache_list, 'all_songs.json')) {
    console.log('保存成功')
  }
  const tmp = read_json_to_array('all_songs.json')
  if (!tmp) {
    console.log('读取成功')
  }
  console.log(`${tmp}`)

}