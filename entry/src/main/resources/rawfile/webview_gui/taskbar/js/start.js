//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {

    // 颜色更新
    set_background_color()
    // 页面归位
    taskbar_page_update(2)   // 临时修改
    // 音量归0
    set_vol(0)
    // 进度条归位
    change_song_range_duration(0)
    change_song_range(0)
    // 播放方式归位
    set_play_mode("play_order")
    // 暂停
    set_play_status(false)

    // ready
    ark.ready()

}

init()