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
// taskbar_page_choice组件监听 //
///////////////////////////////

/////////////
// 监听程序 //
////////////
setInterval(() =>{

}, taskbar_page_screen_freq)

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
        taskbar_page_touch_focus = true
    }, 100)
});
let tmp = false
taskbar_page_touch.addEventListener("touchend", () => {

    // tmp = !tmp
    // taskbar_double(tmp)

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