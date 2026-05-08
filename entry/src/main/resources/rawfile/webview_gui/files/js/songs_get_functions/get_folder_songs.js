////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取文件夹模式的歌曲 //
////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let folder_imageObserver = null

// 从路径提取文件名
function extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 初始化懒加载观察器（元数据 + 图片）
function folder_init_image_observer() {
    if (folder_imageObserver) return

    folder_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const path = element.dataset.path
                const p = element.querySelector('p')
                const imgDiv = element.querySelector('div')

                if (path) {
                    // 异步获取元数据
                    ark.get_song_meta(path).then(meta => {
                        if (meta[0] && meta[0][0]) {
                            p.textContent = meta[0][0]
                        }
                    })
                    // 异步获取图片
                    ark.get_song_image(path).then(img => {
                        if (img) {
                            imgDiv.style.backgroundImage = `url(${img})`
                        }
                    })
                    element.dataset.path = '' // 清除标记，避免重复加载
                }

                folder_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_folder_songs(path = '') {

    // 初始化环境
    const slide = document.querySelector('#folder_frame .slide')
    slide.innerHTML = ''

    // 停止之前观察器
    if (folder_imageObserver) {
        folder_imageObserver.disconnect()
    }

    // 初始化观察器
    folder_init_image_observer()

    // 获取数据 [文件夹列表, 歌曲路径列表]
    const data = ark.get_folder_songs(path)
    const folderList = data[0]  // 文件夹名称数组
    const songsList = data[1]   // 歌曲路径数组

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    // 处理文件夹
    for (const folderName of folderList) {
        const div = create_folder_element(folderName)
        fragment.appendChild(div)
    }

    // 处理歌曲
    for (let i = 0; i < songsList.length; i++) {
        const songPath = songsList[i]

        // 创建元素
        const div = document.createElement('div')
        div.dataset.path = songPath
        div.addEventListener('click', () => { ark.play_song(i) })

        // 创建图片容器
        const imgDiv = document.createElement('div')

        // 创建文本
        const p = document.createElement('p')
        p.className = 'font_color'
        p.style.color = background_color
        p.textContent = extract_filename(songPath)

        // 组装元素
        div.appendChild(imgDiv)
        div.appendChild(p)
        fragment.appendChild(div)

        // 注册懒加载观察
        folder_imageObserver.observe(div)
    }

    // 一次性添加所有元素
    slide.appendChild(fragment)

    // 更新色彩
    set_background_color()

}
