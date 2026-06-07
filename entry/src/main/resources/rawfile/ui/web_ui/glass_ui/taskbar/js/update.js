//
// 后端广播更新函数集
// 所有由后端通过 runJavaScript 调用的函数统一放置在此
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 元数据与封面 (event 712) //
/////////////////////////////

// 元数据更新
function set_meta(meta) {
    console.log('set_meta:', JSON.stringify(meta))
    // meta[0] = 基础数据 [文件名, mtime, 类型, 声道, 采样率, 位深, 比特率, 时长ms, 时长格式化]
    // meta[1] = 音乐信息 [title, artist, album, album_artist, genre]
    taskbar_music_name.innerText = meta[1][0] || meta[0][0]
    player_title.innerText = meta[1][0] || '未知歌曲'
    player_sub_title.innerText = meta[1][1] || '未知歌手'
    // 从元数据中提取总时长
    if (meta[0][7]) {
        set_duration(parseInt(meta[0][7]))
    }
    check_title_overflow()
}

// 封面图片更新 (传入base64)
function set_image(base64) {
    const img = new Image()
    img.onload = function() {
        const url = `url('${base64}')`
        try {
            music_bar_meta_img.style.backgroundImage = url
            player_meta_img.style.backgroundImage = url
            document.body.style.backgroundImage = url
        } catch(e) {}
        img.onload = null
    }
    img.onerror = function() {
        const defaultUrl = "url('taskbar/files/CD.png')"
        try {
            music_bar_meta_img.style.backgroundImage = defaultUrl
            player_meta_img.style.backgroundImage = defaultUrl
            document.body.style.backgroundImage = defaultUrl
        } catch(e) {}
    }
    img.src = base64
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放时间 (event 713) //
/////////////////////////

// 当前播放时间（毫秒）
function set_current_time(time) {
    console.log('set_current_time:', time, 'type:', typeof time)
    const t = Number(time) || 0
    if (!is_adjusting) {
        song_range.value = t
        if (t === 0) {
            music_bar_song_range.style.transition = 'all 0.1s ease'
            player_controller_range.style.transition = 'all 0.1s ease'
            setTimeout(() => { music_bar_song_range.style.transition = 'top 0.1s ease' }, 100)
            setTimeout(() => { player_controller_range.style.transition = null }, 100)
        }
    }
    update_range_visual()
}

// 格式化时间字符串（后端推送可选的格式化值）
function set_current_time_format(formatted) {
    if (formatted && typeof formatted === 'string' && formatted.includes(':')) {
        player_song_range_correct_time.innerText = formatted
        bg_song_range_time.innerText = `${formatted} / ${second_to_time(song_range.max)}`
    }
}

// 总时长更新（从歌曲元数据中获取后由前端自行设置）
function set_duration(time) {
    song_range.max = time
    player_song_range_duration_time.innerText = second_to_time(time)
}

// 更新进度条视觉
function update_range_visual() {
    const max = song_range.max || 1
    const ratio = song_range.value / max
    bg_song_range_bar.style.width = `${ratio * 2 * 100}%`
    bg_song_range_bar.style.left = `-${ratio * 100}%`
    music_bar_song_range.style.width = `${ratio * 2 * 100}%`
    music_bar_song_range.style.left = `-${ratio * 100}%`
    player_controller_range.style.width = `${ratio * 2 * 100}%`
    player_controller_range.style.left = `-${ratio * 100}%`
    player_song_range_correct_time.innerText = second_to_time(song_range.value)
    bg_song_range_time.innerText = `${second_to_time(song_range.value)} / ${second_to_time(song_range.max)}`
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放列表 (event 714) //
/////////////////////////

function set_playing_list(play_list) {
    playing_list = play_list
    // 转发到播放列表 iframe
    play_list.contentWindow.postMessage({action: 'update_playing_songs', arg1: play_list, arg2: playing_list_index}, '*')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放指针 (event 715) //
/////////////////////////

function set_playing_index(index) {
    playing_list_index = index
    // 转发到播放列表 iframe（仅更新高亮）
    play_list.contentWindow.postMessage({action: 'update_playing_songs', arg1: [], arg2: index}, '*')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放状态 (event 716) //
/////////////////////////

function set_play_status(status) {
    console.log('set_play_status:', status, 'type:', typeof status)
    // status 为字符串 'playing'/'paused' 或 boolean true/false
    play_status = (status === 'playing' || status === true)
    if (play_status) {
        music_bar_button_play.classList.add('hidden')
        music_bar_button_pause.classList.remove('hidden')
        player_play_pause_icon.classList.add('active')
    } else {
        music_bar_button_play.classList.remove('hidden')
        music_bar_button_pause.classList.add('hidden')
        player_play_pause_icon.classList.remove('active')
    }
    set_meta_img_rotate(play_status)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放模式 (event 717) //
/////////////////////////

function set_play_mode(value) {
    console.log('set_play_mode:', value, 'type:', typeof value)
    // 0=列表循环  1=单曲  2=顺序  3=随机
    play_only_button.classList.add('hidden')
    play_forlist_button.classList.add('hidden')
    play_order_button.classList.add('hidden')
    play_disorder_button.classList.add('hidden')
    if (value === 0) {
        play_forlist_button.classList.remove('hidden')
    } else if (value === 1) {
        play_only_button.classList.remove('hidden')
    } else if (value === 2) {
        play_order_button.classList.remove('hidden')
    } else if (value === 3) {
        play_disorder_button.classList.remove('hidden')
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 喜欢状态 (event 718) //
/////////////////////////

function set_like(is_like) {
    console.log('set_like:', is_like, 'type:', typeof is_like)
    if (is_like) {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.classList.add('svg_active_color')
            tmp.style.fill = active_color
        })
        player_like_button.style.transition = 'transform 0.15s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        player_like_button.style.transform = 'scale(1.2)'
    } else {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.classList.remove('svg_active_color')
            tmp.style.fill = background_color
        })
        player_like_button.style.transition = 'transform 0.15s ease'
        player_like_button.style.transform = 'scale(0.8)'
    }
    setTimeout(() => { player_like_button.style.transform = 'scale(1)' }, 150)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 定时剩余时间 (event 719) //
/////////////////////////////

function set_timing_time(time) {
    // time 为剩余秒数（由后端 event 719 推送）
    if (time > 0) {
        set_sleep_timer_status(true, time, false)
    } else {
        set_sleep_timer_status(false, 0, false)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主题配置持久化 //
///////////////////

// 从后端加载主题配置
function load_theme_config() {
    try {
        const data = ark.load_data('web_ui')
        console.log('load_theme_config data:', JSON.stringify(data))
        if (data && data.length >= 2) {
            console.log('load_theme_config active_color:', data[0], 'enable:', data[1])
            set_active_color(data[0])
            set_button_enable_active_color(data[1] === '1')
        } else {
            console.log('load_theme_config: 使用默认值')
        }
    } catch(e) {
        console.log('load_theme_config error:', e)
    }
}

// 保存主题配置到后端
function save_theme_config() {
    const data = [
        active_color,
        button_enable_active_color ? '1' : '0'
    ]
    ark.save_data(data, 'web_ui')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 数据库更新 (event 812) //
///////////////////////////

function songs_update() {
    // 通知 files 子页面重新加载数据
    files.contentWindow.postMessage({action: 'songs_update'}, '*')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 返回手势信号 (event 912) //
/////////////////////////////

function back_gesture_signal() {
    // 优先关闭睡眠定时器遮罩
    if (sleep_timer_overlay.classList.contains('active')) {
        sleep_timer_overlay.classList.remove('active')
        return
    }
    // 如果在文件浏览页
    if (page_backup === 2) {
        files.contentWindow.postMessage({action: 'back_gesture'}, '*')
    }
    // 如果在播放主界面
    else if (page_backup === 1) {
        ark.back_desktop()
    }
    // 如果在设置页
    else if (page_backup === 3) {
        setting.contentWindow.postMessage({action: 'back_gesture'}, '*')
    }
    // 其他页面则返回主页
    else {
        taskbar_page_update(1)
    }
}
