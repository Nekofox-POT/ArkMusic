//
// 元数据获取管理器
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 环境准备 //
////////////
// 导入第三方库 //
import media from '@ohos.multimedia.media'
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import nativeModule, { AudioMetadata, BatchAudioMetadata } from 'libentry.so'
import { log } from './system_function'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 外部函数 //
////////////

// 封面获取 //
export async function get_image(path: string = ''): Promise<[boolean, image.PixelMap]> {

  // 创建对象 //
  let avMetadataExtractor = await media.createAVMetadataExtractor()

  // 获取专辑封面 //
  try {
    let tmp = fs.openSync(path)
    avMetadataExtractor.fdSrc = tmp
    const tmp_img = await avMetadataExtractor.fetchAlbumCover()
    avMetadataExtractor.release()
    return [true, tmp_img]
  } catch {
    // 使用默认封面
    avMetadataExtractor.release()
    const resourceManager = getContext().resourceManager
    const mediaData = await resourceManager.getMediaContent($r('app.media.CD'))
    const imageSource = image.createImageSource(mediaData.buffer)
    const tmp_img = await imageSource.createPixelMap()
    return [false, tmp_img]
  }

}

// 封面获取（返回base64）//
export async function image_to_base64(img: PixelMap): Promise<string> {
  return nativeModule.encodeImageToBase64(
    await image.createImagePacker().packing(
      img,
      { format: "image/jpeg", quality: 90 }
    )
  )
}

// 批量元数据获取（多线程并行）//
export async function get_meta_batch(paths: string[]): Promise<Map<string, string[][]>> {

  //
  // 批量获取音频元数据
  // 返回 Map<路径, [基础数据, 制作数据]>
  //

  const result_map = new Map<string, string[][]>()

  try {
    const batch_results = await nativeModule.getAudioMetadata(paths) as BatchAudioMetadata[]

    for (const item of batch_results) {
      const file_path = item['filePath'] as string
      const success = item['success'] as boolean

      if (!success || !file_path) {
        continue
      }

      const file_name = nativeModule.extractFilename(file_path)
      const file_type = file_path.substring(file_path.lastIndexOf('.') + 1).toLowerCase()
      const channels = item['channels'] as number
      const sample_rate = (item['sampleRate'] as number) / 1000
      const bit_depth = item['bitDepth'] as number                      // C++ 已修正有损格式为 16bit
      const bit_rate = ((item['bitrate'] as number) / 1000).toFixed(1)
      const duration = item['duration'] as number                   // 时长（毫秒）
      const duration_format = item['durationFormat'] as string      // 时长（C++ 已格式化为 "分:秒"）
      const mtime = fs.statSync(file_path).mtime                // 文件最后修改时间（ms 时间戳）

      let title = file_name
      let artist = '未知歌手'
      let album = '未知专辑'
      let album_artist = '未知专辑作家'
      let genre = '未知流派'

      const meta_title = item['title'] as string
      if (meta_title) {
        title = meta_title
        const meta_artist = item['artist'] as string
        if (meta_artist) {
          artist = meta_artist
        } else {
          const meta_composer = item['composer'] as string
          if (meta_composer) {
            artist = meta_composer
          }
        }
      }
      const meta_album = item['album'] as string
      if (meta_album) { album = meta_album }
      const meta_album_artist = item['albumArtist'] as string
      if (meta_album_artist) { album_artist = meta_album_artist }
      const meta_genre = item['genre'] as string
      if (meta_genre) { genre = meta_genre }

      result_map.set(file_path, [[
        file_name, `${mtime}`, file_type, `${channels}`, `${sample_rate}khz`, `${bit_depth}bit`, `${bit_rate}kbps`, `${duration}`, duration_format
      ], [
        title, artist, album, album_artist, genre
      ]])
    }

  } catch (e) {
    log(`get_meta_batch：批量元数据获取失败 ${e}`, 'error')
  }

  return result_map
}

// 元数据获取 //
export async function get_meta(path: string): Promise<string[][]> {

  //
  // 获取音频的元数据
  // 分为两个部分
  // 第一个部分是基础数据，包括 [文件名, 修改时间, 文件类型, 声道, 采样率, 位深, 比特率, 时长, 时长(格式化)]
  // 第二个部分是制作数据，包括 [标题, 歌手/作曲家, 专辑名, 专辑作家, 流派]
  //

  try {

    // 获取元数据集
    let meta_data = await nativeModule.getAudioMetadata(path) as AudioMetadata

    const file_name = nativeModule.extractFilename(path)  // 文件名
    const file_type = path.substring(path.lastIndexOf('.') + 1).toLowerCase() // 文件类型
    const channels = meta_data.channels                   // 声道
    const sample_rate = meta_data.sampleRate / 1000       // 采样率
    const bit_depth = meta_data.bitDepth                  // 位深（C++ 已修正有损格式）
    const bit_rate = (meta_data.bitrate / 1000).toFixed(1)// 比特率
    const duration = meta_data.duration                   // 时长（毫秒）
    const duration_format = meta_data.durationFormat      // 时长（C++ 已格式化为 "分:秒"）
    const mtime = fs.statSync(path).mtime                 // 文件最后修改时间（ms 时间戳）

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

    const base_data: string[] = [
      file_name, `${mtime}`, file_type, `${channels}`, `${sample_rate}khz`, `${bit_depth}bit`, `${bit_rate}kbps`, `${duration}`, duration_format
    ]
    const meta_data_arr: string[] = [title, artist, album, album_artist, genre]
    return [base_data, meta_data_arr]

  } catch (e) {
    log(`get_meta：元数据获取失败 ${e}`, 'error')
    return [[], []]
  }

}
