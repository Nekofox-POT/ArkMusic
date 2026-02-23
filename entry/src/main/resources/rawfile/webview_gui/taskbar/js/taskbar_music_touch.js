// 长按定时器
let longPressTimer;
// 触摸起始位置
let touchStartX = 0;
let touchStartY = 0;
// 是否发生滑动
let isMoved = false;
// 当前显示的歌曲名索引
let currentSongIndex = 0;
// 用于记录blur模式下的滑动起点和初始range值
let blurTouchStartX = 0;
let blurRangeStartValue = 0;

let isAnimating = false;

// 动态获取歌曲名容器中的所有p标签
function getSongNameElements() {
    return taskbar_music_song_name.querySelectorAll('p');
}

// 动态获取歌曲总数
function getTotalSongs() {
    return getSongNameElements().length;
}

// 重置位移和索引（当p标签更新后调用）
function resetSongDisplay() {
    currentSongIndex = 0;
    taskbar_music_song_name.style.transition = 'none';
    taskbar_music_song_name.style.transform = 'translateX(0)';
}

// 更新显示歌曲名（带动画）
function updateSongDisplay(targetIndex) {
    if (isAnimating || targetIndex === currentSongIndex) return;
    
    isAnimating = true;
    const offset = -targetIndex * 150;
    taskbar_music_song_name.style.transition = 'transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)';
    taskbar_music_song_name.style.transform = `translateX(${offset}%)`;
    
    setTimeout(() => {
        currentSongIndex = targetIndex;
        isAnimating = false;
    }, 300);
}

// 回弹动画
function revertAnimation() {
    isAnimating = true;
    const offset = -currentSongIndex * 150;
    taskbar_music_song_name.style.transition = 'transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)';
    taskbar_music_song_name.style.transform = `translateX(${offset}%)`;
    
    setTimeout(() => {
        isAnimating = false;
    }, 300);
}

taskbar_music_touch.addEventListener('touchstart', function(e) {
    const touch = e.touches[0];
    touchStartX = touch.clientX;
    touchStartY = touch.clientY;
    isMoved = false;

    taskbar.classList.add('active');

    // 清除过渡动画，使滑动流畅
    taskbar_music_song_name.style.transition = 'none';

    // 启动长按定时器（500ms）
    longPressTimer = setTimeout(() => {
        taskbar.classList.remove('active');
        bg_blur.classList.add('blur');
        isMoved = true; // 标记为已进入blur状态，禁用后续滑动事件
        // 只在进入blur时记录基准
        blurTouchStartX = touch.clientX;
        blurRangeStartValue = Number(music_range.value);
        // 新增：blur判定生效后，给range_bar_two添加active
        const processBarTwo = document.getElementById('range_bar_two');
        if (processBarTwo) {
            processBarTwo.classList.add('active');
        }
    }, 500);
});

taskbar_music_touch.addEventListener('touchmove', function(e) {
    const touch = e.touches[0];
    // 如果已进入blur状态，滑动调节music_range
    if (bg_blur.classList.contains('blur')) {
        // 只处理左右滑动
        const deltaX = touch.clientX - blurTouchStartX;
        // 进度条调节灵敏度（像素->值的映射）
        const sensitivity = 2; // 每2px变化1单位，可根据实际体验调整
        // 获取最新min/max
        const min = Number(music_range.min);
        const max = Number(music_range.max);
        let newValue = blurRangeStartValue + deltaX * ((max - min) / (200 * sensitivity));
        // 限制范围
        newValue = Math.max(min, Math.min(max, Math.round(newValue)));
        music_range.value = newValue;
        // 触发input事件（如有监听）
        music_range.dispatchEvent(new Event('input', { bubbles: true }));
        return;
    }

    // 非blur状态下，原有滑动切歌逻辑
    const deltaX = touch.clientX - touchStartX;
    const deltaY = Math.abs(touch.clientY - touchStartY);

    // 如果垂直移动距离较大，认为不是左右滑动
    if (deltaY > 10 && Math.abs(deltaX) < 10) {
        return;
    }

    // 如果水平移动距离超过10像素，判定为滑动
    if (Math.abs(deltaX) > 10) {
        isMoved = true;
        // 清除长按定时器
        clearTimeout(longPressTimer);
        // 移除active
        taskbar.classList.remove('active');

        // 实时更新歌曲名容器的位置
        // 计算滑动的偏移量（百分比）
        const containerWidth = taskbar_music_song_name.parentElement.offsetWidth;
        const slidePercent = (deltaX / containerWidth) * 100;
        const currentOffset = -currentSongIndex * 150;
        
        taskbar_music_song_name.style.transform = `translateX(${currentOffset + slidePercent}%)`;
    }
});

taskbar_music_touch.addEventListener('touchend', function(e) {

    // 清除定时器
    clearTimeout(longPressTimer);

    // 如果bg_blur有blur类，移除它（无论是否滑动）
    if (bg_blur.classList.contains('blur')) {
        bg_blur.classList.remove('blur');
        isMoved = false; // 重置isMoved标志
        // 新增：松手后移除range_bar_two的active
        const processBarTwo = document.getElementById('range_bar_two');
        if (processBarTwo) {
            processBarTwo.classList.remove('active');
        }
    } else {
        // 如果发生了滑动
        if (isMoved) {
            const touch = e.changedTouches[0];
            const deltaX = touch.clientX - touchStartX;
            const containerWidth = taskbar_music_song_name.parentElement.offsetWidth;
            // 滑动距离阈值（容器宽度的20%）
            const threshold = containerWidth * 0.2;

            let targetIndex = currentSongIndex;
            let shouldUpdate = false;

            // 向右滑动（显示前一首）
            if (deltaX > threshold && currentSongIndex > 0) {
                targetIndex = currentSongIndex - 1;
                shouldUpdate = true;
            }
            // 向左滑动（显示后一首）
            else if (deltaX < -threshold && currentSongIndex < getTotalSongs() - 1) {
                targetIndex = currentSongIndex + 1;
                shouldUpdate = true;
            }

            // 如果要更新索引，执行更新；否则回弹
            if (shouldUpdate) {
                updateSongDisplay(targetIndex);
            } else {
                // 滑动距离不足或在边界，回弹到原位
                revertAnimation();
            }
            return;
        }
        // 如果没有长按，正常移除active
        taskbar.classList.remove('active');
    }

});