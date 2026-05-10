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
                const p = element.querySelector('p')
                const imgDiv = element.querySelector('div')

                if (path) {
                    ark.get_song_meta(path).then(meta => {
                        if (meta[1]) {
                            imgDiv.style.backgroundImage = `url(${meta[1]})`
                        }
                        if (meta[0][0] && meta[0][0][0]) {
                            p.textContent = meta[0][0][0]
                        }
                        element.dataset.path = ''
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
                    ark.get_meta_list_image('专辑', albumName).then(base64 => {
                        if (base64) {
                            imgDiv.style.backgroundImage = `url(${base64})`
                        }
                    })
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

    if (album_imageObserver) {
        album_imageObserver.disconnect()
    }
    if (album_list_imageObserver) {
        album_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', album_handle_scroll)
    container.removeEventListener('scroll', album_list_handle_scroll)

    album_init_image_observer()
    album_list_init_image_observer()

    const data = ark.get_album_list(name)

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
