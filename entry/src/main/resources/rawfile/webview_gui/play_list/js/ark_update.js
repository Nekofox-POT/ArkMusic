//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更新函数 //
////////////

// 异步更新图片
async function get_song_image(img, path) {
    const tmp_img = await ark.get_song_image(path)
    if (tmp_img) {
        img.style.backgroundImage = `url(${tmp_img})`
    }
}

// 更新所有歌曲 //
function update_playing_songs(data, num) {

    // 载入缓存
    playing_index = num

    if (data.length !== 0) {

        // 载入缓存
        all_songs = data.length

        // 清空现有内容
        slide.innerHTML = ''

        // 遍历数据创建元素
        for (let index = 0; index < data.length; index++) {
            const tmp = data[index]
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
            div.className = 'box_color'
            div.id = index

            // 点击事件
            div.addEventListener('click', () => {
                ark.seek_song(index)
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
            get_song_image(imgDiv, tmp[8])

        }

    }

    // 更改高亮色
    // 高亮色根据num和id序号对应更改添加和移除font_active_color
    const items = slide.querySelectorAll('div.box_color')
    items.forEach(item => {
        const p = item.querySelector('p')
        if (p) {
            if (parseInt(item.id) === num) {
                p.className = 'font_color font_active_color'
            } else {
                p.className = 'font_color'
            }
        }
    })

    // 更新头显
    play_index_screen.innerText = `${playing_index + 1} / ${all_songs}`

    // 更新色彩
    set_background_color()

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听 //
/////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 更新所有歌曲栏目
    if (func === 'update_playing_songs') {
        update_playing_songs(event.data.arg1, event.data.arg2)
    }

});