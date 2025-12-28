document.addEventListener('DOMContentLoaded', () => {

    const taskbar = document.querySelector('.taskbar');
    const song_bar = document.querySelector('.song_bar');
    const pageContainer = document.querySelector('.page');
    const btn_back = document.querySelectorAll('[id="back"]');
    const favourite_list = document.getElementById('favourite_list');
    const local_list = document.getElementById('local_list');
    
    // 初始
    slider.style.left = '0vw';

    // 点击音乐栏左半边
    song_bar.addEventListener('click', function(e) {
        // 计算点击位置
        const rect = song_bar.getBoundingClientRect();
        const clickX = e.clientX - rect.left;
        const song_barWidth = rect.width;
        
        // 如果点击在左半边
        if (clickX < song_barWidth / 2) {
            // 获取歌单
            let tmp = Object.values(arkts.get_storage_audio());
            // 遍历添加歌单
            let htmlContent = '';
            for (const i of tmp) {
                console.log(i);
                htmlContent += `<button><img src="img/song.svg"><p>${i}</p></button>`;
            }
            local_list.innerHTML = htmlContent;
            // 切换
            pageContainer.className = 'page local-active';
        } else {
            // 否则点击在右半边
            // 获取歌单
            let tmp = Object.values(arkts.get_example_audio());
            tmp.length = tmp.length - 1;
            // 遍历添加歌单
            let htmlContent = '';
            for (const i of tmp) {
                htmlContent += `<button><img src="img/song.svg"><p>${i}</p></button>`;
            }
            favourite_list.innerHTML = htmlContent;
            // 切换
            pageContainer.className = 'page favourite-active';
        }
    });

    // 点击任务栏左半边
    taskbar.addEventListener('click', function(e) {
        // 计算点击位置
        const rect = taskbar.getBoundingClientRect();
        const clickX = e.clientX - rect.left;
        const taskbarWidth = rect.width;
        
        // 如果点击在左半边
        if (clickX < taskbarWidth / 2) {
            // 滑块移动到播放图标位置（左半边）
            slider.style.left = '0vw';
            pageContainer.className = 'page play-active';
        } else {
            // 否则点击在右半边
            // 滑块移动到个人中心图标位置（右半边）
            slider.style.left = '45vw';
            pageContainer.className = 'page owner-active';
        }
    }); 

    // 返回按钮
    // 为每个匹配的元素添加事件监听器
    btn_back.forEach(button => {
        button.addEventListener('click', function() {
            const pageContainer = document.querySelector('.page'); // 获取页面容器
            if (pageContainer) {
                pageContainer.className = 'page owner-active';
            }
        });
    });
});