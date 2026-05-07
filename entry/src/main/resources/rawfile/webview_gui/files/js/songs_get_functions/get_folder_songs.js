////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取文件夹模式的歌曲 //
////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 配置常量 //
/////////////

const FOLDER_BATCH_SIZE = 20 // 每批渲染的元素数量

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let folder_imageObserver = null

// 初始化图片懒加载观察器
function folder_init_image_observer() {
    if (folder_imageObserver) return // 避免重复创建

    folder_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const imgDiv = entry.target
                const imgPath = imgDiv.dataset.imgPath

                if (imgPath) {
                    folder_get_song_image(imgDiv, imgPath)
                    imgDiv.dataset.imgPath = '' // 清除标记，避免重复加载
                }

                // 停止观察已加载的元素
                folder_imageObserver.unobserve(imgDiv)
            }
        })
    }, {
        rootMargin: '100px' // 提前100px开始加载
    })
}

// 异步更新图片
async function folder_get_song_image(img, path) {
    const tmp_img = await ark.get_song_image(path)
    if (tmp_img) {
        img.style.backgroundImage = `url(${tmp_img})`
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 元素创建 //
/////////////

// 创建文件夹元素
function create_folder_element(folderName) {
    const div = document.createElement('div')

    // 点击事件
    div.addEventListener('click', () => {
        router_list.push(folderName)
        let tmp = ''
        for (const e of router_list) {
            tmp += e
            tmp += '/'
        }
        get_folder_songs(tmp)
    })

    // 创建图标容器
    const imgDiv = document.createElement('div')
    imgDiv.style.borderRadius = '50%'
    imgDiv.style.backgroundImage = 'none'
    imgDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="width: 100%; height: 100%;"><rect width="24" height="24" opacity="0"></rect><path class="svg_color" d="M0,0H24V24H0ZM16.02,10.512a1.6,1.6,0,0,1,.456.12,1.181,1.181,0,0,1,.4.27,1.1,1.1,0,0,1,.252.438,1.379,1.379,0,0,1,.024.636q-.024.1-.1.474t-.168.87q-.1.492-.216,1.014t-.228.894a2.48,2.48,0,0,1-.174.444,1.66,1.66,0,0,1-.294.414,1.479,1.479,0,0,1-.432.306,1.384,1.384,0,0,1-.6.12H8.292A1.4,1.4,0,0,1,7.77,16.4a1.743,1.743,0,0,1-.5-.306,1.579,1.579,0,0,1-.372-.48,1.365,1.365,0,0,1-.144-.63V9.84a1.59,1.59,0,0,1,.4-1.146A1.471,1.471,0,0,1,8.268,8.28h5.9a1.6,1.6,0,0,1,.546.1,1.811,1.811,0,0,1,.51.282,1.546,1.546,0,0,1,.372.42.986.986,0,0,1,.144.516v.132H15.12q-.48,0-1.122-.006T12.63,9.72q-.726,0-1.356-.006t-1.086-.006H9.636a.613.613,0,0,0-.486.2,1.368,1.368,0,0,0-.27.522q-.1.348-.216.738t-.216.726q-.12.4-.24.768a.674.674,0,0,0-.024.156.471.471,0,0,0,.48.48q.372,0,.5-.468L9.8,10.5q1.56.012,2.856.012h3.36Z" fill-rule="evenodd"/></svg>'

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = folderName

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return div
}

// 从路径提取文件名
function extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    // 移除扩展名
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 创建单个歌曲元素（仅基础信息，不阻塞）
function create_folder_song_element(index, path) {
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

    return { div, imgDiv }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

// 启动懒加载观察
function folder_start_lazy_loading(elements) {
    // 初始化观察器
    folder_init_image_observer()

    // 开始观察所有图片元素
    elements.forEach(imgDiv => {
        if (imgDiv.dataset.imgPath) {
            folder_imageObserver.observe(imgDiv)
        }
    })
}

// 分批渲染歌曲
function render_folder_songs_batch(songsList, slide, startIndex, elements) {
    const endIndex = Math.min(startIndex + FOLDER_BATCH_SIZE, songsList.length)

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    for (let index = startIndex; index < endIndex; index++) {
        const path = songsList[index]
        const meta = ark.get_song_meta(path)
        const { div, imgDiv } = create_folder_song_element(meta, index, path)
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

async function get_folder_songs(path = '') {

    // 初始化环境
    const slide = document.querySelector('#folder_frame .slide')
    slide.innerHTML = ''

    // 停止之前观察器对所有元素的关注
    if (folder_imageObserver) {
        folder_imageObserver.disconnect()
    }

    // 获取数据 [文件夹列表, 歌曲路径列表]
    const data = ark.get_folder_songs(path)
    const folderList = data[0]  // 文件夹名称数组
    const songsList = data[1]   // 歌曲路径数组

    // 收集所有图片元素
    const imgElements = []

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    // 处理文件夹
    for (const folderName of folderList) {
        const div = create_folder_element(folderName)
        fragment.appendChild(div)
    }

    // 处理歌曲
    for (let i = 0; i < songsList.length; i++) {
        const path = songsList[i]
        const { div, imgDiv } = create_folder_song_element(i, path)
        fragment.appendChild(div)
        imgElements.push(imgDiv)
    }

    // 一次性添加所有元素
    slide.appendChild(fragment)

    // 启动懒加载
    folder_start_lazy_loading(imgElements)

    // 更新色彩
    set_background_color()

}
