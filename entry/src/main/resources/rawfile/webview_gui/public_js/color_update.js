//
// 公共函数池（根页面不能用）
//
let background_color = 'rgba(0, 0, 0, 0.4)'     // 背景颜色
let active_color = 'rgba(244, 198, 206, 1.0)'   // 主题颜色
let button_enable_active_color = true   // 允许点击改色
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 色彩更改型 //
//////////////

// 主题色修改 //
function set_active_color(color = null) {
    if (color !== null) {
        active_color = color
    }
    document.querySelectorAll('.box_active_color').forEach(element => {
        element.style.backgroundColor = active_color;
    })
    document.querySelectorAll('.svg_active_color').forEach(element => {
        element.style.fill = active_color;
    })
    document.querySelectorAll('.font_active_color').forEach(element => {
        element.style.color = active_color;
    })
}

// 背景色修改 //
function set_background_color(color = null) {
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
    button_enable_active_color = value
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听 //
////////////
window.addEventListener('message', function(event) {
    
    func = event.data.action;
    
    if (func === 'set_active_color') {
        set_active_color(event.data.arg1)
    }
    if (func === 'set_background_color') {
        set_background_color(event.data.arg1)
    }
    if (func === 'set_button_enable_active_color') {
        set_button_enable_active_color(event.data.arg1)
    }
    if (func === 'init') {
        init()
    }

});