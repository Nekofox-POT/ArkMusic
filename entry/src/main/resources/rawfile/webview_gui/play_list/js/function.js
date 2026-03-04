//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// slide内元素更新注册滑动 //
///////////////////////////

const slideContainer = document.getElementById('slide');

// 全局状态
let dragState = {
    isDragging: false,
    targetElement: null,   // 原始被点击的元素
    phantomElement: null,  // 跟随手指的“影子”元素（克隆体）
    placeholder: null,     // 占位的白边元素（其实就是 targetElement 变身来的）
    timer: null,
    startX: 0,
    startY: 0,
    offsetX: 0,
    offsetY: 0
};

// --- 1. 触摸开始：判定长按 ---
slideContainer.addEventListener('touchstart', function(e) {
    const target = e.target.closest('.slide > div');
    if (!target) return;

    // 记录初始信息
    dragState.startX = e.touches[0].clientX;
    dragState.startY = e.touches[0].clientY;
    
    // 200ms 长按判定
    dragState.timer = setTimeout(() => {
        startDrag(e, target);
    }, 200);

}, { passive: false });

// --- 核心函数：开始拖拽 ---
function startDrag(e, target) {
    dragState.isDragging = true;
    dragState.targetElement = target;

    // 1. 阻止页面滚动
    e.preventDefault();

    // 2. 创建跟随手指的“影子元素”
    // 克隆节点
    dragState.phantomElement = target.cloneNode(true);
    // 添加放大样式
    dragState.phantomElement.classList.add('dragging-active');
    // 插入到 body 中 (fixed 定位相对于 viewport)
    document.body.appendChild(dragState.phantomElement);

    // 3. 将原元素变为“占位符” (白边)
    target.classList.add('drag-placeholder');

    // 4. 计算位置偏移，保证手指点哪，影子就停在哪
    const rect = target.getBoundingClientRect();
    dragState.offsetX = dragState.startX - rect.left;
    dragState.offsetY = dragState.startY - rect.top;

    // 5. 初始化影子位置
    updatePhantomPosition(e);

    // 6. 震动反馈
    if (navigator.vibrate) navigator.vibrate(30);
}

// --- 2. 触摸移动：跟随与挤压 ---
slideContainer.addEventListener('touchmove', function(e) {
    // 如果还没开始拖拽，检测是否误触滑动
    if (!dragState.isDragging) {
        const moveX = Math.abs(e.touches[0].clientX - dragState.startX);
        const moveY = Math.abs(e.touches[0].clientY - dragState.startY);
        if (moveX > 10 || moveY > 10) {
            clearTimeout(dragState.timer); // 取消长按判定
        }
        return;
    }

    e.preventDefault(); // 防止页面滚动

    // A. 更新影子元素位置
    updatePhantomPosition(e);

    // B. 碰撞检测 -> DOM 交换 -> 实现挤压效果
    const phantomRect = dragState.phantomElement.getBoundingClientRect();
    // 获取占位符当前的位置（这是我们要比较的对象）
    const placeholderRect = dragState.targetElement.getBoundingClientRect();

    // 获取容器下所有子元素
    const children = Array.from(slideContainer.children);

    for (let child of children) {
        // 忽略占位符自己（因为占位符就是 targetElement）
        if (child === dragState.targetElement) continue;
        // 忽略被移除或不可见的元素
        if (child.classList.contains('drag-placeholder')) continue; // 理论上这里只有 targetElement 是 placeholder

        const childRect = child.getBoundingClientRect();

        // 碰撞判定：中心点重叠
        const overlap = !(phantomRect.right < childRect.left || 
                          phantomRect.left > childRect.right || 
                          phantomRect.bottom < childRect.top || 
                          phantomRect.top > childRect.bottom);

        if (overlap) {
            // 决定插入位置：前还是后
            const phantomCenterY = phantomRect.top + phantomRect.height / 2;
            const childCenterY = childRect.top + childRect.height / 2;

            // 在 DOM 中移动占位符
            // 因为我们是移动占位符，其他元素会自动产生动画挤开
            if (phantomCenterY < childCenterY) {
                slideContainer.insertBefore(dragState.targetElement, child);
            } else {
                slideContainer.insertBefore(dragState.targetElement, child.nextSibling);
            }
            break; // 每次移动只处理一个碰撞
        }
    }
}, { passive: false });

// --- 3. 触摸结束：回归动画 ---
slideContainer.addEventListener('touchend', function(e) {
    clearTimeout(dragState.timer);

    if (!dragState.isDragging) return;

    // 1. 移除影子元素
    if (dragState.phantomElement) {
        // 获取占位符当前位置（作为落地目标）
        const placeholderRect = dragState.targetElement.getBoundingClientRect();
        
        // 【关键动画技巧】：
        // 先把影子元素瞬间移动到占位符的位置，并缩小回原样
        // 然后再删除影子，恢复原元素
        const phantom = dragState.phantomElement;
        phantom.style.transition = 'all 0.2s ease-in-out';
        phantom.style.transform = 'scale(1) translateY(0)';
        phantom.style.left = placeholderRect.left + 'px';
        phantom.style.top = placeholderRect.top + 'px';
        phantom.style.opacity = '1';
        phantom.style.boxShadow = 'none';

        // 延迟移除，让动画播放完
        setTimeout(() => {
            if (phantom.parentNode) phantom.parentNode.removeChild(phantom);
        }, 200);
    }

    // 2. 恢复原元素（去掉白边占位符样式）
    dragState.targetElement.classList.remove('drag-placeholder');
    
    // 强制重绘，确保动画衔接
    void dragState.targetElement.offsetWidth; 

    // 3. 重置状态
    dragState.isDragging = false;
    dragState.targetElement = null;
    dragState.phantomElement = null;
});

// 辅助函数：更新影子位置
function updatePhantomPosition(e) {
    if (!dragState.phantomElement) return;
    const touch = e.touches[0];
    dragState.phantomElement.style.left = (touch.clientX - dragState.offsetX) + 'px';
    dragState.phantomElement.style.top = (touch.clientY - dragState.offsetY) + 'px';
}
