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
// choice_bar_scroll滑动 //
//////////////////////////

////////////
// 变量池 //
//////////
let choice_bar_isDragging = false
let choice_bar_startX = 0
let choice_bar_translateX = 0
let choice_bar_lastX = 0
let choice_bar_lastTime = 0
let choice_bar_velocity = 0
let choice_bar_animationId = null
let choice_bar_maxTranslate = 0
let choice_bar_currentTranslate = 0

/////////////
// 监听程序 //
////////////

// 计算最大滑动距离
function choice_bar_updateMaxTranslate() {
    const scrollWidth = choice_bar_scroll.scrollWidth
    const containerWidth = choice_bar.clientWidth
    choice_bar_maxTranslate = Math.max(0, scrollWidth - containerWidth)
}

// 更新位置
function choice_bar_setTranslate(x) {
    choice_bar_currentTranslate = x
    choice_bar_scroll.style.transform = `translateX(${-x}px)`
}

// 回弹动画
function choice_bar_bounceBack() {
    choice_bar_scroll.classList.add("bounce")
    
    if (choice_bar_currentTranslate < 0) {
        choice_bar_setTranslate(0)
        choice_bar_translateX = 0
    } else if (choice_bar_currentTranslate > choice_bar_maxTranslate) {
        choice_bar_setTranslate(choice_bar_maxTranslate)
        choice_bar_translateX = choice_bar_maxTranslate
    }
    
    setTimeout(() => {
        choice_bar_scroll.classList.remove("bounce")
    }, 300)
}

choice_bar_scroll.addEventListener("touchstart", (e) => {
    choice_bar_isDragging = true
    choice_bar_startX = e.touches[0].clientX
    choice_bar_lastX = choice_bar_startX
    choice_bar_lastTime = Date.now()
    choice_bar_velocity = 0
    
    // 停止惯性动画
    if (choice_bar_animationId) {
        cancelAnimationFrame(choice_bar_animationId)
        choice_bar_animationId = null
    }
    
    // 同步当前位置为滑动起点
    choice_bar_translateX = choice_bar_currentTranslate
    
    // 更新最大滑动距离
    choice_bar_updateMaxTranslate()
    
    // 添加按下效果到 choice_bar
    choice_bar.classList.add("active")
    choice_bar_scroll.classList.remove("bounce")
})

choice_bar_scroll.addEventListener("touchmove", (e) => {
    if (!choice_bar_isDragging) return
    e.preventDefault()
    
    const x = e.touches[0].clientX
    const deltaX = choice_bar_startX - x
    let newTranslate = choice_bar_translateX + deltaX
    
    // 回弹阻尼效果
    if (newTranslate < 0) {
        newTranslate = newTranslate * 0.3
    } else if (newTranslate > choice_bar_maxTranslate) {
        const overflow = newTranslate - choice_bar_maxTranslate
        newTranslate = choice_bar_maxTranslate + overflow * 0.3
    }
    
    choice_bar_setTranslate(newTranslate)
    
    // 计算速度
    const now = Date.now()
    const deltaTime = now - choice_bar_lastTime
    if (deltaTime > 0) {
        choice_bar_velocity = (x - choice_bar_lastX) / deltaTime
    }
    choice_bar_lastX = x
    choice_bar_lastTime = now
})

choice_bar_scroll.addEventListener("touchend", () => {
    if (!choice_bar_isDragging) return
    choice_bar_isDragging = false
    
    // 移除按下效果
    choice_bar.classList.remove("active")
    
    // 惯性滑动
    const friction = 0.95
    const minVelocity = 0.01
    
    function inertiaScroll() {
        if (Math.abs(choice_bar_velocity) < minVelocity) {
            // 检查是否需要回弹
            if (choice_bar_currentTranslate < 0 || choice_bar_currentTranslate > choice_bar_maxTranslate) {
                choice_bar_bounceBack()
            } else {
                choice_bar_translateX = choice_bar_currentTranslate
            }
            choice_bar_animationId = null
            return
        }
        
        let newTranslate = choice_bar_currentTranslate - choice_bar_velocity * 16
        choice_bar_velocity *= friction
        
        choice_bar_setTranslate(newTranslate)
        
        // 边界检查 - 超出边界立即回弹
        if (newTranslate < 0 || newTranslate > choice_bar_maxTranslate) {
            choice_bar_bounceBack()
            choice_bar_animationId = null
            return
        }
        
        choice_bar_animationId = requestAnimationFrame(inertiaScroll)
    }
    
    // 检查是否需要回弹
    if (choice_bar_currentTranslate < 0 || choice_bar_currentTranslate > choice_bar_maxTranslate) {
        choice_bar_bounceBack()
        choice_bar_translateX = Math.max(0, Math.min(choice_bar_maxTranslate, choice_bar_currentTranslate))
    } else {
        inertiaScroll()
    }
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// choice_bar_item点击 //
////////////////////////

/////////////
// 监听程序 //
////////////
choice_bar_items.forEach((item) => {
    item.addEventListener("click", () => {
        // 移除其他item的active类，并恢复文字颜色
        choice_bar_items.forEach(tmp => {
            tmp.classList.remove("active")
            const p = tmp.querySelector('p')
            if (p) {
                p.classList.remove('font_active_color')
                p.style.color = background_color
            }
        })
        // 添加当前item的active类，并设置文字颜色
        item.classList.add("active")
        const activeP = item.querySelector('p')
        if (activeP) {
            activeP.classList.add('font_active_color')
            activeP.style.color = active_color
        }
        
        // 切换框架显示
        const type = item.dataset.type
        Object.keys(frame_map).forEach(key => {
            if (frame_map[key]) {
                if (key === type) {
                    frame_map[key].classList.remove("hide")
                } else {
                    frame_map[key].classList.add("hide")
                }
            }
        })
        
        // 打印选项类型
        console.log(type)
        page = type

        // 添加点击操作
        if (type === '文件夹') {
            let tmp = ''
            for (const e of router_list) {
                tmp += e
                tmp += '/'
            }
            get_folder_songs(tmp)
        }

    })
})