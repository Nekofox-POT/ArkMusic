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
        load_page(type)

    })
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// files_detail点击 //
/////////////////////
files_detail.addEventListener("touchstart", () => {
    if (!files_detail.classList.contains('active')) {
        files_detail.style.transform = 'scale(0.9)'
    }
})
files_detail.addEventListener("touchend", () => {
    files_detail.style.transform = 'scale(1)'
})
files_detail.addEventListener('click', () => {
    if (!files_detail.classList.contains('active')) {
        files_detail_active_open()
    }
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// files_detail_icon 独立亮 //
////////////////////////////
files_detail_icon.addEventListener("touchstart", () => {
    files_detail_icon.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
})
files_detail_icon.addEventListener("touchend", () => {
    files_detail_icon.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// files_detail_option 逐个独立亮 //
//////////////////////////////////
document.querySelectorAll('.files_detail_option').forEach(option => {
    option.addEventListener("touchstart", () => {
        option.style.transform = 'scale(0.9)'
        option.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
    })
    option.addEventListener("touchend", () => {
        option.style.transform = 'scale(1)'
        option.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
    })
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// files_detail 列表选项编辑器 //
////////////////////////////////
const files_detail_list_editor = document.getElementById("files_detail_list_editor")
const list_editor_back = document.getElementById("list_editor_back")
const list_editor_items = document.getElementById("list_editor_items")

// 拖拽排序状态
let dragState = {
    isActive: false,
    element: null,
    startY: 0,
    currentIndex: 0,
    swapCooldown: false
}

// "列表选项" 按钮点击
const listOptionsTrigger = document.querySelector('[data-action="list_options"]')
if (listOptionsTrigger) {
    listOptionsTrigger.addEventListener('click', () => {
        open_list_editor()
    })
}

// "添加外部音频" 按钮点击
document.querySelectorAll('[data-action="add_external"]').forEach(btn => {
    btn.addEventListener('click', () => {
        ark.add_external_songs()
    })
    btn.addEventListener('touchstart', () => {
        const hasTranslate = btn.classList.contains('external_add_btn')
        btn.style.transform = hasTranslate ? 'translateX(-50%) scale(0.9)' : 'scale(0.9)'
        btn.querySelectorAll('.svg_color').forEach(tmp => {if (button_enable_active_color) {tmp.style.fill = active_color}})
        const span = btn.querySelector('.font_color')
        if (span) span.style.color = active_color
    })
    btn.addEventListener('touchend', () => {
        const hasTranslate = btn.classList.contains('external_add_btn')
        btn.style.transform = hasTranslate ? 'translateX(-50%) scale(1)' : 'scale(1)'
        btn.querySelectorAll('.svg_color').forEach(tmp => {tmp.style.fill = background_color})
        const span = btn.querySelector('.font_color')
        if (span) span.style.color = background_color
    })
})

// 返回按钮
list_editor_back.addEventListener('click', () => {
    close_list_editor()
})

function open_list_editor() {
    files_detail_options.style.display = 'none'
    files_detail_list_editor.style.display = 'flex'
    files_detail.classList.add('editor')
    build_list_editor_items()
    set_background_color()
    apply_toggle_visuals()
}

function close_list_editor() {
    files_detail_list_editor.style.display = 'none'
    files_detail_options.style.display = 'grid'
    files_detail.classList.remove('editor')
    save_list_options()
}

function build_list_editor_items() {
    list_editor_items.innerHTML = ''
    const items = choice_bar_scroll.querySelectorAll('.choice_bar_item')
    items.forEach((item) => {
        const type = item.dataset.type
        const name = item.querySelector('p').textContent
        const isHidden = item.style.display === 'none'

        const row = document.createElement('div')
        row.className = 'list_editor_item box_color' + (isHidden ? ' hidden' : '')
        row.dataset.type = type

        // toggle 开关（左侧）
        const toggle = document.createElement('div')
        toggle.className = 'list_item_toggle' + (isHidden ? '' : ' on')
        const knob = document.createElement('div')
        knob.className = 'list_item_toggle_knob'
        toggle.appendChild(knob)

        // 名称
        const nameSpan = document.createElement('span')
        nameSpan.className = 'font_color list_item_name'
        nameSpan.textContent = name

        // 拖拽手柄（右侧）
        const dragDiv = document.createElement('div')
        dragDiv.className = 'list_item_drag'
        dragDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" opacity="0"></rect><g><path class="svg_color" d="M14.5 17.5Q14.5 16.47 13.76 15.74Q13.03 15 12 15Q10.97 15 10.24 15.74Q9.5 16.47 9.5 17.5Q9.5 18.52 10.24 19.26Q10.97 19.99 12 19.99Q13.03 19.99 13.76 19.26Q14.5 18.52 14.5 17.5ZM14.5 6.5Q14.5 5.47 13.76 4.74Q13.03 4.01 12 4.01Q10.97 4.01 10.24 4.74Q9.5 5.47 9.5 6.51Q9.5 7.51 10.24 8.26Q10.97 9 12 9Q13.03 9 13.76 8.26Q14.5 7.53 14.5 6.5Z"></path></g></svg>'

        row.appendChild(toggle)
        row.appendChild(nameSpan)
        row.appendChild(dragDiv)
        list_editor_items.appendChild(row)

        // toggle 事件
        toggle.addEventListener('click', () => {
            const on = toggle.classList.toggle('on')
            row.classList.toggle('hidden', !on)
            set_toggle_visual(toggle, on)
            item.style.display = on ? '' : 'none'
            const prev = item.previousElementSibling
            if (prev && prev.classList.contains('choice_bar_separator')) {
                prev.style.display = on ? '' : 'none'
            }
            if (!on) {
                choice_bar_updateMaxTranslate()
            }
        })
    })
}

function set_toggle_visual(toggle, on) {
    if (on) {
        toggle.classList.add('box_active_color')
        toggle.style.backgroundColor = active_color
    } else {
        toggle.classList.remove('box_active_color')
        toggle.style.backgroundColor = 'rgba(255, 255, 255, 0.25)'
    }
}

function apply_toggle_visuals() {
    const toggles = list_editor_items.querySelectorAll('.list_item_toggle')
    toggles.forEach(toggle => {
        set_toggle_visual(toggle, toggle.classList.contains('on'))
    })
}

function load_page(type) {
    page = type
    if (type === '所有歌曲') {
        get_all_songs()
    } else if (type === '外部歌曲') {
        get_external_songs()
    } else if (type === '文件夹') {
        let tmp = ''
        for (const e of router_list) {
            tmp += e
            tmp += '/'
        }
        get_folder_songs(tmp)
    } else if (type === '播放列表') {
        get_play_list_songs(play_list_backup)
    } else if (type === '我的喜欢') {
        get_favorite_songs()
    } else if (type === '歌手') {
        get_artist_composer_list(artist_composer_backup)
    } else if (type === '专辑') {
        get_album_list(album_backup)
    } else if (type === '专辑作者') {
        get_album_artist_list(album_artist_backup)
    } else if (type === '流派') {
        get_genre_list(genre_backup)
    }
}

function sync_choice_bar_order() {
    const rows = list_editor_items.querySelectorAll('.list_editor_item')
    const typeOrder = Array.from(rows).map(r => r.dataset.type)
    typeOrder.forEach(type => {
        const item = choice_bar_scroll.querySelector(`.choice_bar_item[data-type="${type}"]`)
        if (!item) return
        const prev = item.previousElementSibling
        if (prev && prev.classList.contains('choice_bar_separator')) {
            choice_bar_scroll.appendChild(prev)
        }
        choice_bar_scroll.appendChild(item)
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 列表编辑器 拖拽排序 //
////////////////////////

list_editor_items.addEventListener('touchstart', (e) => {
    const dragHandle = e.target.closest('.list_item_drag')
    if (!dragHandle) return
    const item = dragHandle.closest('.list_editor_item')
    if (!item) return
    e.preventDefault()
    dragState.isActive = true
    dragState.element = item
    dragState.startY = e.touches[0].clientY
    dragState.currentIndex = Array.from(list_editor_items.children).indexOf(item)
    item.style.zIndex = '10'
    item.style.transition = 'none'
}, { passive: false })

list_editor_items.addEventListener('touchmove', (e) => {
    if (!dragState.isActive || dragState.swapCooldown) return
    e.preventDefault()
    const y = e.touches[0].clientY
    const children = Array.from(list_editor_items.children)
    const el = dragState.element
    for (let i = 0; i < children.length; i++) {
        const child = children[i]
        if (child === el) continue
        const rect = child.getBoundingClientRect()
        if (y > rect.top && y < rect.bottom && i !== dragState.currentIndex) {
            dragState.swapCooldown = true

            const elRectBefore = el.getBoundingClientRect()
            const targetRectBefore = child.getBoundingClientRect()

            if (i < dragState.currentIndex) {
                list_editor_items.insertBefore(el, child)
            } else {
                list_editor_items.insertBefore(el, child.nextSibling)
            }

            const elRectAfter = el.getBoundingClientRect()
            const targetRectAfter = child.getBoundingClientRect()
            const elDeltaY = elRectBefore.top - elRectAfter.top
            const targetDeltaY = targetRectBefore.top - targetRectAfter.top

            if (Math.abs(elDeltaY) > 1 || Math.abs(targetDeltaY) > 1) {
                el.style.transition = 'none'
                child.style.transition = 'none'
                el.style.transform = `translateY(${elDeltaY}px)`
                child.style.transform = `translateY(${targetDeltaY}px)`
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        el.style.transition = 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                        child.style.transition = 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
                        el.style.transform = ''
                        child.style.transform = ''
                    })
                })
            }

            dragState.currentIndex = i
            sync_choice_bar_order()
            ark.vib()

            setTimeout(() => { dragState.swapCooldown = false }, 150)
            break
        }
    }
}, { passive: false })

list_editor_items.addEventListener('touchend', () => {
    if (!dragState.isActive) return
    const el = dragState.element
    el.style.transition = 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
    el.style.transform = ''
    dragState.isActive = false
    dragState.element = null
    setTimeout(() => {
        if (el) {
            el.style.zIndex = ''
            el.style.transition = ''
        }
    }, 300)
})

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 列表选项 持久化 //
////////////////////

function save_list_options() {
    const items = choice_bar_scroll.querySelectorAll('.choice_bar_item')
    const data = []
    items.forEach(item => {
        const type = item.dataset.type
        const visible = item.style.display !== 'none' ? '1' : '0'
        data.push(type + ':' + visible)
    })
    ark.save_data(data, 'list_options')
}

function load_list_options() {
    try {
        const data = ark.load_data('list_options')
        if (!data || !Array.isArray(data) || data.length === 0) return
        const map = {}
        const order = []
        data.forEach(entry => {
            const idx = entry.lastIndexOf(':')
            if (idx <= 0) return
            const type = entry.substring(0, idx)
            const visible = entry.substring(idx + 1) === '1'
            map[type] = visible
            order.push(type)
        })
        let firstVisible = null
        order.forEach(type => {
            const item = choice_bar_scroll.querySelector(`.choice_bar_item[data-type="${type}"]`)
            if (!item) return
            const prev = item.previousElementSibling
            if (prev && prev.classList.contains('choice_bar_separator')) {
                choice_bar_scroll.appendChild(prev)
            }
            choice_bar_scroll.appendChild(item)
            item.style.display = map[type] ? '' : 'none'
            const sep = item.previousElementSibling
            if (sep && sep.classList.contains('choice_bar_separator')) {
                sep.style.display = map[type] ? '' : 'none'
            }
            // 清除所有 hardcoded active
            item.classList.remove('active')
            const p = item.querySelector('p')
            if (p) p.classList.remove('font_active_color')
            if (!firstVisible && map[type]) firstVisible = item
        })
        choice_bar_updateMaxTranslate()
        // 始终激活第一个可见项
        if (firstVisible) {
            firstVisible.classList.add('active')
            const p = firstVisible.querySelector('p')
            if (p) {
                p.classList.add('font_active_color')
                p.style.color = active_color
            }
            const type = firstVisible.dataset.type
            Object.keys(frame_map).forEach(key => {
                if (frame_map[key]) {
                    frame_map[key].classList.toggle('hide', key !== type)
                }
            })
            load_page(type)
        }
    } catch (_) {}
}