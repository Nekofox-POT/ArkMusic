//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {
    set_background_color()
    // 高亮开关从 color_update.js 的 button_enable_active_color 读取初始值
    // 父页面会在 iframe 就绪后广播当前值覆盖
    highlight_enabled = button_enable_active_color
    set_toggle_visual(highlight_toggle, highlight_enabled)
    window.parent.postMessage({action: 'iframe_ready'}, '*')
}

init()
