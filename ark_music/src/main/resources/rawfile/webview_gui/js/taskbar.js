// 滑动允许指示
let able_move = true;

// 监听taskbar按下
taskbar.addEventListener('touchstart', function(e) {
    able_move = true;
    taskbar.className = 'taskbar active';
    music_bar.className = 'music_bar active';
    music_bar_playback_screen.classList.remove('high');
    music_bar_playback_screen.classList.add('sink');
});

// 监听taskbar松开（取消）
taskbar.addEventListener('toucancel', function(e) {
    taskbar.className = 'taskbar';
    music_bar.className = 'music_bar';
    music_bar_playback_screen.classList.remove('sink');
});

// 监听taskbar移动
taskbar.addEventListener('touchmove', function(e) {
    if (able_move) {
        // 获取值
        const rect = taskbar.getBoundingClientRect();
        const touch = e.touches[0];
        const x = touch.clientX;
        const y = touch.clientY;
        // 如果滑出边界
        if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
            // 滑出边界，复位
            taskbar.className = 'taskbar';
            music_bar.className = 'music_bar';
            music_bar_playback_screen.classList.remove('sink');
            able_move = false;
        }
    }
});

// 监听taskbar松开（点击）
taskbar.addEventListener('touchend', function(e) {

    // 获取触摸点信息
    const rect = taskbar.getBoundingClientRect();
    const touch = e.changedTouches[0];
    const clickX = touch.clientX - rect.left;
    const taskbarWidth = rect.width;
    
    // 复位
    taskbar.className = 'taskbar';

    // 判断点击位置
    if (clickX < taskbarWidth * (1 / 4)) {
        page_switch(0);
    } else if (clickX < taskbarWidth * (2 / 4)) {
        page_switch(1);
    } else if (clickX < taskbarWidth * (3 / 4)) {
        page_switch(2);
    } else if (clickX < taskbarWidth * (4 / 4)) {
        page_switch(3);
    }
});