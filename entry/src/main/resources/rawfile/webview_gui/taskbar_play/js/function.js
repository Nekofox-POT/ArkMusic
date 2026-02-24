//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取图标坐标 //
///////////////
function get_icon_position() {

    const taskbar_rect = taskbar.getBoundingClientRect()
    const icons = taskbar_page_icon.querySelectorAll('svg')

    let icon_position = []
    icons.forEach((icon, index) => {
        const icon_rect = icon.getBoundingClientRect()
        icon_position.push(((((taskbar_rect.width - (icons.length * icon_rect.width)) / (icons.length + 1)) + (icon_rect.width / 2)) * (index + 1)) + (index * (icon_rect.width / 2)))
    })
    return icon_position

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面切换 //
////////////
function taskbar_page_update(p) {
    page = p
    // 获取坐标
    let tmp = get_icon_position()
    // 移动
    const taskbar_page_rect = taskbar_page.getBoundingClientRect()
    taskbar_page_screen.style.left = `${(tmp[p] - (taskbar_page_screen_rect.width / 2)) + taskbar_page_rect.left}px`
    taskbar_page_screen.style.top = `${taskbar_page_rect.top}px`
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// touch切换页面 //
/////////////////
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
    
    console.log(closestIndex)
    taskbar_page_update(closestIndex)

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar_page_screen跟随 //
////////////////////////////
function taskbar_page_screen_follow(times) {
    const startTime = Date.now();
    const intervalId = setInterval(() => {

        // 超过0.3s退出
        if (Date.now() - startTime >= times) {clearInterval(intervalId);return;}

        let tmp = get_icon_position()
        const taskbar_page_rect = taskbar_page.getBoundingClientRect()
        taskbar_page_screen.style.left = `${(tmp[page] - (taskbar_page_screen_rect.width / 2)) + taskbar_page_rect.left}px`
        taskbar_page_screen.style.top = `${taskbar_page_rect.top}px`
    }, 1);

}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar展开收缩 //
///////////////////
function taskbar_double(status) {
    if (status) {
        taskbar.classList.add("double")
        taskbar_page_screen_follow(300)
        taskbar_page.classList.add("double")
        taskbar_music.classList.add("double")
    } else {
        taskbar.classList.remove("double")
        taskbar_page_screen_follow(300)
        taskbar_page.classList.remove("double")
        taskbar_music.classList.remove("double")
    }
}