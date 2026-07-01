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
// 滑动操作 //
////////////

function startSwipe(element, x, y) {
    const children = Array.from(slide.children)
    const index = children.indexOf(element)

    swipeState.isActive = true
    swipeState.element = element
    swipeState.startX = x
    swipeState.startY = y
    swipeState.mode = null
    swipeState.hasPassedDeleteThreshold = false
    swipeState.originalIndex = index
    swipeState.currentSwapIndex = index
    swipeState.preventClick = false
    swipeState.swapCooldown = false

    element.style.transition = 'none'
    element.style.transform = 'translateX(0px)'
    element.style.zIndex = '10'
}

function createDeleteIndicator(element) {
    const indicator = document.createElement('div')
    indicator.className = 'box_color swipe-delete-indicator'
    indicator.style.cssText = `position:absolute;top:${element.offsetTop + 25}px;right:-70px;width:50px;height:50px;border-radius:50%;overflow:visible;margin-bottom:0;display:flex;align-items:center;justify-content:center;pointer-events:none;z-index:5;opacity:0;transform:translateY(-50%) translateX(0px);transition:opacity 0.15s ease;`

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.setAttribute('width', '22')
    svg.setAttribute('height', '22')
    svg.setAttribute('viewBox', '0 0 24 24')

    const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
    rect.setAttribute('width', '24')
    rect.setAttribute('height', '24')
    rect.setAttribute('opacity', '0')

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('class', 'svg_color')
    path.style.fill = background_color
    path.style.transition = 'fill 0.3s ease'
    path.setAttribute('d', 'M16.54 23.21Q17.11 23.21 17.77 22.84Q18.43 22.46 18.89 21.91Q19.34 21.36 19.39 20.83L20.52 9.1Q20.57 8.59 20.18 8.24Q19.8 7.9 19.27 7.9L4.73 7.9Q4.2 7.9 3.82 8.24Q3.43 8.59 3.48 9.1L4.61 20.83Q4.66 21.41 5.11 21.96Q5.57 22.51 6.2 22.86Q6.84 23.21 7.46 23.21L16.54 23.21ZM14.33 19.51Q13.8 19.51 13.44 19.15Q13.08 18.79 13.1 18.34L13.37 11.78Q13.37 11.3 13.73 10.99Q14.09 10.68 14.62 10.68Q15.14 10.7 15.49 11.05Q15.84 11.4 15.82 11.88L15.58 18.41Q15.55 18.89 15.2 19.2Q14.86 19.51 14.33 19.51ZM9.7 19.51Q9.17 19.51 8.82 19.2Q8.47 18.89 8.45 18.41L8.18 11.88Q8.16 11.4 8.48 11.05Q8.81 10.7 9.34 10.68Q9.89 10.66 10.26 10.98Q10.63 11.3 10.63 11.78L10.92 18.34Q10.94 18.79 10.58 19.15Q10.22 19.51 9.7 19.51ZM16.32 3.58Q15.86 2.23 14.7 1.4Q13.54 0.58 12.1 0.58Q10.66 0.58 9.49 1.4Q8.33 2.23 7.87 3.58L3.43 3.58Q2.83 3.58 2.39 4.02Q1.94 4.46 1.94 5.06Q1.94 5.69 2.39 6.13Q2.83 6.58 3.43 6.58L8.93 6.58L15.29 6.58L20.57 6.55Q21.17 6.55 21.61 6.12Q22.06 5.69 22.06 5.06Q22.06 4.46 21.61 4.02Q21.17 3.58 20.57 3.58L16.32 3.58Z')

    svg.appendChild(rect)
    svg.appendChild(path)
    indicator.appendChild(svg)
    slide.appendChild(indicator)

    return indicator
}

function updateSwipe(x, y) {
    if (!swipeState.isActive) return

    const dx = x - swipeState.startX
    const dy = y - swipeState.startY

    if (!swipeState.mode && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
        swipeState.mode = Math.abs(dx) > Math.abs(dy) ? 'delete' : 'reorder'
        swipeState.preventClick = true

        if (swipeState.mode === 'delete') {
            swipeState.deleteIndicator = createDeleteIndicator(swipeState.element)
        }
    }

    if (!swipeState.mode) return

    if (swipeState.mode === 'delete') {
        updateDeleteSwipe(x, y)
    } else if (swipeState.mode === 'reorder') {
        updateReorderSwipe(x, y)
    }
}

function updateDeleteSwipe(x, y) {
    const dx = x - swipeState.startX
    const translateX = Math.min(0, dx)

    swipeState.element.style.transform = `translateX(${translateX}px)`

    if (swipeState.deleteIndicator) {
        swipeState.deleteIndicator.style.opacity = '1'
        swipeState.deleteIndicator.style.transform = `translateY(-50%) translateX(${translateX}px)`

        const progress = Math.min(1, Math.abs(translateX) / swipeState.deleteThreshold)
        const path = swipeState.deleteIndicator.querySelector('path')
        const wasActive = swipeState.hasPassedDeleteThreshold
        const isActive = progress >= 1

        if (path) {
            if (isActive) {
                path.setAttribute('class', 'svg_active_color')
                path.style.fill = active_color
            } else {
                path.setAttribute('class', 'svg_color')
                path.style.fill = background_color
            }
        }

        if (isActive !== wasActive) {
            ark.vib()
        }
    }

    swipeState.hasPassedDeleteThreshold = Math.abs(translateX) >= swipeState.deleteThreshold
}

function updateReorderSwipe(x, y) {
    if (swipeState.swapCooldown) return

    const children = Array.from(slide.children)
    const el = swipeState.element

    for (let i = 0; i < children.length; i++) {
        const child = children[i]
        if (child === el) continue

        const rect = child.getBoundingClientRect()
        if (y > rect.top && y < rect.bottom && i !== swipeState.currentSwapIndex) {
            swapWithElement(el, child, i)
            break
        }
    }
}

function swapWithElement(el, target, targetIndex) {
    swipeState.swapCooldown = true

    const elRectBefore = el.getBoundingClientRect()
    const targetRectBefore = target.getBoundingClientRect()
    const fromIndex = swipeState.currentSwapIndex

    if (targetIndex < swipeState.currentSwapIndex) {
        slide.insertBefore(el, target)
    } else {
        slide.insertBefore(el, target.nextSibling)
    }

    const elRectAfter = el.getBoundingClientRect()
    const targetRectAfter = target.getBoundingClientRect()

    const elDeltaY = elRectBefore.top - elRectAfter.top
    const targetDeltaY = targetRectBefore.top - targetRectAfter.top

    if (Math.abs(elDeltaY) > 1 || Math.abs(targetDeltaY) > 1) {
        el.style.transition = 'none'
        target.style.transition = 'none'
        el.style.transform = `translateY(${elDeltaY}px)`
        target.style.transform = `translateY(${targetDeltaY}px)`

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                el.style.transition = 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                target.style.transition = 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                el.style.transform = ''
                target.style.transform = ''
            })
        })
    }

    swipeState.currentSwapIndex = targetIndex
    // 标记跳过后续 2 次刷新（list + index），避免交换动画被打断
    window._skip_next_render = 2
    // 如果正在播放的歌曲被移动，更新指针
    if (fromIndex === playing_index) {
        playing_index = targetIndex
    } else if (targetIndex === playing_index) {
        playing_index = fromIndex
    }
    // 更新头显
    play_index_screen.innerText = `${playing_index + 1} / ${all_songs}`
    ark.switch_songs(fromIndex, targetIndex)
    ark.vib()

    setTimeout(() => {
        swipeState.swapCooldown = false
    }, 150)
}

function removeDeleteIndicator() {
    const indicator = swipeState.deleteIndicator
    if (indicator && indicator.parentNode) {
        indicator.style.transition = 'transform 0.2s ease, opacity 0.2s ease'
        indicator.style.opacity = '0'
        const currentTx = swipeState.element ? swipeState.element.style.transform.match(/translateX\(([^)]+)\)/) : null
        const tx = currentTx ? currentTx[1] : '0px'
        indicator.style.transform = `translateY(-50%) translateX(${tx})`
        setTimeout(() => {
            if (indicator.parentNode) {
                indicator.parentNode.removeChild(indicator)
            }
        }, 220)
    }
    swipeState.deleteIndicator = null
}

function endSwipe() {
    if (!swipeState.isActive) return

    const el = swipeState.element
    const mode = swipeState.mode

    if (mode === 'delete' && swipeState.hasPassedDeleteThreshold) {
        removeDeleteIndicator()

        el.style.transition = 'transform 0.3s ease, opacity 0.3s ease, height 0.3s ease 0.15s, margin-bottom 0.3s ease 0.15s'
        el.style.transform = 'translateX(-120%)'
        el.style.opacity = '0'
        el.style.height = '0'
        el.style.marginBottom = '0'
        el.style.overflow = 'hidden'
        el.dataset.deleting = '1'

        const deleteIndex = swipeState.originalIndex
        // 标记跳过后续 2 次刷新（list + index）
        window._skip_next_render = 2
        // 更新指针（如果删除的歌在播放歌曲之前）
        if (deleteIndex < playing_index) {
            playing_index--
        }
        all_songs--
        play_index_screen.innerText = `${playing_index + 1} / ${all_songs}`
        ark.delete_song(deleteIndex)
        setTimeout(() => {
            if (el.parentNode) {
                el.parentNode.removeChild(el)
            }
            console.log(`删除: 第${deleteIndex}首`)
        }, 500)
    } else {
        el.style.transition = 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        el.style.transform = ''

        removeDeleteIndicator()
    }

    swipeState.isActive = false
    swipeState.element = null
    swipeState.mode = null

    setTimeout(() => {
        if (el) {
            el.style.zIndex = ''
            el.style.transition = ''
        }
    }, 350)
}

function cancelSwipe() {
    if (!swipeState.isActive) return

    const el = swipeState.element
    el.style.transition = 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
    el.style.transform = ''

    removeDeleteIndicator()

    swipeState.isActive = false
    swipeState.element = null
    swipeState.mode = null

    setTimeout(() => {
        if (el) {
            el.style.zIndex = ''
            el.style.transition = ''
        }
    }, 350)
}
