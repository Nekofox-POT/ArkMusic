//
// 环境配置
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 组件绑定 //
/////////////

// 页面容器
const setting_page_container = document.getElementById('setting_page_container')

// 设置图标框架
const setting_icon_frame = document.getElementById('setting_icon_frame')

// 配置卡片框架
const setting_config = document.getElementById('setting_config')

// UI设置
const setting_ui_config = document.getElementById('setting_ui_config')

// 快速扫描数据库
const setting_scan_fast = document.getElementById('setting_scan_fast')

// 完整扫描数据库
const setting_scan_full = document.getElementById('setting_scan_full')

// UI设置页 - 返回按钮
const ui_setting_back = document.getElementById('ui_setting_back')

// UI设置页 - 图标高亮开关
const highlight_toggle = document.getElementById('highlight_toggle')

// UI设置页 - 修改主题色按钮
const setting_color_btn = document.getElementById('setting_color_btn')

// 颜色选择器 - 遮罩
const color_picker_overlay = document.getElementById('color_picker_overlay')

// 颜色选择器 - 关闭按钮
const color_picker_close = document.getElementById('color_picker_close')

// 颜色选择器 - 调色板
const color_picker_palette_wrap = document.getElementById('color_picker_palette_wrap')
const color_picker_palette_bg = document.getElementById('color_picker_palette_bg')
const color_picker_palette_dot = document.getElementById('color_picker_palette_dot')

// 颜色选择器 - 色相条
const color_picker_hue_bar = document.getElementById('color_picker_hue_bar')
const color_picker_hue_thumb = document.getElementById('color_picker_hue_thumb')

// 颜色选择器 - 预览
const color_picker_preview = document.getElementById('color_picker_preview')

// 颜色选择器 - HEX输入
const color_picker_hex_input = document.getElementById('color_picker_hex_input')

// 颜色选择器 - RGB输入
const color_picker_r_input = document.getElementById('color_picker_r_input')
const color_picker_g_input = document.getElementById('color_picker_g_input')
const color_picker_b_input = document.getElementById('color_picker_b_input')

// 颜色选择器 - 主题色预览圆点
const setting_color_preview = document.getElementById('setting_color_preview')

// 颜色选择器 - 恢复默认按钮
const setting_color_reset = document.getElementById('setting_color_reset')

// 颜色选择器 - 确认按钮
const color_picker_confirm = document.getElementById('color_picker_confirm')

// 确认对话框
const confirm_overlay = document.getElementById('confirm_overlay')
const confirm_title = document.getElementById('confirm_title')
const confirm_message = document.getElementById('confirm_message')
const confirm_cancel = document.getElementById('confirm_cancel')
const confirm_ok = document.getElementById('confirm_ok')

// 确认对话框回调
let confirm_callback = null

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
/////////////

// 当前设置页索引（0=主设置, 1=UI设置）
let setting_page_index = 0

// 图标高亮状态
let highlight_enabled = button_enable_active_color

// 当前选中的颜色
let selected_color = active_color

// 调色板状态
let picker_hue = 0     // 0-360
let picker_sv = [0, 1] // [saturation, value] 0-1
