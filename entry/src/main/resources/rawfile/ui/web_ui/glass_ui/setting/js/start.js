//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {
    set_background_color()
    // 初始化高亮开关为开启状态（默认值）
    highlight_enabled = true
    set_toggle_visual(highlight_toggle, highlight_enabled)
    window.parent.postMessage({action: 'iframe_ready'}, '*')
}

init()
