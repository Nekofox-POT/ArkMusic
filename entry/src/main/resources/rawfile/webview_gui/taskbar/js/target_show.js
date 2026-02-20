
// 放大定时器
let scaleTimeout = null;
//页面计数器(防重复)
index_backup = 0;

// target_show跟随函数
function target_show_follow(x) {
    // 获取 taskbar 的边界
    const taskbarRect = taskbar.getBoundingClientRect();

    // 计算触摸点相对于 taskbar 的位置
    const relativeX = x - taskbarRect.left;

    // 获取所有 SVG 图标元素
    const icons = taskbar_page_icon.querySelectorAll('svg');

    // 计算每个图标的中心位置
    const iconPositions = [];
    icons.forEach((icon, index) => {
        const iconRect = icon.getBoundingClientRect();
        const iconCenter = iconRect.left + iconRect.width / 2 - taskbarRect.left;
        iconPositions.push(iconCenter);
    });

    // 找出距离触摸点最近的图标索引
    let closestIndex = 0;
    let minDistance = Math.abs(relativeX - iconPositions[0]);

    for (let i = 1; i < iconPositions.length; i++) {
        const distance = Math.abs(relativeX - iconPositions[i]);
        if (distance < minDistance) {
            minDistance = distance;
            closestIndex = i;
        }
    }

    // arkts接口
    if (index_backup != closestIndex) {
        // 恢复上一个图标的颜色为默认
        const targetbgColor = get_bgcolor();
        const prevIconPaths = icons[index_backup].querySelectorAll('.svg_color');
        prevIconPaths.forEach(path => {
            path.style.fill = targetbgColor;
            path.style.transition = 'fill 0.3s ease';
            setTimeout(() => {
                path.style.transition = 'fill 1s ease';
            }, 300);
        });

        index_backup = closestIndex;
        console.log(closestIndex)

        // 获取目标颜色并设置给当前锁定图标
        const targetColor = get_color();
        const currentIconPaths = icons[closestIndex].querySelectorAll('.svg_color');
        currentIconPaths.forEach(path => {
            path.style.fill = targetColor;
            path.style.transition = 'fill 0.3s ease';
            setTimeout(() => {
                path.style.transition = 'fill 1s ease';
            }, 300);
        });
    }

    // 计算 target_show 应该移动到的位置（目标图标的位置 - target_show 半径）
    const targetShowWidth = target_show.offsetWidth;
    const targetShowRadius = targetShowWidth / 2;
    const targetPosition = iconPositions[closestIndex] - targetShowRadius;

    // 应用变换
    target_show.style.transform = `translateX(${targetPosition}px) scale(1.25)`;

}

// 初始化位置(移动到第二个图标)
function initializePosition() {
    // 获取所有 SVG 图标元素
    const icons = taskbar_page_icon.querySelectorAll('svg');

    // 获取第二个图标（索引为1）
    if (icons.length > 1) {
        const secondIcon = icons[1];
        const iconRect = secondIcon.getBoundingClientRect();
        const iconCenterX = iconRect.left + iconRect.width / 2;

        // 调用 target_show_follow，传入第二个图标的中心 X 坐标
        target_show_follow(iconCenterX);

        // 初始化后立即设置为 scale(1)
        target_show.style.transform = target_show.style.transform.replace('scale(1.25)', 'scale(1)');
    }
}

// 页面加载完成后初始化位置
window.addEventListener('load', initializePosition);

// 触摸事件
taskbar_target.addEventListener('touchstart', function (e) {

    taskbar.classList.add('active');
    setTimeout(() => {
        taskbar.classList.remove('active');
    }, 100);
    const touchX = e.touches[0].clientX;

    // 清除之前的放大定时器
    if (scaleTimeout) {
        clearTimeout(scaleTimeout);
        scaleTimeout = null;
    }

    // 移动到触摸位置，但不放大
    target_show_follow(touchX);
    target_show.style.transform = target_show.style.transform.replace('scale(1.25)', 'scale(1)');

    // 100ms 后再放大，保存定时器 ID
    scaleTimeout = setTimeout(() => {
        target_show.style.transform = target_show.style.transform.replace('scale(1)', 'scale(1.25)');
        scaleTimeout = null;
    }, 100);
})
taskbar_target.addEventListener('touchmove', function (e) {
    const touchX = e.touches[0].clientX;
    target_show_follow(touchX);
})
taskbar_target.addEventListener('touchend', function (e) {

    taskbar.classList.add('active');

    // 清除放大定时器，如果在100ms内松手则不会放大
    if (scaleTimeout) {
        clearTimeout(scaleTimeout);
        scaleTimeout = null;
    }

    // 使用更强的回弹效果，更快响应
    target_show.style.transition = 'transform 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)';
    target_show.style.transform = target_show.style.transform.replace('scale(1.25)', 'scale(1)');

    setTimeout(() => {
        taskbar.classList.remove('active');

        // 动画完成后恢复原来的过渡设置
        setTimeout(() => {
            target_show.style.transition = 'transform 0.35s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
        }, 500);
    }, 100);

})