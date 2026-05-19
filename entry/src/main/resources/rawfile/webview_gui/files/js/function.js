//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 歌曲详情按钮 //
///////////////
let detail_active = null

function song_detail_click(path, index, btnEl) {
    if (detail_active) {
        if (detail_active._sourceBtn === btnEl) {
            close_detail_panel()
            return
        }
        close_detail_panel()
    }

    const frame = btnEl.closest('.files_main_bar')

    const backdrop = document.createElement('div')
    backdrop.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;z-index:500;backdrop-filter:blur(10px);opacity:0;transition:opacity 0.3s ease;border-radius:25px;'
    backdrop.addEventListener('click', () => { close_detail_panel() })
    frame.appendChild(backdrop)

    const popup = document.createElement('div')
    popup.className = 'box_color'
    popup._sourceBtn = btnEl
    popup._backdrop = backdrop
    popup.style.cssText = 'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);z-index:501;width:260px;max-height:75%;overflow-y:auto;border-radius:20px;padding:24px 20px;display:flex;flex-direction:column;gap:6px;opacity:0;transition:opacity 0.3s ease;'

    const loading = document.createElement('p')
    loading.className = 'font_color'
    loading.textContent = '加载中...'
    loading.style.cssText = 'margin:0;text-align:center;font-size:0.85rem;'
    popup.appendChild(loading)

    frame.appendChild(popup)
    detail_active = popup

    requestAnimationFrame(() => {
        backdrop.style.opacity = '1'
        popup.style.opacity = '1'
    })

    // 异步加载元数据
    ark.get_song_meta(path).then(meta => {
        if (popup !== detail_active) return
        loading.remove()

        const title = document.createElement('p')
        title.className = 'font_color'
        title.textContent = meta[0][1][0] || extract_filename(path)
        title.style.cssText = 'font-size:1rem;font-weight:700;margin:0 0 12px 0;text-align:center;'

        const musicFields = [
            ['歌手', meta[0][1][1]],
            ['专辑', meta[0][1][2]],
            ['专辑作者', meta[0][1][3]],
            ['流派', meta[0][1][4]],
        ]
        const techFields = [
            ['文件名', meta[0][0][0]],
            ['类型', (meta[0][0][1] || '').toUpperCase()],
            ['声道', meta[0][0][2]],
            ['采样率', meta[0][0][3]],
            ['位深', meta[0][0][4]],
            ['码率', meta[0][0][5]],
            ['时长', meta[0][0][6]],
        ]

        popup.appendChild(title)

        for (const [label, value] of musicFields) {
            popup.appendChild(create_meta_row(label, value))
        }

        const sep = document.createElement('div')
        sep.style.cssText = 'height:1px;background:rgba(255,255,255,0.2);margin:2px 0;'
        popup.appendChild(sep)

        for (const [label, value] of techFields) {
            popup.appendChild(create_meta_row(label, value))
        }

        set_background_color()
    })
}

function create_meta_row(label, value) {
    const row = document.createElement('div')
    row.style.cssText = 'display:flex;justify-content:space-between;align-items:center;'
    const lbl = document.createElement('span')
    lbl.className = 'font_color'
    lbl.textContent = label
    lbl.style.cssText = 'font-size:0.8rem;font-weight:600;'
    const val = document.createElement('span')
    val.className = 'font_color'
    val.textContent = value || '-'
    val.style.cssText = 'font-size:0.75rem;text-align:right;max-width:60%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;'
    row.appendChild(lbl)
    row.appendChild(val)
    return row
}

function close_detail_panel() {
    if (!detail_active) return

    const popup = detail_active
    const backdrop = popup._backdrop
    detail_active = null

    backdrop.style.opacity = '0'
    popup.style.opacity = '0'
    popup.addEventListener('transitionend', () => {
        popup.remove()
        if (backdrop) backdrop.remove()
    })
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 详情盒子 //
/////////////
let files_detail_backdrop = null

function files_detail_active_open() {
    files_detail.classList.add('active')

    files_detail_backdrop = document.createElement('div')
    files_detail_backdrop.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:899;backdrop-filter:blur(10px);opacity:0;transition:opacity 0.3s ease;'
    files_detail_backdrop.addEventListener('click', () => {
        files_detail_active_close()
    })
    document.body.appendChild(files_detail_backdrop)

    requestAnimationFrame(() => {
        files_detail_backdrop.style.opacity = '1'
    })
}

function files_detail_active_close() {
    files_detail.classList.remove('active', 'editor')
    const editor = document.getElementById("files_detail_list_editor")
    if (editor) editor.style.display = 'none'
    files_detail_options.style.display = ''
    if (files_detail_backdrop) {
        files_detail_backdrop.style.opacity = '0'
        files_detail_backdrop.addEventListener('transitionend', () => {
            files_detail_backdrop.remove()
            files_detail_backdrop = null
        })
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 菜单回滚 //
////////////
function router_back() {

    // 详情盒子优先关闭
    if (files_detail.classList.contains('active')) {
        files_detail_active_close()
        return
    }

    // 详情弹窗优先关闭
    if (detail_active) {
        close_detail_panel()
        return
    }

    // 分类定制 //
    if (page === '所有歌曲') {
        ark.back_to_player()
    }
    else if (page === '外部歌曲') {
        ark.back_to_player()
    }
    else if (page === '文件夹') {
        for (let i of router_list) {
        }
        if (router_list.length !== 0) {
            router_list.pop()
            let tmp = ''
            for (const e of router_list) {
                tmp += e
                tmp += '/'
            }
            get_folder_songs(tmp)
        } else {
            ark.back_to_player()
        }
    }
    else if (page === '播放列表') {
        if (play_list_backup === '') {
            ark.back_to_player()
        } else {
            play_list_backup = ''
            get_play_list_songs(play_list_backup)
        }
    }
    else if (page === '我的喜欢') {
        ark.back_to_player()
    }
    else if (page === '歌手') {
        if (artist_composer_backup === '') {
            ark.back_to_player()
        } else {
            artist_composer_backup = ''
            get_artist_composer_list(artist_composer_backup)
        }
    }
    else if (page === '专辑') {
        if (album_backup === '') {
            ark.back_to_player()
        } else {
            album_backup = ''
            get_album_list(album_backup)
        }
    }
    else if (page === '专辑作者') {
        if (album_artist_backup === '') {
            ark.back_to_player()
        } else {
            album_artist_backup = ''
            get_album_artist_list(album_artist_backup)
        }
    }
    else if (page === '流派') {
        if (genre_backup === '') {
            ark.back_to_player()
        } else {
            genre_backup = ''
            get_genre_list(genre_backup)
        }
    }

}