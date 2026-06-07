//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {
    // 加载列表选项配置
    load_list_options()
    // 如果没有任何激活项（首次运行无保存配置），默认加载"所有歌曲"
    const activeItem = document.querySelector('.choice_bar_item.active')
    if (activeItem) {
        const p = activeItem.querySelector('p')
        if (p) {
            p.classList.add('font_active_color')
            p.style.color = active_color
        }
    } else {
        // 首次运行，激活第一个可见项
        const firstItem = document.querySelector('.choice_bar_item')
        if (firstItem) {
            firstItem.classList.add('active')
            const p = firstItem.querySelector('p')
            if (p) {
                p.classList.add('font_active_color')
                p.style.color = active_color
            }
            load_page(firstItem.dataset.type)
        }
    }
    // 颜色更新
    set_background_color()
    window.parent.postMessage({action: 'iframe_ready'}, '*')
}

init()
