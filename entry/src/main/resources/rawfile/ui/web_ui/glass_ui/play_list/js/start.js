//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {
    console.log('[play_list iframe] init 开始')
    // 颜色更新
    set_background_color()
    console.log('[play_list iframe] post iframe_ready')
    window.parent.postMessage({action: 'iframe_ready'}, '*')
}

init()