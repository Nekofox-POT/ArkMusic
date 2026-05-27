//
// 文件管理器
// 广播：8
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import emitter from '@ohos.events.emitter'
import picker from '@ohos.file.picker'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice as notice_down } from './system_function'
import { get_meta_batch } from './meta_manager'
import { array_to_json_save, load_json_to_array } from './array_save_load'

// 导入类
import { class_global_config } from './class_global_config'

// 变量池 //
const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']  // 支持的文件类型
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']
const song_path = new fileUri.FileUri('file://docs/storage/Users/currentUser/Download/com.nekofox.linmusic').path   // 文件目录
const audio_player_path = getContext().filesDir + '/audio_player/'    // 音频播放器目录
const files_manager_path = getContext().filesDir + '/files_manager/'    // 文件管理器目录
const external_path = getContext().filesDir + '/files_manager_external_cache/'  // 外部歌曲缓存目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// 扫描进度上报 //
function notice(msg: string) {
  emitter.emit({ eventId: 812 }, { data: {
    msg: msg
  } })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class class_files_manager {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 变量池 //

  // 类 //
  global_config: class_global_config | null = null

  // 共享变量池 //
  is_working: boolean = false
  all_songs_list: string[] = []
  external_songs_list: string[] = []
  play_list = new Map<string, string[]>()
  artist_composer_list = new Map<string, string[]>()
  album_list = new Map<string, string[]>()
  album_artist_list = new Map<string, string[]>()
  genre_list = new Map<string, string[]>()

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 重置表 //
  reset_song_data() {
    // 重置目录
    try {fs.rmdirSync(files_manager_path)} catch {}
    // 重置列表
    this.all_songs_list = []
    this.play_list = new Map<string, string[]>()
    this.artist_composer_list = new Map<string, string[]>()
    this.album_list = new Map<string, string[]>()
    this.album_artist_list = new Map<string, string[]>()
    this.genre_list = new Map<string, string[]>()
  }

  // 建立歌曲缓存 //
  async make_songs_cache() {

    // 初始化数据库
    log('初始化数据库...')
    notice('初始化数据库...')
    try {fs.rmdirSync(files_manager_path)} catch {}
    fs.mkdirSync(files_manager_path)
    fs.mkdirSync(files_manager_path + '/play_list')
    fs.mkdirSync(files_manager_path + '/artist_composer')
    fs.mkdirSync(files_manager_path + '/album')
    fs.mkdirSync(files_manager_path + '/album_artist')
    fs.mkdirSync(files_manager_path + '/genre')
    fs.mkdirSync(files_manager_path + '/dsd_cache')

    // 扫描歌曲(普通歌曲) //
    log('扫描普通歌曲')
    let tmp_audio = fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_audio_format } })
    const tmp_audio_length = tmp_audio.length

    // 构建完整路径列表
    const tmp_audio_paths: string[] = []
    for (let i = 0; i < tmp_audio_length; i++) {
      tmp_audio_paths.push(song_path + '/' + tmp_audio[i])
    }

    // 分批处理歌曲元数据
    const BATCH_SIZE = 16
    const batch_count = Math.ceil(tmp_audio_length / BATCH_SIZE)

    for (let b = 0; b < batch_count; b++) {
      const start = b * BATCH_SIZE
      const end = Math.min(start + BATCH_SIZE, tmp_audio_length)
      const batch_paths = tmp_audio_paths.slice(start, end)

      notice(`正在处理 (${start + 1}-${end}/${tmp_audio_length})`)

      // 批量获取元数据（C++ 多线程并行）
      const batch_meta_map = await get_meta_batch(batch_paths)

      // 处理批量结果
      for (let i = start; i < end; i++) {
        const tmp_path = tmp_audio_paths[i]
        const tmp_meta = batch_meta_map.get(tmp_path)

        if (!tmp_meta) {
          log(`跳过无效元数据: ${tmp_path}`, 'error')
          continue
        }

        // 添加所有歌曲列
        this.all_songs_list.push(tmp_path)

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
      }

    }
    log('扫描dsd')
    if (this.global_config?.dsd_support) {
      let tmp_dsd = fs.listFileSync(song_path, { recursion: true, filter: { suffix: support_dsd_format } })
      const tmp_dsd_length = tmp_dsd.length
      for (let i = 0; i < tmp_dsd_length; i++) {

        notice(`正在转换(${i}/${tmp_dsd_length}): ${tmp_dsd[i]}`)

        // 获取ino号
        let tmp_dsd_path = song_path + '/' + tmp_dsd[i]
        let tmp_ino = `${fs.statSync(fs.openSync(tmp_dsd_path).fd).ino}`

        // 判断是否有已经转换好的文件（获取ino核对名称。）
        let cached_path =audio_player_path + '/dsd_cache/' + tmp_ino + '.wav'
        try {
          fs.statSync(cached_path)
        } catch {
          // 没有缓存，使用ffmpeg转换
          try {
            await nativeModule.dsdToWav(tmp_dsd_path, cached_path)
          } catch (e) {
            log(`dsd转换失败: ${e}`, 'error')
            continue
          }
        }

        // 添加到列表
        this.all_songs_list.push(tmp_dsd_path)

      }
    }
    // 扫描歌单(m3u) //
    log('扫描m3u列表')
    let tmp_m3u_list = fs.listFileSync(song_path, { recursion: true, filter: { suffix: ['.m3u'] } })
    const tmp_m3u_list_length = tmp_m3u_list.length
    for (let i = 0; i < tmp_m3u_list_length; i++) {

      // 尝试读取
      notice(`正在处理(${i}/${tmp_m3u_list_length}): ${tmp_m3u_list[i]}`)
      try {fs.readTextSync(song_path + tmp_m3u_list[i])} catch {continue}

      // 注册环境
      let tmp_play_list: string[] = []
      const tmp_path = song_path + tmp_m3u_list[i]
      const tmp_env = tmp_path.substring(0, tmp_path.lastIndexOf('/') + 1)
      let tmp_name = nativeModule.extractFilename(tmp_path)
      const tmp_list = fs.readTextSync(tmp_path).replace(/\r\n/g, '\n').split('\n').filter(Boolean)

      // 读取
      for (const e of tmp_list) {

        // 格式化
        const tmp = tmp_env + '/' + e.replaceAll('\\', '/')

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

            if (this.global_config?.dsd_support) {

              tmp_play_list.push(tmp)
              // 获取ino号
              let tmp_ino = `${fs.statSync(fs.openSync(tmp).fd).ino}`

              // 判断是否有已经转换好的文件（获取ino核对名称。）
              let cached_path =audio_player_path + '/dsd_cache/' + tmp_ino + '.wav'
              try {
                fs.statSync(cached_path)

              } catch {
                // 没有缓存，使用ffmpeg转换
                try {
                  await nativeModule.dsdToWav(tmp, cached_path)
                } catch (e) {
                  log(`dsd转换失败: ${e}`, 'error')
                  continue
                }
              }

            }

          }

        } catch (e) {log(e, 'error')}

      }

      // 载入
      while (true) {
        if (this.play_list.has(tmp_name)) {tmp_name = tmp_name + ' '} else {break}
      }
      this.play_list.set(tmp_name, tmp_play_list)

    }

    // 保存 //
    let tmp_keys: string[] = []
    let tmp_keys_length: number = 0
    let tmp_values: string[] = []
    let tick: number = 0
    // 所有歌曲
    log('保存 所有歌曲')
    this.all_songs_list = nativeModule.sortStringArray(this.all_songs_list)
    array_to_json_save(this.all_songs_list, files_manager_path + '/all_songs.json')
    // 外部歌曲
    log('保存 外部歌曲')
    this.external_songs_list = nativeModule.sortStringArray(this.external_songs_list)
    array_to_json_save(this.external_songs_list, files_manager_path + '/external_songs.json')
    // 歌手 / 作曲家
    log('保存 歌手 / 作曲家')
    tick = 0
    tmp_keys =  nativeModule.sortStringArray(Array.from(this.artist_composer_list.keys()))
    tmp_keys_length = tmp_keys.length
    for (let i = 0; i < tmp_keys_length; i++) {
      notice(`正在保存 (${i}/${tmp_keys_length})`)
      tmp_values = nativeModule.sortStringArray(this.artist_composer_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, files_manager_path + '/artist_composer/' + tick++ + '.json')
    }
    // 专辑
    log('保存 专辑')
    tick = 0
    tmp_keys = nativeModule.sortStringArray(Array.from(this.album_list.keys()))
    tmp_keys_length = tmp_keys.length
    for (let i = 0; i < tmp_keys_length; i++) {
      notice(`正在保存 (${i}/${tmp_keys_length})`)
      tmp_values = nativeModule.sortStringArray(this.album_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, files_manager_path + '/album/' + tick++ + '.json')
    }
    // 专辑作家
    log('保存 专辑作家')
    tick = 0
    tmp_keys = nativeModule.sortStringArray(Array.from(this.album_artist_list.keys()))
    tmp_keys_length = tmp_keys.length
    for (let i = 0; i < tmp_keys_length; i++) {
      notice(`正在保存 (${i}/${tmp_keys_length})`)
      tmp_values = nativeModule.sortStringArray(this.album_artist_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, files_manager_path + '/album_artist/' + tick++ + '.json')
    }
    // 流派
    log('保存 流派')
    tick = 0
    tmp_keys = nativeModule.sortStringArray(Array.from(this.genre_list.keys()))
    tmp_keys_length = tmp_keys.length
    for (let i = 0; i < tmp_keys_length; i++) {
      notice(`正在保存 (${i}/${tmp_keys_length})`)
      tmp_values = nativeModule.sortStringArray(this.genre_list.get(tmp_keys[i]) ?? [])
      tmp_values.push(tmp_keys[i])
      array_to_json_save(tmp_values, files_manager_path + '/genre/' + tick++ + '.json')
    }
    // 列表
    log('保存 列表')
    tmp_keys = nativeModule.sortStringArray(Array.from(this.play_list.keys()))
    for (const i of tmp_keys) {
      array_to_json_save(this.play_list.get(i) ?? [], files_manager_path + '/play_list/' + nativeModule.base64urlCode(i, true) + '.json')
    }
    log('保存完毕！')
    notice('完成！')

  }

  // 载入列表 //
  async load_data() {

    // 读取文件夹 //
    try {
      fs.statSync(files_manager_path)

      // 加载 //
      // 加载所有歌曲
      notice('读取 所有歌曲')
      for (const i of load_json_to_array(files_manager_path + '/all_songs.json')) {
        // 检查有效性
        try {
          fs.openSync(i)
          this.all_songs_list.push(i)
        } catch {}
      }
      // 加载外部歌曲
      for (const i of fs.listFileSync(external_path, { recursion: false })) {
        this.external_songs_list.push(external_path + i)
      }
      // 加载歌手 / 艺术家
      for (const i of fs.listFileSync(files_manager_path + '/artist_composer/', { recursion: false })) {
        const tmp_path = files_manager_path + '/artist_composer/' + i
        // 读取
        let tmp_list = load_json_to_array(tmp_path)
        // 获取文件名
        const tmp_name = tmp_list.pop() ?? ''
        // 载入
        this.artist_composer_list.set(tmp_name, tmp_list)
      }
      // 加载专辑
      notice('读取 专辑')
      for (const i of fs.listFileSync(files_manager_path + '/album/', { recursion: false })) {
        const tmp_path = files_manager_path + '/album/' + i
        let tmp_list = load_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_list.set(tmp_name, load_json_to_array(tmp_path))
      }
      // 加载专辑作家
      notice('读取 专辑作家')
      for (const i of fs.listFileSync(files_manager_path + '/album_artist/', { recursion: false })) {
        const tmp_path = files_manager_path + '/album_artist/' + i
        let tmp_list = load_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.album_artist_list.set(tmp_name, load_json_to_array(tmp_path))
      }
      // 加载流派
      notice('读取 流派')
      for (const i of fs.listFileSync(files_manager_path + '/genre/', { recursion: false })) {
        const tmp_path = files_manager_path + '/genre/' + i
        let tmp_list = load_json_to_array(tmp_path)
        const tmp_name = tmp_list.pop() ?? ''
        this.genre_list.set(tmp_name, load_json_to_array(tmp_path))
      }
      // 加载列表
      notice('读取 列表')
      for (const i of fs.listFileSync(files_manager_path + '/play_list/', { recursion: false })) {
        const tmp_path = files_manager_path + '/play_list/' + i
        const tmp_name = nativeModule.extractFilename(tmp_path)
        this.play_list.set(nativeModule.base64urlCode(tmp_name, false), load_json_to_array(tmp_path))
      }
      // 加载dsd文件

      notice('完成.')

    } catch (e) {
      // 没有文件夹，扫描
      await this.make_songs_cache()
    }

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部歌曲处理库 //
  ////////////////

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
          if (this.global_config?.dsd_support) {
            file_list.push(tmp_path)
          }
        }
        // 播放列表
        else if (file_suffix == '.m3u') {}

      }

    }

    // 返回
    return [nativeModule.sortStringArray(dir_list), nativeModule.sortStringArray(file_list)]

  }

  // 添加外部歌曲 //
  async get_external_song() {

    // 获取
    const audioSelectOptions = new picker.AudioSelectOptions()
    const audioPicker = new picker.AudioViewPicker()
    const tmp = await audioPicker.select(audioSelectOptions)

    // 导入
    let success: number = 0
    log(`外部添加${tmp.length}首歌曲`)
    for (const i of tmp) {
      try {

        // 解析真实路径
        const tmp_path = new fileUri.FileUri(i).path
        const tmp_name = nativeModule.extractFilename(tmp_path) + tmp_path.substring(tmp_path.lastIndexOf('.')).toLowerCase()

        // 复制到外部缓存目录
        log(`复制：${tmp_path}`)
        fs.copyFileSync(tmp_path, external_path + tmp_name)
        success++

      } catch (e) {log(`外部歌曲添加失败：${e}`, 'error')}
    }

    // 更新表
    this.external_songs_list = []
    for (const i of fs.listFileSync(external_path, { recursion: false })) {
      this.external_songs_list.push(external_path + i)
    }

    // 排序
    this.external_songs_list = nativeModule.sortStringArray(this.external_songs_list)
    notice_down(`成功添加 ${success} 首音乐`)

  }
  // 删除外部歌曲 //
  del_external_song(index: number) {

    // 删除
    const tmp = this.external_songs_list[index]
    try {fs.unlinkSync(tmp)} catch {log(`删除了一个未知目录：${tmp}`, 'error'); return}
    // 更新表
    this.external_songs_list.splice(index, 1)
    // 排序
    notice_down(`已删除：${nativeModule.extractFilename(tmp)}`)

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////
  constructor(import_global_config: class_global_config) {

    // 导入类
    this.global_config = import_global_config
    // 检查外部歌曲目录，没有则创建
    try {fs.statSync(external_path)} catch {fs.mkdirSync(external_path)}

  }

}