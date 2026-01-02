// 页面切换函数
function page_switch(page = 1) {
    if (page === 1) {
        taskbar.className = 'taskbar';
        music_bar.className = 'music_bar';
        music_bar_frame.className = 'music_bar_frame';
        music_bar_playback_screen.classList.remove('high');
        music_bar_playback_screen.classList.add('sink');
    } else if ( page === 0 || page === 2 || page === 3 ) {
        taskbar.className = 'taskbar';
        music_bar.className = 'music_bar show';
        music_bar_frame.className = 'music_bar_frame show';
        music_bar_playback_screen.classList.remove('sink');
        music_bar_playback_screen.classList.add('high');
    } else {
        taskbar.className = 'taskbar hide';
        music_bar_frame.className = 'music_bar_frame show';
        music_bar.className = 'music_bar';
        music_bar_playback_screen.classList.remove('high');
        music_bar_playback_screen.classList.add('sink');
    }
    taskbar_selector.style.transform = `translateX(${(page * 100) - 400}%)`
    main_gui.style.transform = `translateX(-${(page) * 100}%)`
}

// 页面切换外部接口
window.addEventListener('message', function(event) {
    if (event.data.type === 'page_switch') {
        page_switch(event.data.page);
    } else if (event.data.type === 'play_change') {
        play_change();
    }
});