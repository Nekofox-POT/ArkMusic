document.addEventListener('DOMContentLoaded', () => {
    
    // 获取元素
    const btn_play = document.getElementById('btn_play');

    btn_play.addEventListener('click', () => {
        arkts.song_play();
    });

});