// 处理主标题
const mainTitleContainer = document.querySelector('.play_page_title');
const mainTitleScroll = document.getElementById('play_page_title_scroll');
const mainTitleElement = document.getElementById('page_play_title');

// 处理副标题
const subTitleContainer = document.querySelector('.play_page_sub_title');
const subTitleScroll = document.getElementById('play_page_sub_title_scroll');
const subTitleElement = document.getElementById('page_play_sub_title');

// 初始化检查
function title_and_sub_title_update_check() {
    checkAndSetupScrolling(mainTitleContainer, mainTitleScroll, mainTitleElement);
    checkAndSetupScrolling(subTitleContainer, subTitleScroll, subTitleElement);
}
title_and_sub_title_update_check();

// 监听窗口大小变化
window.addEventListener('resize', function() {
    checkAndSetupScrolling(mainTitleContainer, mainTitleScroll, mainTitleElement);
    checkAndSetupScrolling(subTitleContainer, subTitleScroll, subTitleElement);
});

// 监听标题内容变化
const observer = new MutationObserver(function() {
    checkAndSetupScrolling(mainTitleContainer, mainTitleScroll, mainTitleElement);
    checkAndSetupScrolling(subTitleContainer, subTitleScroll, subTitleElement);
});

observer.observe(mainTitleElement, { characterData: true, subtree: true });
observer.observe(subTitleElement, { characterData: true, subtree: true });

function checkAndSetupScrolling(container, scrollElement, titleElement) {
    // 获取容器和内容的宽度
    const containerWidth = container.clientWidth;
    const contentWidth = scrollElement.scrollWidth;
    
    // 如果内容超出容器宽度，则启用滚动效果
    if (contentWidth > containerWidth) {
        enableScrolling(container, scrollElement, contentWidth, containerWidth);
    } else {
        disableScrolling(container, scrollElement);
    }
}

function enableScrolling(container, scrollElement, contentWidth, containerWidth) {
    // 添加滚动类
    container.classList.add('scrolling');
    
    // 设置动画 - 3秒完成一次滚动
    scrollElement.style.animation = 'scrollTitle 10s linear infinite';
    scrollElement.style.width = 'auto';
    
    // 重置位置
    scrollElement.style.left = '0px';
}

function disableScrolling(container, scrollElement) {
    // 移除滚动类
    container.classList.remove('scrolling');
    
    // 清除动画
    scrollElement.style.animation = 'none';
    scrollElement.style.width = '100%';
}