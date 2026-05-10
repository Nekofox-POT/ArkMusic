////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取流派的歌曲 //
//////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 懒加载观察器 //
/////////////////

let genre_imageObserver = null

function genre_init_image_observer() {
    if (genre_imageObserver) return

    genre_imageObserver = new IntersectionObserver((entries) => {
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

                genre_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

let genre_list_imageObserver = null

function genre_list_init_image_observer() {
    if (genre_list_imageObserver) return

    genre_list_imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const element = entry.target
                const genreName = element.dataset.genreName
                const imgDiv = element.querySelector('div')

                if (genreName) {
                    ark.get_meta_list_image('歌流派', genreName).then(base64 => {
                        if (base64) {
                            imgDiv.style.backgroundImage = `url(${base64})`
                        }
                    })
                    element.dataset.genreName = ''
                }

                genre_list_imageObserver.unobserve(element)
            }
        })
    }, {
        rootMargin: '100px'
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 分批渲染 //
/////////////

const GENRE_BATCH_SIZE = 200

let genre_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let genre_list_batchState = {
    list: [],
    currentIndex: 0,
    isRendering: false
}

let genre_list_pendingScrollTop = -1

function genre_create_list_element(name) {
    const div = document.createElement('div')
    div.dataset.genreName = name

    div.addEventListener('click', () => {
        genre_backup = name
        get_genre_list(name)
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

function genre_create_song_element(path, index) {
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

function genre_list_render_next_batch() {
    if (genre_list_batchState.isRendering) return
    if (genre_list_batchState.currentIndex >= genre_list_batchState.list.length) return

    genre_list_batchState.isRendering = true

    const slide = document.querySelector('#genre_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        genre_list_batchState.currentIndex + GENRE_BATCH_SIZE,
        genre_list_batchState.list.length
    )

    for (let i = genre_list_batchState.currentIndex; i < endIndex; i++) {
        const element = genre_create_list_element(genre_list_batchState.list[i])
        fragment.appendChild(element)
        genre_list_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    genre_list_batchState.currentIndex = endIndex
    genre_list_batchState.isRendering = false

    set_background_color()

    genre_list_restore_scroll()

    requestAnimationFrame(() => {
        genre_list_check_and_fill()
    })
}

function genre_list_restore_scroll() {
    if (genre_list_pendingScrollTop < 0) return
    const scrollFrame = document.querySelector('#genre_frame .slide_frame')
    if (!scrollFrame) return

    scrollFrame.scrollTop = genre_list_pendingScrollTop
    if (scrollFrame.scrollTop >= genre_list_pendingScrollTop) {
        genre_list_pendingScrollTop = -1
    }
}

function genre_list_check_and_fill() {
    const container = document.querySelector('#genre_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMore = genre_list_batchState.currentIndex < genre_list_batchState.list.length

    if (hasMore && !hasScrollbar) {
        genre_list_render_next_batch()
    }
}

function genre_list_handle_scroll() {
    const container = document.querySelector('#genre_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        genre_list_batchState.currentIndex < genre_list_batchState.list.length) {
        genre_list_render_next_batch()
    }
}

function genre_render_next_batch() {
    if (genre_batchState.isRendering) return
    if (genre_batchState.currentIndex >= genre_batchState.list.length) return

    genre_batchState.isRendering = true

    const slide = document.querySelector('#genre_frame .slide')
    const fragment = document.createDocumentFragment()

    const endIndex = Math.min(
        genre_batchState.currentIndex + GENRE_BATCH_SIZE,
        genre_batchState.list.length
    )

    for (let i = genre_batchState.currentIndex; i < endIndex; i++) {
        const element = genre_create_song_element(
            genre_batchState.list[i],
            i
        )
        fragment.appendChild(element)
        genre_imageObserver.observe(element)
    }

    slide.appendChild(fragment)
    genre_batchState.currentIndex = endIndex
    genre_batchState.isRendering = false

    set_background_color()

    requestAnimationFrame(() => {
        genre_check_and_fill()
    })
}

function genre_check_and_fill() {
    const container = document.querySelector('#genre_frame')
    if (!container) return

    const hasScrollbar = container.scrollHeight > container.clientHeight
    const hasMoreSongs = genre_batchState.currentIndex < genre_batchState.list.length

    if (hasMoreSongs && !hasScrollbar) {
        genre_render_next_batch()
    }
}

function genre_handle_scroll() {
    const container = document.querySelector('#genre_frame')
    if (!container) return

    const scrollBottom = container.scrollTop + container.clientHeight
    const threshold = container.scrollHeight - 500

    if (scrollBottom >= threshold &&
        genre_batchState.currentIndex < genre_batchState.list.length) {
        genre_render_next_batch()
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主函数 //
///////////

async function get_genre_list(name) {

    const slide = document.querySelector('#genre_frame .slide')
    const container = document.querySelector('#genre_frame')

    if (name) {
        const scrollFrame = document.querySelector('#genre_frame .slide_frame')
        genre_list_pendingScrollTop = scrollFrame ? scrollFrame.scrollTop : 0
    }

    slide.innerHTML = ''

    if (genre_imageObserver) {
        genre_imageObserver.disconnect()
    }
    if (genre_list_imageObserver) {
        genre_list_imageObserver.disconnect()
    }

    container.removeEventListener('scroll', genre_handle_scroll)
    container.removeEventListener('scroll', genre_list_handle_scroll)

    genre_init_image_observer()
    genre_list_init_image_observer()

    const data = ark.get_genre_list(name)

    if (!name) {
        genre_list_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', genre_list_handle_scroll)

        genre_list_render_next_batch()
    } else {
        genre_batchState = {
            list: data,
            currentIndex: 0,
            isRendering: false
        }

        container.addEventListener('scroll', genre_handle_scroll)

        genre_render_next_batch()
    }

    set_background_color()

}
