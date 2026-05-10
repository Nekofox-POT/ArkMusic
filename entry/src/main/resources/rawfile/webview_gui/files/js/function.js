//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 类型 //
/////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 歌曲详情按钮 //
///////////////
function song_detail_click(path, index) {
    console.log('详情按钮点击:', path, index)
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