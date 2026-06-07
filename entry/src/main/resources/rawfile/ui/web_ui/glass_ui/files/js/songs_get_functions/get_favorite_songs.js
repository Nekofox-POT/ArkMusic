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
    const wrapper = document.createElement('div')
    wrapper.dataset.path = path
    wrapper.style.cssText = 'height:62px;margin-bottom:3px;display:flex;'

    const mainArea = document.createElement('div')
    mainArea.className = 'song_main'
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:12.5px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;'
    mainArea.addEventListener('click', () => { ark.set_play_list(favorite_batchState.list, index) })

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

    // 空状态：重置
    show_frame_empty('favorite_frame', false)

    // 停止之前的观察器和滚动监听
    if (favorite_imageObserver) {
        favorite_imageObserver.disconnect()
    }

    const container = document.querySelector('#favorite_frame')
    container.removeEventListener('scroll', favorite_handle_scroll)

    // 获取喜欢的歌曲路径列表
    const songsList = ark.get_like_songs()

    // 空状态：检查
    if (songsList.length === 0) {
        show_frame_empty('favorite_frame', true)
        set_background_color()
        return
    }

    // 初始化观察器
    favorite_init_image_observer()

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
