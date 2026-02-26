//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {

    // 广播其他页面
    // abc.contentWindow.postMessage({action: 'init'}, '*')

    // ready
    try { ark.ready() } catch {}
    // 颜色更新
    set_background_color()
    set_active_color()
    // 页面归位
    taskbar_page_update()
    // 音量归0
    set_vol(0)
    // 进度条归位
    change_song_range_duration(0)
    change_song_range(0)
    // 暂停
    set_play_status(false)

}

init()