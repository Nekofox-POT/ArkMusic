//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
let iframe_ready_count = 0

function init() {
    console.log('[init] 开始')

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

    console.log('[init] 等待 iframe_ready...')

    // 等待所有iframe加载完毕再ready
    window.addEventListener('message', function(e) {
        if (e.data.action === 'iframe_ready') {
            iframe_ready_count++
            console.log('[init] iframe_ready 收到, count:', iframe_ready_count, 'source:', e.source === play_list.contentWindow ? 'play_list' : e.source === files.contentWindow ? 'files' : e.source === setting.contentWindow ? 'setting' : 'unknown')
            if (iframe_ready_count >= 3) {
                console.log('[init] 全部就绪，调用 ark.ready()')
                ark.ready()
                // 重新广播当前主题色给已就绪的iframe
                set_active_color(active_color)
                set_button_enable_active_color(button_enable_active_color)
                // 页面准备完成后，拉取初始播放状态
                fetch_initial_state()
            }
        }
    })

    console.log('[init] 结束')
}

// 从后端拉取初始播放状态
async function fetch_initial_state() {

    // 播放列表 & 指针（局部变量 songs，避免遮盖全局 DOM 引用 play_list）
    const songs = ark.get_playing_play_list()
    const index = ark.get_playing_index()

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
            if (meta && meta[0] && meta[0].length > 0) {
                set_meta(meta)
            }
        } catch(e) {}

        try {
            const img = await ark.get_image(path)
            if (img[0]) {
                set_image(img[1])
            }
        } catch(e) {}
    }

    // 播放状态
    set_play_status(ark.get_playing_status())

    // 播放模式
    set_play_mode(ark.get_play_mode())

    // 喜欢状态
    set_like(ark.get_like())

    // 定时状态
    const timing = ark.get_timing()
    if (timing > 0) {
        set_timing_time(timing)
    }

    // 当前播放时间
    const current_time = ark.get_playing_time()
    set_current_time(current_time)
    set_current_time_format(second_to_time(current_time))

    // 通知 files 页加载初始数据
    files.contentWindow.postMessage({action: 'songs_update'}, '*')
}

init()
