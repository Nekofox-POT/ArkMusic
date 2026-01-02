window.addEventListener('message', function(event) {
    if (event.data.type === 'play_page_update_title') {
        page_play_title.innerText = event.data.arg1;
    } else if (event.data.type === 'play_page_update_sub_title') {
        page_play_sub_title.innerText = event.data.arg1;
        title_and_sub_title_update_check();
    } else if (event.data.type === 'play_page_update_img') {
        page_play_set_song_image(event.data.arg1)
    }
}, false);

function page_play_set_song_image(byteString) {
    try {
        // 将数字数组字符串转换回字符，得到外层的base64
        let byteArrayStr = byteString.replace(/[\[\]]/g, '');
        let byteNumbers = byteArrayStr.split(',').map(num => parseInt(num.trim()));

        // 将数字数组转换回base64字符串
        let outerBase64 = '';
        for (let i = 0; i < byteNumbers.length; i++) {
            outerBase64 += String.fromCharCode(byteNumbers[i]);
        }

        // 解码外层base64，得到真正的Data URL定义
        let innerContent = atob(outerBase64);

        // 分离MIME类型和数字数组部分
        let [mimeTypePartWithBase64, numbersPart] = innerContent.split(';base64,');
        let mimeType = mimeTypePartWithBase64.replace(';base64', '');

        // 将数字字符串转换回真正的base64
        let numberArray = numbersPart.split(',').map(num => parseInt(num.trim()));
        let realBase64 = '';
        for (let i = 0; i < numberArray.length; i++) {
            realBase64 += String.fromCharCode(numberArray[i]);
        }

        // 解码base64为二进制数据
        let binaryData = atob(realBase64);

        // 转换为Uint8Array
        let uint8Array = new Uint8Array(binaryData.length);
        for (let i = 0; i < binaryData.length; i++) {
            uint8Array[i] = binaryData.charCodeAt(i);
        }

        // 创建Blob对象
        let blob = new Blob([uint8Array], { type: mimeType });
        let blobUrl = URL.createObjectURL(blob);

        const img = new Image();

        img.onload = function() {
            // 加载成功，清空div并添加新图片
            page_play_meta_img.innerHTML = '';
            page_play_meta_img.appendChild(img);
            // 使用完成后释放blob URL以节省内存
            img.onload = null; // 清除事件处理器
        };

        img.onerror = function() {
            // 加载失败，清空div并添加默认图片
            page_play_meta_img.innerHTML = '';
            const defaultImg = new Image();
            defaultImg.src = 'file/CD.png';
            page_play_meta_img.appendChild(defaultImg);
            // 释放失败的blob URL
            URL.revokeObjectURL(blobUrl);
        };

        // 设置src
        img.src = blobUrl;

    } catch (error) {
        // 发生错误，添加默认图片
        page_play_meta_img.innerHTML = '';
        const defaultImg = new Image();
        defaultImg.src = 'file/CD.png';
        page_play_meta_img.appendChild(defaultImg);
    }
}