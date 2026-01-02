// 在函数外部定义，用于追踪渲染状态
let isSongsRendered = false; 
let renderTaskId = null; 

function files_get_all_songs() {
    const options_list = document.getElementById('all_music_options_list');
    
    // 1. 如果已经渲染过了，直接跳过，不再重新生成 DOM
    // 除非你需要刷新列表（如果是刷新，请先将 isSongsRendered 设为 false）
    if (isSongsRendered) return;

    const songs = arkts.get_songs("get_all_songs");
    if (!songs || songs.length === 0) return;

    // 2. 如果之前有正在进行的渲染任务，先取消它，防止切回页面时多个任务并行
    if (renderTaskId) {
        cancelAnimationFrame(renderTaskId);
    }

    options_list.innerHTML = ''; // 清空
    const batchSize = 25;
    let currentIndex = 0;

    function renderStep() {
        const fragment = document.createDocumentFragment();
        const limit = Math.min(currentIndex + batchSize, songs.length);

        for (let i = currentIndex; i < limit; i++) {
            const row = songs[i];
            const btn = document.createElement('button');
            btn.className = "list_button";
            btn.id = row[0];
            // 使用事件委托的思路（可选），这里先保持你的逻辑
            btn.onclick = function() {
                arkts.play_songs(this.id, 'all_songs');
                page_switch();
            };
            btn.innerHTML = `<img src="file/song.svg"><div><p>${row[1]}</p></div>`;
            fragment.appendChild(btn);
        }

        options_list.appendChild(fragment);
        currentIndex += batchSize;

        if (currentIndex < songs.length) {
            renderTaskId = requestAnimationFrame(renderStep);
        } else {
            // 3. 渲染完成后标记状态
            isSongsRendered = true;
            renderTaskId = null;
        }
    }

    renderStep();
}

window.addEventListener('message', function(event) {
    if (event.data.type === 'files_get_all_songs') {
        files_get_all_songs()
    }
}, false);