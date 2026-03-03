//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面切换型 //
/////////////

// 获取icon位置 //
function get_icon_position() {

    const taskbar_rect = taskbar.getBoundingClientRect()

    let icon_position = []
    taskbar_icons.forEach((icon, index) => {
        const icon_rect = icon.getBoundingClientRect()
        icon_position.push(((((taskbar_rect.width - (taskbar_icons.length * icon_rect.width)) / (taskbar_icons.length + 1)) + (icon_rect.width / 2)) * (index + 1)) + (index * (icon_rect.width / 2)))
    })
    return icon_position

}

// 页面切换函数 //
function taskbar_page_update(p = page_backup) {
    page_backup = p
    // 获取坐标
    let tmp = get_icon_position()
    // 移动
    const taskbar_page_rect = taskbar_page.getBoundingClientRect()
    taskbar_page_screen.style.left = `${(tmp[p] - (taskbar_page_screen_rect.width / 2)) + taskbar_page_rect.left}px`
    // taskbar变换
    if (p === 1) {
        taskbar_double('single')
    } else {
        taskbar_double('double')
    }
    // 主题色上色
    taskbar_icons.forEach((icon, index) => {
        const icon_path = icon.querySelectorAll('.svg_color')
        if (index === p) {
            icon_path.forEach(path => {
                path.classList.add('svg_active_color')
                path.style.fill = active_color
            })
        } else {
            icon_path.forEach(path => {
                path.classList.remove('svg_active_color')
                path.style.fill = background_color
            })
        }
    })
    // 更新页面
    page.style.transform = `translateX(-${p * 100}%)`

}

// touch切换页面 //
function touch_switch_page(touch_x) {
    const taskbar_page_rect = taskbar_page.getBoundingClientRect()
    const icon_position = get_icon_position()
    
    // 计算touch_x最靠近哪个icon的坐标
    let minDistance = Infinity
    let closestIndex = -1
    
    icon_position.forEach((position, index) => {
        const distance = Math.abs(touch_x - (position + taskbar_page_rect.left))
        if (distance < minDistance) {
            minDistance = distance
            closestIndex = index
        }
    })

    if (closestIndex !== page) {
        taskbar_page_update(closestIndex)
    }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar展开收缩                     //
// double是展开 single是收缩 hide是隐藏 //
//////////////////////////////////////
function taskbar_double(status) {
    if (status === 'single') {
        taskbar.classList.remove("hidden")
        taskbar.classList.remove("double")
        taskbar_page.classList.remove("double")
        music_bar.classList.remove("double")
    } else if (status === 'double') {
        taskbar.classList.remove("hidden")
        taskbar_page_touch.classList.remove("hidden")
        setTimeout(() => {taskbar_page_screen.classList.remove("hidden")}, 50)
        taskbar.classList.add("double")
        taskbar_page.classList.add("double")
        music_bar.classList.add("double")
    } else if (status === 'hidden') {
        taskbar.classList.add("hidden")
        taskbar_page_touch.classList.add("hidden")
        setTimeout(() => {taskbar_page_screen.classList.add("hidden")}, 50)
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放状态            //
// true播放 false暂停 //
//////////////////////
function set_play_status(status) {
    play_status = status
    if (status) {
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
// 进度更改 //
////////////

// 秒转时间函数 //
function second_to_time(time) {
    let min = Math.floor(time / 60000)
    let second = ((time % 60000) / 1000).toFixed(0)
    second = second.padStart(2, '0')
    return `${min}:${second}`
}

// 更改播放时长 //
function change_song_range(value = null) {

    // 更新变量
    if ((value !== null) && !is_adjusting) {
        song_range.value = value
        // 如果为0则添加动画
        if (value === 0) {
            music_bar_song_range.style.transition = 'all 0.1s ease'
            player_controller_range.style.transition = 'all 0.1s ease'
            setTimeout(() => {music_bar_song_range.style.transition = 'top 0.1s ease'}, 100)
            setTimeout(() => {player_controller_range.style.transition = null}, 100)
        }
    }

    // 更新展示器变量
    bg_song_range_bar.style.width = `${(song_range.value / song_range.max) * 2 * 100}%`
    bg_song_range_bar.style.left = `-${(song_range.value / song_range.max) * 100}%`
    music_bar_song_range.style.width = `${(song_range.value / song_range.max) * 2 * 100}%`
    music_bar_song_range.style.left = `-${(song_range.value / song_range.max) * 100}%`
    player_controller_range.style.width = `${(song_range.value / song_range.max) * 2 * 100}%`
    player_controller_range.style.left = `-${(song_range.value / song_range.max) * 100}%`
    // 更新时间
    player_song_range_correct_time.innerText = second_to_time(song_range.value)

}

// 更改总时长 //
function change_song_range_duration(value) {
    song_range.max = value
    player_song_range_duration_time.innerText = second_to_time(value)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 元数据传入 //
/////////////

// 标题 //
function set_meta(meta) {
    taskbar_music_name.innerText = meta[0]
    player_title.innerText = meta[1]
    player_sub_title.innerText = meta[2]
}

// 封面 //
function set_meta_img(dataUrl) {
    // 此时 dataUrl 已经是标准的格式："data:image/jpeg;base64,..."
    // 浏览器可以直接识别，无需 atob 解码，也无需 Blob 转换

    const img = new Image();

    // 成功加载：把封面作为背景图
    img.onload = function() {
        // 注意：直接使用 Data URL 作为背景，不需要 createObjectURL
        const url = `url('${dataUrl}')`;
        try {
            // 更新背景
            music_bar_meta_img.style.backgroundImage = url;
            player_meta_img.style.backgroundImage = url;
            document.body.style.backgroundImage = url;
        } catch (e) {
            console.log('set_meta_img: unable to apply background images', e);
        }
        // 清理引用，防止内存泄漏（虽然 Data URL 占用很小，但保持习惯）
        img.onload = null;
    };

    // 加载失败：设置默认封面
    img.onerror = function() {
        const defaultUrl = "url('taskbar/files/CD.png')";
        try {
            music_bar_meta_img.style.backgroundImage = defaultUrl;
            player_meta_img.style.backgroundImage = defaultUrl;
            document.body.style.backgroundImage = defaultUrl;
        } catch (e) {
            console.log('set_meta_img: unable to apply background images', e);
        }
    };

    // 直接将 Data URL 赋值给 src
    img.src = dataUrl;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放完成提示 //
///////////////
function play_complete() {
    // 暂停
    set_play_status(false)
    // 切歌
    ark.play_song('./洛天依 - 秋之风.flac')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放列表操作 //
///////////////

// 传入 //

// 放歌 //
function play_song() {}