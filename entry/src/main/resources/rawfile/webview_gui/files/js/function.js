//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

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