//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
let iframe_ready_count = 0

function init() {

    // 颜色更新
    set_background_color()
    // 页面归位
    taskbar_page_update(1)
    // 音量归0
    set_vol(0)
    // 进度条归位
    change_song_range_duration(0)
    change_song_range(0)
    // 播放方式归位
    set_play_mode(0)
    // 暂停
    set_play_status(false)

    // 等待所有iframe加载完毕再ready
    window.addEventListener('message', function(e) {
        if (e.data.action === 'iframe_ready') {
            iframe_ready_count++
            if (iframe_ready_count >= 3) {
                ark.ready()
            }
        }
    })

}

init()