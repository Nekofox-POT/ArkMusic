window.addEventListener('message', function(event) {
    
    func = event.data.action;

    if (func == 'double_load') {
        if (event.data.arg1) {
            taskbar.classList.add('double');
            taskbar_page.classList.add('double');
            taskbar_music.classList.add('double');
        } else {
            taskbar.classList.remove('double');
            taskbar_page.classList.remove('double');
            taskbar_music.classList.remove('double');
        }
    }
});