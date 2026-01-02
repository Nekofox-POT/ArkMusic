// 音乐播放栏标题滚动功能
const titleContainer = document.getElementById('music_bar_title');
const titleScroll = document.getElementById('music_bar_title_scroll');
const titleElement = document.getElementById('title');

// 初始化时检查是否需要滚动
checkAndSetupScrolling();

// 监听窗口大小变化
window.addEventListener('resize', checkAndSetupScrolling);

// 监听标题内容变化
const observer = new MutationObserver(checkAndSetupScrolling);
observer.observe(titleElement, { characterData: true, subtree: true });

function checkAndSetupScrolling() {
    // 获取容器和内容的宽度
    const containerWidth = titleContainer.clientWidth;
    const contentWidth = titleScroll.scrollWidth;
    
    // 如果内容超出容器宽度，则启用滚动效果
    if (contentWidth > containerWidth) {
        enableScrolling();
    } else {
        disableScrolling();
    }
}

function enableScrolling() {
    // 添加滚动类
    titleContainer.classList.add('scrolling');
    
    // 设置动画 - 3秒完成一次滚动
    titleScroll.style.animation = 'scrollTitle 3s linear infinite';
    titleScroll.style.width = 'auto';
    
    // 重置位置
    titleScroll.style.left = '0px';
}

function disableScrolling() {
    // 移除滚动类
    titleContainer.classList.remove('scrolling');
    
    // 清除动画
    titleScroll.style.animation = 'none';
    titleScroll.style.width = '100%';
}