// 获取 DOM 元素
const taskbar = document.querySelector('.taskbar');
const taskbarInner = document.querySelector('.taskbar-inner');
const targetShow = document.querySelector('.target_show');
const svgs = taskbarInner.querySelectorAll('svg');

// 状态变量
let isDragging = false;
let startX = 0;
let currentX = 0;
let originalLeft = 0;
let isExpanded = false;
let pressTimer = null;
let hasMoved = false;
const LONG_PRESS_THRESHOLD = 300; // 长按阈值（毫秒）
const MOVE_THRESHOLD = 5; // 滑动阈值（像素）
let iconWidths = []; // 缓存每个图标的原始宽度
let iconRelativeLefts = []; // 缓存每个图标相对于taskbar-inner的left值

// 获取 target_show 的实际宽度（处理百分比）
function getTargetShowWidth() {
    return targetShow.offsetWidth;
}

// 获取图标相对于 taskbar-inner 的中心位置
function getIconRelativeCenter(icon) {
    const iconIndex = Array.from(svgs).indexOf(icon);
    if (iconIndex >= 0 && iconWidths[iconIndex]) {
        // 使用缓存的相对位置和宽度
        const relativeLeft = iconRelativeLefts[iconIndex];
        const centerX = relativeLeft + iconWidths[iconIndex] / 2;
        return centerX;
    }
    // 降级处理
    const iconRect = icon.getBoundingClientRect();
    const innerRect = taskbarInner.getBoundingClientRect();
    return iconRect.left - innerRect.left + iconRect.width / 2;
}

// 初始化：将 target_show 定位到第一个图标上方
function initTargetShow() {
    const innerRect = taskbarInner.getBoundingClientRect();
    // 缓存所有图标的原始宽度和相对位置
    iconWidths = [];
    iconRelativeLefts = [];
    svgs.forEach(svg => {
        const rect = svg.getBoundingClientRect();
        iconWidths.push(rect.width);
        iconRelativeLefts.push(rect.left - innerRect.left);
    });

    const firstIcon = svgs[0];
    const iconRect = firstIcon.getBoundingClientRect();

    // 计算第一个图标的中心位置相对于 taskbar-inner
    const iconCenterX = getIconRelativeCenter(firstIcon);

    // 小粉色条宽度与图标一样长
    const targetShowWidth = iconWidths[0];

    // 设置样式
    targetShow.style.width = `${targetShowWidth}px`;
    targetShow.style.height = '5px';
    targetShow.style.borderRadius = '5px';
    targetShow.style.backgroundColor = 'rgb(244, 198, 206)';
    targetShow.style.backgroundImage = 'none';
    targetShow.style.backdropFilter = 'none';
    targetShow.style.webkitBoxReflect = 'none';
    targetShow.style.boxShadow = 'none';

    // 初始位置：小粉色条，在第一个图标正上方
    targetShow.style.left = `${iconCenterX - targetShowWidth / 2}px`;
    targetShow.style.top = '0px';
    targetShow.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
}

// 展开 target_show 为大胶囊
function expandTargetShow(x) {
    // 计算当前的center位置
    const currentLeft = targetShow.offsetLeft;
    const currentWidth = targetShow.offsetWidth;
    const currentCenter = currentLeft + currentWidth / 2;
    
    // 计算胶囊的目标left位置（保持中心位置）
    const capsuleWidth = 80;
    const targetLeft = currentCenter - capsuleWidth / 2;
    
    // 设置过渡效果
    targetShow.style.transition = 'all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)';
    
    // 改变尺寸和位置（保持中心不变）
    targetShow.style.left = `${targetLeft}px`;
    targetShow.style.width = '80px';
    targetShow.style.height = '50px'; // 与 taskbar 高度一致
    targetShow.style.borderRadius = '25px';
    targetShow.style.top = '0px';

    // taskbar恢复正常大小
    taskbar.classList.remove('shrunk', 'pressed');
    taskbar.classList.add('expanded');

    // 强液态玻璃效果 - 放大和折射
    targetShow.style.backdropFilter = 'blur(30px) brightness(1.2) saturate(180%)'; // 更强的模糊和饱和度
    targetShow.style.border = 'none';

    // 多层边框模拟折射
    targetShow.style.boxShadow = `
        inset 0 2px 4px rgba(255, 255, 255, 0.8),
        inset 0 -2px 4px rgba(0, 0, 0, 0.15),
        inset 0 4px 8px rgba(255, 255, 255, 0.5),
        inset 0 -4px 8px rgba(0, 0, 0, 0.1),
        0 4px 16px rgba(0, 0, 0, 0.2),
        0 8px 32px rgba(0, 0, 0, 0.15),
        0 0 0 1px rgba(255, 255, 255, 0.1),
        0 0 0 2px rgba(255, 255, 255, 0.05)
    `;

    // 中心放大效果 - 径向渐变
    targetShow.style.background = `
        linear-gradient(145deg, rgba(255,255,255,0.15) 0%, rgba(255,255,255,0.08) 40%, rgba(255,255,255,0.03) 100%),
        radial-gradient(ellipse at 50% 30%, rgba(255,255,255,0.4) 0%, rgba(255,255,255,0.15) 30%, rgba(255,255,255,0.05) 60%, rgba(255,255,255,0) 70%),
        radial-gradient(ellipse at 50% 70%, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.05) 50%, rgba(255,255,255,0) 80%)
    `;

    // 添加内部反射效果
    targetShow.style.webkitBoxReflect = 'below 0px linear-gradient(transparent 0%, rgba(0, 0, 0, 0.1) 100%)';

    isExpanded = true;
}

// 收缩 target_show 为小粉色条
function shrinkTargetShow(targetIconIndex) {
    // 先重置状态
    isExpanded = false;

    // 定位到目标图标上方
    if (targetIconIndex >= 0 && targetIconIndex < svgs.length) {
        // 使用缓存的相对位置和宽度
        const iconWidth = iconWidths[targetIconIndex];
        const iconRelativeLeft = iconRelativeLefts[targetIconIndex];
        const targetShowWidth = iconWidth;

        // 计算目标图标的中心位置相对于 taskbar-inner
        const iconCenterX = iconRelativeLeft + iconWidth / 2;
        const targetLeft = iconCenterX - targetShowWidth / 2;

        // 计算当前胶囊的中心位置
        const currentLeft = targetShow.offsetLeft;
        const currentWidth = targetShow.offsetWidth;
        const currentCenter = currentLeft + currentWidth / 2;

        // 计算小粉色条的left位置（保持当前中心不变）
        const startLeft = currentCenter - targetShowWidth / 2;

        // 设置过渡效果 - 胶囊收缩为小粉条
        targetShow.style.transition = 'all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)';

        // 先改变尺寸和位置（保持中心不变）
        targetShow.style.left = `${startLeft}px`;
        targetShow.style.width = `${targetShowWidth}px`;
        targetShow.style.height = '5px';
        targetShow.style.borderRadius = '5px';
        targetShow.style.top = '0px';

        // 移除液态玻璃效果
        targetShow.style.backdropFilter = 'none';
        targetShow.style.webkitBoxReflect = 'none';
        targetShow.style.boxShadow = 'none';

        // 设置背景色
        targetShow.style.backgroundColor = 'rgb(244, 198, 206)';
        targetShow.style.backgroundImage = 'none';

        // 动画完成后再移动到目标位置
        setTimeout(() => {
            targetShow.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
            targetShow.style.left = `${targetLeft}px`;
        }, 400);
    }
}

// 获取最近的图标索引（使用相对坐标，与shrinkTargetShow一致）
function getClosestIconIndex(screenX) {
    let minDistance = Infinity;
    let closestIndex = 0;

    const innerRect = taskbarInner.getBoundingClientRect();
    const relativeX = screenX - innerRect.left;

    svgs.forEach((svg, index) => {
        const iconCenterX = getIconRelativeCenter(svg);
        const distance = Math.abs(relativeX - iconCenterX);

        if (distance < minDistance) {
            minDistance = distance;
            closestIndex = index;
        }
    });

    return closestIndex;
}

// 触摸开始
function handleTouchStart(e) {
    e.preventDefault();
    const touch = e.touches[0];
    isDragging = true;
    hasMoved = false;

    const innerRect = taskbarInner.getBoundingClientRect();
    startX = touch.clientX - innerRect.left;
    currentX = startX;

    const targetShowRect = targetShow.getBoundingClientRect();
    originalLeft = targetShow.offsetLeft;

    // 清除之前的定时器，防止竞态条件   
    if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
    }

    // 添加 taskbar 按压效果（按下就有）
    taskbar.classList.add('pressed');

    // 启动长按定时器
    pressTimer = setTimeout(() => {
        // 长按：taskbar缩小
        taskbar.classList.remove('pressed');
        taskbar.classList.add('shrunk');

        // 延迟展开为胶囊
        pressTimer = setTimeout(() => {
            // 展开为胶囊，taskbar恢复正常大小
            expandTargetShow(startX);
            pressTimer = null;
        }, 150);
    }, LONG_PRESS_THRESHOLD);
}

// 触摸移动
function handleTouchMove(e) {
    if (!isDragging) return;
    e.preventDefault();

    const touch = e.touches[0];
    const innerRect = taskbarInner.getBoundingClientRect();

    // 计算新的位置
    currentX = touch.clientX - innerRect.left;
    const deltaX = Math.abs(currentX - startX);

    // 检测是否发生了移动
    if (deltaX > MOVE_THRESHOLD) {
        hasMoved = true;

        // 如果还在长按定时器中，取消长按（滑动不触发长按）
        if (pressTimer) {
            clearTimeout(pressTimer);
            pressTimer = null;
        }
    }

    // 如果已展开为胶囊（长按成功），跟随手指移动
    if (isExpanded) {
        // 限制在 taskbar-inner 范围内
        const maxX = innerRect.width - targetShow.offsetWidth;
        let newX = currentX - targetShow.offsetWidth / 2;
        newX = Math.max(0, Math.min(maxX, newX));
        targetShow.style.left = `${newX}px`;
    }
}

// 触摸结束
function handleTouchEnd(e) {
    if (!isDragging) return;
    isDragging = false;

    // 清除所有定时器
    if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
    }

    // 获取屏幕坐标用于计算最近图标
    const touch = e.changedTouches[0];
    const closestIndex = getClosestIconIndex(touch.clientX);

    // 判断是轻点击（包括滑动）还是长按
    if (!hasMoved) {
        // 没有移动：可能是轻点击或长按
        // 如果展开了胶囊（长按成功），收缩回小粉条
        if (isExpanded) {
            taskbar.classList.remove('shrunk', 'expanded');
            shrinkTargetShow(closestIndex);
        } else {
            // 轻点击：直接添加回弹效果，移动小粉条
            taskbar.classList.remove('pressed');
            void taskbar.offsetWidth;
            taskbar.classList.add('click-bounce');
            setTimeout(() => {
                taskbar.classList.remove('click-bounce');
            }, 300);
            moveTargetShowToIcon(closestIndex);
        }
    } else {
        // 有移动：按轻点击处理，移动小粉条
        taskbar.classList.remove('pressed');
        moveTargetShowToIcon(closestIndex);
    }
}

// 直接移动小粉条到图标上方（不改变尺寸）
function moveTargetShowToIcon(iconIndex) {
    if (iconIndex >= 0 && iconIndex < svgs.length) {
        const targetIcon = svgs[iconIndex];
        const iconRect = targetIcon.getBoundingClientRect();

        // 使用getIconRelativeCenter获取中心位置（与initTargetShow一致）
        const iconCenterX = getIconRelativeCenter(targetIcon);

        // 使用缓存的宽度
        const targetShowWidth = iconWidths[iconIndex];
        const targetLeft = iconCenterX - targetShowWidth / 2;

        // 添加平滑过渡
        targetShow.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)';

        // 确保使用粉色条样式
        targetShow.style.width = `${targetShowWidth}px`;
        targetShow.style.height = '5px';
        targetShow.style.borderRadius = '5px';
        targetShow.style.backgroundColor = 'rgb(244, 198, 206)';
        targetShow.style.backgroundImage = 'none';
        targetShow.style.backdropFilter = 'none';
        targetShow.style.webkitBoxReflect = 'none';
        targetShow.style.boxShadow = 'none';

        targetShow.style.left = `${targetLeft}px`;
        targetShow.style.top = '0px';
    }
}

// 鼠标事件（支持桌面调试）
function handleMouseDown(e) {
    e.preventDefault();
    isDragging = true;
    hasMoved = false;

    const innerRect = taskbarInner.getBoundingClientRect();
    startX = e.clientX - innerRect.left;
    currentX = startX;

    const targetShowRect = targetShow.getBoundingClientRect();
    originalLeft = targetShow.offsetLeft;

    // 添加 taskbar 按压效果（按下就有）
    taskbar.classList.add('pressed');

    // 启动长按定时器
    pressTimer = setTimeout(() => {
        // 长按：taskbar缩小
        taskbar.classList.remove('pressed');
        taskbar.classList.add('shrunk');

        // 延迟展开为胶囊
        setTimeout(() => {
            expandTargetShow(startX);
        }, 150);
    }, LONG_PRESS_THRESHOLD);
}

function handleMouseMove(e) {
    if (!isDragging) return;
    e.preventDefault();

    const innerRect = taskbarInner.getBoundingClientRect();

    // 计算新的位置
    currentX = e.clientX - innerRect.left;
    const deltaX = Math.abs(currentX - startX);

    // 检测是否发生了移动
    if (deltaX > MOVE_THRESHOLD) {
        hasMoved = true;

        // 如果还在长按定时器中，取消长按（滑动不触发长按）
        if (pressTimer) {
            clearTimeout(pressTimer);
            pressTimer = null;
        }
    }

    // 如果已展开为胶囊（长按成功），跟随手指移动
    if (isExpanded) {
        // 限制在 taskbar-inner 范围内
        const maxX = innerRect.width - targetShow.offsetWidth;
        let newX = currentX - targetShow.offsetWidth / 2;
        newX = Math.max(0, Math.min(maxX, newX));
        targetShow.style.left = `${newX}px`;
    }
}

function handleMouseUp(e) {
    if (!isDragging) return;
    isDragging = false;

    // 清除所有定时器
    if (pressTimer) {
        clearTimeout(pressTimer);
        pressTimer = null;
    }

    // 获取屏幕坐标用于计算最近图标
    const closestIndex = getClosestIconIndex(e.clientX);

    // 判断是轻点击（包括滑动）还是长按
    if (!hasMoved) {
        // 没有移动：可能是轻点击或长按
        // 如果展开了胶囊（长按成功），收缩回小粉条
        if (isExpanded) {
            taskbar.classList.remove('shrunk', 'expanded');
            shrinkTargetShow(closestIndex);
        } else {
            // 轻点击：直接添加回弹效果，移动小粉条
            taskbar.classList.remove('pressed');
            void taskbar.offsetWidth;
            taskbar.classList.add('click-bounce');
            setTimeout(() => {
                taskbar.classList.remove('click-bounce');
            }, 300);
            moveTargetShowToIcon(closestIndex);
        }
    } else {
        // 有移动：按轻点击处理，移动小粉条
        taskbar.classList.remove('pressed');
        moveTargetShowToIcon(closestIndex);
    }
}

// 添加事件监听器
taskbar.addEventListener('touchstart', handleTouchStart, { passive: false });
taskbar.addEventListener('touchmove', handleTouchMove, { passive: false });
taskbar.addEventListener('touchend', handleTouchEnd, { passive: false });

// 鼠标事件（桌面支持）
taskbar.addEventListener('mousedown', handleMouseDown);
document.addEventListener('mousemove', handleMouseMove);
document.addEventListener('mouseup', handleMouseUp);

// 初始化
window.addEventListener('load', initTargetShow);
window.addEventListener('resize', () => {
    // 延迟执行，等待taskbar动画完成后再重新缓存
    setTimeout(initTargetShow, 400);
});
