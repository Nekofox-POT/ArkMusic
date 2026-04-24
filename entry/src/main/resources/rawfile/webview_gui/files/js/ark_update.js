//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 配置常量 //
/////////////

const BATCH_SIZE = 20 // 每批渲染的元素数量

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let imageObserver = null

// 初始化图片懒加载观察器
function init_image_observer() {
    if (imageObserver) return // 避免重复创建

    imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const imgDiv = entry.target
                const imgPath = imgDiv.dataset.imgPath

                if (imgPath) {
                    get_song_image(imgDiv, imgPath)
                    imgDiv.dataset.imgPath = '' // 清除标记，避免重复加载
                }

                // 停止观察已加载的元素
                imageObserver.unobserve(imgDiv)
            }
        })
    }, {
        rootMargin: '100px' // 提前100px开始加载
    })
}

// 异步更新图片
async function get_song_image(img, path) {
    const tmp_img = await ark.get_song_image(path)
    if (tmp_img) {
        img.style.backgroundImage = `url(${tmp_img})`
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更新函数 //
////////////

// 创建单个歌曲元素
function create_song_element(tmp, index) {
    // tmp[0] = path (路径)
    // tmp[1] = name (文件名)
    // tmp[2] = song_title (歌曲标题)
    // tmp[3] = song_artist (艺术家)
    // tmp[4] = album (专辑)
    // tmp[5] = album_artist (专辑艺术家)
    // tmp[6] = author (作者)
    // tmp[7] = composer (作曲家)
    // tmp[8] = img_path (图片路径)
    // tmp[9] = sample_rate (采样率)

    // 创建元素
    const div = document.createElement('div')

    // 点击事件
    div.addEventListener('click', () => {
        ark.play_with_all_songs(index)
    })

    // 创建图片容器
    const imgDiv = document.createElement('div')
    imgDiv.dataset.imgPath = tmp[8] // 存储图片路径供懒加载使用

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.textContent = tmp[1]

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return { div, imgDiv }
}

// 分批渲染歌曲
function render_songs_batch(data, slide, startIndex, elements) {
    const endIndex = Math.min(startIndex + BATCH_SIZE, data.length)

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    for (let index = startIndex; index < endIndex; index++) {
        const { div, imgDiv } = create_song_element(data[index], index)
        fragment.appendChild(div)
        elements.push(imgDiv) // 收集图片元素用于后续观察
    }

    slide.appendChild(fragment)

    // 返回是否还有更多数据
    return endIndex < data.length
}

// 启动懒加载观察
function start_lazy_loading(elements) {
    // 初始化观察器
    init_image_observer()

    // 开始观察所有图片元素
    elements.forEach(imgDiv => {
        if (imgDiv.dataset.imgPath) {
            imageObserver.observe(imgDiv)
        }
    })
}

// 更新所有歌曲（优化版）
function update_all_songs(data) {
    const slide = document.querySelector('#all_song_frame .slide')

    // 清空现有内容
    slide.innerHTML = ''

    // 停止之前观察器对所有元素的关注
    if (imageObserver) {
        imageObserver.disconnect()
    }

    // 收集所有图片元素
    const imgElements = []

    // 当前渲染索引
    let currentIndex = 0

    // 分批渲染函数
    function render_next_batch() {
        const hasMore = render_songs_batch(data, slide, currentIndex, imgElements)
        currentIndex += BATCH_SIZE

        if (hasMore) {
            // 使用 requestAnimationFrame 继续渲染下一批
            requestAnimationFrame(render_next_batch)
        } else {
            // 所有元素渲染完成，启动懒加载
            start_lazy_loading(imgElements)
            // 更新色彩
            set_background_color()
        }
    }

    // 开始渲染
    render_next_batch()

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听 //
/////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 返回手势
    if (func === 'back_gesture') {router_back()}

    // 更新所有歌曲栏目
    if (func === 'update_all_songs') {
        update_all_songs(event.data.arg1)
    }

});
