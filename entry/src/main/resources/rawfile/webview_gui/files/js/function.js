//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取播放列表模式的歌曲 //
///////////////////////

// 创建播放列表元素
function create_playlist_element(playlistData) {
    const div = document.createElement('div')

    // 点击事件
    div.addEventListener('click', () => {
        play_list_backup = playlistData
        get_play_list_songs(playlistData)
    })

    // 创建图标容器
    const imgDiv = document.createElement('div')
    imgDiv.style.borderRadius = '50%'
    imgDiv.style.backgroundImage = 'none'
    imgDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 1024 1024" style="width: 100%; height: 100%;"><rect width="24" height="24" opacity="0"></rect><path class="svg_color" d="M0,0H1024V1024H0ZM501.12,420.48a28.153,28.153,0,0,0,20.16-8.32q8.64-8.32,8.64-19.2t-8.64-19.2a28.153,28.153,0,0,0-20.16-8.32H329.92a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h171.2M529.92,512q0-10.88-8.64-19.2a28.153,28.153,0,0,0-20.16-8.32H329.92a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h171.2a28.153,28.153,0,0,0,20.16-8.32q8.64-8.32,8.64-19.2m-200,91.52a28.153,28.153,0,0,0-20.16,8.32q-8.64,8.32-8.64,19.2t8.64,19.2a28.153,28.153,0,0,0,20.16,8.32h91.2a27.086,27.086,0,0,0,19.84-8.32q8.32-8.32,8.32-19.2t-8.32-19.2a27.086,27.086,0,0,0-19.84-8.32h-91.2M667.52,371.2q-15.36,1.28-24.96,12.16T633.6,409.6l.64,34.56V569.6a14.248,14.248,0,0,1-1.28,6.4,20.057,20.057,0,0,1-3.84,5.12q-5.76,5.12-24.96,13.12l-1.6.64q-25.92,9.6-42.56,22.08t-24.96,34.56a60.092,60.092,0,0,0-2.56,30.08,55.415,55.415,0,0,0,12.16,26.88q12.8,15.36,33.92,21.12t39.04,3.2q41.6-5.12,57.6-32.64a115.231,115.231,0,0,0,16-58.88V456.96q.64-5.76,3.2-8.32a38.831,38.831,0,0,1,8.32-5.76q7.68-4.48,16.96-9.92,18.24-11.52,24-26.88t-1.28-34.24l-74.88-.64M610.56,689.92a43.215,43.215,0,0,1-16-.96,21.139,21.139,0,0,1-10.88-7.36,16.836,16.836,0,0,1-2.56-6.4,16.154,16.154,0,0,1,.64-7.68q2.56-8.32,11.84-14.08t25.28-12.16l.96-.64,3.2-1.28q5.44-2.56,10.56-4.48a43.889,43.889,0,0,0,8.96-4.48v17.28a63.325,63.325,0,0,1-5.76,26.24Q631.04,686.72,610.56,689.92Z" fill-rule="evenodd"/></svg>'

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = playlistData

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return div
}

// 创建播放列表歌曲元素
function create_playlist_song_element(tmp, index) {
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
        ark.play_with_play_list_mode(play_list_backup, index)
    })

    // 创建图片容器
    const imgDiv = document.createElement('div')
    imgDiv.dataset.imgPath = tmp[8] // 存储图片路径供懒加载使用

    // 创建文本
    const p = document.createElement('p')
    p.className = 'font_color'
    p.style.color = background_color
    p.textContent = tmp[1]

    // 组装元素
    div.appendChild(imgDiv)
    div.appendChild(p)

    return { div, imgDiv }
}

function get_play_list_songs(name) {

    // 初始化环境
    const slide = document.querySelector('#playlist_frame .slide')
    slide.innerHTML = ''

    // 获取歌曲
    let data = ark.get_play_list_songs(name)

    // 使用 DocumentFragment 减少DOM重绘
    const fragment = document.createDocumentFragment()

    // 收集所有图片元素
    const imgElements = []

    if (name === '') {
        console.log('文件夹模式')
        // 列表模式：data 是 [['歌单1'], ['歌单2'], ['歌单3']]
        for (const i of data) {
            const div = create_playlist_element(i)
            fragment.appendChild(div)
        }
    } else {
        console.log('歌曲模式')
        // 歌曲模式：data 是正常的音乐列表数组
        for (let i = 0; i < data.length; i++) {
            const { div, imgDiv } = create_playlist_song_element(data[i], i)
            fragment.appendChild(div)
            imgElements.push(imgDiv)
        }
    }

    // 一次性添加所有元素
    slide.appendChild(fragment)

    // 启动懒加载（仅歌曲模式）
    if (name !== '' && imgElements.length > 0) {
        folder_start_lazy_loading(imgElements)
    }

    // 更新色彩
    set_background_color()

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 菜单回滚 //
////////////
function router_back() {

    // 分类定制 //
    if (page === '所有歌曲') {
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
            get_play_list_songs('')
        }
    }

}