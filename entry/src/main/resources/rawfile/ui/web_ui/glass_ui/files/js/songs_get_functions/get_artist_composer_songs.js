////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取歌手/艺术家的歌曲 //
/////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let artist_imageObserver = null

// 初始化懒加载观察器（元数据 + 图片）—— 用于歌曲元素
function artist_init_image_observer() {
    if (artist_imageObserver) return

    artist_imageObserver = new IntersectionObserver((entries) => {
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

                artist_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

let artist_list_imageObserver = null

// 初始化懒加载观察器（封面图）—— 用于歌手列表元素
function artist_list_init_image_observer() {
    if (artist_list_imageObserver) return

    artist_list_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const artistName = element.dataset.artistName
                const imgDiv = element.querySelector('div')

                if (artistName) {
                    const songs = ark.get_artist_songs(artistName)
                    if (songs && songs.length > 0) {
                        ark.get_image(songs[0]).then(img => {
                            if (img[0]) {
                                imgDiv.style.backgroundImage = `url(${img[1]})`
                            }
                        })
                    }
                    element.dataset.artistName = ''
                }

                artist_list_imageObserver.unobserve(element)
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
const ARTIST_BATCH_SIZE = 200

// 歌曲列表的分批渲染状态
let artist_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

// 歌手列表的分批渲染状态
let artist_list_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

// 滚动位置记忆
let artist_list_pendingScrollTop = -1

// 创建歌手列表元素
function artist_create_list_element(name) {
    const div = document.createElement('div')
    div.dataset.artistName = name

    // 点击事件
    div.addEventListener('click', () => {
        artist_composer_backup = name
        get_artist_composer_list(name)
    })

    // 创建图标容器
    const imgDiv = document.createElement('div')
    imgDiv.style.borderRadius = '50%'
    imgDiv.style.backgroundImage = 'none'

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = name

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return div
}

// 创建歌曲元素
function artist_create_song_element(path, index) {
    const wrapper = document.createElement('div')
    wrapper.dataset.path = path
    wrapper.style.cssText = 'height:62px;margin-bottom:3px;display:flex;'

    const mainArea = document.createElement('div')
    mainArea.className = 'song_main'
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:12.5px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;'
    mainArea.addEventListener('click', () => { ark.set_play_list(artist_batchState.list, index) })

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

    wrapper.appendChild(mainArea)
    wrapper.appendChild(detailArea)

    return wrapper
}

// 渲染下一批歌手列表元素
function artist_list_render_next_batch() {
    if (artist_list_batchState.isRendering) return
    if (artist_list_batchState.currentIndex >= artist_list_batchState.list.length) return

    artist_list_batchState.isRendering = true

    const slide = document.querySelector('#artist_composer_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        artist_list_batchState.currentIndex + ARTIST_BATCH_SIZE,
        artist_list_batchState.list.length
    )

    for (let i = artist_list_batchState.currentIndex; i < endIndex; i++) {
        const element = artist_create_list_element(artist_list_batchState.list[i])
        fragment.appendChild(element)
        artist_list_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    artist_list_batchState.currentIndex = endIndex
    artist_list_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 尝试恢复滚动位置
    artist_list_restore_scroll()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        artist_list_check_and_fill()
    })
}

// 尝试恢复滚动位置（在每批渲染后调用）
function artist_list_restore_scroll() {
    if (artist_list_pendingScrollTop < 0) return
    const scrollFrame = document.querySelector('#artist_composer_frame .slide_frame')
    if (!scrollFrame) return

    scrollFrame.scrollTop = artist_list_pendingScrollTop
    if (scrollFrame.scrollTop >= artist_list_pendingScrollTop) {
        artist_list_pendingScrollTop = -1
    }
}

// 歌手列表 check_and_fill
function artist_list_check_and_fill() {
    const container = document.querySelector('#artist_composer_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMore = artist_list_batchState.currentIndex < artist_list_batchState.list.length

    if (hasMore && !hasScrollbar) {
        artist_list_render_next_batch()
    }
}

// 歌手列表滚动监听
function artist_list_handle_scroll() {
    const container = document.querySelector('#artist_composer_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        artist_list_batchState.currentIndex < artist_list_batchState.list.length) {
        artist_list_render_next_batch()
    }
}

// 渲染下一批歌曲元素
function artist_render_next_batch() {
    if (artist_batchState.isRendering) return
    if (artist_batchState.currentIndex >= artist_batchState.list.length) return

    artist_batchState.isRendering = true

    const slide = document.querySelector('#artist_composer_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        artist_batchState.currentIndex + ARTIST_BATCH_SIZE,
        artist_batchState.list.length
    )

    for (let i = artist_batchState.currentIndex; i < endIndex; i++) {
        const element = artist_create_song_element(
            artist_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        artist_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    artist_batchState.currentIndex = endIndex
    artist_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        artist_check_and_fill()
    })
}

// 歌曲列表 check_and_fill
function artist_check_and_fill() {
    const container = document.querySelector('#artist_composer_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = artist_batchState.currentIndex < artist_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        artist_render_next_batch()
    }
}

// 歌曲列表滚动监听
function artist_handle_scroll() {
    const container = document.querySelector('#artist_composer_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        artist_batchState.currentIndex < artist_batchState.list.length) {
        artist_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_artist_composer_list(name) {

    // 初始化环境
    const slide = document.querySelector('#artist_composer_frame .slide')
    const container = document.querySelector('#artist_composer_frame')

    // 进入子视图前：保存根列表滚动位置（实际滚动在 .slide_frame 上）
    if (name) {
        const scrollFrame = document.querySelector('#artist_composer_frame .slide_frame')
        artist_list_pendingScrollTop = scrollFrame ? scrollFrame.scrollTop : 0
    }

    slide.innerHTML = ''

    // 空状态：重置
    show_frame_empty('artist_composer_frame', false)

    // 停止之前的观察器和滚动监听
    if (artist_imageObserver) {
        artist_imageObserver.disconnect()
    }
    if (artist_list_imageObserver) {
        artist_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', artist_handle_scroll)
    container.removeEventListener('scroll', artist_list_handle_scroll)

    // 获取数据
    const data = ark.get_artist_songs(name)

    // 空状态：检查
    if (data.length === 0) {
        show_frame_empty('artist_composer_frame', true)
        set_background_color()
        return
    }

    // 初始化观察器
    artist_init_image_observer()
    artist_list_init_image_observer()

    if (!name) {
        // 歌手列表模式：分批渲染
        artist_list_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        // 注册滚动监听
        container.addEventListener('scroll', artist_list_handle_scroll)

        // 渲染第一批
        artist_list_render_next_batch()
    } else {
        // 歌曲列表模式：data 是歌曲路径数组
        // 重置分批渲染状态
        artist_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        // 注册滚动监听
        container.addEventListener('scroll', artist_handle_scroll)

        // 渲染第一批
        artist_render_next_batch()
    }

    // 更新色彩
    set_background_color()

}
