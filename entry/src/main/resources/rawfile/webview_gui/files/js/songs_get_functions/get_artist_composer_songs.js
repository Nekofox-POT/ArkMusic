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
                const p = element.querySelector('p')
                const imgDiv = element.querySelector('div')

                if (path) {
                    // 异步加载元数据
                    ark.get_song_meta(path).then(meta => {
                        if (meta[1]) {
                            imgDiv.style.backgroundImage = `url(${meta[1]})`
                        }
                        if (meta[0][0] && meta[0][0][0]) {
                            p.textContent = meta[0][0][0]
                        }
                        element.dataset.path = '' // 清除标记，避免重复加载
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
                    ark.get_meta_list_image('歌手', artistName).then(base64 => {
                        if (base64) {
                            imgDiv.style.backgroundImage = `url(${base64})`
                        }
                    })
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
    const div = document.createElement('div')
    div.dataset.path = path
    div.addEventListener('click', () => { ark.play_song(index) })

    const imgDiv = document.createElement('div')

    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = extract_filename(path)

    div.appendChild(imgDiv)
    div.appendChild(p)

    return div
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

    // 停止之前的观察器和滚动监听
    if (artist_imageObserver) {
        artist_imageObserver.disconnect()
    }
    if (artist_list_imageObserver) {
        artist_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', artist_handle_scroll)
    container.removeEventListener('scroll', artist_list_handle_scroll)

    // 初始化观察器
    artist_init_image_observer()
    artist_list_init_image_observer()

    // 获取数据
    const data = ark.get_artist_composer_list(name)

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
