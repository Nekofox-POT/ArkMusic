// arkts文档接口

// 更改play状态
function change_play_status(status) {
    change_page_play_status(status)
    // 如果为播放
    if (status === 'play') {
        if (screen_white_black_mode) {
            play_change.innerHTML = '<div style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;"><svg style="z-index: 910;" xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 40 44"><rect class="icon gray" width="15" height="44" rx="7.5"/><rect class="icon gray" width="15" height="44" rx="7.5" transform="translate(25)"/></svg></div>'
        } else {
            play_change.innerHTML = '<div style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;"><svg style="z-index: 910;" xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 40 44"><rect class="icon" width="15" height="44" rx="7.5"/><rect class="icon" width="15" height="44" rx="7.5" transform="translate(25)"/></svg></div>'
        }
        startBackgroundRotation();
    } else if (status === 'pause') {
        // 修改图标
        if (screen_white_black_mode) {
            play_change.innerHTML = '<div style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;"><svg style="z-index: 910;" xmlns="http://www.w3.org/2000/svg" width="25px" height="25px" viewBox="0 0 40 40"><path class="icon gray" d="M19.164,7.9a4.93,4.93,0,0,1,8.957,0L42.955,36.461a6.254,6.254,0,0,1-.007,5.715,5.1,5.1,0,0,1-4.472,2.855H8.809a5.1,5.1,0,0,1-4.472-2.855,6.254,6.254,0,0,1-.007-5.715Z" transform="translate(45.03 -3.643) rotate(90)"/></svg></div>'
        } else {
            play_change.innerHTML = '<div style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;"><svg style="z-index: 910;" xmlns="http://www.w3.org/2000/svg" width="25px" height="25px" viewBox="0 0 40 40"><path class="icon" d="M19.164,7.9a4.93,4.93,0,0,1,8.957,0L42.955,36.461a6.254,6.254,0,0,1-.007,5.715,5.1,5.1,0,0,1-4.472,2.855H8.809a5.1,5.1,0,0,1-4.472-2.855,6.254,6.254,0,0,1-.007-5.715Z" transform="translate(45.03 -3.643) rotate(90)"/></svg></div>'
        }
        stopBackgroundRotation();
    }

}
function change_page_play_status(status) {
    page_play.contentWindow.postMessage({
        type: 'play_page_change_play_status', arg1: status
    }, '*');
}

// 更新时间
function update_duration_time(time) {
    let min = Math.floor(time / 60000);
    let second = ((time % 60000) / 1000).toFixed(0);
    second = second.padStart(2, '0');
    let format_time = `${min}:${second}`
    music_bar_playback_control.max = time;
    page_play.contentWindow.postMessage({
        type: 'play_page_update_duration_time', arg1: time, arg2: format_time
    }, '*');
}
function update_current_time(time) {
    let min = Math.floor(time / 60000);
    let second = ((time % 60000) / 1000).toFixed(0);
    second = second.padStart(2, '0');
    let format_time = `${min}:${second}`
    music_bar_playback_control.value = time;
    music_bar_playback_screen.style.width = `${(music_bar_playback_control.value / music_bar_playback_control.max * 100)}%`;
    page_play.contentWindow.postMessage({
        type: 'play_page_update_current_time', arg1: time, arg2: format_time
    }, '*');
}

// 更新音量
function change_volume(vol) {
    page_play.contentWindow.postMessage({
        type: 'change_volume', arg1: vol
    }, '*');
}