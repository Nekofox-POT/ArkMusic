////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取播放列表模式的歌曲 //
//////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let playlist_imageObserver = null

// 从路径提取文件名
function extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 初始化懒加载观察器（元数据 + 图片）
function playlist_init_image_observer() {
    if (playlist_imageObserver) return

    playlist_imageObserver = new IntersectionObserver((entries) => {
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

                playlist_imageObserver.unobserve(element)
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
const PLAYLIST_BATCH_SIZE = 200

// 分批渲染状态
let playlist_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

// 创建歌单元素
function playlist_create_list_element(name) {
    const div = document.createElement('div')

    // 点击事件
    div.addEventListener('click', () => {
        play_list_backup = name
        get_play_list_songs(name)
    })

    // 创建图标容器
    const imgDiv = document.createElement('div')
    imgDiv.style.borderRadius = '50%'
    imgDiv.style.backgroundImage = 'none'
    imgDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 1024 1024" style="width: 100%; height: 100%;"><rect width="24" height="24" opacity="0"></rect><path class="svg_color" d="M0,0H1024V1024H0ZM501.12,420.48a28.153,28.153,0,0,0,20.16-8.32q8.64-8.32,8.64-19.2t-8.64-19.2a28.153,28.153,0,0,0-20.16-8.32H329.92a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h171.2M529.92,512q0-10.88-8.64-19.2a28.153,28.153,0,0,0-20.16-8.32H329.92a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h171.2a28.153,28.153,0,0,0,20.16-8.32q8.64-8.32,8.64-19.2m-200,91.52a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h91.2a27.086,27.086,0,0,0,19.84-8.32q8.32-8.32,8.32-19.2t-8.32-19.2a27.086,27.086,0,0,0-19.84-8.32h-91.2M667.52,371.2q-15.36,1.28-24.96,12.16T633.6,409.6l.64,34.56V569.6a14.248,14.248,0,0,1-1.28,6.4,20.057,20.057,0,0,1-3.84,5.12q-5.76,5.12-24.96,13.12l-1.6.64q-25.92,9.6-42.56,22.08t-24.96,34.56a60.092,60.092,0,0,0-2.56,30.08,55.415,55.415,0,0,0,12.16,26.88q12.8,15.36,33.92,21.12t39.04,3.2q41.6-5.12,57.6-32.64a115.231,115.231,0,0,0,16-58.88V456.96q.64-5.76,3.2-8.32a38.831,38.831,0,0,1,8.32-5.76q7.68-4.48,16.96-9.92,18.24-11.52,24-26.88t-1.28-34.24l-74.88-.64M610.56,689.92a43.215,43.215,0,0,1-16-.96,21.139,21.139,0,0,1-10.88-7.36,16.836,16.836,0,0,1-2.56-6.4,16.154,16.154,0,0,1,.64-7.68q2.56-8.32,11.84-14.08t25.28-12.16l.96-.64,3.2-1.28q5.44-2.56,10.56-4.48a43.889,43.889,0,0,0,8.96-4.48v17.28a63.325,63.325,0,0,1-5.76,26.24Q631.04,686.72,610.56,689.92Z" fill-rule="evenodd"/></svg>'

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
function playlist_create_song_element(path, index) {
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
function playlist_render_next_batch() {
    if (playlist_batchState.isRendering) return
    if (playlist_batchState.currentIndex >= playlist_batchState.list.length) return

    playlist_batchState.isRendering = true

    const slide = document.querySelector('#playlist_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        playlist_batchState.currentIndex + PLAYLIST_BATCH_SIZE,
        playlist_batchState.list.length
    )

    for (let i = playlist_batchState.currentIndex; i < endIndex; i++) {
        const element = playlist_create_song_element(
            playlist_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        playlist_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    playlist_batchState.currentIndex = endIndex
    playlist_batchState.isRendering = false

    // 更新色彩
    set_background_color()

    // 渲染完成后检查：如果内容不足以填满容器，继续加载
    requestAnimationFrame(() => {
        playlist_check_and_fill()
    })
}

// 检查是否需要继续填充内容
function playlist_check_and_fill() {
    const container = document.querySelector('#playlist_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = playlist_batchState.currentIndex < playlist_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        playlist_render_next_batch()
    }
}

// 滚动监听 - 滚动到底部时加载更多
function playlist_handle_scroll() {
    const container = document.querySelector('#playlist_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        playlist_batchState.currentIndex < playlist_batchState.list.length) {
        playlist_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_play_list_songs(name) {

    // 初始化环境
    const slide = document.querySelector('#playlist_frame .slide')
    slide.innerHTML = ''

    // 停止之前的观察器和滚动监听
    if (playlist_imageObserver) {
        playlist_imageObserver.disconnect()
    }

    const container = document.querySelector('#playlist_frame')
    container.removeEventListener('scroll', playlist_handle_scroll)

    // 初始化观察器
    playlist_init_image_observer()

    // 获取数据
    const data = ark.get_play_list_songs(name)

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    if (!name) {
        // 歌单列表模式：data 是歌单名称数组
        for (const listName of data) {
            const div = playlist_create_list_element(listName)
            fragment.appendChild(div)
        }
        slide.appendChild(fragment)
    } else {
        // 歌曲列表模式：data 是歌曲路径数组
        // 重置分批渲染状态
        playlist_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        // 注册滚动监听
        container.addEventListener('scroll', playlist_handle_scroll)

        // 渲染第一批
        playlist_render_next_batch()
    }

    // 更新色彩
    set_background_color()

}
