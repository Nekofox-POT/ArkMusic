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

// 创建歌曲元素
function folder_create_song_element(path, index) {
    const wrapper = document.createElement('div')
    wrapper.dataset.path = path
    wrapper.style.cssText = 'height:62px;margin-bottom:3px;display:flex;'

    const mainArea = document.createElement('div')
    mainArea.className = 'song_main'
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:12.5px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;'
    mainArea.addEventListener('click', () => { ark.play_song(index) })

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

////////////////////////////////////////////////////////////////////////////////
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
        const element = folder_create_song_element(songsList[i], i)
        fragment.appendChild(element)
        folder_imageObserver.observe(element)
    }

    // 一次性添加所有元素
    slide.appendChild(fragment)

    // 更新色彩
    set_background_color()

}
