// 初始化时检查所有按钮
setupScrollingForAllButtons();

// 使用MutationObserver监听DOM变化，当按钮被添加或删除时重新检查
const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
        if (mutation.type === 'childList' && mutation.target.id === 'all_music_options_list') {
            // 检查是否有按钮被添加或删除
            setupScrollingForAllButtons();
        }
    });
});

// 开始观察
const optionsList = document.getElementById('all_music_options_list');
if (optionsList) {
    observer.observe(optionsList, { childList: true, subtree: true });
}

// 为所有按钮设置滚动效果
function setupScrollingForAllButtons() {
    const buttons = document.querySelectorAll('.list_button');
    buttons.forEach(setupScrollingForButton);
}

// 为单个按钮设置滚动效果
function setupScrollingForButton(button) {
    // 避免重复设置
    if (button.dataset.scrollInitialized) return;
    
    const textContainer = button.querySelector('div');
    const textElement = button.querySelector('p');
    
    if (textContainer && textElement) {
        // 标记已初始化
        button.dataset.scrollInitialized = 'true';
        
        // 检查是否需要滚动
        checkAndSetupScrolling(textContainer, textElement);
        
        // 监听文本内容变化
        const textObserver = new MutationObserver(function() {
            checkAndSetupScrolling(textContainer, textElement);
        });
        
        textObserver.observe(textElement, { characterData: true, subtree: true });
    }
}

// 检查并设置滚动效果
function checkAndSetupScrolling(container, textElement) {
    // 获取容器和内容的宽度
    const containerWidth = container.clientWidth;
    const contentWidth = textElement.scrollWidth;
    
    // 如果内容超出容器宽度，则启用滚动效果
    if (contentWidth > containerWidth) {
        enableScrolling(container, textElement, contentWidth, containerWidth);
    } else {
        disableScrolling(container, textElement);
    }
}

// 启用滚动效果
function enableScrolling(container, textElement, contentWidth, containerWidth) {
    // 添加滚动类
    container.classList.add('scrolling');
    
    // 设置动画 - 3秒完成一次滚动
    textElement.style.animation = 'scrollText 3s linear infinite';
    textElement.style.width = 'auto';
}

// 禁用滚动效果
function disableScrolling(container, textElement) {
    // 移除滚动类
    container.classList.remove('scrolling');
    
    // 清除动画
    textElement.style.animation = 'none';
}