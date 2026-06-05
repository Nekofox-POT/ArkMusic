//
// 文件管理器
// 广播：8
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 导入第三方库 //
import { fileIo as fs } from '@kit.CoreFileKit'
import emitter from '@ohos.events.emitter'

// 导入自创建模块 //
import nativeModule from 'libentry.so'
import { log, notice } from '../system_function'

// 导入类
import { class_global_config } from '../class_global_config'
import { class_download_manager } from './download_manager'
import { class_external_manager } from './external_manager'

// 变量池 //
const files_manager_path = getContext().filesDir + '/files_manager/'    // 文件管理器目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// Map整合(带自动排序) //
function merge_map(map_a: Map<string, string[]>, map_b: Map<string, string[]>): Map<string, string[]> {

  // 环境准备 //
  let tmp_map = new Map<string, string[]>()
  let result_map = new Map<string, string[]>()

  // 遍历A //
  map_a.forEach((value, key) => {
    if (!tmp_map.has(key)) {
      tmp_map.set(key, [])
    }
    for (const i of value) {tmp_map.get(key)?.push(i)}
  })

  // 遍历B //
  map_b.forEach((value, key) => {
    if (!tmp_map.has(key)) {
      tmp_map.set(key, [])
    }
    for (const i of value) {tmp_map.get(key)?.push(i)}
  })

  // 序列化 //
  for (const i of nativeModule.sortStringArray(Array.from(tmp_map.keys()))) {
    result_map.set(i, nativeModule.sortStringArray(tmp_map.get(i) ?? []))
  }

  // 回传 //
  return result_map

}

// 曲库更新上报 //
function update_post() {
  emitter.emit({ eventId: 812 })
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
  download_manager: class_download_manager | null = null
  external_manager: class_external_manager | null = null

  // 共享变量池 //
  working: boolean = false
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

  // 整合更新数据库 //
  private update_data() {

    // 整合 所有歌曲 //
    this.all_songs_list = nativeModule.sortStringArray([...(this.download_manager?.all_songs_list ?? []), ...(this.external_manager?.all_songs_list ?? [])])
    // 整合 dsd //
    this.dsd_songs_list = this.download_manager?.dsd_songs_list ?? []
    // 整合 hi-res //
    this.hr_songs_list = nativeModule.sortStringArray([...(this.download_manager?.hr_songs_list ?? []), ...(this.external_manager?.hr_songs_list ?? [])])
    // 整合 播放列表 //
    this.play_list = this.download_manager?.play_list ?? new Map<string, string[]>()
    // 整合 歌手 //
    this.artist_list = merge_map(this.download_manager?.artist_list ?? new Map<string, string[]>(), this.external_manager?.artist_list ?? new Map<string, string[]>())
    // 整合 专辑 //
    this.album_list = merge_map(this.download_manager?.album_list ?? new Map<string, string[]>(), this.external_manager?.album_list ?? new Map<string, string[]>())
    // 整合 专辑作家 //
    this.album_artist_list = merge_map(this.download_manager?.album_artist_list ?? new Map<string, string[]>(), this.external_manager?.album_artist_list ?? new Map<string, string[]>())
    // 整合 流派 //
    this.genre_list = merge_map(this.download_manager?.genre_list ?? new Map<string, string[]>(), this.external_manager?.genre_list ?? new Map<string, string[]>())

    // 上报 //
    update_post()

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 扫描 //
  async scan_data(fast: boolean = true) {
    try {

      // 上锁 //
      if (this.working) {return} else {this.working = true}

      // 扫描 //
      if (fast) {
        // 快速扫描
        await this.download_manager?.scan_data_fast()
      } else {
        // 完整扫描
        await this.download_manager?.scan_data()
      }

      // 更新 //
      this.update_data()

      // 解锁 //
      this.working = false

    } catch (e) {
      log(`扫描出错：${e}`, 'error')
      this.working = false
    }
  }

  // 文件夹查询访问 //
  get_dir(path: string = ''): string[][] {return this.download_manager?.get_dir(path) ?? [[], [], []]}

  // 添加外部歌曲 //
  async add_external_songs() {
    try {

      // 上锁 //
      if (this.working) {return} else {this.working = true}

      // 获取 //
      await this.external_manager?.add_external_song()

      // 更新 //
      this.update_data()

      // 解锁 //
      this.working = false

    } catch (e) {
    log(`外部歌曲添加出错：${e}`, 'error')
    this.working = false
    }
  }

  // 删除外部歌曲 //
  async del_external_songs(del_list: string[]) {
    try {

      // 上锁 //
      if (this.working) {return} else {this.working = true}

      // 获取 //
      await this.external_manager?.del_external_song(del_list)

      // 更新 //
      this.update_data()

      // 解锁 //
      this.working = false

    } catch (e) {
      log(`外部歌曲删除出错：${e}`, 'error')
      this.working = false
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 初始化 //
  //////////

  // 初始化数据库 //
  async load_data() {
    this.download_manager?.load_data()
    await this.external_manager?.scan_data()
    this.update_data()
  }

  // 构造 //
  constructor(import_global_config: class_global_config) {

    // 导入类 //
    this.global_config = import_global_config

    // 初始化类 //
    this.download_manager = new class_download_manager(this.global_config)
    this.external_manager = new class_external_manager(this.global_config)

    // 检查工作目录 //
    try {fs.statSync(files_manager_path)} catch {fs.mkdirSync(files_manager_path)}

  }

}