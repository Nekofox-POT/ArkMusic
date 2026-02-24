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
    taskbar.classList.add("active")
    taskbar_page_screen.classList.add("active")

    // 0.1秒后激活focus
    taskbar_page_touch_timer = setTimeout(() => {
        taskbar_page_screen.classList.add("focus");
        taskbar_page_update(page)
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
        setTimeout(() => {taskbar_page_update(page)}, 300)
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