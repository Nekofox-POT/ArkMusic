//
// 监听池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 触控件 //
///////////

////////////
// 变量池 //
///////////

//////////////
// 监听程序 //
/////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// slide滑动 //
//////////////

////////////
// 变量池 //
//////////

/////////////
// 监听程序 //
////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 拖拽排序事件监听 //
////////////////////

////////////
// 变量池 //
//////////

/////////////
// 监听程序 //
////////////

// 为slide容器添加事件委托
slide.addEventListener('touchstart', handleTouchStart, { passive: false })
slide.addEventListener('touchmove', handleTouchMove, { passive: false })
slide.addEventListener('touchend', handleTouchEnd, { passive: false })
slide.addEventListener('touchcancel', handleTouchCancel, { passive: false })

// 鼠标事件支持（用于桌面端调试）
slide.addEventListener('mousedown', handleMouseDown)
document.addEventListener('mousemove', handleMouseMove)
document.addEventListener('mouseup', handleMouseUp)

/**
 * 触摸开始事件处理
 * @param {TouchEvent} e - 触摸事件
 */
function handleTouchStart(e) {
    // 只处理单指触摸
    if (e.touches.length !== 1) return
    
    const touch = e.touches[0]
    const target = e.target.closest('.slide > div')
    
    // 确保点击的是滑块元素
    if (!target || target.classList.contains('drag-placeholder')) return
    
    // 开始长按检测
    startLongPressCheck(target, touch.clientX, touch.clientY)
}

/**
 * 触摸移动事件处理
 * @param {TouchEvent} e - 触摸事件
 */
function handleTouchMove(e) {
    // 如果有长按计时器在运行，检测是否移动超过阈值
    if (dragState.longPressTimer && !dragState.isDragging) {
        const touch = e.touches[0]
        if (isMovementOverThreshold(touch.clientX, touch.clientY)) {
            // 移动超过阈值，取消长按
            clearLongPressTimer()
            return
        }
    }
    
    // 正在拖拽中，更新位置
    if (dragState.isDragging) {
        e.preventDefault()
        const touch = e.touches[0]
        updateDragPosition(touch.clientX, touch.clientY)
    }
}

/**
 * 触摸结束事件处理
 * @param {TouchEvent} e - 触摸事件
 */
function handleTouchEnd(e) {
    // 清除长按计时器
    clearLongPressTimer()
    
    // 结束拖拽
    if (dragState.isDragging) {
        endDrag()
    }
}

/**
 * 触摸取消事件处理
 * @param {TouchEvent} e - 触摸事件
 */
function handleTouchCancel(e) {
    // 取消拖拽
    cancelDrag()
}

/**
 * 鼠标按下事件处理（桌面端支持）
 * @param {MouseEvent} e - 鼠标事件
 */
function handleMouseDown(e) {
    const target = e.target.closest('.slide > div')
    
    if (!target || target.classList.contains('drag-placeholder')) return
    
    e.preventDefault()
    startLongPressCheck(target, e.clientX, e.clientY)
}

/**
 * 鼠标移动事件处理（桌面端支持）
 * @param {MouseEvent} e - 鼠标事件
 */
function handleMouseMove(e) {
    // 检测移动阈值
    if (dragState.longPressTimer && !dragState.isDragging) {
        if (isMovementOverThreshold(e.clientX, e.clientY)) {
            clearLongPressTimer()
            return
        }
    }
    
    // 更新拖拽位置
    if (dragState.isDragging) {
        e.preventDefault()
        updateDragPosition(e.clientX, e.clientY)
    }
}

/**
 * 鼠标释放事件处理（桌面端支持）
 * @param {MouseEvent} e - 鼠标事件
 */
function handleMouseUp(e) {
    clearLongPressTimer()
    
    if (dragState.isDragging) {
        endDrag()
    }
}
