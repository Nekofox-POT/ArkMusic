//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 页面切换型 //
///////////////

// 页面切换
function switch_setting_page(n) {
    setting_page_index = n
    setting_page_container.style.transform = `translateX(-${n * 100}%)`
    if (n === 0) {
        // 回到主设置页，展开taskbar
        window.parent.postMessage({action: 'taskbar_double', arg1: 'double'}, '*')
    } else {
        // 进入子页面，收起taskbar
        window.parent.postMessage({action: 'taskbar_double', arg1: 'hidden'}, '*')
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 操作型 //
///////////

// 快速扫描数据库
function scan_fast() {
    ark.scan_data(true)
}

// 完整扫描数据库
function scan_full() {
    ark.scan_data(false)
}

// 打开UI设置
function open_ui_setting() {
    switch_setting_page(1)
}

// 关闭UI设置
function close_ui_setting() {
    switch_setting_page(0)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 开关型 //
///////////

// 切换图标高亮
function toggle_highlight() {
    highlight_enabled = !highlight_enabled
    set_toggle_visual(highlight_toggle, highlight_enabled)
    window.parent.postMessage({action: 'set_button_enable_active_color', arg1: highlight_enabled}, '*')
}

// 设置开关视觉效果
function set_toggle_visual(toggle, on) {
    if (on) {
        toggle.classList.add('on')
        toggle.classList.add('box_active_color')
        toggle.style.backgroundColor = active_color
    } else {
        toggle.classList.remove('on')
        toggle.classList.remove('box_active_color')
        toggle.style.backgroundColor = 'rgba(255, 255, 255, 0.25)'
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 打开/关闭 //
///////////////////////////

// 打开颜色选择器
function open_color_picker() {
    selected_color = active_color
    if (!selected_color.startsWith('#')) {
        selected_color = rgba_to_hex(selected_color)
    }
    const rgb = hex_to_rgb(selected_color)
    const hsv = rgb_to_hsv(rgb[0], rgb[1], rgb[2])
    picker_hue = hsv[0]
    picker_sv = [hsv[1], hsv[2]]

    color_picker_overlay.classList.add('show')
    setTimeout(() => {
        update_palette_hue()
        update_palette_dot()
        update_hue_thumb()
        update_picker_inputs()
    }, 50)
}

// 关闭颜色选择器
function close_color_picker() {
    color_picker_overlay.classList.remove('show')
}

// 应用颜色（通过父页面 postMessage 通知全局更新）
function apply_color() {
    setting_color_preview.style.backgroundColor = selected_color
    window.parent.postMessage({action: 'set_active_color', arg1: selected_color}, '*')
    close_color_picker()
}

// 恢复默认主题色
function reset_color_default() {
    selected_color = '#F4C6CE'
    const rgb = hex_to_rgb(selected_color)
    const hsv = rgb_to_hsv(rgb[0], rgb[1], rgb[2])
    picker_hue = hsv[0]
    picker_sv = [hsv[1], hsv[2]]
    setting_color_preview.style.backgroundColor = selected_color
    window.parent.postMessage({action: 'set_active_color', arg1: selected_color}, '*')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 调色板/色相触摸 //
/////////////////////////////////

// 调色板触摸
function palette_on_touch(e) {
    e.preventDefault()
    const rect = color_picker_palette_wrap.getBoundingClientRect()
    const x = Math.max(0, Math.min(e.touches[0].clientX - rect.left, rect.width))
    const y = Math.max(0, Math.min(e.touches[0].clientY - rect.top, rect.height))
    picker_sv = [x / rect.width, 1 - (y / rect.height)]
    update_palette_dot()
    update_inputs_from_hsv()
}

// 色相条触摸
function hue_on_touch(e) {
    e.preventDefault()
    const rect = color_picker_hue_bar.getBoundingClientRect()
    const x = Math.max(0, Math.min(e.touches[0].clientX - rect.left, rect.width))
    picker_hue = (x / rect.width) * 360
    update_hue_thumb()
    update_palette_hue()
    update_inputs_from_hsv()
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - 视觉更新 //
///////////////////////////

// 更新调色板色相背景
function update_palette_hue() {
    const rgb = hsv_to_rgb(picker_hue, 1, 1)
    color_picker_palette_bg.style.backgroundColor = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`
}

// 更新调色板圆点位置
function update_palette_dot() {
    const rect = color_picker_palette_wrap.getBoundingClientRect()
    color_picker_palette_dot.style.left = `${picker_sv[0] * rect.width}px`
    color_picker_palette_dot.style.top = `${(1 - picker_sv[1]) * rect.height}px`
}

// 更新色相滑块位置
function update_hue_thumb() {
    const rect = color_picker_hue_bar.getBoundingClientRect()
    color_picker_hue_thumb.style.left = `${(picker_hue / 360) * rect.width}px`
}

// 从HSV更新预览/输入框
function update_inputs_from_hsv() {
    const rgb = hsv_to_rgb(picker_hue, picker_sv[0], picker_sv[1])
    const hex = rgb_to_hex(rgb[0], rgb[1], rgb[2])
    color_picker_preview.style.backgroundColor = hex
    color_picker_hex_input.value = hex
    color_picker_r_input.value = rgb[0]
    color_picker_g_input.value = rgb[1]
    color_picker_b_input.value = rgb[2]
    selected_color = hex
}

// 刷新预览/键盘输入框（不改变HSV）
function update_picker_inputs() {
    color_picker_preview.style.backgroundColor = selected_color
    color_picker_hex_input.value = selected_color
    const rgb = hex_to_rgb(selected_color)
    color_picker_r_input.value = rgb[0]
    color_picker_g_input.value = rgb[1]
    color_picker_b_input.value = rgb[2]
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色选择器 - HEX/RGB输入同步 //
//////////////////////////////////

// 从HEX输入更新
function update_color_from_hex() {
    const val = color_picker_hex_input.value.trim()
    if (val.length === 7 && /^#[0-9A-Fa-f]{6}$/.test(val)) {
        const hex = val.toUpperCase()
        selected_color = hex
        const rgb = hex_to_rgb(hex)
        const hsv = rgb_to_hsv(rgb[0], rgb[1], rgb[2])
        picker_hue = hsv[0]
        picker_sv = [hsv[1], hsv[2]]
        update_palette_hue()
        update_palette_dot()
        update_hue_thumb()
        update_picker_inputs()
    }
}

// 从RGB输入更新
function update_color_from_rgb_inputs() {
    let r = clamp_rgb(parseInt(color_picker_r_input.value) || 0)
    let g = clamp_rgb(parseInt(color_picker_g_input.value) || 0)
    let b = clamp_rgb(parseInt(color_picker_b_input.value) || 0)
    const hex = rgb_to_hex(r, g, b)
    selected_color = hex
    color_picker_preview.style.backgroundColor = hex
    color_picker_hex_input.value = hex
    color_picker_r_input.value = r
    color_picker_g_input.value = g
    color_picker_b_input.value = b
    const hsv = rgb_to_hsv(r, g, b)
    picker_hue = hsv[0]
    picker_sv = [hsv[1], hsv[2]]
    update_palette_hue()
    update_palette_dot()
    update_hue_thumb()
}

function clamp_rgb(v) {
    return Math.max(0, Math.min(255, v))
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 颜色转换工具 //
/////////////////

// RGBA → HEX
function rgba_to_hex(rgba) {
    const nums = rgba.match(/[\d.]+/g)
    if (nums && nums.length >= 3) {
        return rgb_to_hex(parseInt(nums[0]), parseInt(nums[1]), parseInt(nums[2]))
    }
    return '#F4C6CE'
}

// HEX → RGB
function hex_to_rgb(hex) {
    hex = hex.replace('#', '')
    return [
        parseInt(hex.substring(0, 2), 16),
        parseInt(hex.substring(2, 4), 16),
        parseInt(hex.substring(4, 6), 16)
    ]
}

// RGB → HEX
function rgb_to_hex(r, g, b) {
    return '#' + [r, g, b].map(x => {
        const h = x.toString(16)
        return h.length === 1 ? '0' + h : h
    }).join('').toUpperCase()
}

// HSV → RGB
function hsv_to_rgb(h, s, v) {
    let r, g, b
    const i = Math.floor(h / 60)
    const f = h / 60 - i
    const p = v * (1 - s)
    const q = v * (1 - f * s)
    const t = v * (1 - (1 - f) * s)
    switch (i % 6) {
        case 0: r = v; g = t; b = p; break
        case 1: r = q; g = v; b = p; break
        case 2: r = p; g = v; b = t; break
        case 3: r = p; g = q; b = v; break
        case 4: r = t; g = p; b = v; break
        case 5: r = v; g = p; b = q; break
    }
    return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)]
}

// RGB → HSV
function rgb_to_hsv(r, g, b) {
    r /= 255; g /= 255; b /= 255
    const max = Math.max(r, g, b)
    const min = Math.min(r, g, b)
    const d = max - min
    let h = 0
    const s = max === 0 ? 0 : d / max
    const v = max
    if (d !== 0) {
        if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
        else if (max === g) h = ((b - r) / d + 2) / 6
        else h = ((r - g) / d + 4) / 6
    }
    return [h * 360, s, v]
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 确认对话框 //
///////////////

// 打开确认对话框（通用）
function open_confirm_dialog(title, message, onConfirm) {
    confirm_title.innerText = title
    confirm_message.innerText = message
    confirm_callback = onConfirm
    confirm_overlay.classList.add('show')
    window.parent.postMessage({action: 'taskbar_double', arg1: 'hidden'}, '*')
}

// 关闭确认对话框
function close_confirm_dialog() {
    confirm_overlay.classList.remove('show')
    confirm_callback = null
    if (setting_page_index === 0) {
        window.parent.postMessage({action: 'taskbar_double', arg1: 'double'}, '*')
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 头像/背景图 //
///////////////

// 设置头像（已废除，进群聊聊天）
function set_head_photo() {
    // 功能已移除
}
