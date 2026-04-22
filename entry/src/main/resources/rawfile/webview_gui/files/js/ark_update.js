//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 更新所有歌曲栏目
    if (func === 'update_all_songs') {

        Object.keys(frame_map).forEach(async key => {
            if (key === '所有歌曲') {
                const data = event.data.arg1
                for (tmp of data) {
                    // 更新元素
                    // <div><div></div><p class="font_color"> 所有歌曲</p></div> 这个是要更新的元素模板
                    // 第一步，p标签里填入tmp[1]
                    //
                    // 第二步，<div></div>更改背景图
                    // 这里会用ark获取图片的base64编码
                    // 返回的是完整的 "data:image/jpeg;base64,xxxx" 字符串
                    const tmp_img = await ark.get_song_image(tmp[8])
                    if (tmp_img) {
                        console.log('有数据')
                    }
                }
            }
        })
    }

});