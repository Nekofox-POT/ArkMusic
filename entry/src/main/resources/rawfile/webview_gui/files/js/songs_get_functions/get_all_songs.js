////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取所有歌曲 //
/////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 配置常量 //
/////////////

const ALL_SONGS_BATCH_SIZE = 20 // 每批渲染的元素数量

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let all_songs_imageObserver = null

// 初始化图片懒加载观察器
function all_songs_init_image_observer() {
    if (all_songs_imageObserver) return // 避免重复创建

    all_songs_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const imgDiv = entry.target
                const imgPath = imgDiv.dataset.imgPath

                if (imgPath) {
                    all_songs_get_song_image(imgDiv, imgPath)
                    imgDiv.dataset.imgPath = '' // 清除标记，避免重复加载
                }

                // 停止观察已加载的元素
                all_songs_imageObserver.unobserve(imgDiv)
            }
        })
    }, {
        rootMargin: '100px' // 提前100px开始加载
    })
}

// 异步更新图片
async function all_songs_get_song_image(img, path) {
    const tmp_img = await ark.get_song_image(path)
    if (tmp_img) {
        img.style.backgroundImage = `url(${tmp_img})`
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 元素创建 //
/////////////

// 从路径提取文件名
function extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    // 移除扩展名
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 创建单个歌曲元素（仅基础信息，不阻塞）
function create_all_songs_element(index, path) {
    // 从路径提取文件名作为初始显示
    const file_name = extract_filename(path)

    // 创建元素
    const div = document.createElement('div')

    // 点击事件
    div.addEventListener('click', () => {
        ark.play_song(index)
    })

    // 创建图片容器
    const imgDiv = document.createElement('div')
    imgDiv.dataset.imgPath = path // 存储图片路径供懒加载使用

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = file_name

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return { div, imgDiv, p }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

// 启动懒加载观察
function all_songs_start_lazy_loading(elements) {
    // 初始化观察器
    all_songs_init_image_observer()

    // 开始观察所有图片元素
    elements.forEach(imgDiv => {
        if (imgDiv.dataset.imgPath) {
            all_songs_imageObserver.observe(imgDiv)
        }
    })
}

// 分批渲染歌曲
function render_all_songs_batch(songsList, slide, startIndex, elements) {
    const endIndex = Math.min(startIndex + ALL_SONGS_BATCH_SIZE, songsList.length)

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    for (let index = startIndex; index < endIndex; index++) {
        const path = songsList[index]
        const { div, imgDiv } = create_all_songs_element(index, path)
        fragment.appendChild(div)
        elements.push(imgDiv) // 收集图片元素用于后续观察
    }

    slide.appendChild(fragment)

    // 返回是否还有更多数据
    return endIndex < songsList.length
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_all_songs() {

    // 初始化环境
    const slide = document.querySelector('#all_song_frame .slide')
    slide.innerHTML = ''

    // 停止之前观察器对所有元素的关注
    if (all_songs_imageObserver) {
        all_songs_imageObserver.disconnect()
    }

    // 获取歌曲路径列表
    const songsList = ark.get_all_songs()

    // 收集所有图片元素
    const imgElements = []

    // 当前渲染索引
    let currentIndex = 0

    // 分批渲染函数
    function render_next_batch() {
        const hasMore = render_all_songs_batch(songsList, slide, currentIndex, imgElements)
        currentIndex += ALL_SONGS_BATCH_SIZE

        if (hasMore) {
            // 使用 requestAnimationFrame 继续渲染下一批
            requestAnimationFrame(render_next_batch)
        } else {
            // 所有元素渲染完成，启动懒加载
            all_songs_start_lazy_loading(imgElements)
            // 更新色彩
            set_background_color()
        }
    }

    // 开始渲染
    render_next_batch()

}