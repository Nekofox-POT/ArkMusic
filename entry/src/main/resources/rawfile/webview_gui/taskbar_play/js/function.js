//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面切换 //
////////////

taskbar_page_touch.follow = function(x) {
    // 获取 taskbar 的边界
    const taskbarRect = taskbar_page.getBoundingClientRect()
    // 计算触摸点相对于 taskbar 的位置
    const relativeX = x - taskbarRect.left
    
    // 获取所有 SVG 图标元素
    const icons = taskbar_page_icon.querySelectorAll('svg')
    
    // 计算每个图标的中心位置
    const iconPositions = []
    icons.forEach((icon, index) => {
        const iconRect = icon.getBoundingClientRect()
        const iconCenter = iconRect.left + iconRect.width / 2 - taskbarRect.left
        iconPositions.push(iconCenter)
    })
    
    // 找出距离触摸点最近的图标索引
    let closestIndex = 0
    let minDistance = Math.abs(relativeX - iconPositions[0])
    
    for (let i = 1; i < iconPositions.length; i++) {
        const distance = Math.abs(relativeX - iconPositions[i])
        if (distance < minDistance) {
            minDistance = distance
            closestIndex = i
        }
    }
    
    // 调用taskbar_page_update更新位置和颜色
    taskbar_page_update(closestIndex)
}
function taskbar_page_update(page) {
    // 获取所有 SVG 图标元素
    const icons = taskbar_page_icon.querySelectorAll('svg')
    
    // 图标颜色变化
    if (page_index_backup !== page) {
        // 恢复上一个图标的颜色为默认
        const prevIconPaths = icons[page_index_backup].querySelectorAll('.svg_color')
        prevIconPaths.forEach(path => {
            path.style.transition = 'fill 0.3s ease'
            path.style.fill = get_bgcolor()
            setTimeout(() => {
                path.style.transition = 'fill 1s ease'
            }, 300)
        })
        
        page_index_backup = page
        
        // 获取目标颜色并设置给当前锁定图标
        const currentIconPaths = icons[page].querySelectorAll('.svg_color')
        currentIconPaths.forEach(path => {
            path.style.transition = 'fill 0.3s ease'
            path.style.fill = get_color()
            setTimeout(() => {
                path.style.transition = 'fill 1s ease'
            }, 300)
        })
    }
    
    // 获取组件信息
    const taskbar_rect = taskbar_page_icon.getBoundingClientRect()
    const icon_rect = taskbar_page_icon.querySelectorAll('svg')[page].getBoundingClientRect()
    
    // 计算图标中心相对于taskbar的位置
    // taskbar_page_screen会使用translate(-50%, -50%)将中心对齐到taskbar_page_choice的左上角
    // 所以taskbar_page_choice的left值应该直接等于图标中心的坐标
    const iconCenterX = icon_rect.left - taskbar_rect.left + icon_rect.width / 2
    
    // 转换为百分比
    taskbar_page_choice.style.left = `${(iconCenterX / taskbar_rect.width) * 100}%`
    
    // 标记为已初始化，这样 setInterval 就会使用正常位置
    taskbar_page_screen_initialized = true
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar_page_screen提频 //
////////////////////////////
function taskbar_page_screen_freq_up() {
    taskbar_page_screen_freq = 1
    setTimeout(() => {taskbar_page_screen_freq = 100}, 300)
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar展开收缩 //
///////////////////
function taskbar_double(status) {
    if (status) {
        taskbar_page_screen_freq_up()
        taskbar.classList.add("double")
        taskbar_page.classList.add("double")
        taskbar_music.classList.add("double")
    } else {
        taskbar.classList.remove("double")
        taskbar_page.classList.remove("double")
        taskbar_music.classList.remove("double")
    }
}