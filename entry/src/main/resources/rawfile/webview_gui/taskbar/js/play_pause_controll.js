// 状态更改函数
function change_play_pause(isPlaying) {
    if (isPlaying) {
        button_play.classList.remove('show')
        button_pause.classList.add('show')
    } else {
        button_play.classList.add('show')
        button_pause.classList.remove('show')
    }
}

const play_path = button_play.querySelector('path');
const pause_path = button_pause.querySelector('path');

// 初始化
change_play_pause(false);

// button_play 事件监听
button_play.addEventListener('touchstart', function(e) {
    button_play.classList.add('active');
    play_path.style.transition = 'fill 0.3s ease';
    play_path.style.fill = get_color();
    setTimeout(() => {
        play_path.style.transition = 'fill 1s ease';
    }, 300);
});
button_play.addEventListener('touchend', function(e) {
    button_play.classList.remove('active');
    play_path.style.transition = 'fill 0.3s ease';
    play_path.style.fill = get_bgcolor();
    setTimeout(() => {
        play_path.style.transition = 'fill 1s ease';
    }, 300);

    change_play_pause(true);
})

// button_pause 事件监听
button_pause.addEventListener('touchstart', function(e) {
    button_pause.classList.add('active');
    pause_path.style.transition = 'fill 0.3s ease';
    pause_path.style.fill = get_color();
    setTimeout(() => {
        pause_path.style.transition = 'fill 1s ease';
    }, 300);
});
button_pause.addEventListener('touchend', function(e) {
    button_pause.classList.remove('active');
    pause_path.style.transition = 'fill 0.3s ease';
    pause_path.style.fill = get_bgcolor();
    setTimeout(() => {
        pause_path.style.transition = 'fill 1s ease';
    }, 300);

    change_play_pause(false);
})