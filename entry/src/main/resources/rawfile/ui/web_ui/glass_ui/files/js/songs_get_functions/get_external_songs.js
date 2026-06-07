////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 外部歌曲设置 //
/////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 滑动删除 状态 //
//////////////////

let ext_swipeState = {
    isActive: false,
    element: null,
    deleteIndicator: null,
    startX: 0,
    startY: 0,
    hasPassedDeleteThreshold: false,
    deleteThreshold: 65,
    preventClick: false
}

let ext_swipeListenersReady = false

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 滑动删除 函数 //
//////////////////

function ext_createDeleteIndicator(element) {
    const indicator = document.createElement('div')
    indicator.className = 'box_color swipe-delete-indicator'
    indicator.style.cssText = `position:absolute;top:${element.offsetTop + 31}px;right:-70px;width:50px;height:50px;border-radius:50%;overflow:visible;margin-bottom:0;display:flex;align-items:center;justify-content:center;pointer-events:none;z-index:5;opacity:0;transform:translateY(-50%) translateX(0px);transition:opacity 0.15s ease;`

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

    const slide = document.querySelector('#external_song_frame .slide')
    slide.appendChild(indicator)

    return indicator
}

function ext_removeDeleteIndicator() {
    const indicator = ext_swipeState.deleteIndicator
    if (indicator && indicator.parentNode) {
        indicator.style.transition = 'transform 0.2s ease, opacity 0.2s ease'
        indicator.style.opacity = '0'
        const currentTx = ext_swipeState.element ? ext_swipeState.element.style.transform.match(/translateX\(([^)]+)\)/) : null
        const tx = currentTx ? currentTx[1] : '0px'
        indicator.style.transform = `translateY(-50%) translateX(${tx})`
        setTimeout(() => {
            if (indicator.parentNode) {
                indicator.parentNode.removeChild(indicator)
            }
        }, 220)
    }
    ext_swipeState.deleteIndicator = null
}

function ext_startSwipe(element, x, y) {
    ext_swipeState.isActive = true
    ext_swipeState.element = element
    ext_swipeState.startX = x
    ext_swipeState.startY = y
    ext_swipeState.hasPassedDeleteThreshold = false
    ext_swipeState.preventClick = false

    element.style.transition = 'none'
    element.style.transform = 'translateX(0px)'
    element.style.zIndex = '10'
}

function ext_updateSwipe(x, y) {
    if (!ext_swipeState.isActive) return

    const dx = x - ext_swipeState.startX
    const translateX = Math.min(0, dx)

    ext_swipeState.element.style.transform = `translateX(${translateX}px)`

    if (!ext_swipeState.deleteIndicator && Math.abs(dx) > 8) {
        ext_swipeState.preventClick = true
        ext_swipeState.deleteIndicator = ext_createDeleteIndicator(ext_swipeState.element)
    }

    if (ext_swipeState.deleteIndicator) {
        ext_swipeState.deleteIndicator.style.opacity = '1'
        ext_swipeState.deleteIndicator.style.transform = `translateY(-50%) translateX(${translateX}px)`

        const progress = Math.min(1, Math.abs(translateX) / ext_swipeState.deleteThreshold)
        const path = ext_swipeState.deleteIndicator.querySelector('path')
        const wasActive = ext_swipeState.hasPassedDeleteThreshold
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

    ext_swipeState.hasPassedDeleteThreshold = Math.abs(translateX) >= ext_swipeState.deleteThreshold
}

function ext_endSwipe() {
    if (!ext_swipeState.isActive) return

    const el = ext_swipeState.element

    if (ext_swipeState.hasPassedDeleteThreshold) {
        ext_removeDeleteIndicator()

        const deleteIndex = parseInt(el.id)
        const path = el.dataset.path || external_songs_batchState.list[deleteIndex] || ''
        ark.del_external_songs([path])

        el.style.transition = 'transform 0.3s ease, opacity 0.3s ease, height 0.3s ease 0.15s, margin-bottom 0.3s ease 0.15s'
        el.style.transform = 'translateX(-120%)'
        el.style.opacity = '0'
        el.style.height = '0'
        el.style.marginBottom = '0'
        el.style.overflow = 'hidden'

        setTimeout(() => {
            if (el.parentNode) {
                el.parentNode.removeChild(el)
            }
        }, 500)
    } else {
        el.style.transition = 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        el.style.transform = ''

        ext_removeDeleteIndicator()
    }

    ext_swipeState.isActive = false
    ext_swipeState.element = null

    setTimeout(() => {
        if (el) {
            el.style.zIndex = ''
            el.style.transition = ''
        }
    }, 350)
}

function ext_cancelSwipe() {
    if (!ext_swipeState.isActive) return

    const el = ext_swipeState.element
    el.style.transition = 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
    el.style.transform = ''

    ext_removeDeleteIndicator()

    ext_swipeState.isActive = false
    ext_swipeState.element = null

    setTimeout(() => {
        if (el) {
            el.style.zIndex = ''
            el.style.transition = ''
        }
    }, 350)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 滑动删除 监听注册 //
//////////////////////

function ext_setupSwipeListeners() {
    if (ext_swipeListenersReady) return
    ext_swipeListenersReady = true

    const slide = document.querySelector('#external_song_frame .slide')

    slide.addEventListener('touchstart', function(e) {
        const handle = e.target.closest('.ext_drag_handle')
        if (!handle) return

        const songItem = handle.closest('.slide > div')
        if (!songItem) return

        if (e.touches.length === 1) {
            e.preventDefault()
            const touch = e.touches[0]
            ext_startSwipe(songItem, touch.clientX, touch.clientY)
        }
    }, { passive: false })

    slide.addEventListener('touchmove', function(e) {
        if (!ext_swipeState.isActive) return

        e.preventDefault()
        const touch = e.touches[0]
        ext_updateSwipe(touch.clientX, touch.clientY)
    }, { passive: false })

    slide.addEventListener('touchend', function(e) {
        if (!ext_swipeState.isActive) return
        ext_endSwipe()
    })

    slide.addEventListener('touchcancel', function(e) {
        if (!ext_swipeState.isActive) return
        ext_cancelSwipe()
    })

    // 阻止滑动过程中的点击事件
    slide.addEventListener('click', function(e) {
        if (ext_swipeState.preventClick) {
            e.stopPropagation()
            e.preventDefault()
            ext_swipeState.preventClick = false
        }
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

// 通过 ark 主动获取外部歌曲列表
function get_external_songs() {
    const list = ark.get_external_songs()

    // 初始化环境
    const slide = document.querySelector('#external_song_frame .slide')
    slide.innerHTML = ''

    // 空状态：重置并检查
    show_frame_empty('external_song_frame', false)

    if (list.length === 0) {
        show_frame_empty('external_song_frame', true)
        set_background_color()
        return
    }

    // 注册滑动删除监听（仅一次）
    ext_setupSwipeListeners()

    // 停止之前的观察器和滚动监听
    if (external_songs_imageObserver) {
        external_songs_imageObserver.disconnect()
    }

    const container = document.querySelector('#external_song_frame')
    container.removeEventListener('scroll', external_songs_handle_scroll)

    // 初始化观察器
    external_songs_init_image_observer()

    // 重置分批渲染状态
    external_songs_batchState = {
        list: list,
        currentIndex: 0,
        isRendering: false,
        sentinel: null
    }

    // 注册滚动监听
    container.addEventListener('scroll', external_songs_handle_scroll)

    // 渲染第一批
    external_songs_render_next_batch()

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let external_songs_imageObserver = null

// 初始化懒加载观察器（元数据 + 图片）
function external_songs_init_image_observer() {
    if (external_songs_imageObserver) return

    external_songs_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const path = element.dataset.path
                const imgDiv = element.querySelector('.song_cover')
                const titleWrap = element.querySelector('.song_item_title_wrap')
                const titleP = element.querySelector('.song_item_title')
                const artistWrap = element.querySelector('.song_item_artist_wrap')
                const artistP = element.querySelector('.song_item_artist')
                const sampleP = element.querySelector('.song_meta_sample')
                const depthP = element.querySelector('.song_meta_depth')
                const rateP = element.querySelector('.song_meta_rate')

                if (path) {
                    ark.get_meta(path).then(meta => {
                        if (meta[1] && meta[1][0]) {
                            titleP.textContent = meta[1][0]
                        }
                        if (meta[1] && meta[1][1]) {
                            artistP.textContent = meta[1][1]
                        }
                        if (meta[0]) {
                            sampleP.textContent = meta[0][4]
                            depthP.textContent = meta[0][5]
                            rateP.textContent = meta[0][6]
                        }
                        // 检查标题/歌手是否需要滚动字幕
                        void titleWrap.offsetWidth
                        void artistWrap.offsetWidth
                        if (titleP.scrollWidth > titleWrap.clientWidth) {
                            titleWrap.classList.add('marquee')
                        }
                        if (artistP.scrollWidth > artistWrap.clientWidth) {
                            artistWrap.classList.add('marquee')
                        }
                        element.dataset.path = ''
                    })
                    ark.get_image(path).then(img => {
                        if (img[0]) {
                            imgDiv.style.backgroundImage = `url(${img[1]})`
                        }
                    })
                }

                external_songs_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

// 配置参数
const EXTERNAL_SONGS_BATCH_SIZE = 200  // 每批渲染数量
const EXTERNAL_SONGS_RENDER_DELAY = 8 // 渲染间隔（约60fps）

// 分批渲染状态
let external_songs_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false,
    sentinel: null  // 底部哨兵元素
}

// 创建单个歌曲元素
function external_songs_create_song_element(path, index) {
    const wrapper = document.createElement('div')
    wrapper.dataset.path = path
    wrapper.id = index
    wrapper.style.cssText = 'height:62px;margin-bottom:3px;display:flex;'

    const mainArea = document.createElement('div')
    mainArea.className = 'song_main'
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:12.5px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;'
    mainArea.addEventListener('click', () => { ark.set_play_list(external_songs_batchState.list, index) })

    const imgDiv = document.createElement('div')
    imgDiv.className = 'song_cover'

    const infoDiv = document.createElement('div')
    infoDiv.style.cssText = 'display:flex;flex-direction:column;justify-content:center;flex:1;margin:0 6px;min-width:0;max-width:55%;height:auto;'

    const titleWrap = document.createElement('div')
    titleWrap.className = 'song_item_title_wrap'
    const titleP = document.createElement('p')
    titleP.className = 'font_color song_item_title'
    titleP.style.cssText = `color:${background_color};font-size:0.82rem;font-weight:700;margin:0 0 1px 0;line-height:1.15;`

    const artistWrap = document.createElement('div')
    artistWrap.className = 'song_item_artist_wrap'
    const artistP = document.createElement('p')
    artistP.className = 'font_color song_item_artist'
    artistP.style.cssText = `color:${background_color};font-size:0.62rem;font-weight:400;margin:0;line-height:1.15;`

    titleWrap.appendChild(titleP)
    artistWrap.appendChild(artistP)
    infoDiv.appendChild(titleWrap)
    infoDiv.appendChild(artistWrap)

    const metaDiv = document.createElement('div')
    metaDiv.style.cssText = 'display:flex;flex-direction:column;justify-content:center;align-items:flex-end;flex-shrink:0;min-width:50px;margin-right:6px;height:auto;'

    const sampleP = document.createElement('p')
    sampleP.className = 'font_color song_meta_sample'
    sampleP.style.cssText = `color:${background_color};font-size:0.5rem;font-weight:500;margin:0;`

    const depthP = document.createElement('p')
    depthP.className = 'font_color song_meta_depth'
    depthP.style.cssText = `color:${background_color};font-size:0.5rem;font-weight:500;margin:0;`

    const rateP = document.createElement('p')
    rateP.className = 'font_color song_meta_rate'
    rateP.style.cssText = `color:${background_color};font-size:0.5rem;font-weight:500;margin:0;`

    metaDiv.appendChild(sampleP)
    metaDiv.appendChild(depthP)
    metaDiv.appendChild(rateP)

    mainArea.appendChild(imgDiv)
    mainArea.appendChild(infoDiv)
    mainArea.appendChild(metaDiv)

    const detailArea = document.createElement('div')
    detailArea.style.cssText = 'flex-shrink:0;display:flex;align-items:center;padding-right:4px;height:auto;background-image:none;box-shadow:none;border-radius:0;margin-left:0;'

    // 详情按钮
    const detailBtn = document.createElement('div')
    detailBtn.className = 'box_color song_item_detail_btn'
    detailBtn.style.cssText = 'width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;background-image:none;-webkit-tap-highlight-color:transparent;transition:transform 0.15s ease;flex-shrink:0;'
    detailBtn.addEventListener('pointerdown', () => {
        wrapper.classList.add('no_active')
    })
    detailBtn.addEventListener('pointerup', () => {
        wrapper.classList.remove('no_active')
    })
    detailBtn.addEventListener('pointercancel', () => {
        wrapper.classList.remove('no_active')
    })
    detailBtn.addEventListener('click', (e) => {
        e.stopPropagation()
        song_detail_click(path, index, detailBtn)
    })

    const detailSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    detailSvg.setAttribute('width', '14')
    detailSvg.setAttribute('height', '14')
    detailSvg.setAttribute('viewBox', '0 0 14 14')
    detailSvg.innerHTML = '<rect width="14" height="14" opacity="0"></rect><circle class="svg_color" cx="7" cy="3" r="1.3"></circle><circle class="svg_color" cx="7" cy="7" r="1.3"></circle><circle class="svg_color" cx="7" cy="11" r="1.3"></circle>'

    detailBtn.appendChild(detailSvg)
    detailArea.appendChild(detailBtn)

    // 拖拽图标（滑动删除手柄）
    const dragHandle = document.createElement('div')
    dragHandle.className = 'ext_drag_handle'
    dragHandle.style.cssText = 'width:28px;height:28px;display:flex;align-items:center;justify-content:center;flex-shrink:0;'
    dragHandle.addEventListener('pointerdown', () => {
        wrapper.classList.add('no_active')
    })
    dragHandle.addEventListener('pointerup', () => {
        wrapper.classList.remove('no_active')
    })
    dragHandle.addEventListener('pointercancel', () => {
        wrapper.classList.remove('no_active')
    })

    const dragSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    dragSvg.setAttribute('width', '24')
    dragSvg.setAttribute('height', '24')
    dragSvg.setAttribute('viewBox', '0 0 24 24')
    dragSvg.innerHTML = '<rect width="24" height="24" opacity="0"></rect><g><path class="svg_color" d="M14.5 17.5Q14.5 16.47 13.76 15.74Q13.03 15 12 15Q10.97 15 10.24 15.74Q9.5 16.47 9.5 17.5Q9.5 18.52 10.24 19.26Q10.97 19.99 12 19.99Q13.03 19.99 13.76 19.26Q14.5 18.52 14.5 17.5ZM14.5 6.5Q14.5 5.47 13.76 4.74Q13.03 4.01 12 4.01Q10.97 4.01 10.24 4.74Q9.5 5.47 9.5 6.51Q9.5 7.51 10.24 8.26Q10.97 9 12 9Q13.03 9 13.76 8.26Q14.5 7.53 14.5 6.5Z"></path></g></svg>'

    dragHandle.appendChild(dragSvg)
    detailArea.appendChild(dragHandle)

    wrapper.appendChild(mainArea)
    wrapper.appendChild(detailArea)

    return wrapper
}

// 渲染下一批元素
function external_songs_render_next_batch() {
    if (external_songs_batchState.isRendering) return
    if (external_songs_batchState.currentIndex >= external_songs_batchState.list.length) return

    external_songs_batchState.isRendering = true

    const slide = document.querySelector('#external_song_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        external_songs_batchState.currentIndex + EXTERNAL_SONGS_BATCH_SIZE,
        external_songs_batchState.list.length
    )

    for (let i = external_songs_batchState.currentIndex; i < endIndex; i++) {
        const element = external_songs_create_song_element(
            external_songs_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        external_songs_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    external_songs_batchState.currentIndex = endIndex
    external_songs_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        external_songs_check_and_fill()
    })
}

// 检查是否需要继续填充内容
function external_songs_check_and_fill() {
    const container = document.querySelector('#external_song_frame')
    if (!container) return

    // 如果还有更多歌曲，且内容不足以产生滚动条，继续加载
    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = external_songs_batchState.currentIndex < external_songs_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        external_songs_render_next_batch()
    }
}

// 滚动监听 - 滚动到底部时加载更多
function external_songs_handle_scroll() {
    const container = document.querySelector('#external_song_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500 // 提前500px加载

    if (scrollBottom >= threshold &&
        external_songs_batchState.currentIndex < external_songs_batchState.list.length) {
        external_songs_render_next_batch()
    }
}

