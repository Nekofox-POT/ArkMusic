//
// 文件管理器
// 广播：8
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { fileUri } from  '@kit.CoreFileKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import picker from '@ohos.file.picker'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice } from '../system_function'
import { get_meta, get_meta_batch } from '../meta_manager'
// 导入类
import { class_global_config } from '../class_global_config'

// 变量池 //
const support_hires_format: string[][] = [
  ['.wav', '.flac', '.ape'],
  ['48khz', '64khz', '88.2khz', '96khz', '128khz', '176.4khz', '192khz', '352.8khz', '384khz'],
  ['24bit', '32bit']
]
const files_manager_path = getContext().filesDir + '/files_manager/'    // 文件管理器目录
const external_path = getContext().filesDir + '/files_manager/external/'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export class class_external_manager {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 类 //
  global_config: class_global_config | null = null

  // 共享变量池 //
  all_songs_list: string[] = []
  hr_songs_list: string[] = []
  play_list = new Map<string, string[]>()
  artist_list = new Map<string, string[]>()
  album_list = new Map<string, string[]>()
  album_artist_list = new Map<string, string[]>()
  genre_list = new Map<string, string[]>()

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 内部函数 //
  ////////////

  // 格式化保存数据 //
  private save_data(data: Map<string, string[][]>) {

    // 初始化所有数据池 //
    this.all_songs_list = []
    this.hr_songs_list = []
    this.artist_list = new Map<string, string[]>()
    this.album_list = new Map<string, string[]>()
    this.album_artist_list = new Map<string, string[]>()
    this.genre_list = new Map<string, string[]>()

    // 分拣 //
    data.forEach((value, key) => {

      // 添加 所有歌曲 //
      this.all_songs_list.push(key)
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

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 添加外部歌曲 //
  async add_external_song() {

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

        // 歌曲检测
        if ((await get_meta(tmp_path))[0].length != 0) {
          // 复制到外部缓存目录
          log(`复制：${tmp_name}`)
          await fs.copyFile(tmp_path, external_path + tmp_name)
          success++
        }

      } catch (e) {log(`外部歌曲添加失败：${e}`, 'error')}
    }

    // 重建数据库 //
    await this.scan_data()

    log(`添加 ${success} 首`)
    notice(`成功添加 ${success} 首歌曲`)

  }

  // 删除歌曲 //
  async del_external_song(del_list: string[]) {

    // 遍历删除 //
    let count: number = 0
    for (const i of del_list) {
      try {
        await fs.unlink(i)
        count++
      } catch {continue}
    }

    // 缓存更新 //
    await this.scan_data()

    log(`删除 ${count} 首`)
    notice(`成功删除 ${count} 首歌曲`)

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////

  // 扫描数据 //
  async scan_data() {

    // 扫描歌曲（格式化完整路径） //
    let tmp_audio: string[] = []
    for (const i of await fs.listFile(external_path)) {
      tmp_audio.push(external_path + i)
    }

    // 获取元数据 //
    const tmp_meta = await get_meta_batch(tmp_audio)

    // 保存 //
    this.save_data(tmp_meta)

  }

  // 构造 //
  constructor(import_global_config: class_global_config) {

    // 导入类 //
    this.global_config = import_global_config

    // 检查工作目录 //
    try {fs.statSync(files_manager_path)} catch {fs.mkdirSync(files_manager_path)}
    try {fs.statSync(external_path)} catch {fs.mkdirSync(external_path)}

  }

}