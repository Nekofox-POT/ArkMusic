target = true;

function test() {
    console.log("test");
    // 更改taskbar高度
    const taskbar = document.getElementById('taskbar');
    if (target) {
        taskbar.classList.add('double');
        taskbar_page.classList.add('double');
        target = false;
    } else {
        target = true;
        taskbar.classList.remove('double');
        taskbar_page.classList.remove('double');
    }
}