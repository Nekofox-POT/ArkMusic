//
// 初始化
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function init() {
    // 设置默认选中项的文字颜色
    const activeItem = document.querySelector('.choice_bar_item.active')
    if (activeItem) {
        const p = activeItem.querySelector('p')
        if (p) {
            p.classList.add('font_active_color')
            p.style.color = active_color
        }
    }
    // 颜色更新
    set_background_color()
    // 歌曲更新
    ark.get_all_songs()
}

init()