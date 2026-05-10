////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取专辑作者的歌曲 //
//////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let album_artist_imageObserver = null

function album_artist_init_image_observer() {
    if (album_artist_imageObserver) return

    album_artist_imageObserver = new IntersectionObserver((entries) => {
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

                album_artist_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

let album_artist_list_imageObserver = null

function album_artist_list_init_image_observer() {
    if (album_artist_list_imageObserver) return

    album_artist_list_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const albumArtistName = element.dataset.albumArtistName
                const imgDiv = element.querySelector('div')

                if (albumArtistName) {
                    ark.get_meta_list_image('专辑作者', albumArtistName).then(base64 => {
                        if (base64) {
                            imgDiv.style.backgroundImage = `url(${base64})`
                        }
                    })
                    element.dataset.albumArtistName = ''
                }

                album_artist_list_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

const ALBUM_ARTIST_BATCH_SIZE = 200

let album_artist_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let album_artist_list_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let album_artist_list_pendingScrollTop = -1

function album_artist_create_list_element(name) {
    const div = document.createElement('div')
    div.dataset.albumArtistName = name

    div.addEventListener('click', () => {
        album_artist_backup = name
        get_album_artist_list(name)
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

function album_artist_create_song_element(path, index) {
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

function album_artist_list_render_next_batch() {
    if (album_artist_list_batchState.isRendering) return
    if (album_artist_list_batchState.currentIndex >= album_artist_list_batchState.list.length) return

    album_artist_list_batchState.isRendering = true

    const slide = document.querySelector('#album_artist_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        album_artist_list_batchState.currentIndex + ALBUM_ARTIST_BATCH_SIZE,
        album_artist_list_batchState.list.length
    )

    for (let i = album_artist_list_batchState.currentIndex; i < endIndex; i++) {
        const element = album_artist_create_list_element(album_artist_list_batchState.list[i])
        fragment.appendChild(element)
        album_artist_list_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    album_artist_list_batchState.currentIndex = endIndex
    album_artist_list_batchState.isRendering = false

    set_background_color()

    album_artist_list_restore_scroll()

    requestAnimationFrame(() => {
        album_artist_list_check_and_fill()
    })
}

function album_artist_list_restore_scroll() {
    if (album_artist_list_pendingScrollTop < 0) return
    const scrollFrame = document.querySelector('#album_artist_frame .slide_frame')
    if (!scrollFrame) return

    scrollFrame.scrollTop = album_artist_list_pendingScrollTop
    if (scrollFrame.scrollTop >= album_artist_list_pendingScrollTop) {
        album_artist_list_pendingScrollTop = -1
    }
}

function album_artist_list_check_and_fill() {
    const container = document.querySelector('#album_artist_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMore = album_artist_list_batchState.currentIndex < album_artist_list_batchState.list.length

    if (hasMore && !hasScrollbar) {
        album_artist_list_render_next_batch()
    }
}

function album_artist_list_handle_scroll() {
    const container = document.querySelector('#album_artist_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        album_artist_list_batchState.currentIndex < album_artist_list_batchState.list.length) {
        album_artist_list_render_next_batch()
    }
}

function album_artist_render_next_batch() {
    if (album_artist_batchState.isRendering) return
    if (album_artist_batchState.currentIndex >= album_artist_batchState.list.length) return

    album_artist_batchState.isRendering = true

    const slide = document.querySelector('#album_artist_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        album_artist_batchState.currentIndex + ALBUM_ARTIST_BATCH_SIZE,
        album_artist_batchState.list.length
    )

    for (let i = album_artist_batchState.currentIndex; i < endIndex; i++) {
        const element = album_artist_create_song_element(
            album_artist_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        album_artist_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    album_artist_batchState.currentIndex = endIndex
    album_artist_batchState.isRendering = false

    set_background_color()

    requestAnimationFrame(() => {
        album_artist_check_and_fill()
    })
}

function album_artist_check_and_fill() {
    const container = document.querySelector('#album_artist_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = album_artist_batchState.currentIndex < album_artist_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        album_artist_render_next_batch()
    }
}

function album_artist_handle_scroll() {
    const container = document.querySelector('#album_artist_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        album_artist_batchState.currentIndex < album_artist_batchState.list.length) {
        album_artist_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_album_artist_list(name) {

    const slide = document.querySelector('#album_artist_frame .slide')
    const container = document.querySelector('#album_artist_frame')

    if (name) {
        const scrollFrame = document.querySelector('#album_artist_frame .slide_frame')
        album_artist_list_pendingScrollTop = scrollFrame ? scrollFrame.scrollTop : 0
    }

    slide.innerHTML = ''

    if (album_artist_imageObserver) {
        album_artist_imageObserver.disconnect()
    }
    if (album_artist_list_imageObserver) {
        album_artist_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', album_artist_handle_scroll)
    container.removeEventListener('scroll', album_artist_list_handle_scroll)

    album_artist_init_image_observer()
    album_artist_list_init_image_observer()

    const data = ark.get_album_artist_list(name)

    if (!name) {
        album_artist_list_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', album_artist_list_handle_scroll)

        album_artist_list_render_next_batch()
    } else {
        album_artist_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', album_artist_handle_scroll)

        album_artist_render_next_batch()
    }

    set_background_color()

}
