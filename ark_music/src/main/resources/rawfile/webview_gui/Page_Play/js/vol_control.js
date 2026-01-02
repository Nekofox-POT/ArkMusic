// 按下事件
vol_control_button.addEventListener('touchstart', function(e) {
    if (vol_control_button.style.width === '40px') {
        vol_control_button.style.transform = 'scale(0.8)';
    }
});
// 移开（点击）事件
vol_control_button.addEventListener('touchend', function(e) {
    vol_control_button.style.width = '150px';
    vol_control_button.style.transform = 'translateX(-110px) scale(1)';
    vol_control_button.style.boxShadow = '0 4px 8px rgba(0, 0, 0, 0.2)';
    vol_control_flex_frame.style.transform = 'translateX(0px)';
    arkts.change_volume(-1);
});
// 移开（取消）事件
vol_control_button.addEventListener('touchcancel', function(e) {
    vol_control_button.style.transform = 'scale(1)';
});

// 点击页面其他地方关闭音量控制面板
document.addEventListener('click', function(e) {
    // 检查点击的目标是否在音量控制区域内
    if (!vol_control_button.contains(e.target)) {
        vol_control_button.style.width = '40px';
        vol_control_button.style.transform = 'translateX(0px) scale(1)';
        vol_control_flex_frame.style.transform = 'translateX(-167px)';
        arkts.change_volume(-2);
    }
});

// 音量滑动事件
vol_control_input.addEventListener('input', function() {
    arkts.change_volume(vol_control_input.value);
});

// arkts接口

window.addEventListener('message', function(event) {
    if (event.data.type === 'change_volume') {
        change_volume(event.data.arg1)
    }
}, false);

function change_volume(vol) {
    console.log('Changing volume to:', vol);
    vol_control_input.value = vol;
    vol_control_input.input
    vol_control_screen.style.width = (vol_control_input.value / vol_control_input.max * 150) + 'px';
}