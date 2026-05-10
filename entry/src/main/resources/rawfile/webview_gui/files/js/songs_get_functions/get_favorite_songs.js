////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取喜欢的歌曲 //
//////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let favorite_imageObserver = null

// 初始化懒加载观察器（元数据 + 图片）
function favorite_init_image_observer() {
    if (favorite_imageObserver) return

    favorite_imageObserver = new IntersectionObserver((entries) => {
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

                favorite_imageObserver.unobserve(element)
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
const FAVORITE_BATCH_SIZE = 200  // 每批渲染数量

// 分批渲染状态
let favorite_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false,
    sentinel: null  // 底部哨兵元素
}

// 创建单个歌曲元素
function favorite_create_song_element(path, index) {
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

// 渲染下一批元素
function favorite_render_next_batch() {
    if (favorite_batchState.isRendering) return
    if (favorite_batchState.currentIndex >= favorite_batchState.list.length) return

    favorite_batchState.isRendering = true

    const slide = document.querySelector('#favorite_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        favorite_batchState.currentIndex + FAVORITE_BATCH_SIZE,
        favorite_batchState.list.length
    )

    for (let i = favorite_batchState.currentIndex; i < endIndex; i++) {
        const element = favorite_create_song_element(
            favorite_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        favorite_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    favorite_batchState.currentIndex = endIndex
    favorite_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        favorite_check_and_fill()
    })
}

// 检查是否需要继续填充内容
function favorite_check_and_fill() {
    const container = document.querySelector('#favorite_frame')
    if (!container) return

    // 如果还有更多歌曲，且内容不足以产生滚动条，继续加载
    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = favorite_batchState.currentIndex < favorite_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        favorite_render_next_batch()
    }
}

// 滚动监听 - 滚动到底部时加载更多
function favorite_handle_scroll() {
    const container = document.querySelector('#favorite_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500 // 提前500px加载

    if (scrollBottom >= threshold && 
        favorite_batchState.currentIndex < favorite_batchState.list.length) {
        favorite_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_favorite_songs() {

    // 初始化环境
    const slide = document.querySelector('#favorite_frame .slide')
    slide.innerHTML = ''

    // 停止之前的观察器和滚动监听
    if (favorite_imageObserver) {
        favorite_imageObserver.disconnect()
    }

    const container = document.querySelector('#favorite_frame')
    container.removeEventListener('scroll', favorite_handle_scroll)

    // 初始化观察器
    favorite_init_image_observer()

    // 获取喜欢的歌曲路径列表
    const songsList = ark.get_like_songs()

    // 重置分批渲染状态
    favorite_batchState = {
        list: songsList,
        currentIndex: 0,
        isRendering: false,
        sentinel: null
    }

    // 注册滚动监听
    container.addEventListener('scroll', favorite_handle_scroll)

    // 渲染第一批
    favorite_render_next_batch()

}
