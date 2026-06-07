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
// 控制栏 监听团 //
////////////////

/////////////
// 监听程序 //
////////////
player_last_button.addEventListener("touchstart", () => {
    player_last_button.style.transform = 'scale(0.9)'
    player_last_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
player_last_button.addEventListener("touchend", () => {
    player_last_button.style.transform = 'scale(1)'
    player_last_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
player_play_pause_button.addEventListener("touchstart", () => {
    player_play_pause_button.style.transform = 'scale(0.9)'
    player_play_pause_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
player_play_pause_button.addEventListener("touchend", () => {
    player_play_pause_button.style.transform = 'scale(1)'
    player_play_pause_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    if (play_status) {ark.pause()} else {ark.playing()}
})
player_next_button.addEventListener("touchstart", () => {
    player_next_button.style.transform = 'scale(0.9)'
    player_next_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
player_next_button.addEventListener("touchend", () => {
    player_next_button.style.transform = 'scale(1)'
    player_next_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 音量监听 //
////////////
vol_control.addEventListener("touchstart", () => {
    vol_control.style.transform = 'scale(0.9)'
    vol_control.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
vol_control.addEventListener("touchend", () => {
    vol_control.style.transform = 'scale(1)'
    if (vol_control.classList.contains('focus')) {
        vol_control.classList.remove('focus')
        vol_control_frame.classList.remove('active')
        vol_control.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    } else {
        vol_control.classList.add('focus')
        vol_control_frame.classList.add('active')
        ark.set_vol(-1)
    }
})
vol_range.addEventListener("input", (e) => {console.log(e.target.value); ark.set_vol(e.target.value)})
// 点击页面其他地方关闭音量控制面板
document.addEventListener('click', function(e) {
    // 检查点击的目标是否在音量控制区域内
    if (!vol_control.contains(e.target)) {
        vol_control.classList.remove('focus')
        vol_control_frame.classList.remove('active')
        vol_control.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
        ark.set_vol(-2)
    }
});
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 标题监听 //
////////////
player_title_frame.addEventListener("touchstart", () => {
    player_title_frame.classList.add('active')
})
player_title_frame.addEventListener("touchend", () => {
    player_title_frame.classList.remove('active')
    taskbar_page_update(0)
})
player_sub_title_frame.addEventListener("touchstart", () => {
    player_sub_title_frame.classList.add('active')
})
player_sub_title_frame.addEventListener("touchend", () => {
    player_sub_title_frame.classList.remove('active')
    taskbar_page_update(0)
})
window.addEventListener('resize', check_title_overflow)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放方式监听 //
///////////////
play_only_button.addEventListener("touchstart", () => {
    play_only_button.classList.add('active')
    play_only_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_only_button.addEventListener("touchend", () => {
    play_only_button.classList.remove('active')
    play_only_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
play_forlist_button.addEventListener("touchstart", () => {
    play_forlist_button.classList.add('active')
    play_forlist_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_forlist_button.addEventListener("touchend", () => {
    play_forlist_button.classList.remove('active')
    play_forlist_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
play_order_button.addEventListener("touchstart", () => {
    play_order_button.classList.add('active')
    play_order_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_order_button.addEventListener("touchend", () => {
    play_order_button.classList.remove('active')
    play_order_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
play_disorder_button.addEventListener("touchstart", () => {
    play_disorder_button.classList.add('active')
    play_disorder_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_disorder_button.addEventListener("touchend", () => {
    play_disorder_button.classList.remove('active')
    play_disorder_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 睡眠定时器 //
//////////////

// 定时状态
let sleep_timer_is_active = false
let sleep_timer_wait_end = false

// 打开/关闭遮罩
sleep_timer_icon.addEventListener("touchstart", () => {
    sleep_timer_icon.style.transform = 'scale(0.9)'
    sleep_timer_icon.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
sleep_timer_icon.addEventListener("touchend", () => {
    sleep_timer_icon.style.transform = 'scale(1)'
    sleep_timer_icon.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
sleep_timer_icon.addEventListener("click", () => {
    sleep_timer_overlay.classList.add('active')
    // 同步定时状态
    if (sleep_timer_is_active) {
        // 后端 get_timing 返回毫秒，转换为时分
        const ms = ark.get_timing()
        if (ms > 0) {
            const totalSec = Math.floor(ms / 1000)
            timer_hours = Math.floor(totalSec / 3600)
            timer_minutes = Math.floor((totalSec % 3600) / 60)
            update_hours_text()
            update_minutes_text()
        }
        // 恢复拨动开关状态
        if (ark.get_timed_mode()) {
            sleep_timer_toggle.classList.add('on')
            sleep_timer_toggle.classList.add('box_active_color')
            sleep_timer_toggle.style.backgroundColor = active_color
        } else {
            sleep_timer_toggle.classList.remove('on')
            sleep_timer_toggle.classList.remove('box_active_color')
            sleep_timer_toggle.style.backgroundColor = 'rgba(255, 255, 255, 0.25)'
        }
    }
    // 初始化数字的静止态样式
    set_rest_scales(sleep_timer_hours_prev, sleep_timer_hours, sleep_timer_hours_next)
    set_rest_scales(sleep_timer_minutes_prev, sleep_timer_minutes, sleep_timer_minutes_next)
})
sleep_timer_overlay.addEventListener("click", (e) => {
    if (!sleep_timer_panel.contains(e.target)) {
        sleep_timer_overlay.classList.remove('active')
    }
})

// 开始计时按钮
sleep_timer_start.addEventListener("touchstart", () => {
    sleep_timer_start.style.transform = 'scale(0.9)'
})
sleep_timer_start.addEventListener("touchend", () => {
    sleep_timer_start.style.transform = 'scale(1)'
    const waitEnd = sleep_timer_toggle.classList.contains('on')
    // set_timing 接收毫秒
    const totalMs = (timer_hours * 3600 + timer_minutes * 60) * 1000
    ark.set_timed_mode(waitEnd)
    ark.set_timing(totalMs)
    sleep_timer_overlay.classList.remove('active')
})

// 取消按钮
sleep_timer_cancel.addEventListener("touchstart", () => {
    sleep_timer_cancel.style.transform = 'scale(0.9)'
})
sleep_timer_cancel.addEventListener("touchend", () => {
    sleep_timer_cancel.style.transform = 'scale(1)'
    // 取消定时
    ark.set_timing(0)
    sleep_timer_overlay.classList.remove('active')
})

// 拨动开关
sleep_timer_toggle.addEventListener("click", () => {
    if (sleep_timer_toggle.classList.contains('on')) {
        sleep_timer_toggle.classList.remove('on')
        sleep_timer_toggle.classList.remove('box_active_color')
        sleep_timer_toggle.style.backgroundColor = 'rgba(255, 255, 255, 0.25)'
    } else {
        sleep_timer_toggle.classList.add('on')
        sleep_timer_toggle.classList.add('box_active_color')
        sleep_timer_toggle.style.backgroundColor = active_color
    }
})

// 滚轮时间调节
let timer_hours = 0
let timer_minutes = 30
const STEP_PX = 45           // 每一步对应的像素距离
const ITEM_SPACE = 45        // 相邻数字中心间距

function update_hours_text() {
    sleep_timer_hours.textContent = String(timer_hours).padStart(2, '0')
    sleep_timer_hours_prev.textContent = String((timer_hours + 23) % 24).padStart(2, '0')
    sleep_timer_hours_next.textContent = String((timer_hours + 1) % 24).padStart(2, '0')
}
function update_minutes_text() {
    sleep_timer_minutes.textContent = String(timer_minutes).padStart(2, '0')
    sleep_timer_minutes_prev.textContent = String((timer_minutes + 59) % 60).padStart(2, '0')
    sleep_timer_minutes_next.textContent = String((timer_minutes + 1) % 60).padStart(2, '0')
}

// 根据偏移量设置三个数字的 scale / opacity
// offset: 列当前的 translateY 偏移（px），0 表示中间数字在正中
function apply_number_scales(prev, curr, next, offset) {
    set_num_style(prev, -ITEM_SPACE + offset)
    set_num_style(curr, offset)
    set_num_style(next,  ITEM_SPACE + offset)
}
function set_num_style(el, dist) {
    const t = Math.min(Math.abs(dist) / ITEM_SPACE, 1) // 0=圆心, 1=边缘
    const scale = 1 - t * 0.57  // 1 → 0.43
    const opacity = 1 - t * 0.7 // 1 → 0.3
    el.style.transform = `scale(${scale})`
    el.style.opacity = opacity
}
function reset_number_scales(prev, curr, next) {
    prev.style.transform = ''
    prev.style.opacity = ''
    curr.style.transform = ''
    curr.style.opacity = ''
    next.style.transform = ''
    next.style.opacity = ''
}
// 设置三个数字的最终静止样式（边缘数字缩小、低透明度）
function set_rest_scales(prev, curr, next) {
    set_num_style(prev, -ITEM_SPACE)   // 上边缘：scale≈0.43 opacity≈0.3
    set_num_style(curr, 0)             // 中心：scale=1 opacity=1
    set_num_style(next,  ITEM_SPACE)   // 下边缘：scale≈0.43 opacity≈0.3
}

// ease-out cubic
function ease_out(t) { return 1 - Math.pow(1 - t, 3) }

// JS 驱动列动画（偏移 → 0，动画结束更新文案并重置到 CSS 静止态）
function animate_column_step(column, targetOffset, updateFn, prev, curr, next, duration) {
    const startOffset = parseFloat(column.style.transform.replace(/[^-\d.]/g, '')) || 0
    const startTime = performance.now()

    function tick(now) {
        const p = Math.min((now - startTime) / duration, 1)
        const offset = startOffset + (targetOffset - startOffset) * ease_out(p)
        column.style.transform = `translateY(${offset}px)`
        apply_number_scales(prev, curr, next, offset)
        if (p < 1) {
            requestAnimationFrame(tick)
        } else {
            column.style.transform = 'translateY(0)'
            if (updateFn) updateFn()
            set_rest_scales(prev, curr, next)
        }
    }
    requestAnimationFrame(tick)
}

function animate_snap_back(column, prev, curr, next) {
    const startOffset = parseFloat(column.style.transform.replace(/[^-\d.]/g, '')) || 0
    if (Math.abs(startOffset) < 0.5) { set_rest_scales(prev, curr, next); return }
    animate_column_step(column, 0, null, prev, curr, next, 300)
}

function change_hours(delta) {
    timer_hours = (timer_hours + delta + 24) % 24
    animate_column_step(sleep_timer_hours_column, delta > 0 ? -STEP_PX : STEP_PX,
        update_hours_text, sleep_timer_hours_prev, sleep_timer_hours, sleep_timer_hours_next, 300)
}
function change_minutes(delta) {
    timer_minutes = (timer_minutes + delta + 60) % 60
    animate_column_step(sleep_timer_minutes_column, delta > 0 ? -STEP_PX : STEP_PX,
        update_minutes_text, sleep_timer_minutes_prev, sleep_timer_minutes, sleep_timer_minutes_next, 300)
}

// 小时滚轮（deltaY > 0 为滚轮下滚，值减小）
sleep_timer_hours_unit.addEventListener("wheel", (e) => {
    e.preventDefault()
    change_hours(e.deltaY > 0 ? -1 : 1)
}, {passive: false})
// 分钟滚轮
sleep_timer_minutes_unit.addEventListener("wheel", (e) => {
    e.preventDefault()
    change_minutes(e.deltaY > 0 ? -1 : 1)
}, {passive: false})

// 小时触摸拖动
let hours_touch_start_y = 0
let hours_touch_start_value = 0
sleep_timer_hours_unit.addEventListener("touchstart", (e) => {
    hours_touch_start_y = e.touches[0].clientY
    hours_touch_start_value = timer_hours
    sleep_timer_hours_column.classList.add("dragging")
})
sleep_timer_hours_unit.addEventListener("touchmove", (e) => {
    e.preventDefault()
    const rawOffset = e.touches[0].clientY - hours_touch_start_y
    const steps = Math.round(rawOffset / STEP_PX)
    const newValue = (hours_touch_start_value - steps + 24 * 100) % 24
    const remainder = rawOffset - steps * STEP_PX

    if (newValue !== timer_hours) {
        timer_hours = newValue
        update_hours_text()
    }
    sleep_timer_hours_column.style.transform = `translateY(${remainder}px)`
    apply_number_scales(sleep_timer_hours_prev, sleep_timer_hours, sleep_timer_hours_next, remainder)
}, {passive: false})
sleep_timer_hours_unit.addEventListener("touchend", () => {
    sleep_timer_hours_column.classList.remove("dragging")
    hours_touch_start_value = timer_hours
    animate_snap_back(sleep_timer_hours_column,
        sleep_timer_hours_prev, sleep_timer_hours, sleep_timer_hours_next)
})

// 分钟触摸拖动
let minutes_touch_start_y = 0
let minutes_touch_start_value = 0
sleep_timer_minutes_unit.addEventListener("touchstart", (e) => {
    minutes_touch_start_y = e.touches[0].clientY
    minutes_touch_start_value = timer_minutes
    sleep_timer_minutes_column.classList.add("dragging")
})
sleep_timer_minutes_unit.addEventListener("touchmove", (e) => {
    e.preventDefault()
    const rawOffset = e.touches[0].clientY - minutes_touch_start_y
    const steps = Math.round(rawOffset / STEP_PX)
    const newValue = (minutes_touch_start_value - steps + 60 * 100) % 60
    const remainder = rawOffset - steps * STEP_PX

    if (newValue !== timer_minutes) {
        timer_minutes = newValue
        update_minutes_text()
    }
    sleep_timer_minutes_column.style.transform = `translateY(${remainder}px)`
    apply_number_scales(sleep_timer_minutes_prev, sleep_timer_minutes, sleep_timer_minutes_next, remainder)
}, {passive: false})
sleep_timer_minutes_unit.addEventListener("touchend", () => {
    sleep_timer_minutes_column.classList.remove("dragging")
    minutes_touch_start_value = timer_minutes
    animate_snap_back(sleep_timer_minutes_column,
        sleep_timer_minutes_prev, sleep_timer_minutes, sleep_timer_minutes_next)
})
player_like_button.addEventListener("touchstart", () => {
    player_like_button.style.transform = 'scale(0.9)'
})
player_like_button.addEventListener("touchend", () => {
    player_like_button.style.transform = 'scale(1)'
})
player_like_button.addEventListener("click", () => {
    ark.toggle_like()
})