//
// 设置 专用函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 色彩更改型 //
/////////////

// 主题色修改 //
function set_active_color(color = null) {
    play_list.contentWindow.postMessage({action: 'set_active_color', arg1: color}, '*')
    files.contentWindow.postMessage({action: 'set_active_color', arg1: color}, '*')
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
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 图标高亮设置修改 //
//////////////////
function set_button_enable_active_color(value) {
    play_list.contentWindow.postMessage({action: 'set_button_enable_active_color', arg1: value}, '*')
    files.contentWindow.postMessage({action: 'set_button_enable_active_color', arg1: value}, '*')
    button_enable_active_color = value
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 返回手势 //
////////////
function back_gesture() {
    // 如果在页面2则转发手势
    if (page_backup === 2) {
        files.contentWindow.postMessage({action: 'back_gesture'}, '*')
    }
    // 如果在页面1则返回桌面
    else if (page_backup === 1) {
        return 'back'
    }
    // 其他页面则直接返回主页
    else {
        taskbar_page_update(1)
    }
    return ''
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ark文件更新池 //
////////////////
function songs_update(mode, obj) {
    files.contentWindow.postMessage({action: mode, arg1: obj}, '*')
}
function playing_update(obj, num) {
    play_list.contentWindow.postMessage({action: 'update_playing_songs', arg1: obj, arg2: num}, '*')
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 喜欢图标更改 //
///////////////
function set_like(is_like) {
    if (is_like) {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.style.fill = active_color
        })
    } else {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.style.fill = background_color
        })
    }
}