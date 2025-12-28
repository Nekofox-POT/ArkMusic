document.addEventListener('DOMContentLoaded', () => {

    const local_list = document.getElementById('local_list');
    
    // 绑定local_add按钮
    document.getElementById('local_add').addEventListener('click', async () => {
        await arkts.local_add();
        tmp = arkts.get_storage_audio();
        // 遍历添加歌单
        let htmlContent = '';
        for (const i of tmp) {
            console.log(i);
            htmlContent += `<button><img src="img/song.svg"><p>${i}</p></button>`;
        }
        local_list.innerHTML = htmlContent;
    });

});