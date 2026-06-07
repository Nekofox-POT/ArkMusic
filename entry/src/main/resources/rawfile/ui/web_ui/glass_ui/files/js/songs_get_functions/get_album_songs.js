////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取专辑的歌曲 //
//////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let album_imageObserver = null

function album_init_image_observer() {
    if (album_imageObserver) return

    album_imageObserver = new IntersectionObserver((entries) => {
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

                album_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

let album_list_imageObserver = null

function album_list_init_image_observer() {
    if (album_list_imageObserver) return

    album_list_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const albumName = element.dataset.albumName
                const imgDiv = element.querySelector('div')

                if (albumName) {
                    const songs = ark.get_album_songs(albumName)
                    if (songs && songs.length > 0) {
                        ark.get_image(songs[0]).then(img => {
                            if (img[0]) {
                                imgDiv.style.backgroundImage = `url(${img[1]})`
                            }
                        })
                    }
                    element.dataset.albumName = ''
                }

                album_list_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

const ALBUM_BATCH_SIZE = 200

let album_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let album_list_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let album_list_pendingScrollTop = -1

function album_create_list_element(name) {
    const div = document.createElement('div')
    div.dataset.albumName = name

    div.addEventListener('click', () => {
        album_backup = name
        get_album_list(name)
    })

    const imgDiv = document.createElement('div')
    imgDiv.style.borderRadius = '50%'
    imgDiv.style.backgroundImage = 'none'

    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = name

    div.appendChild(imgDiv)
    div.appendChild(p)

    return div
}

function album_create_song_element(path, index) {
    const wrapper = document.createElement('div')
    wrapper.dataset.path = path
    wrapper.style.cssText = 'height:62px;margin-bottom:3px;display:flex;'

    const mainArea = document.createElement('div')
    mainArea.className = 'song_main'
    mainArea.style.cssText = 'flex:1;display:flex;align-items:center;overflow:hidden;border-radius:12.5px;min-width:0;height:auto;background-image:none;box-shadow:none;margin-left:0;'
    mainArea.addEventListener('click', () => { ark.set_play_list(album_batchState.list, index) })

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

function album_list_render_next_batch() {
    if (album_list_batchState.isRendering) return
    if (album_list_batchState.currentIndex >= album_list_batchState.list.length) return

    album_list_batchState.isRendering = true

    const slide = document.querySelector('#album_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        album_list_batchState.currentIndex + ALBUM_BATCH_SIZE,
        album_list_batchState.list.length
    )

    for (let i = album_list_batchState.currentIndex; i < endIndex; i++) {
        const element = album_create_list_element(album_list_batchState.list[i])
        fragment.appendChild(element)
        album_list_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    album_list_batchState.currentIndex = endIndex
    album_list_batchState.isRendering = false

    set_background_color()

    album_list_restore_scroll()

    requestAnimationFrame(() => {
        album_list_check_and_fill()
    })
}

function album_list_restore_scroll() {
    if (album_list_pendingScrollTop < 0) return
    const scrollFrame = document.querySelector('#album_frame .slide_frame')
    if (!scrollFrame) return

    scrollFrame.scrollTop = album_list_pendingScrollTop
    if (scrollFrame.scrollTop >= album_list_pendingScrollTop) {
        album_list_pendingScrollTop = -1
    }
}

function album_list_check_and_fill() {
    const container = document.querySelector('#album_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMore = album_list_batchState.currentIndex < album_list_batchState.list.length

    if (hasMore && !hasScrollbar) {
        album_list_render_next_batch()
    }
}

function album_list_handle_scroll() {
    const container = document.querySelector('#album_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        album_list_batchState.currentIndex < album_list_batchState.list.length) {
        album_list_render_next_batch()
    }
}

function album_render_next_batch() {
    if (album_batchState.isRendering) return
    if (album_batchState.currentIndex >= album_batchState.list.length) return

    album_batchState.isRendering = true

    const slide = document.querySelector('#album_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        album_batchState.currentIndex + ALBUM_BATCH_SIZE,
        album_batchState.list.length
    )

    for (let i = album_batchState.currentIndex; i < endIndex; i++) {
        const element = album_create_song_element(
            album_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        album_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    album_batchState.currentIndex = endIndex
    album_batchState.isRendering = false

    set_background_color()

    requestAnimationFrame(() => {
        album_check_and_fill()
    })
}

function album_check_and_fill() {
    const container = document.querySelector('#album_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = album_batchState.currentIndex < album_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        album_render_next_batch()
    }
}

function album_handle_scroll() {
    const container = document.querySelector('#album_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        album_batchState.currentIndex < album_batchState.list.length) {
        album_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_album_list(name) {

    const slide = document.querySelector('#album_frame .slide')
    const container = document.querySelector('#album_frame')

    if (name) {
        const scrollFrame = document.querySelector('#album_frame .slide_frame')
        album_list_pendingScrollTop = scrollFrame ? scrollFrame.scrollTop : 0
    }

    slide.innerHTML = ''

    // 空状态：重置
    show_frame_empty('album_frame', false)

    if (album_imageObserver) {
        album_imageObserver.disconnect()
    }
    if (album_list_imageObserver) {
        album_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', album_handle_scroll)
    container.removeEventListener('scroll', album_list_handle_scroll)

    const data = ark.get_album_songs(name)

    // 空状态：检查
    if (data.length === 0) {
        show_frame_empty('album_frame', true)
        set_background_color()
        return
    }

    album_init_image_observer()
    album_list_init_image_observer()

    if (!name) {
        album_list_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', album_list_handle_scroll)

        album_list_render_next_batch()
    } else {
        album_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', album_handle_scroll)

        album_render_next_batch()
    }

    set_background_color()

}
