//
// 环境配置
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 组件绑定 //
////////////
const taskbar = document.getElementById('taskbar')
const taskbar_music = document.getElementById('taskbar_music')
const taskbar_page = document.getElementById('taskbar_page')
const taskbar_page_icon = document.getElementById('taskbar_page_icon')
const taskbar_page_touch = document.getElementById('taskbar_page_touch')
const taskbar_music_touch = document.getElementById('taskbar_music_touch')
const taskbar_page_screen = document.getElementById('taskbar_page_screen')
const taskbar_page_screen_inner = document.getElementById('taskbar_page_screen_inner')
const taskbar_page_choice = document.getElementById('taskbar_page_choice')

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
////////////
let taskbar_page_screen_freq = 100  // 指示器同步延迟（默认10hz 100ms）
let page_index_backup = 0   // 图标索引备份（防重复）
let taskbar_page_screen_initialized = false  // taskbar_page_screen 是否已初始化