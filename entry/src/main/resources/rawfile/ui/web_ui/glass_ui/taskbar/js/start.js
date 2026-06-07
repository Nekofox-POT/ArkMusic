//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
let iframe_ready_count = 0

function init() {

    // 加载主题配置
    load_theme_config()

    // 颜色更新
    set_background_color()
    // 页面归位
    taskbar_page_update(1)
    // 音量归0
    set_vol(0)
    // 进度条归位
    set_duration(0)
    set_current_time(0)
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
                // 重新广播当前主题色给已就绪的iframe
                set_active_color(active_color)
                set_button_enable_active_color(button_enable_active_color)
                // 页面准备完成后，拉取初始播放状态
                fetch_initial_state()
            }
        }
    })

}

// 从后端拉取初始播放状态
async function fetch_initial_state() {
    console.log('===== fetch_initial_state 开始 =====')

    // 播放列表 & 指针（局部变量 songs，避免遮盖全局 DOM 引用 play_list）
    const songs = ark.get_playing_play_list()
    const index = ark.get_playing_index()
    console.log('get_playing_play_list:', JSON.stringify(songs), 'length:', songs.length)
    console.log('get_playing_index:', index)

    playing_list = songs
    playing_list_index = index
    if (songs.length > 0) {
        play_list.contentWindow.postMessage({action: 'update_playing_songs', arg1: songs, arg2: index}, '*')
    }

    // 元数据和封面（异步，各自独立，互不阻塞）
    if (songs.length > 0) {
        const path = songs[index]

        try {
            const meta = await ark.get_playing_meta()
            console.log('get_playing_meta:', JSON.stringify(meta))
            if (meta && meta[0] && meta[0].length > 0) {
                set_meta(meta)
            }
        } catch(e) {
            console.log('get_playing_meta error:', e)
        }

        try {
            const img = await ark.get_image(path)
            console.log('get_image hasImg:', img[0], 'len:', img[1] ? img[1].length : 0)
            if (img[0]) {
                set_image(img[1])
            }
        } catch(e) {
            console.log('get_image error:', e)
        }
    }

    // 播放状态
    const status = ark.get_playing_status()
    console.log('get_playing_status:', status, 'type:', typeof status)
    set_play_status(status)

    // 播放模式
    const mode = ark.get_play_mode()
    console.log('get_play_mode:', mode, 'type:', typeof mode)
    set_play_mode(mode)

    // 喜欢状态
    const like = ark.get_like()
    console.log('get_like:', like, 'type:', typeof like)
    set_like(like)

    // 定时状态
    const timing = ark.get_timing()
    console.log('get_timing:', timing)
    if (timing > 0) {
        set_timing_time(timing)
    }

    // 当前播放时间
    const current_time = ark.get_playing_time()
    console.log('get_playing_time:', current_time, 'type:', typeof current_time)
    set_current_time(current_time)
    set_current_time_format(second_to_time(current_time))

    console.log('===== fetch_initial_state 结束 =====')
}

init()
