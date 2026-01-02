
function post_play_change() {
    if (window.parent) {
        window.parent.postMessage({
            type: 'post_play_change',
        }, '*');
    }
}
function post_last_song() {
    if (window.parent) {
        window.parent.postMessage({
            type: 'post_last_song',
        }, '*');
    }
}
function post_next_song() {
    if (window.parent) {
        window.parent.postMessage({
            type: 'post_next_song',
        }, '*');
    }
}

function play_page_change_play_status(status) {
    // 如果为播放
    if (status === 'play') {
        play_page_play_change.style.transform = 'translateX(-25%)'
    } else if (status === 'pause') {
        play_page_play_change.style.transform = 'translateX(27%)'
    }
}

window.addEventListener('message', function(event) {
    if (event.data.type === 'play_page_change_play_status') {
        play_page_change_play_status(event.data.arg1);
    }
}, false);