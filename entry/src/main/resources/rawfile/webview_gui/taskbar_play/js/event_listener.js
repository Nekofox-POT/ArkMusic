//
// 监听池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 触控件 //
//////////

///////////
// 变量池 //
//////////

/////////////
// 监听程序 //
////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar_page_touch组件监听 //
//////////////////////////////

////////////
// 变量池 //
//////////
let taskbar_page_touch_timer = null
let taskbar_page_touch_focus = false

/////////////
// 监听程序 //
////////////
taskbar_page_touch.addEventListener("touchstart", (e) => {
    touch_switch_page(e.touches[0].clientX)
    taskbar_page_screen_rect = taskbar_page_screen.getBoundingClientRect()
    taskbar.classList.add("active")
    taskbar_page_screen.classList.add("active")

    // 0.1秒后激活focus
    taskbar_page_touch_timer = setTimeout(() => {
        taskbar_page_screen.classList.add("focus");
        taskbar_page_update()
        taskbar_page_touch_focus = true
    }, 100)
});
taskbar_page_touch.addEventListener("touchend", () => {

    taskbar.classList.remove("active")
    // taskbar_page_screen归位
    if (taskbar_page_touch_timer) {
        clearTimeout(taskbar_page_touch_timer)
        taskbar_page_touch_timer = null
    }
    if (taskbar_page_touch_focus) {
        setTimeout(() => {taskbar_page_update()}, 300)
    }
    taskbar_page_touch_focus = false
    taskbar_page_screen.classList.remove("active")
    taskbar_page_screen.classList.remove("focus")
});
taskbar_page_touch.addEventListener("touchmove", (e) => {
    touch_switch_page(e.touches[0].clientX)
});
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// music_bar_play_pause_button组件监听 //
///////////////////////////////////////

/////////////
// 监听程序 //
////////////
music_bar_button_play.addEventListener("touchstart", () => {
    music_bar_button_play.classList.add("active")
    music_bar_button_play.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = active_color})
})
music_bar_button_play.addEventListener("touchend", () => {
    music_bar_button_play.classList.remove("active")
    music_bar_button_play.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
music_bar_button_pause.addEventListener("touchstart", () => {
    music_bar_button_pause.classList.add("active")
    music_bar_button_pause.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = active_color})
})
music_bar_button_pause.addEventListener("touchend", () => {
    music_bar_button_pause.classList.remove("active")
    music_bar_button_pause.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// music_bar_song_name组件监听 //
///////////////////////////////

////////////
// 变量池 //
//////////
let music_bar_touch_startX = 0
let music_bar_touch_currentX = 0
let music_bar_touch_isAnimating = false
let music_bar_longPressTimer = null
let music_bar_isMoved = false
let music_bar_isLongPressed = false
let music_bar_rangeStartX = 0
let music_bar_rangeStartValue = 0

/////////////
// 监听程序 //
////////////
music_bar_touch.addEventListener("touchstart", (e) => {
    if (music_bar_touch_isAnimating) return

    setTimeout(() => {taskbar_page_update()}, 50)
    
    music_bar_touch_startX = e.touches[0].clientX
    music_bar_touch_currentX = music_bar_touch_startX
    music_bar_isMoved = false
    music_bar_isLongPressed = false
    
    // 添加dragging类以禁用过渡效果
    music_bar_song_name.classList.add("dragging")
    
    taskbar.classList.add("active")
    
    // 启动长按定时器
    music_bar_longPressTimer = setTimeout(() => {
        music_bar_isLongPressed = true
        music_bar_isMoved = true // 标记为已进入长按状态
        // 显示bg_song_range
        bg_song_range.style.top = '0'
        bg_song_range.style.opacity = '1'
        // 记录调节基准点
        music_bar_rangeStartX = e.touches[0].clientX
        music_bar_rangeStartValue = Number(song_range.value)
        // 更新进度条显示

    }, 500)
})
music_bar_touch.addEventListener("touchmove", (e) => {
    if (music_bar_touch_isAnimating) return
    
    const touch = e.touches[0]
    music_bar_touch_currentX = touch.clientX
    
    // 如果已进入长按状态，调节song_range
    if (music_bar_isLongPressed) {
        is_adjusting = true
        const deltaX = touch.clientX - music_bar_rangeStartX
        // 进度条调节灵敏度（像素->值的映射）
        const sensitivity = 2 // 每2px变化1单位，可根据实际体验调整
        // 获取最新min/max
        const min = Number(song_range.min)
        const max = Number(song_range.max)
        let newValue = music_bar_rangeStartValue + deltaX * ((max - min) / (200 * sensitivity))
        // 限制范围
        newValue = Math.max(min, Math.min(max, Math.round(newValue)))
        song_range.value = newValue
        // 更新进度条显示
        change_song_range()
        return
    }
    
    // 非长按状态下，检测是否发生滑动
    const deltaX = music_bar_touch_currentX - music_bar_touch_startX
    
    // 如果滑动距离超过10像素，判定为滑动
    if (Math.abs(deltaX) > 10) {
        music_bar_isMoved = true
        // 清除长按定时器
        clearTimeout(music_bar_longPressTimer)
        
        // 只在事件可取消时阻止默认行为
        if (e.cancelable) {
            e.preventDefault()
        }
        
        // 限制滑动范围，不让它完全滑出
        const maxDelta = 150
        const clampedDelta = Math.max(-maxDelta, Math.min(maxDelta, deltaX))
        
        // 实时更新song_name的位置
        music_bar_song_name.style.transform = `translateX(calc(0% + ${clampedDelta}px))`
    }
})
music_bar_touch.addEventListener("touchend", (e) => {
    if (music_bar_touch_isAnimating) return
    
    // 清除长按定时器
    clearTimeout(music_bar_longPressTimer)
    
    // 如果处于长按状态，隐藏bg_song_range
    if (music_bar_isLongPressed) {
        is_adjusting = false
        bg_song_range.classList.remove("active")
        bg_song_range.style.opacity = '0'
        setTimeout(() => {bg_song_range.style.top = '100vh'}, 300)
        music_bar_isLongPressed = false
        music_bar_isMoved = false
    } else {
        // 移除dragging类以启用过渡效果
        music_bar_song_name.classList.remove("dragging")
        
        // 如果没有发生滑动，判定为点击
        if (!music_bar_isMoved) {
            taskbar_page_update(1)
        } else {
            // 发生滑动，判断是否超过阈值
            const deltaX = music_bar_touch_currentX - music_bar_touch_startX
            
            if (Math.abs(deltaX) >= 50) {
                music_bar_touch_isAnimating = true
                if (deltaX < 0) {
                    // 往右滑动 -> 上一首
                    music_bar_song_name.style.transform = "translateX(calc(-100% - 50px))"
                    console.log("上一首")
                } else {
                    // 往左滑动 -> 下一首
                    music_bar_song_name.style.transform = "translateX(calc(100% + 50px))"
                    console.log("下一首")
                }
                music_bar_touch_isAnimating = false
            } else {
                // 滑动距离不够，返回原位
                music_bar_song_name.style.transform = "translateX(calc(0% - 0px))"
            }
        }
    }
    
    // 归位
    taskbar.classList.remove("active")
    setTimeout(() => {taskbar_page_update()}, 50)
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// song_range进度条监听 //
///////////////////////
song_range.addEventListener('touchstart', () => {
    is_adjusting = true
})
song_range.addEventListener('touchend', () => {
    is_adjusting = false
})
song_range.addEventListener("input", (e) => {
    change_song_range()
})