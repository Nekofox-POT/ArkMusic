//
// 元数据获取管理器
//

import media from '@ohos.multimedia.media'
import { image } from '@kit.ImageKit'
import { picker, fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import nativeModule from 'libentry.so'

import { log } from './system_function'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 内部函数 //
////////////

// 秒 转化 分:秒
function translate_second(duration: number): string {
  const minutes = Math.floor(duration / 60)
  const seconds = Math.floor(duration % 60)
  const formattedDuration = `${minutes}:${seconds.toString().padStart(2, '0')}`
  return formattedDuration
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 外部函数 //
////////////

// 封面获取 //
export async function get_image(path: string): Promise<image.PixelMap> {

  let meta_img: image.PixelMap | null = null

  // 创建对象
  let avMetadataExtractor = await media.createAVMetadataExtractor()
  let tmp = fs.openSync(path)
  avMetadataExtractor.fdSrc = tmp

  // 获取专辑封面
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
  avMetadataExtractor.release()
  return meta_img
}

// 封面获取（返回base64）
export async function image_to_base64(img: PixelMap) {
  // 获取封面
  let packOpts: image.PackingOption = { format: "image/jpeg", quality: 90 }
  let arrayBuffer = await image.createImagePacker().packing(img, packOpts)
  let dataURL = nativeModule.encodeImageToBase64(arrayBuffer)
  return dataURL
}

// 元数据获取 //
export async function get_meta(path: string): Promise<string[][]> {

  //
  // 获取音频的元数据
  // 分为两个部分
  // 第一个部分是基础数据，包括 [文件名, 文件类型, 声道, 采样率, 位深, 比特率, 时长]
  // 第二个部分是制作数据，包括 [标题, 歌手/作曲家, 专辑名, 专辑作家, 流派]
  //

  try {

    // 获取元数据集
    let meta_data = nativeModule.getAudioMetadata(path)

    const file_name = nativeModule.extractFilename(path)  // 文件名
    const file_type = path.substring(path.lastIndexOf('.') + 1).toLowerCase() // 文件类型
    const channels = meta_data.channels                   // 声道
    const sample_rate = meta_data.sampleRate              // 采样率
    const bit_depth = meta_data.bitDepth                  // 位深
    const bit_rate = (meta_data.bitrate / 1000).toFixed(1)// 比特率
    const duration = translate_second(meta_data.duration) // 时长

    let title = file_name             // 歌曲名
    let artist = '未知歌手'            // 歌手
    let album = '未知专辑'             // 专辑
    let album_artist = '未知专辑作家'   // 专辑作家
    let genre = '未知流派'             // 流派
    if (meta_data.title) {
      title = meta_data.title
      if (meta_data.artist) {
        artist = meta_data.artist
      } else {
        if (meta_data.composer) {
          artist = meta_data.composer
        }
      }
    }
    if (meta_data.album) {album = meta_data.album}
    if (meta_data.albumArtist) {album_artist = meta_data.albumArtist}
    if (meta_data.genre) {genre = meta_data.genre}

    return [[
      file_name, file_type, `${channels}`, `${sample_rate}hz`, `${bit_depth}bit`, `${bit_rate}kbps`, duration
    ], [
      title, artist, album, album_artist, genre
    ]]

  } catch (e) {
    log(`get_meta：元数据获取失败 ${e}`, 'error')
    return [[], []]
  }

}