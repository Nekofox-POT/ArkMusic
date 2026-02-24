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
const taskbar_page_choice = document.getElementById('taskbar_page_choice')

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
////////////

const taskbar_page_screen_rect = taskbar_page_screen.getBoundingClientRect()    // 初始化taskbar_page_screen大小

let taskbar_page_screen_freq = 100  // 指示器同步延迟（默认10hz 100ms）
let page = 1    //当前页码