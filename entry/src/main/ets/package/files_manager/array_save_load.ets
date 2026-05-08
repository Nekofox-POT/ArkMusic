//
// array的 储存 / 读取
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { log } from '../system_function'
import nativeModule from 'libentry.so'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 任务池任务 //
//////////////

// 多线程保存任务 //
@Concurrent
function save_task(data: string, path: string): boolean {

  try {
    // 保存
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, data)
    fs.closeSync(file)
  } catch (e) {
    return false
  }

  return true

}

// 扫描结果解析函数（在主线程调用）
export function parse_scan_result(jsonStr: string): Record<string, Object> {
  return JSON.parse(jsonStr) as Record<string, Object>
}

// 多线程扫描任务（返回JSON字符串，符合@Concurrent限制） //
// 注意：@Concurrent 函数不能调用外部定义的函数，所有辅助代码必须内联
@Concurrent
export function scan_songs_task(
  songPath: string,
  rootPath: string,
  supportAudioFormat: string[],
  supportDsdFormat: string[]
): string {

  // ===== 内联的字符比较器 =====
  const PUNCTUATION = 0
  const DIGIT = 1
  const LETTER = 2
  const CHINESE = 3

  const getCharWeight = (char: string): number => {
    if (!char) return CHINESE
    const code = char.charCodeAt(0)
    if ((code >= 33 && code <= 47) ||
      (code >= 58 && code <= 64) ||
      (code >= 91 && code <= 96) ||
      (code >= 123 && code <= 126)) {
      return PUNCTUATION
    }
    if (code >= 48 && code <= 57) {
      return DIGIT
    }
    if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
      return LETTER
    }
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3400 && code <= 0x4DBF) ||
      (code >= 0x20000 && code <= 0x2A6DF)) {
      return CHINESE
    }
    return PUNCTUATION
  }

  const customCompare = (strA: string, strB: string): number => {
    const lenA = strA.length
    const lenB = strB.length
    const minLen = Math.min(lenA, lenB)
    for (let i = 0; i < minLen; i++) {
      const charA = strA.charAt(i)
      const charB = strB.charAt(i)
      const weightA = getCharWeight(charA)
      const weightB = getCharWeight(charB)
      if (weightA !== weightB) {
        return weightA - weightB
      }
      if (weightA === LETTER) {
        const lowerA = charA.toLowerCase()
        const lowerB = charB.toLowerCase()
        if (lowerA < lowerB) return -1
        if (lowerA > lowerB) return 1
      } else if (weightA === CHINESE) {
        const collator = new Intl.Collator('zh-CN')
        const cmp = collator.compare(charA, charB)
        if (cmp !== 0) return cmp
      } else {
        if (charA < charB) return -1
        if (charA > charB) return 1
      }
    }
    return lenA - lenB
  }
  // ===== 内联结束 =====

  // 所有歌曲列表
  let all_songs_list: string[] = []

  // 分类数组
  let artistComposerData: string[][] = []
  let artistComposerNames: string[] = []
  let albumData: string[][] = []
  let albumNames: string[] = []
  let albumArtistData: string[][] = []
  let albumArtistNames: string[] = []
  let genreData: string[][] = []
  let genreNames: string[] = []
  let playListData: string[][] = []
  let playListNames: string[] = []

  // 扫描普通歌曲
  const audioFiles = fs.listFileSync(songPath, { recursion: true, filter: { suffix: supportAudioFormat } })

  for (const i of audioFiles) {
    const fullPath = songPath + '/' + i
    all_songs_list.push(fullPath)

    // 获取元数据
    try {
      const meta_data = nativeModule.getAudioMetadata(fullPath)
      const artist = meta_data.artist || meta_data.composer || '未知歌手'
      const album = meta_data.album || '未知专辑'
      const albumArtist = meta_data.albumArtist || '未知专辑作家'
      const genre = meta_data.genre || '未知流派'

      // 分类：歌手/作曲家
      let artistIdx = artistComposerNames.indexOf(artist)
      if (artistIdx === -1) {
        artistComposerNames.push(artist)
        artistComposerData.push([])
        artistIdx = artistComposerNames.length - 1
      }
      artistComposerData[artistIdx].push(fullPath)

      // 分类：专辑
      let albumIdx = albumNames.indexOf(album)
      if (albumIdx === -1) {
        albumNames.push(album)
        albumData.push([])
        albumIdx = albumNames.length - 1
      }
      albumData[albumIdx].push(fullPath)

      // 分类：专辑作家
      let albumArtistIdx = albumArtistNames.indexOf(albumArtist)
      if (albumArtistIdx === -1) {
        albumArtistNames.push(albumArtist)
        albumArtistData.push([])
        albumArtistIdx = albumArtistNames.length - 1
      }
      albumArtistData[albumArtistIdx].push(fullPath)

      // 分类：流派
      let genreIdx = genreNames.indexOf(genre)
      if (genreIdx === -1) {
        genreNames.push(genre)
        genreData.push([])
        genreIdx = genreNames.length - 1
      }
      genreData[genreIdx].push(fullPath)

    } catch (e) {
      // 元数据获取失败，使用默认分类
      const defaultArtist = '未知歌手'
      let artistIdx = artistComposerNames.indexOf(defaultArtist)
      if (artistIdx === -1) {
        artistComposerNames.push(defaultArtist)
        artistComposerData.push([])
        artistIdx = artistComposerNames.length - 1
      }
      artistComposerData[artistIdx].push(fullPath)
    }
  }

  // 扫描 m3u 播放列表
  const m3uFiles = fs.listFileSync(songPath, { recursion: true, filter: { suffix: ['.m3u'] } })

  for (const i of m3uFiles) {
    const tmpPath = songPath + i
    try {
      const content = fs.readTextSync(tmpPath)
      const tmpEnv = tmpPath.substring(0, tmpPath.lastIndexOf('/') + 1)
      let tmpName = nativeModule.extractFilename(tmpPath)
      const tmpList = content.replace(/\r\n/g, '\n').split('\n').filter(Boolean)

      let tmpPlayList: string[] = []
      for (const e of tmpList) {
        const tmp = tmpEnv + '/' + e.replaceAll('\\', '/')
        try {
          let fileSuffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
          if (supportAudioFormat.includes(fileSuffix)) {
            tmpPlayList.push(tmp)
          }
        } catch (e) {
          // 忽略错误
        }
      }

      // 确保名称唯一
      while (playListNames.includes(tmpName)) {
        tmpName = tmpName + ' '
      }
      playListNames.push(tmpName)
      playListData.push(tmpPlayList)
    } catch (e) {
      // 忽略读取错误
    }
  }

  // 排序所有歌曲
  all_songs_list.sort((a: string, b: string) => customCompare(a, b))

  // 排序各分类
  for (let i = 0; i < artistComposerData.length; i++) {
    artistComposerData[i].sort((a: string, b: string) => customCompare(a, b))
  }
  for (let i = 0; i < albumData.length; i++) {
    albumData[i].sort((a: string, b: string) => customCompare(a, b))
  }
  for (let i = 0; i < albumArtistData.length; i++) {
    albumArtistData[i].sort((a: string, b: string) => customCompare(a, b))
  }
  for (let i = 0; i < genreData.length; i++) {
    genreData[i].sort((a: string, b: string) => customCompare(a, b))
  }

  // 构建结果对象并返回JSON字符串
  const result: Record<string, Object> = {
    'all_songs_list': all_songs_list,
    'play_list_data': playListData,
    'play_list_names': playListNames,
    'artist_composer_data': artistComposerData,
    'artist_composer_names': artistComposerNames,
    'album_data': albumData,
    'album_names': albumNames,
    'album_artist_data': albumArtistData,
    'album_artist_names': albumArtistNames,
    'genre_data': genreData,
    'genre_names': genreNames
  }

  return JSON.stringify(result)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// string[]转json储存（覆盖） //
export function array_to_json_save(data: string[], path: string): boolean {

  try {fs.rmdirSync(path)} catch {}

  // 转换
  const packData = JSON.stringify(data)

  // 保存
  try {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, packData)
    fs.closeSync(file)
  } catch (e) {
    log(`保存文件失败: ${e}`, 'error')
    return false
  }

  return true

}

// string[]转json储存（多线程版） //
export async function array_to_json_save_async(data: string[], path: string): Promise<boolean> {

  try {fs.rmdirSync(path)} catch {}

  // 转换
  const packData = JSON.stringify(data)

  // 多线程保存
  try {
    const task = new taskpool.Task(save_task, packData, path)
    const result = await taskpool.execute(task) as boolean
    if (!result) {
      log(`保存文件失败`, 'error')
    }
    return result
  } catch (e) {
    log(`保存文件失败: ${e}`, 'error')
    return false
  }

}

// 批量多线程保存 //
export async function batch_save_async(data_list: Array<Array<string>>, path_list: Array<string>): Promise<boolean[]> {

  const tasks: Promise<boolean>[] = []

  // 创建所有任务
  for (let i = 0; i < data_list.length; i++) {
    tasks.push(array_to_json_save_async(data_list[i], path_list[i]))
  }

  // 并行执行
  const task_results = await Promise.all(tasks)

  return task_results

}

// json读取转string[] //
export function read_json_to_array(path: string): string[] {

  try {
    console.log(path)
    let json: string = fs.readTextSync(path)

    const parsed = JSON.parse(json) as string[]

    // 校验：必须是数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组")
    }

    const result: string[] = []

    // 遍历每个元素，确保是字符串
    for (let i = 0; i < parsed.length; i++) {
      const element = parsed[i]
      if (typeof element !== 'string') {
        throw new Error("JSON 格式错误：数组元素必须是字符串")
      }
      result.push(element)
    }

    return result

  } catch (e) {
    log(`读取文件失败: ${e}`, 'error')
    return []
  }
}