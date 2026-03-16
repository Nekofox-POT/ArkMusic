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

///////////
// 变量池 //
//////////
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const root_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofoxpot.arkmusic/').path   // 文件目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 内部函数库 //
/////////////

//////////////
// 获取元数据 //
//////////////
async function get_meta(file: fs.File): Promise<[string, string, string, string, string, string, image.PixelMap | null, ]> {
  // 创建对象
  let avMetadataExtractor = await media.createAVMetadataExtractor();
  avMetadataExtractor.fdSrc = file;
  // 获取元数据。
  let meta_data = await avMetadataExtractor.fetchMetadata();


  let sample_rate = meta_data.sampleRate + 'hz'   // 采样率
  let song_artist = ''    // 歌手
  let album = ''    // 专辑
  let album_artist = ''   // 专辑作家
  let author = ''   // 作者
  let composer = ''   // 作曲家

  if (meta_data.artist) {song_artist = meta_data.artist} else {song_artist = '未知歌手'}
  if (meta_data.album) {album = meta_data.album} else {album = '未知专辑'}
  if (meta_data.albumArtist) {album_artist = meta_data.albumArtist} else {album_artist = '未知专辑艺术家'}
  if (meta_data.author) {author = meta_data.author} else {author = '未知作者'}
  if (meta_data.composer) {composer = meta_data.composer} else {composer = '未知作曲家'}

  // 获取专辑封面
  let meta_img: image.PixelMap | null = null
  try {
    meta_img = await avMetadataExtractor.fetchAlbumCover()
  } catch {
    // 使用默认封面
    const resourceManager = getContext().resourceManager
    const mediaData = await resourceManager.getMediaContent($r('app.media.CD'))
    const imageSource = image.createImageSource(mediaData.buffer)
    meta_img = await imageSource.createPixelMap()
  }
  // 释放
  avMetadataExtractor.release();
  // 输出
  return [sample_rate, song_artist, album, album_artist, author, composer, meta_img]
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


  // 扫描download的所有曲库 //
  let filenames = fs.listFileSync(root_path, { recursion: true })

  // 处理识别音频是否有效，如果有效则添加 //
  for (const i of filenames) {
    const tmp = root_path + i
    try {
      // 如果音频有效
      if (fs.statSync(tmp).isFile()) {
        // 获取后缀
        let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
        // 解析后缀（普通音乐）
        if (support_audio_format.includes(file_suffix)) {

          // 获取元数据 //
          let meta = await get_meta(fs.openSync(tmp))

          // 添加
          console.log(tmp)
          console.log(nativeModule.extractFilename(tmp))

        }
        // 解析后缀（dsd音乐）
        else if (support_dsd_format.includes(file_suffix)) {
          console.log('有dsd音频！')
        }
      }
    } catch (e) {log(e, 'error')}
  }

}