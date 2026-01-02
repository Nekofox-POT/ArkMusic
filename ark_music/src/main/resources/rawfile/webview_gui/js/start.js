// 初始化
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(function() {
        console.log('加载完毕！')
        set_icon_color_white(255);
        // 初始化
        main_gui.style.transform = `translateX(-100%)`
        taskbar_selector.style.transform = `translateX(-300%)`
    }, 100);
});