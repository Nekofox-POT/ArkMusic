//
// 监听池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 触控件 //
///////////

////////////
// 变量池 //
///////////

//////////////
// 监听程序 //
////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// setting_icon_frame 组件监听 //
////////////////////////////////

setting_icon_frame.addEventListener("touchstart", () => {
    setting_icon_frame.classList.add("active")
    setting_icon_frame.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
setting_icon_frame.addEventListener("touchend", () => {
    setting_icon_frame.classList.remove("active")
    setting_icon_frame.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
setting_icon_frame.addEventListener("click", () => {
    // 头图功能已移除
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// setting_config / setting_ui_config 组件监听 //
////////////////////////////////////////////////

// 整体框架按下
setting_config.addEventListener("touchstart", () => {
    setting_config.classList.add("active")
})
setting_config.addEventListener("touchend", () => {
    setting_config.classList.remove("active")
})

// UI设置
setting_ui_config.addEventListener("touchstart", () => {
    setting_ui_config.classList.add("active")
    setting_ui_config.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
setting_ui_config.addEventListener("touchend", () => {
    setting_ui_config.classList.remove("active")
    setting_ui_config.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
setting_ui_config.addEventListener("click", () => {
    open_ui_setting()
})

// 更多设置
setting_more_config.addEventListener("touchstart", () => {
    setting_more_config.classList.add("active")
    setting_more_config.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
setting_more_config.addEventListener("touchend", () => {
    setting_more_config.classList.remove("active")
    setting_more_config.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
setting_more_config.addEventListener("click", () => {
    ark.open_setting()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// setting_scan_fast / setting_scan_full 组件监听 //
///////////////////////////////////////////////////

setting_scan_fast.addEventListener("touchstart", () => {
    setting_scan_fast.classList.add("active")
})
setting_scan_fast.addEventListener("touchend", () => {
    setting_scan_fast.classList.remove("active")
})
setting_scan_fast.addEventListener("click", () => {
    scan_fast()
})

setting_scan_full.addEventListener("touchstart", () => {
    setting_scan_full.classList.add("active")
})
setting_scan_full.addEventListener("touchend", () => {
    setting_scan_full.classList.remove("active")
})
setting_scan_full.addEventListener("click", () => {
    scan_full()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ui_setting_back 返回按钮 //
/////////////////////////////

const ui_setting_back_btn = ui_setting_back.querySelector('.setting_sub_back_btn')
ui_setting_back_btn.addEventListener("touchstart", () => {
    ui_setting_back_btn.classList.add("active")
    ui_setting_back_btn.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
ui_setting_back_btn.addEventListener("touchend", () => {
    ui_setting_back_btn.classList.remove("active")
    ui_setting_back_btn.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
ui_setting_back_btn.addEventListener("click", () => {
    close_ui_setting()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// highlight_toggle 高亮开关 //
//////////////////////////////

highlight_toggle.addEventListener("click", () => {
    toggle_highlight()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// setting_color_btn 修改主题色 //
/////////////////////////////////

setting_color_btn.addEventListener("touchstart", () => {
    setting_color_btn.classList.add("active")
})
setting_color_btn.addEventListener("touchend", () => {
    setting_color_btn.classList.remove("active")
})
setting_color_btn.addEventListener("click", () => {
    open_color_picker()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// setting_color_reset 恢复默认主题色 //
///////////////////////////////////////

setting_color_reset.addEventListener("touchstart", () => {
    setting_color_reset.classList.add("active")
})
setting_color_reset.addEventListener("touchend", () => {
    setting_color_reset.classList.remove("active")
})
setting_color_reset.addEventListener("click", (e) => {
    e.stopPropagation()
    reset_color_default()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 关闭/遮罩 //
///////////////////////////

color_picker_close.addEventListener("touchstart", () => {
    color_picker_close.classList.add("active")
})
color_picker_close.addEventListener("touchend", () => {
    color_picker_close.classList.remove("active")
})
color_picker_close.addEventListener("click", () => {
    close_color_picker()
})

color_picker_overlay.addEventListener("click", (e) => {
    if (e.target === color_picker_overlay) {
        close_color_picker()
    }
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 调色板触摸 //
////////////////////////////

color_picker_palette_wrap.addEventListener("touchstart", (e) => {
    palette_on_touch(e)
})
color_picker_palette_wrap.addEventListener("touchmove", (e) => {
    palette_on_touch(e)
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 色相条触摸 //
////////////////////////////

color_picker_hue_bar.addEventListener("touchstart", (e) => {
    hue_on_touch(e)
})
color_picker_hue_bar.addEventListener("touchmove", (e) => {
    hue_on_touch(e)
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - HEX/RGB输入 //
/////////////////////////////

color_picker_hex_input.addEventListener("input", () => {
    update_color_from_hex()
})

color_picker_r_input.addEventListener("input", () => {
    update_color_from_rgb_inputs()
})
color_picker_g_input.addEventListener("input", () => {
    update_color_from_rgb_inputs()
})
color_picker_b_input.addEventListener("input", () => {
    update_color_from_rgb_inputs()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 确认按钮 //
//////////////////////////

color_picker_confirm.addEventListener("touchstart", () => {
    color_picker_confirm.classList.add("active")
})
color_picker_confirm.addEventListener("touchend", () => {
    color_picker_confirm.classList.remove("active")
})
color_picker_confirm.addEventListener("click", () => {
    apply_color()
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 模糊度调节页 监听 //
//////////////////////

setting_blur_btn.addEventListener("touchstart", () => {
    setting_blur_btn.classList.add("active")
})
setting_blur_btn.addEventListener("touchend", () => {
    setting_blur_btn.classList.remove("active")
})
setting_blur_btn.addEventListener("click", () => {
    open_blur_setting()
})

blur_setting_back_btn.addEventListener("touchstart", () => {
    blur_setting_back_btn.classList.add("active")
    blur_setting_back_btn.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
blur_setting_back_btn.addEventListener("touchend", () => {
    blur_setting_back_btn.classList.remove("active")
    blur_setting_back_btn.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})
blur_setting_back_btn.addEventListener("click", () => {
    close_blur_setting()
})

blur_picker_slider.addEventListener("input", () => {
    update_blur_picker_visual()
    sync_blur_to_parent()
})

blur_picker_range_frame.addEventListener("touchstart", () => {
    blur_picker_range_frame.classList.add("active")
})
blur_picker_range_frame.addEventListener("touchend", () => {
    blur_picker_range_frame.classList.remove("active")
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 确认对话框 监听 //
////////////////////

confirm_overlay.addEventListener("click", (e) => {
    if (e.target === confirm_overlay) {
        close_confirm_dialog()
    }
})

confirm_cancel.addEventListener("touchstart", () => {
    confirm_cancel.classList.add("active")
})
confirm_cancel.addEventListener("touchend", () => {
    confirm_cancel.classList.remove("active")
})
confirm_cancel.addEventListener("click", () => {
    close_confirm_dialog()
})

confirm_ok.addEventListener("touchstart", () => {
    confirm_ok.classList.add("active")
})
confirm_ok.addEventListener("touchend", () => {
    confirm_ok.classList.remove("active")
})
confirm_ok.addEventListener("click", () => {
    if (confirm_callback) {
        confirm_callback()
    }
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听（back手势、色彩同步） //
/////////////////////////////////

window.addEventListener('message', function(event) {
    if (event.data.action === 'back_gesture') {
        if (confirm_overlay.classList.contains('show')) {
            close_confirm_dialog()
        } else if (setting_page_index === 2) {
            close_blur_setting()
        } else if (color_picker_overlay.classList.contains('show')) {
            close_color_picker()
        } else if (setting_page_index !== 0) {
            switch_setting_page(0)
        } else {
            window.parent.postMessage({action: 'setting_request_back'}, '*')
        }
    }
    if (event.data.action === 'set_button_enable_active_color') {
        const val = event.data.arg1 === true || event.data.arg1 === 'true'
        highlight_enabled = val
        set_toggle_visual(highlight_toggle, val)
    }
    if (event.data.action === 'set_blur_intensity') {
        const val = Number(event.data.arg1)
        if (!isNaN(val)) {
            blur_intensity = val
            blur_picker_slider.value = val
            setting_blur_value.textContent = `${val}px`
            update_blur_picker_visual()
        }
    }
    if (event.data.action === 'set_background_image') {
        set_background_image(event.data.arg1)
    }
    // 扫描完成 → 恢复按钮
    if (event.data.action === 'songs_update') {
        document.querySelector('.setting_list').classList.remove('scanning')
        document.querySelectorAll('.scan_spinner.active').forEach(s => s.classList.remove('active'))
    }
})
