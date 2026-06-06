//
// 文件管理器
// 广播：8
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log } from '../system_function'
import { get_meta_batch } from '../meta_manager'
import { save_array, load_array, save_map_cust_a, load_map_cust_a, save_map_cust_b, load_map_cust_b } from '../data_save_load'

// 导入类
import class_global_config from '../class_global_config'

// 变量池 //
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_hires_format: string[][] = [
  ['.wav', '.flac', '.ape'],
  ['48khz', '64khz', '88.2khz', '96khz', '128khz', '176.4khz', '192khz', '352.8khz', '384khz'],
  ['24bit', '32bit']
]
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.linmusic').path   // 文件目录
const files_manager_path = getContext().filesDir + '/files_manager/'    // 文件管理器目录
const download_manager_path = getContext().filesDir + '/files_manager/download/'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class class_download_manager {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 类 //
  global_config: class_global_config | null = null

  // 共享变量池 //
  meta_cache = new Map<string, string[][]>()
  all_songs_list: string[] = []
  dsd_songs_list: string[] = []
  hr_songs_list: string[] = []
  play_list = new Map<string, string[]>()
  artist_list = new Map<string, string[]>()
  album_list = new Map<string, string[]>()
  album_artist_list = new Map<string, string[]>()
  genre_list = new Map<string, string[]>()

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 列表扫描保存 //
  private scan_play_list() {

    // 初始化列表 //
    log(`files_manager: 扫描列表`)
    this.play_list = new Map<string, string[]>()

    // 扫描 //
    for (const i of fs.listFileSync(song_path, { recursion: true, filter: { suffix: ['.m3u'] } })) {

      const tmp_path = song_path + '/' + i

      // 文件检查 //
      try {fs.readTextSync(tmp_path)} catch {continue}

      // 环境准备 //
      let tmp_play_list: string[] = []
      const tmp_env = tmp_path.substring(0, tmp_path.lastIndexOf('/') + 1)
      let tmp_name = nativeModule.extractFilename(tmp_path)
      const tmp_list = fs.readTextSync(tmp_path).replace(/\r\n/g, '\n').split('\n').filter(Boolean)

      // 检查 //
      for (const e of tmp_list) {

        // 格式化 //
        const tmp = tmp_env + '/' + e.replaceAll('\\', '/')

        // 文件有效性 //
        try {fs.openSync(tmp)} catch {continue}

        // 后缀解析 //
        let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
        // 普通音乐
        if (support_audio_format.includes(file_suffix)) {tmp_play_list.push(tmp)}
        // dsd音乐
        else if (support_dsd_format.includes(file_suffix)) {
          if (this.global_config!.dsd_support) {
            tmp_play_list.push(tmp)
          }
        }

      }

      // 载入 //
      while (true) {
        if (this.play_list.has(tmp_name)) {tmp_name = tmp_name + ' '} else {break}
      }
      log(`files_manager: 处理列表${tmp_name}`)
      this.play_list.set(tmp_name, tmp_play_list)

    }

    // 保存 //
    save_map_cust_b(this.play_list, download_manager_path + 'play_list.json')

  }

  // 格式化保存数据 //
  private save_data(data: Map<string, string[][]>) {

    // 先完成播放列表初始化 //
    this.scan_play_list()

    // 初始化所有数据池 //
    this.all_songs_list = []
    this.dsd_songs_list = []
    this.hr_songs_list = []
    this.artist_list = new Map<string, string[]>()
    this.album_list = new Map<string, string[]>()
    this.album_artist_list = new Map<string, string[]>()
    this.genre_list = new Map<string, string[]>()

    // 分拣 //
    log(`files_manager: 歌曲分类中。`)
    data.forEach((value, key) => {

      // 添加 所有歌曲 //
      this.all_songs_list.push(key)
      // 添加 dsd //
      if (support_dsd_format.includes(key.substring(key.lastIndexOf('.')).toLowerCase())) {
        this.dsd_songs_list.push(key)
        this.hr_songs_list.push(key)
      }
      // 添加 hires //
      if (
          support_hires_format[0].includes(key.substring(key.lastIndexOf('.')).toLowerCase())
          &&
          support_hires_format[1].includes(value[0][4])
          &&
          support_hires_format[2].includes(value[0][5])
      ) {this.hr_songs_list.push(key)}

      // 添加 歌手 / 作曲家 //
      if (!this.artist_list.has(value[1][1])) { this.artist_list.set(value[1][1], [])}
      this.artist_list.get(value[1][1])?.push(key)
      // 添加 专辑 //
      if (!this.album_list.has(value[1][2])) { this.album_list.set(value[1][2], [])}
      this.album_list.get(value[1][2])?.push(key)
      // 添加 专辑作家 //
      if (!this.album_artist_list.has(value[1][3])) { this.album_artist_list.set(value[1][3], [])}
      this.album_artist_list.get(value[1][3])?.push(key)
      // 添加 流派 //
      if (!this.genre_list.has(value[1][4])) { this.genre_list.set(value[1][4], [])}
      this.genre_list.get(value[1][4])?.push(key)

    })

    // 序列化 //
    // 所有歌曲
    this.all_songs_list = nativeModule.sortStringArray(this.all_songs_list)
    // dsd
    this.dsd_songs_list = nativeModule.sortStringArray(this.dsd_songs_list)
    // hires
    this.hr_songs_list = nativeModule.sortStringArray(this.hr_songs_list)
    // --------- //
    let tmp_map = new Map<string, string[]>()
    //  歌手 / 作曲家
    for (const i of nativeModule.sortStringArray(Array.from(this.artist_list.keys()))) {
      tmp_map.set(i, nativeModule.sortStringArray(this.artist_list.get(i) ?? []))
    }
    this.artist_list = new Map(tmp_map)
    // 专辑
    tmp_map = new Map<string, string[]>()
    for (const i of nativeModule.sortStringArray(Array.from(this.album_list.keys()))) {
      tmp_map.set(i, nativeModule.sortStringArray(this.album_list.get(i) ?? []))
    }
    this.album_list = new Map(tmp_map)
    // 专辑作家
    tmp_map = new Map<string, string[]>()
    for (const i of nativeModule.sortStringArray(Array.from(this.album_artist_list.keys()))) {
      tmp_map.set(i, nativeModule.sortStringArray(this.album_artist_list.get(i) ?? []))
    }
    this.album_artist_list = new Map(tmp_map)
    // 流派
    tmp_map = new Map<string, string[]>()
    for (const i of nativeModule.sortStringArray(Array.from(this.genre_list.keys()))) {
      tmp_map.set(i, nativeModule.sortStringArray(this.genre_list.get(i) ?? []))
    }
    this.genre_list = new Map(tmp_map)

    // 保存 //
    save_array(this.all_songs_list, download_manager_path + 'all_songs.json')
    save_array(this.dsd_songs_list, download_manager_path + 'dsd.json')
    save_array(this.hr_songs_list, download_manager_path + 'hr.json')
    save_map_cust_b(this.artist_list, download_manager_path + 'artist.json')
    save_map_cust_b(this.album_list, download_manager_path + 'album.json')
    save_map_cust_b(this.album_artist_list, download_manager_path + 'album_artist.json')
    save_map_cust_b(this.genre_list, download_manager_path + 'genre.json')

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 快速扫描数据库 //
  async scan_data_fast() {

    // 扫描歌曲（格式化完整路径） //
    let tmp_audio: string[] = []
    for (const i of await fs.listFile(song_path, { recursion: true, filter: { suffix: support_audio_format } })) {
      tmp_audio.push(song_path + '/' + i)
    }
    if (this.global_config!.dsd_support) {
      for (const i of await fs.listFile(song_path, { recursion: true, filter: { suffix: support_dsd_format } })) {
        tmp_audio.push(song_path + '/' + i)
      }
    }

    // 缓存查询分离 //
    let tmp_meta = new Map<string, string[][]>()
    let meta_cache_offline: string[] = []
    for (const i of tmp_audio) {
      if (this.meta_cache.has(i)) {
        if ((this.meta_cache.get(i) ?? [])[0][1] == `${fs.statSync(i).mtime}`) {
          // 存在缓存
          tmp_meta.set(i, this.meta_cache.get(i) ?? [])
        } else {
          // 缓存过时
          meta_cache_offline.push(i)
        }

      } else {
        // 不存在缓存
        meta_cache_offline.push(i)
      }
    }

    // 多线程获取元数据（无效数据分拣） //
    const raw_meta = await get_meta_batch(meta_cache_offline)
    raw_meta.forEach((value, key) => {if (value[0].length != 0) {tmp_meta.set(key, value)}})

    // 分类保存 //
    this.save_data(tmp_meta)

    // 处理meta缓存表 //
    this.meta_cache = tmp_meta
    save_map_cust_a(this.meta_cache, download_manager_path + 'meta_cache.json')

  }

  // 完整扫描数据库 //
  async scan_data() {

    // 扫描歌曲（格式化完整路径） //
    let tmp_audio: string[] = []
    for (const i of await fs.listFile(song_path, { recursion: true, filter: { suffix: support_audio_format } })) {
      tmp_audio.push(song_path + '/' + i)
    }
    if (this.global_config!.dsd_support) {
      for (const i of await fs.listFile(song_path, { recursion: true, filter: { suffix: support_dsd_format } })) {
        tmp_audio.push(song_path + '/' + i)
      }
    }

    // 多线程获取元数据（无效数据分拣） //
    log(`files_manager: 获取元数据`)
    let tmp_meta = new Map<string, string[][]>()
    const raw_meta = await get_meta_batch(tmp_audio)
    raw_meta.forEach((value, key) => {if (value[0].length != 0) {tmp_meta.set(key, value)}})

    // 分类保存 //
    this.save_data(tmp_meta)

    // 处理meta缓存表 //
    this.meta_cache = tmp_meta
    save_map_cust_a(this.meta_cache, download_manager_path + 'meta_cache.json')

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 文件夹处理 //
  //////////////
  get_dir(path: string = ''): string[][] {

    // 环境准备 //
    let dir: string[] = []
    let files: string[] = []
    let play_list: string[] = []
    let raw_path: string = song_path + '/' + path
    try {

      // 判断类型 //
      // 文件夹
      if (fs.statSync(raw_path).isDirectory()) {

        // 扫描文件夹 //
        for (const i of fs.listFileSync(raw_path, { recursion: false })) {

          // 拼接路径 //
          let tmp_path = raw_path + '/' + i

          // 文件夹处理 //
          if (fs.statSync(tmp_path).isDirectory()) {
            // 文件存在检测
            if (!(
              fs.listFileSync(tmp_path, { recursion: true, filter: { suffix: support_audio_format } }).length == 0
                &&
                fs.listFileSync(tmp_path, { recursion: true, filter: { suffix: support_dsd_format } }).length == 0
                &&
                fs.listFileSync(tmp_path, { recursion: true, filter: { suffix: ['.m3u'] } }).length == 0
            )) {
              // 添加
              dir.push(i)
            }
          }

          // 文件处理 //
          else if (fs.statSync(tmp_path).isFile()) {

            // 判断类型 //
            let file_suffix = tmp_path.substring(tmp_path.lastIndexOf('.')).toLowerCase()
            // 普通音乐
            if (support_audio_format.includes(file_suffix)) {files.push(tmp_path)}
            // dsd音乐
            else if (support_dsd_format.includes(file_suffix)) {if (this.global_config!.dsd_support) {files.push(tmp_path)}}
            // 播放列表
            else if (file_suffix == '.m3u') {play_list.push(tmp_path)}

          }

        }

      }
      // 播放列表
      else if ((fs.statSync(raw_path).isFile()) && (raw_path.substring(raw_path.lastIndexOf('.')).toLowerCase() == '.m3u')) {

        // 扫描 //
        for (const i of fs.readTextSync(raw_path).replace(/\r\n/g, '\n').split('\n').filter(Boolean)) {

          // 格式化 //
          const tmp = raw_path.substring(0, raw_path.lastIndexOf('/') + 1) + '/' + i.replaceAll('\\', '/')

          // 文件有效性 //
          try {fs.openSync(tmp)} catch {continue}

          // 后缀解析 //
          let file_suffix = tmp.substring(tmp.lastIndexOf('.')).toLowerCase()
          // 普通音乐
          if (support_audio_format.includes(file_suffix)) {files.push(tmp)}
          // dsd音乐
          else if (support_dsd_format.includes(file_suffix)) {
            if (this.global_config!.dsd_support) {
              files.push(tmp)
            }
          }

        }

      }

    } catch {}

    // 返回
    return [nativeModule.sortStringArray(dir), nativeModule.sortStringArray(files), nativeModule.sortStringArray(play_list)]

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////

  // 载入数据 //
  load_data() {

    // 载入数据 //
    // 载入元数据缓存
    this.meta_cache = load_map_cust_a(download_manager_path + 'meta_cache.json')
    // 载入 所有歌曲
    for (const i of load_array(download_manager_path + 'all_songs.json')) {
      // 检查有效性
      try {
        fs.openSync(i)
        this.all_songs_list.push(i)
      } catch {}
    }
    // 载入 dsd歌曲
    for (const i of load_array(download_manager_path + 'dsd.json')) {
      // 检查有效性
      try {
        fs.openSync(i)
        this.dsd_songs_list.push(i)
      } catch {}
    }
    // 载入 hires
    for (const i of load_array(download_manager_path + 'hr.json')) {
      // 检查有效性
      try {
        fs.openSync(i)
        this.hr_songs_list.push(i)
      } catch {}
    }
    // 载入 播放列表
    load_map_cust_b(download_manager_path + 'play_list.json').forEach((value, key) => {
      // 检查有效性
      let tmp: string[] = []
      for (const i of value) {
        try {
          fs.openSync(i)
          tmp.push(i)
        } catch {continue}
      }
      this.play_list.set(key, tmp)
    })
    // 载入 歌手类
    load_map_cust_b(download_manager_path + 'artist.json').forEach((value, key) => {
      // 检查有效性
      let tmp: string[] = []
      for (const i of value) {
        try {
          fs.openSync(i)
          tmp.push(i)
        } catch {continue}
      }
      this.artist_list.set(key, tmp)
    })
    // 载入 专辑类
    load_map_cust_b(download_manager_path + 'album.json').forEach((value, key) => {
      // 检查有效性
      let tmp: string[] = []
      for (const i of value) {
        try {
          fs.openSync(i)
          tmp.push(i)
        } catch {continue}
      }
      this.album_list.set(key, tmp)
    })
    // 载入 专辑作家类
    load_map_cust_b(download_manager_path + 'album_artist.json').forEach((value, key) => {
      // 检查有效性
      let tmp: string[] = []
      for (const i of value) {
        try {
          fs.openSync(i)
          tmp.push(i)
        } catch {continue}
      }
      this.album_artist_list.set(key, tmp)
    })
    // 载入 流派类
    load_map_cust_b(download_manager_path + 'genre.json').forEach((value, key) => {
      // 检查有效性
      let tmp: string[] = []
      for (const i of value) {
        try {
          fs.openSync(i)
          tmp.push(i)
        } catch {continue}
      }
      this.genre_list.set(key, tmp)
    })

  }

  // 构造 //
  constructor(import_global_config: class_global_config) {

    // 导入类 //
    this.global_config = import_global_config

    // 检查工作目录 //
    try {fs.statSync(files_manager_path)} catch {fs.mkdirSync(files_manager_path)}
    try {fs.statSync(download_manager_path)} catch {fs.mkdirSync(download_manager_path)}

  }

}