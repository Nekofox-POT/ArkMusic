//
// 环境配置
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 组件绑定 //
/////////////
const choice_bar = document.querySelector(".choice_bar")
const choice_bar_scroll = document.getElementById("choice_bar_scroll")
const choice_bar_items = document.querySelectorAll(".choice_bar_item")

// 框架组件映射
const frame_map = {
    '所有歌曲': document.getElementById("all_song_frame"),
    '文件夹': document.getElementById("folder_frame"),
    '播放列表': document.getElementById("playlist_frame"),
    '我的喜欢': document.getElementById("favorite_frame"),
    '专辑': document.getElementById("album_frame"),
    '歌手': document.getElementById("artist_frame"),
    '播放最多': document.getElementById("most_played_frame")
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 变量配置 //
////////////