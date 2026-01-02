function set_icon_color_white(tmp) {

    page_play.contentWindow.postMessage({
        type: 'set_icon_color_white', arg1: tmp
    }, '*');

    const icon = document.querySelectorAll('.icon');
    const icon_p = document.querySelectorAll('.icon_p');
    const icon_div = document.querySelectorAll('.icon_div');
    if (tmp < 180) {
        screen_white_black_mode = false;
        icon.forEach(icon => {
            icon.classList.remove('gray');
        });
        icon_p.forEach(icon_p => {
            icon_p.classList.remove('gray');
        });
        icon_div.forEach(icon_div => {
            icon_div.classList.remove('gray');
        })
    } else {
        screen_white_black_mode = true;
        icon.forEach(icon => {
            icon.classList.add('gray');
        });
        icon_p.forEach(icon_p => {
            icon_p.classList.add('gray');
        });
        icon_div.forEach(icon_div => {
            icon_div.classList.add('gray');
        })
    }
}