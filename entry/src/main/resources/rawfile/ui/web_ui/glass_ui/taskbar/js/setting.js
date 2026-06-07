//
// 设置 / 文件页 桥接函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 监听子页面的跨层级请求
window.addEventListener('message', function(event) {

    // 设置页请求返回主页面
    if (event.data.action === 'setting_request_back') {
        taskbar_page_update(1)
    }

    // files页请求返回播放页
    if (event.data.action === 'back_to_player') {
        taskbar_page_update(1)
    }

    // 设置页请求展开/收起taskbar
    if (event.data.action === 'taskbar_double') {
        taskbar_double(event.data.arg1)
    }

    // 设置页修改主题色（转发到全局并保存）
    if (event.data.action === 'set_active_color') {
        set_active_color(event.data.arg1)
    }

    // 设置页修改图标高亮开关（转发到全局并保存）
    if (event.data.action === 'set_button_enable_active_color') {
        set_button_enable_active_color(event.data.arg1)
    }

})
