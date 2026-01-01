function files_get_all_songs() {
    // 绑定元素
    const options_list = document.getElementById('all_music_options_list')
    let htmltext = ''

    let tmp = arkts.get_songs("get_all_songs");
        if (tmp.length !== 0) {
            for (const row of tmp) {
                htmltext += `<button class="list_button" id="${row[0]}" onclick="arkts.play_songs(this.id, 'all_songs'); page_switch();"><img src="file/song.svg"><div><p>${row[1]}</p></div></button>`
            }
        }
    // 修改元素
    options_list.innerHTML = htmltext;
}

window.addEventListener('message', function(event) {
    if (event.data.type === 'files_get_all_songs') {
        files_get_all_songs()
    }
}, false);