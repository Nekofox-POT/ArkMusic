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
    // 获取taskbar_page_choice的位置
    const choiceRect = taskbar_page_choice.getBoundingClientRect()
    const taskbarRect = taskbar.getBoundingClientRect()
    const screenRect = taskbar_page_screen.getBoundingClientRect()
    
    // 计算垂直偏移：让 taskbar_page_screen 的中心对齐到 choiceRect 的中心
    // screenRect.top + screenHeight/2 + translateY = choiceRect.top + choiceRect.height/2
    // 所以 translateY = choiceRect.top + choiceRect.height/2 - screenRect.top - screenHeight/2
    const targetY = choiceRect.top + choiceRect.height / 2 - screenRect.top - screenRect.height / 2
    
    // 计算水平位置：让元素的中心对齐到 choiceRect.left
    const targetX = choiceRect.left - taskbarRect.left - screenRect.width / 2
    
    // 如果未初始化，设置初始隐藏位置在屏幕左边
    if (!taskbar_page_screen_initialized) {
        // 向左偏移到屏幕外，保持垂直位置正确
        taskbar_page_screen.style.transform = `translate(${targetX - window.innerWidth}px, ${targetY}px)`
    } else {
        // 正常定位，同时控制水平和垂直位置
        taskbar_page_screen.style.transform = `translate(${targetX}px, ${targetY}px)`
    }
}, taskbar_page_screen_freq)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// taskbar_page_touch组件监听 //
//////////////////////////////

////////////
// 变量池 //
///////////
let focusTimer = null

//////////////
// 监听程序 //
/////////////
taskbar_page_touch.addEventListener("touchstart", (e) => {
    const touchX = e.touches[0].clientX
    taskbar_page_touch.follow(touchX)
    
    taskbar_page_screen_freq_up()
    taskbar.classList.add("active");
    taskbar_page_screen_inner.classList.add("active");

    // 启动定时器，0.1秒后激活focus
    focusTimer = setTimeout(() => {
        taskbar_page_screen_inner.classList.remove("active");
        taskbar_page_screen_inner.classList.add("focus");
        focusTimer = null
    }, 100)
});
taskbar_page_touch.addEventListener("touchend", () => {
    taskbar_page_screen_freq_up()
    taskbar.classList.remove("active");

    // 清除定时器（如果未触发）
    if (focusTimer) {
        clearTimeout(focusTimer)
        focusTimer = null
    }

    // 移除所有状态
    taskbar_page_screen_inner.classList.remove("active");
    taskbar_page_screen_inner.classList.remove("focus");
});
taskbar_page_touch.addEventListener("touchmove", (e) => {
    const touchX = e.touches[0].clientX
    taskbar_page_touch.follow(touchX)
});