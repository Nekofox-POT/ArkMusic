////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取所有歌曲 //
/////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let all_songs_imageObserver = null

// 从路径提取文件名
function extract_filename(path) {
    const lastSlash = path.lastIndexOf('/')
    const fileName = lastSlash >= 0 ? path.substring(lastSlash + 1) : path
    const dotIndex = fileName.lastIndexOf('.')
    return dotIndex >= 0 ? fileName.substring(0, dotIndex) : fileName
}

// 初始化懒加载观察器（元数据 + 图片）
function all_songs_init_image_observer() {
    if (all_songs_imageObserver) return

    all_songs_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const path = element.dataset.path
                const p = element.querySelector('p')
                const imgDiv = element.querySelector('div')

                if (path) {
                    // 异步获取元数据
                    let meta = ark.get_song_meta(path)
                    if (meta[0] && meta[0][0]) {
                        p.textContent = meta[0][0]
                    }
                    // 异步获取图片
                    ark.get_song_image(path).then(img => {
                        if (img) {
                            imgDiv.style.backgroundImage = `url(${img})`
                        }
                    })
                    element.dataset.path = '' // 清除标记，避免重复加载
                }

                all_songs_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_all_songs() {

    // 初始化环境
    const slide = document.querySelector('#all_song_frame .slide')
    slide.innerHTML = ''

    // 停止之前观察器
    if (all_songs_imageObserver) {
        all_songs_imageObserver.disconnect()
    }

    // 初始化观察器
    all_songs_init_image_observer()

    // 获取歌曲路径列表
    const songsList = ark.get_all_songs()

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    for (let index = 0; index < songsList.length; index++) {
        const path = songsList[index]

        // 创建元素
        const div = document.createElement('div')
        div.dataset.path = path
        div.addEventListener('click', () => { ark.play_song(index) })

        // 创建图片容器
        const imgDiv = document.createElement('div')

        // 创建文本
        const p = document.createElement('p')
        p.className = 'font_color'
        p.style.color = background_color
        p.textContent = extract_filename(path)

        // 组装元素
        div.appendChild(imgDiv)
        div.appendChild(p)
        fragment.appendChild(div)

        // 注册懒加载观察
        all_songs_imageObserver.observe(div)
    }

    // 一次性添加所有元素
    slide.appendChild(fragment)

    // 更新色彩
    set_background_color()

}