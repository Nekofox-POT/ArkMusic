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
    if (play_status) {ark.pause()} else {ark.play()}
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
    vol_control.classList.add('active')
})
vol_control.addEventListener("touchend", () => {
    vol_control.classList.remove('active')
    vol_control.classList.add('focus')
    vol_control_frame.classList.add('active')
    ark.set_vol(-1)
})
vol_range.addEventListener("input", (e) => {console.log(e.target.value); ark.set_vol(e.target.value)})
// 点击页面其他地方关闭音量控制面板
document.addEventListener('click', function(e) {
    // 检查点击的目标是否在音量控制区域内
    if (!vol_control.contains(e.target)) {
        vol_control.classList.remove('focus')
        vol_control_frame.classList.remove('active')
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
    set_play_mode("play_forlist")
})
play_forlist_button.addEventListener("touchstart", () => {
    play_forlist_button.classList.add('active')
    play_forlist_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_forlist_button.addEventListener("touchend", () => {
    play_forlist_button.classList.remove('active')
    play_forlist_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    set_play_mode("play_order")
})
play_order_button.addEventListener("touchstart", () => {
    play_order_button.classList.add('active')
    play_order_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_order_button.addEventListener("touchend", () => {
    play_order_button.classList.remove('active')
    play_order_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    set_play_mode("play_disorder")
})
play_disorder_button.addEventListener("touchstart", () => {
    play_disorder_button.classList.add('active')
    play_disorder_button.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
play_disorder_button.addEventListener("touchend", () => {
    play_disorder_button.classList.remove('active')
    play_disorder_button.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    set_play_mode("play_only")
})
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 喜欢图标监听 //
///////////////
player_like_button.addEventListener("touchstart", () => {
    player_like_button.style.transform = 'scale(0.9)'
})
player_like_button.addEventListener("touchend", () => {
    player_like_button.style.transform = 'scale(1)'
    // ark.like(
})