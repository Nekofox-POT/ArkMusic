//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 获取文件夹模式的歌曲 //
/////////////////////
async function get_folder_songs(path = '') {

    // 初始化环境 //
    const slide = document.querySelector('#folder_frame .slide')
    slide.innerHTML = ''

    // 获取歌曲 //
    let data = ark.get_dir_songs(path)
    // 这里返回的是一个三维数组。

    // 处理文件夹 //
    for (const i of data[0]) {
        
        // 创建元素 //
        const div = document.createElement('div')

        // 点击事件 //
        div.addEventListener('click', () => {
            router_list.push(i[0])
            let tmp = ''
            for (const e of router_list) {
                tmp += e
                tmp += '/'
            }
            get_folder_songs(tmp)
        })

        // 创建图标容器 //
        const imgDiv = document.createElement('div')
        imgDiv.style.borderRadius = '50%'
        imgDiv.style.backgroundImage = 'none'
        imgDiv.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" style="width: 100%; height: 100%;"><rect width="24" height="24" opacity="0"></rect><path class="svg_color" d="M0,0H24V24H0ZM16.02,10.512a1.6,1.6,0,0,1,.456.12,1.181,1.181,0,0,1,.4.27,1.1,1.1,0,0,1,.252.438,1.379,1.379,0,0,1,.024.636q-.024.1-.1.474t-.168.87q-.1.492-.216,1.014t-.228.894a2.48,2.48,0,0,1-.174.444,1.66,1.66,0,0,1-.294.414,1.479,1.479,0,0,1-.432.306,1.384,1.384,0,0,1-.6.12H8.292A1.4,1.4,0,0,1,7.77,16.4a1.743,1.743,0,0,1-.5-.306,1.579,1.579,0,0,1-.372-.48,1.365,1.365,0,0,1-.144-.63V9.84a1.59,1.59,0,0,1,.4-1.146A1.471,1.471,0,0,1,8.268,8.28h5.9a1.6,1.6,0,0,1,.546.1,1.811,1.811,0,0,1,.51.282,1.546,1.546,0,0,1,.372.42.986.986,0,0,1,.144.516v.132H15.12q-.48,0-1.122-.006T12.63,9.72q-.726,0-1.356-.006t-1.086-.006H9.636a.613.613,0,0,0-.486.2,1.368,1.368,0,0,0-.27.522q-.1.348-.216.738t-.216.726q-.12.4-.24.768a.674.674,0,0,0-.024.156.471.471,0,0,0,.48.48q.372,0,.5-.468L9.8,10.5q1.56.012,2.856.012h3.36Z" fill-rule="evenodd"/></svg>'

        // 创建文本 //
        const p = document.createElement('p')
        p.className = 'font_color'
        p.textContent = i[0]

        // 组装元素 //
        div.appendChild(imgDiv)
        div.appendChild(p)

        // 添加到容器 //
        slide.appendChild(div)

    }

    // 处理歌曲 //
    for (let i = 0; i < data[1].length; i++) {

        const tmp = data[1][i]
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
            // ark.play_with_all_songs(index)
            let tmp = ''
            for (const e of router_list) {
                tmp += e
                tmp += '/'
            }
            ark.play_with_dir_mode(tmp, i)
        })

        // 创建图片容器
        const imgDiv = document.createElement('div')

        // 创建文本
        const p = document.createElement('p')
        p.className = 'font_color'
        p.textContent = tmp[1]

        // 组装元素
        div.appendChild(imgDiv)
        div.appendChild(p)

        // 添加到容器
        slide.appendChild(div)

        // 异步加载图片
        const tmp_img = await ark.get_song_image(tmp[8])
        if (tmp_img) {
            imgDiv.style.backgroundImage = `url(${tmp_img})`
        }

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
    } else if (page === '文件夹') {
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

}