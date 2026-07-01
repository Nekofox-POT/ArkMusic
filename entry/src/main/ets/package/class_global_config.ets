//
// 全局配置池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////
// 导入第三方库 //
///////////////
import common from '@ohos.app.ability.common'
import { fileIo as fs } from '@kit.CoreFileKit'

//////////////////
// 导入自创建模块 //
/////////////////
import { save_array, load_array } from './data_save_load'
import { log } from './system_function'

///////////
// 变量池 //
//////////
const root_path = getContext().filesDir   // 工作目录
const global_config_json = getContext().filesDir + '/config.json'    // 配置文件

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类框架 //
//////////
@Observed
export default class class_global_config {

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 环境准备 //
  ////////////

  // 公共变量池 //
  reset: boolean = false        // 清理卡

  version: string = '0'         // 当前版本

  player_mode: boolean = false  // 播放器使用 ( F：官方播放器 T：星铃播放器 )
  dsd_support: boolean = true   // dsd播放支持
  ui_mode: number = 0           // ui界面设置 （ 0：个性 1：极简 2：灵动 3：液态 ）

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 外部函数 //
  ////////////

  // 重置app //
  reset_app() {
    this.reset = true
    // 删除所有文件
    for (const i of fs.listFileSync(root_path)) {
      const tmp = `${root_path}/${i}`
      const stat = fs.statSync(tmp)
      if (stat.isDirectory()) {
        fs.rmdirSync(tmp)
      } else {
        fs.unlinkSync(tmp)
      }
    }
    // 关机
    const context = getContext() as common.UIAbilityContext
    context.terminateSelf()
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 保存文件 //
  ////////////
  save_data() {
    if (!this.reset) {
      // 保存文件
      save_array([

        this.version,           // 版本号

        `${this.player_mode}`,  // 播放器模式选择
        `${this.dsd_support}`,  // dsd支持
        `${this.ui_mode}`,      // ui界面选择

      ], global_config_json)
      log('global_config：保存完成！')
    }
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // 打开文件 //
  ////////////

  constructor() {
    // 检测文件存在性
    const tmp = load_array(global_config_json)
    if (tmp.length != 0) {

      // 加载文件
      this.version = tmp[0]

      this.player_mode = (tmp[1] == 'true') ? true : false
      this.dsd_support = (tmp[2] == 'true') ? true : false
      this.ui_mode = Number.parseInt(tmp[3])

    } else {

    }
  }

}