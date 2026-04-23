//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 更新函数 //
/////////////

// 更新所有歌曲 //
async function update_all_songs(data) {
    const slide = document.querySelector('#all_song_frame .slide')

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

        // 点击事件
        div.addEventListener('click', () => {
            ark.play_with_all_songs(index)
            console.log(index)
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
// 上级监听 //
/////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 更新所有歌曲栏目
    if (func === 'update_all_songs') {
        update_all_songs(event.data.arg1)
    }

});
