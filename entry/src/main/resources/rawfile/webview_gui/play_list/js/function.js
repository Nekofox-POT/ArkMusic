//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更新元素 //
////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 拖拽排序功能 //
///////////////

/**
 * 开始长按检测
 * @param {HTMLElement} element - 被触摸的元素
 * @param {number} x - 触摸点X坐标
 * @param {number} y - 触摸点Y坐标
 */
function startLongPressCheck(element, x, y) {
    // 清除之前的计时器
    clearLongPressTimer()
    
    // 记录起始位置
    dragState.startX = x
    dragState.startY = y
    
    // 计算元素相对于触摸点的偏移
    const rect = element.getBoundingClientRect()
    dragState.offsetX = x - rect.left
    dragState.offsetY = y - rect.top
    
    // 设置长按计时器
    dragState.longPressTimer = setTimeout(() => {
        // 长按触发，开始拖拽
        startDrag(element, x, y)
    }, dragConfig.longPressDelay)
}

/**
 * 清除长按计时器
 */
function clearLongPressTimer() {
    if (dragState.longPressTimer) {
        clearTimeout(dragState.longPressTimer)
        dragState.longPressTimer = null
    }
}

/**
 * 开始拖拽
 * @param {HTMLElement} element - 要拖拽的元素
 * @param {number} x - 触摸点X坐标
 * @param {number} y - 触摸点Y坐标
 */
function startDrag(element, x, y) {
    if (dragState.isDragging) return
    
    dragState.isDragging = true
    dragState.dragElement = element
    
    // 获取元素在列表中的索引
    const children = Array.from(slide.children)
    dragState.startIndex = children.indexOf(element)
    dragState.currentIndex = dragState.startIndex
    
    // 创建跟随手指的克隆元素
    createDragClone(element, x, y)
    
    // 标记原元素为拖拽源（显示虚线框效果）
    createPlaceholder(element)
    
    // 震动反馈（如果支持且允许）
    try {
        if (navigator.vibrate) {
            navigator.vibrate(50)
        }
    } catch (e) {
        // 忽略跨域 iframe 中的震动 API 错误
    }
}

/**
 * 创建拖拽时的克隆元素
 * @param {HTMLElement} element - 原元素
 * @param {number} x - 触摸点X坐标
 * @param {number} y - 触摸点Y坐标
 */
function createDragClone(element, x, y) {
    // 克隆元素
    dragState.dragClone = element.cloneNode(true)
    dragState.dragClone.classList.add('dragging-active')
    
    // 获取原元素的计算样式
    const computedStyle = window.getComputedStyle(element)
    
    // 设置固定定位
    dragState.dragClone.style.position = 'fixed'
    dragState.dragClone.style.left = (x - dragState.offsetX) + 'px'
    dragState.dragClone.style.top = (y - dragState.offsetY) + 'px'
    dragState.dragClone.style.width = element.offsetWidth + 'px'
    dragState.dragClone.style.height = element.offsetHeight + 'px'
    dragState.dragClone.style.zIndex = '1000'
    dragState.dragClone.style.pointerEvents = 'none'
    
    // 复制关键样式（因为脱离了 .slide > div 选择器）
    dragState.dragClone.style.borderRadius = '12.5px'
    dragState.dragClone.style.overflow = 'hidden'
    dragState.dragClone.style.display = 'flex'
    dragState.dragClone.style.alignItems = 'center'
    dragState.dragClone.style.justifyContent = 'flex-start'
    
    // 复制 box_color 相关样式
    dragState.dragClone.style.backdropFilter = computedStyle.backdropFilter
    dragState.dragClone.style.webkitBackdropFilter = computedStyle.webkitBackdropFilter
    dragState.dragClone.style.border = computedStyle.border
    dragState.dragClone.style.boxShadow = computedStyle.boxShadow
    dragState.dragClone.style.backgroundColor = computedStyle.backgroundColor
    
    // 处理子元素样式（专辑封面和文字）
    const childDiv = dragState.dragClone.querySelector('div')
    if (childDiv) {
        const originalDiv = element.querySelector('div')
        const divStyle = originalDiv ? window.getComputedStyle(originalDiv) : null
        
        childDiv.style.height = '50%'
        childDiv.style.aspectRatio = '1/1'
        childDiv.style.marginLeft = '12.5px'
        childDiv.style.borderRadius = '25%'
        childDiv.style.boxShadow = '0 4px 8px rgba(71, 71, 71, 0.2)'
        // 使用计算后的背景图，避免相对路径问题
        if (divStyle && divStyle.backgroundImage && divStyle.backgroundImage !== 'none') {
            childDiv.style.backgroundImage = divStyle.backgroundImage
        } else {
            childDiv.style.backgroundImage = 'url(../files/CD.png)'
        }
        childDiv.style.backgroundSize = 'cover'
    }
    
    const childP = dragState.dragClone.querySelector('p')
    if (childP) {
        const originalP = element.querySelector('p')
        const pStyle = originalP ? window.getComputedStyle(originalP) : null
        
        childP.style.width = 'auto'
        childP.style.border = '0'
        childP.style.margin = '0'
        childP.style.marginLeft = '12.5px'
        childP.style.display = 'flex'
        childP.style.alignItems = 'center'
        childP.style.justifyContent = 'center'
        // 从 p 元素本身获取样式
        if (pStyle) {
            childP.style.fontSize = pStyle.fontSize
            childP.style.fontWeight = pStyle.fontWeight
            childP.style.color = pStyle.color
            childP.style.fontFamily = pStyle.fontFamily
        } else {
            childP.style.fontSize = '0.8rem'
            childP.style.fontWeight = '750'
            childP.style.color = computedStyle.color
        }
    }
    
    // 添加拎出动画 - 初始状态
    dragState.dragClone.style.transform = 'scale(1)'
    dragState.dragClone.style.opacity = '1'
    
    // 添加到body
    document.body.appendChild(dragState.dragClone)
    
    // 强制重绘后触发拎出动画
    requestAnimationFrame(() => {
        if (dragState.dragClone) {
            dragState.dragClone.style.transition = 'transform 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
            dragState.dragClone.style.transform = 'scale(1.05) translateY(-5px)'
        }
    })
}

/**
 * 创建占位符元素
 * @param {HTMLElement} element - 原元素
 */
function createPlaceholder(element) {
    // 直接在原元素上添加 drag-source 类，不创建占位符
    // 这样原元素保留空间，但显示为虚线框效果
    element.classList.add('drag-source')
}

/**
 * 更新拖拽位置
 * @param {number} x - 触摸点X坐标
 * @param {number} y - 触摸点Y坐标
 */
function updateDragPosition(x, y) {
    if (!dragState.isDragging || !dragState.dragClone) return
    
    // 更新克隆元素位置
    dragState.dragClone.style.left = (x - dragState.offsetX) + 'px'
    dragState.dragClone.style.top = (y - dragState.offsetY) + 'px'
    
    // 检测碰撞并交换位置
    checkCollisionAndSwap(x, y)
    
    // 处理边界滚动
    handleEdgeScroll(y)
}

/**
 * 检测碰撞并交换位置
 * @param {number} x - 触摸点X坐标
 * @param {number} y - 触摸点Y坐标
 */
function checkCollisionAndSwap(x, y) {
    const children = Array.from(slide.children)
    
    for (let i = 0; i < children.length; i++) {
        const child = children[i]
        
        // 跳过拖拽元素本身
        if (child === dragState.dragElement) continue
        
        const rect = child.getBoundingClientRect()
        
        // 检测触摸点是否在当前元素范围内
        if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) {
            const targetIndex = children.indexOf(child)
            
            if (targetIndex !== dragState.currentIndex) {
                // 直接交换DOM位置
                if (targetIndex < dragState.currentIndex) {
                    // 向上移动：将拖拽元素插入到目标元素前面
                    slide.insertBefore(dragState.dragElement, child)
                } else {
                    // 向下移动：将拖拽元素插入到目标元素后面
                    slide.insertBefore(dragState.dragElement, child.nextSibling)
                }
                
                dragState.currentIndex = targetIndex
            }
            break
        }
    }
}

/**
 * 处理边界自动滚动
 * @param {number} y - 触摸点Y坐标
 */
function handleEdgeScroll(y) {
    const slideFrame = document.querySelector('.slide_frame')
    if (!slideFrame) return
    
    const rect = slideFrame.getBoundingClientRect()
    const scrollTop = slideFrame.scrollTop
    
    // 上边界滚动
    if (y < rect.top + dragConfig.scrollThreshold) {
        slideFrame.scrollTop = scrollTop - dragConfig.scrollSpeed
    }
    // 下边界滚动
    else if (y > rect.bottom - dragConfig.scrollThreshold) {
        slideFrame.scrollTop = scrollTop + dragConfig.scrollSpeed
    }
}

/**
 * 结束拖拽
 */
function endDrag() {
    if (!dragState.isDragging) return
    
    const dragElement = dragState.dragElement
    const dragClone = dragState.dragClone
    
    // 获取目标位置
    const targetRect = dragElement ? dragElement.getBoundingClientRect() : null
    
    // 放回动画 - 克隆元素移动到目标位置并淡出
    if (dragClone && targetRect) {
        dragClone.style.transition = 'all 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        dragClone.style.left = targetRect.left + 'px'
        dragClone.style.top = targetRect.top + 'px'
        dragClone.style.transform = 'scale(1)'
        dragClone.style.opacity = '0'
    }
    
    // 延迟移除克隆元素并恢复原元素
    setTimeout(() => {
        // 移除克隆元素
        if (dragClone && dragClone.parentNode) {
            dragClone.parentNode.removeChild(dragClone)
        }
        
        // 恢复原元素样式
        if (dragElement) {
            dragElement.classList.remove('drag-source')
            // 强制重绘以确保样式生效
            void dragElement.offsetWidth
        }
        
        // 重置状态
        dragState.isDragging = false
        dragState.dragElement = null
        dragState.dragClone = null
        dragState.placeholder = null
        dragState.startIndex = -1
        dragState.currentIndex = -1
    }, 250)
    
    // 触发排序完成回调
    if (dragState.startIndex !== dragState.currentIndex) {
        onDragSortComplete(dragState.startIndex, dragState.currentIndex)
    }
}

/**
 * 取消拖拽
 */
function cancelDrag() {
    clearLongPressTimer()
    
    if (!dragState.isDragging) return
    
    const dragElement = dragState.dragElement
    const dragClone = dragState.dragClone
    
    // 如果有克隆元素，执行放回动画
    if (dragClone && dragElement) {
        const originalRect = dragElement.getBoundingClientRect()
        dragClone.style.transition = 'all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        dragClone.style.left = originalRect.left + 'px'
        dragClone.style.top = originalRect.top + 'px'
        dragClone.style.transform = 'scale(1)'
        dragClone.style.opacity = '0'
    }
    
    // 延迟移除
    setTimeout(() => {
        // 移除克隆元素
        if (dragClone && dragClone.parentNode) {
            dragClone.parentNode.removeChild(dragClone)
        }
        
        // 恢复原元素样式
        if (dragElement) {
            dragElement.classList.remove('drag-source')
        }
        
        // 重置状态
        dragState.isDragging = false
        dragState.dragElement = null
        dragState.dragClone = null
        dragState.placeholder = null
        dragState.startIndex = -1
        dragState.currentIndex = -1
    }, 300)
}

/**
 * 拖拽排序完成回调
 * @param {number} fromIndex - 起始索引
 * @param {number} toIndex - 目标索引
 */
function onDragSortComplete(fromIndex, toIndex) {
    console.log(`排序完成: 从 ${fromIndex} 移动到 ${toIndex}`)
    // 可以在这里调用原生接口通知排序变化
    // 例如: window.arkMusic?.onPlayListReorder(fromIndex, toIndex)
}

/**
 * 检测移动是否超过阈值
 * @param {number} x - 当前X坐标
 * @param {number} y - 当前Y坐标
 * @returns {boolean} 是否超过阈值
 */
function isMovementOverThreshold(x, y) {
    const dx = Math.abs(x - dragState.startX)
    const dy = Math.abs(y - dragState.startY)
    return dx > 10 || dy > 10
}