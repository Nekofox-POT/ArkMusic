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
const music_bar_button_play = document.getElementById('music_bar_button_play')
const music_bar_button_pause = document.getElementById('music_bar_button_pause')
const music_bar_meta_img = document.getElementById('music_bar_meta_img')
const music_bar_song_name = document.getElementById('music_bar_song_name')
const bg_song_range = document.getElementById('bg_song_range')
const song_range = document.getElementById('song_range')
const bg_song_range_bar = document.getElementById('bg_song_range_bar')
const music_bar_song_range = document.getElementById('music_bar_song_range')
const page = document.getElementById('page')

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
////////////

const taskbar_icons = taskbar_page_icon.querySelectorAll('svg')     // icons个数

let taskbar_page_screen_rect = taskbar_page_screen.getBoundingClientRect()    // 初始化taskbar_page_screen大小
let background_color = 'rgba(0, 0, 0, 0.4)'     // 背景颜色
let active_color = 'rgba(244, 198, 206, 1.0)'   // 主题颜色
let page_backup = 1    //当前页码
let is_adjusting = false    // 进度条调节指示器