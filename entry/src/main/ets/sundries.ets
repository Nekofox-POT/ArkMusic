//
// 杂物间
// 放一些乱七八糟的变量的地方
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const root_path = getContext().filesDir   // 工作目录
const web_ui_path = getContext().filesDir + '/web_ui/'    // web_ui目录
const audio_player_path = getContext().filesDir + '/audio_player/'    // 音频播放器目录
const files_manager_path = getContext().filesDir + '/files_manager/'    // 文件管理器目录

const global_config_json = getContext().filesDir + '/config.json'   // 配置文件
const version_json = getContext().filesDir + '/version_json.json'   // 版本文件

const support_audio_format: string[] = ['.m4a', '.aac', '.mp3', '.ogg', '.wav', '.flac', '.amr', '.ape']    // 普通音频格式集
const support_dsd_format: string[] = ['.dff', '.dsf', '.dst']   // dsd格式集