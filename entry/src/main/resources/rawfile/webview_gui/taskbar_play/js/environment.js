//
// 环境配置
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 组件绑定 //
////////////
const taskbar = document.getElementById('taskbar')
const music_bar = document.getElementById('music_bar')
const taskbar_page = document.getElementById('taskbar_page')
const taskbar_page_icon = document.getElementById('taskbar_page_icon')
const taskbar_page_touch = document.getElementById('taskbar_page_touch')
const music_bar_touch = document.getElementById('music_bar_touch')
const taskbar_page_screen = document.getElementById('taskbar_page_screen')

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
////////////

const taskbar_page_screen_rect = taskbar_page_screen.getBoundingClientRect()    // 初始化taskbar_page_screen大小
const taskbar_page_raw_rect = taskbar_page.getBoundingClientRect()    // 初始化taskbar原位置

let taskbar_page_screen_freq = 100  // 指示器同步延迟（默认10hz 100ms）
let page = 1    //当前页码