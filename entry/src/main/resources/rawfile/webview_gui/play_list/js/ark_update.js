//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 配置常量 //
/////////////

const PLAYLIST_BATCH_SIZE = 200 // 每批渲染的元素数量

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let playList_imageObserver = null

// 从路径提取文件名
function playList_extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 初始化懒加载观察器（元数据 + 图片）
function playList_init_image_observer() {
    if (playList_imageObserver) return

    playList_imageObserver = new IntersectionObserver((entries) => {
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
                    ark.get_song_meta(path).then(meta => {
                        if (meta[1]) {
                            imgDiv.style.backgroundImage = `url(${meta[1]})`
                        }
                        if (meta[0][1] && meta[0][1][0]) {
                            titleP.textContent = meta[0][1][0]
                        }
                        if (meta[0][1] && meta[0][1][1]) {
                            artistP.textContent = meta[0][1][1]
                        }
                        if (meta[0][0]) {
                            sampleP.textContent = meta[0][0][3]
                            depthP.textContent = meta[0][0][4]
                            rateP.textContent = meta[0][0][5]
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
                }

                playList_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更新函数 //
/////////////

// 创建单个歌曲元素
function playList_create_song_element(path, index, num) {
    const wrapper = document.createElement('div')
    wrapper.className = 'box_color'
    wrapper.id = index
    wrapper.dataset.path = path
    wrapper.style.cssText = 'height:50px;display:flex;border-radius:50px;'
    
    const mainArea = document.createElement('div')
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:50px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;padding:0 10px;'
    mainArea.addEventListener('click', () => { ark.seek_song(index) })

    const imgDiv = document.createElement('div')
    imgDiv.className = 'song_cover'

    const infoDiv = document.createElement('div')
    infoDiv.style.cssText = 'display:flex;flex-direction:column;justify-content:center;flex:1;margin:0 6px;min-width:0;max-width:55%;height:auto;'

    const titleWrap = document.createElement('div')
    titleWrap.className = 'song_item_title_wrap'
    const titleP = document.createElement('p')
    titleP.className = (index === num) ? 'font_color song_item_title font_active_color' : 'font_color song_item_title'
    titleP.style.cssText = `${index === num ? 'color:' + active_color + ';' : 'color:' + background_color + ';'}font-size:0.82rem;font-weight:700;margin:0 0 1px 0;line-height:1.15;`

    const artistWrap = document.createElement('div')
    artistWrap.className = 'song_item_artist_wrap'
    const artistP = document.createElement('p')
    artistP.className = 'font_color song_item_artist'
    artistP.style.cssText = `color:${background_color};font-size:0.62rem;font-weight:400;margin:0;line-height:1.15;`

    titleP.textContent = ''
    titleWrap.appendChild(titleP)
    artistWrap.appendChild(artistP)
    infoDiv.appendChild(titleWrap)
    infoDiv.appendChild(artistWrap)

    const metaDiv = document.createElement('div')
    metaDiv.style.cssText = 'display:flex;flex-direction:column;justify-content:center;align-items:flex-end;flex-shrink:0;min-width:50px;margin-left:auto;margin-right:8px;height:auto;'

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

    wrapper.appendChild(mainArea)

    return wrapper
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

// 分批渲染状态
let playList_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false,
    num: 0
}

// 渲染下一批元素
function playList_render_next_batch() {
    if (playList_batchState.isRendering) return
    if (playList_batchState.currentIndex >= playList_batchState.list.length) return

    playList_batchState.isRendering = true

    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        playList_batchState.currentIndex + PLAYLIST_BATCH_SIZE,
        playList_batchState.list.length
    )

    for (let i = playList_batchState.currentIndex; i < endIndex; i++) {
        const element = playList_create_song_element(
            playList_batchState.list[i],
            i,
            playList_batchState.num
        )
        fragment.appendChild(element)
        playList_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    playList_batchState.currentIndex = endIndex
    playList_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        playList_check_and_fill()
    })
}

// 检查是否需要继续填充内容
function playList_check_and_fill() {
    const container = document.querySelector('.slide_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = playList_batchState.currentIndex < playList_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        playList_render_next_batch()
    }
}

// 滚动监听 - 滚动到底部时加载更多
function playList_handle_scroll() {
    const container = document.querySelector('.slide_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        playList_batchState.currentIndex < playList_batchState.list.length) {
        playList_render_next_batch()
    }
}

// 更新高亮色（独立函数）
function update_highlight(num) {
    const items = slide.querySelectorAll('div.box_color')
    items.forEach(item => {
        const titleP = item.querySelector('.song_item_title')
        if (titleP) {
            if (parseInt(item.id) === num) {
                titleP.className = 'font_color song_item_title font_active_color'
                titleP.style.color = active_color
            } else {
                titleP.className = 'font_color song_item_title'
                titleP.style.color = background_color
            }
        }
    })
}

// 滚动到指定歌曲位置
function scroll_to_song(index) {
    const container = document.querySelector('.slide_frame')
    const targetElement = document.getElementById(index.toString())
    
    if (targetElement) {
        // 元素已存在，直接滚动
        targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
    } else if (index >= playList_batchState.currentIndex) {
        // 元素还未渲染，需要先渲染到目标位置
        const fragment = document.createDocumentFragment()
        const endIndex = Math.min(
            Math.ceil((index + 1) / PLAYLIST_BATCH_SIZE) * PLAYLIST_BATCH_SIZE,
            playList_batchState.list.length
        )
        
        for (let i = playList_batchState.currentIndex; i < endIndex; i++) {
            const element = playList_create_song_element(
                playList_batchState.list[i],
                i,
                playList_batchState.num
            )
            fragment.appendChild(element)
            playList_imageObserver.observe(element)
        }
        
        slide.appendChild(fragment)
        playList_batchState.currentIndex = endIndex
        
        // 更新色彩后滚动
        set_background_color()
        
        // 使用 requestAnimationFrame 确保 DOM 更新后再滚动
        requestAnimationFrame(() => {
            const newTarget = document.getElementById(index.toString())
            if (newTarget) {
                newTarget.scrollIntoView({ behavior: 'smooth', block: 'center' })
            }
        })
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

// 更新所有歌曲（优化版）
function update_playing_songs(data, num) {

    console.log('update_playing_songs 被调用, data:', data, 'num:', num)

    // 载入缓存
    playing_index = num

    // 判断是否需要重新渲染列表
    if (data && data.length !== 0) {

        console.log('开始渲染列表, 长度:', data.length)

        // 载入缓存
        all_songs = data.length

        // 清空现有内容
        slide.innerHTML = ''

        // 停止之前观察器
        if (playList_imageObserver) {
            playList_imageObserver.disconnect()
        }

        // 移除之前的滚动监听
        const container = document.querySelector('.slide_frame')
        container.removeEventListener('scroll', playList_handle_scroll)

        // 初始化观察器
        playList_init_image_observer()

        // 重置分批渲染状态
        playList_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false,
            num: num
        }

        // 注册滚动监听
        container.addEventListener('scroll', playList_handle_scroll)

        // 如果目标歌曲不在第一批，需要渲染到目标位置
        if (num >= PLAYLIST_BATCH_SIZE) {
            // 渲染到包含目标歌曲的批次
            const targetBatch = Math.ceil((num + 1) / PLAYLIST_BATCH_SIZE)
            for (let i = 0; i < targetBatch; i++) {
                playList_render_next_batch()
            }
        } else {
            // 渲染第一批
            playList_render_next_batch()
        }

        // 更新头显
        play_index_screen.innerText = `${playing_index + 1} / ${all_songs}`

        // 滚动到当前播放歌曲
        requestAnimationFrame(() => {
            scroll_to_song(num)
        })

    } else {
        console.log('数据为空或长度为0, 只更新高亮')
        // 只更新高亮色（不重新渲染列表）
        update_highlight(num)
        // 更新头显
        play_index_screen.innerText = `${playing_index + 1} / ${all_songs}`
        // 滚动到当前播放歌曲
        scroll_to_song(num)
    }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听 //
/////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 更新所有歌曲栏目
    if (func === 'update_playing_songs') {
        console.log('收到播放列表更新:', event.data.arg1, event.data.arg2)
        update_playing_songs(event.data.arg1, event.data.arg2)
    }

});