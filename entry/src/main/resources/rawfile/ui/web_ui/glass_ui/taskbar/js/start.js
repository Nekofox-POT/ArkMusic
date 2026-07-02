//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function init() {
    console.log('[init] 开始')

    // 加载主题配置
    load_theme_config()

    // 颜色更新
    set_background_color()
    // 模糊度更新
    set_blur_intensity()
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

    console.log('[init] ping 所有 iframe...')

    // 主动 ping 所有 iframe，补偿可能在监听器注册前已发送的消息
    play_list.contentWindow.postMessage({action: 'ping'}, '*')
    files.contentWindow.postMessage({action: 'ping'}, '*')
    setting.contentWindow.postMessage({action: 'ping'}, '*')

    console.log('[init] 结束，当前就绪:', Object.keys(iframe_ready_set).length + '/3')
    // 如果 ping 之前就已经全部就绪了（消息在 environment.js 阶段已收全），直接完成
    try_finish_init()
}

// 检查是否全部就绪，是则完成初始化
function try_finish_init() {
    if (_init_all_done) return
    if (Object.keys(iframe_ready_set).length >= 3) {
        _init_all_done = true
        console.log('[init] 全部就绪，调用 ark.ready()')
        ark.ready()
        // 重新广播当前主题色给已就绪的iframe
        set_active_color(active_color)
        set_button_enable_active_color(button_enable_active_color)
        set_blur_intensity(blur_intensity)
        // 页面准备完成后，拉取初始播放状态
        fetch_initial_state()
    }
}

// environment.js 的监听器收到消息后会调用 try_finish_init（如果已定义）

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
