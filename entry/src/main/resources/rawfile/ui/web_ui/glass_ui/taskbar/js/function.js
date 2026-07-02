//
// 函数池（UI交互型，非后端广播更新）
// 后端调用的更新函数已统一移至 update.js
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
// 工具函数 //
////////////

// 毫秒转时间格式 //
function second_to_time(time) {
    let min = Math.floor(time / 60000)
    let second = ((time % 60000) / 1000).toFixed(0)
    second = second.padStart(2, '0')
    return `${min}:${second}`
}

// 检查标题是否需要滚动 //
function check_title_overflow() {
    player_title_frame.classList.remove('marquee')
    player_sub_title_frame.classList.remove('marquee')

    void player_title_frame.offsetWidth
    void player_sub_title_frame.offsetWidth

    if (player_title.scrollWidth > player_title_frame.clientWidth * 0.8) {
        player_title_frame.classList.add('marquee')
    }
    if (player_sub_title.scrollWidth > player_sub_title_frame.clientWidth * 0.8) {
        player_sub_title_frame.classList.add('marquee')
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 色彩更改 //
/////////////

// 主题色修改（仅更新UI和广播到iframes，不自动保存。保存由调用方决定）
function set_active_color(color = null) {
    play_list.contentWindow.postMessage({action: 'set_active_color', arg1: color}, '*')
    files.contentWindow.postMessage({action: 'set_active_color', arg1: color}, '*')
    setting.contentWindow.postMessage({action: 'set_active_color', arg1: color}, '*')
    if (color !== null) {
        active_color = color
    }
    document.querySelectorAll('.box_active_color').forEach(element => {
        element.style.backgroundColor = active_color;
    })
    document.querySelectorAll('.svg_active_color').forEach(element => {
        element.style.fill = active_color;
    })
}

// 背景色修改 //
function set_background_color(color = null) {
    play_list.contentWindow.postMessage({action: 'set_background_color', arg1: color}, '*')
    files.contentWindow.postMessage({action: 'set_background_color', arg1: color}, '*')
    setting.contentWindow.postMessage({action: 'set_background_color', arg1: color}, '*')
    if (color !== null) {
        background_color = color
    }
    document.querySelectorAll('.svg_color').forEach(element => {
        element.style.fill = background_color;
    });
    document.querySelectorAll('.font_color').forEach(element => {
        element.style.color = background_color;
    })
    set_active_color()
    update_box_color_advance()
}

// 图标高亮设置修改（仅更新UI和广播，不自动保存）
function set_button_enable_active_color(value) {
    play_list.contentWindow.postMessage({action: 'set_button_enable_active_color', arg1: value}, '*')
    files.contentWindow.postMessage({action: 'set_button_enable_active_color', arg1: value}, '*')
    setting.contentWindow.postMessage({action: 'set_button_enable_active_color', arg1: value}, '*')
    button_enable_active_color = value
}

// 背景模糊度修改（仅更新UI和广播，不自动保存。保存由调用方决定）
function set_blur_intensity(value = null) {
    play_list.contentWindow.postMessage({action: 'set_blur_intensity', arg1: value}, '*')
    files.contentWindow.postMessage({action: 'set_blur_intensity', arg1: value}, '*')
    setting.contentWindow.postMessage({action: 'set_blur_intensity', arg1: value}, '*')
    if (value !== null) {
        blur_intensity = value
    }
    const overlay = document.getElementById('bg_blur_overlay')
    if (overlay) {
        overlay.style.backdropFilter = `blur(${blur_intensity}px)`
    }
    // 高级模糊材质切换
    update_box_color_advance()
}

// 根据 blur_intensity 自动切换高级模糊材质
function update_box_color_advance() {
    if (blur_intensity <= 10) {
        document.querySelectorAll('.box_color').forEach(el => {
            el.classList.add('box_color_advance')
        })
    } else {
        document.querySelectorAll('.box_color_advance').forEach(el => {
            el.classList.remove('box_color_advance')
        })
    }
}
