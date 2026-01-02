function set_meta(tmp) {
    // 设置名字
    title.innerText = tmp[0];
    checkAndSetupScrolling()
    // 设置标题
    page_play.contentWindow.postMessage({
        type: 'play_page_update_title', arg1: tmp[1]
    }, '*');
    // 设置艺术家（副标题）
    page_play.contentWindow.postMessage({
        type: 'play_page_update_sub_title', arg1: tmp[2]
    }, '*')


}

function set_meta_img(tmp) {
    // 设置图片
    page_play.contentWindow.postMessage({
        type: 'play_page_update_img', arg1: tmp
    }, '*')
    set_song_image(tmp)
}

function set_song_image(byteString) {
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
            meta_img.innerHTML = '';
            meta_img.appendChild(img);

            // 分析图片并设置模糊背景
            ark_music_set_background(img, blobUrl);

            // 使用完成后释放blob URL以节省内存
            img.onload = null; // 清除事件处理器
        };

        img.onerror = function() {
            // 加载失败，清空div并添加默认图片
            meta_img.innerHTML = '';
            const defaultImg = new Image();
            defaultImg.src = 'file/CD.png';
            meta_img.appendChild(defaultImg);
            // 释放失败的blob URL
            URL.revokeObjectURL(blobUrl);

            // 同时设置默认背景
            setBlurBackground('file/CD.png', 1.0, 1.2); // 使用默认的清新效果
            set_icon_color_white(255);
        };

        // 设置src
        img.src = blobUrl;

    } catch (error) {
        // 发生错误，添加默认图片
        meta_img.innerHTML = '';
        const defaultImg = new Image();
        defaultImg.src = 'file/CD.png';
        meta_img.appendChild(defaultImg);

        // 同时设置默认背景
        setBlurBackground('file/CD.png', 1.0, 1.2); // 使用默认的清新效果
        set_icon_color_white(255);
    }
}

// 分析图片并设置背景
function ark_music_set_background(img, blobUrl) {
    try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');

        const sampleSize = img.width;

        canvas.width = img.width;
        canvas.height = img.height;

        // 绘制缩放后的图片
        ctx.drawImage(img, 0, 0, sampleSize, sampleSize);

        // 获取像素数据
        const imageData = ctx.getImageData(0, 0, sampleSize, sampleSize);
        const data = imageData.data;

        let totalBrightness = 0;
        let pixelCount = 0;

        // 计算平均亮度
        for (let i = 0; i < data.length; i += 4) {
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];

            // 使用加权平均计算亮度 (ITU-R BT.709)
            const brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            totalBrightness += brightness;
            pixelCount++;
        }

        const avgBrightness = totalBrightness / pixelCount;

        // 根据平均亮度计算调整参数
        let brightnessAdjust = 1.0; // 默认亮度
        let saturationAdjust = 1.2; // 默认饱和度

        // 如果图片较暗，增加亮度
        if (avgBrightness < 80) {
            brightnessAdjust = 2;
            saturationAdjust = 1.3;
        } else if (avgBrightness < 120) {
            brightnessAdjust = 1.7;
            saturationAdjust = 1.2;
        } else if (avgBrightness > 180) {
            // 如果图片很亮，稍微降低亮度，增加饱和度
            brightnessAdjust = 1;
            saturationAdjust = 1.4;
        } else {
            // 中等亮度，使用适中的调整
            brightnessAdjust = 1.2;
            saturationAdjust = 1.3;
        }

        // 切换主题
        set_icon_color_white(avgBrightness);

        // 设置背景
        setBlurBackground(blobUrl, brightnessAdjust, saturationAdjust);

        // 清理canvas
        canvas.width = 0;
        canvas.height = 0;

    } catch (error) {
        console.error('分析图片时出错:', error);
        // 如果分析失败，使用默认设置
        setBlurBackground(blobUrl, 1.0, 1.2);
        set_icon_color_white(255);
    }
}

// 设置模糊背景（带渐变动画和色彩调整）
function setBlurBackground(imageSrc, brightness, saturation) {
    // 创建新背景图片元素
    const newBackgroundImg = document.createElement('img');
    newBackgroundImg.src = imageSrc;

    // 设置样式，包括动态的亮度和饱和度调整
    newBackgroundImg.style.position = 'absolute';
    newBackgroundImg.style.top = '0';
    newBackgroundImg.style.left = '0';
    newBackgroundImg.style.width = '100%';
    newBackgroundImg.style.height = '100%';
    newBackgroundImg.style.objectFit = 'cover';
    newBackgroundImg.style.filter = `blur(120px) brightness(${brightness}) saturate(${saturation})`;
    newBackgroundImg.style.opacity = '0'; // 初始透明
    newBackgroundImg.style.transition = 'opacity 1s ease-in-out'; // 渐变过渡

    // 当新图片加载完成后
    newBackgroundImg.onload = function() {
        // 如果容器中已有图片，先将它们透明度设为0
        const existingImgs = ark_music_background.querySelectorAll('img');
        existingImgs.forEach(img => {
            img.style.opacity = '0';
            // 在过渡结束后移除旧图片
            setTimeout(() => {
                if (img.parentNode === ark_music_background) {
                    ark_music_background.removeChild(img);
                }
            }, 1000); // 与过渡时间匹配
        });

        // 如果之前有旋转状态，保持这个状态
        const wasRotating = ark_music_background.classList.contains('rotating');

        // 将新图片添加到容器
        ark_music_background.appendChild(newBackgroundImg);

        // 如果之前在旋转，重新添加旋转类
        if (wasRotating) {
            ark_music_background.classList.add('rotating');
        }

        // 触发渐入动画
        setTimeout(() => {
            newBackgroundImg.style.opacity = '1';
        }, 10); // 短暂延迟确保样式应用

        newBackgroundImg.onload = null;
    };

    // 添加错误处理
    newBackgroundImg.onerror = function() {
        console.error('背景图片加载失败');
        newBackgroundImg.onerror = null;
    };
}

// 背景旋转
let ark_music_background_rotating = false;
let ark_music_background_rotation = 0;
let ark_music_background_rotation_start_time = 0;
let ark_music_background_rotation_accumulated = 0;
function startBackgroundRotation() {
    if (ark_music_background_rotating) return; // 如果已经在旋转，直接返回

    ark_music_background_rotating = true;

    // 移除暂停时的transform样式，应用CSS动画
    ark_music_background.style.animation = 'backgroundRotate 10s linear infinite';
    ark_music_background.style.animationPlayState = 'running';

    // 添加旋转类
    ark_music_background.classList.add('rotating');

    // 记录开始时间
    ark_music_background_rotation_start_time = Date.now();
}
function stopBackgroundRotation() {
    if (!ark_music_background_rotating) return; // 如果没有在旋转，直接返回

    ark_music_background_rotating = false;

    // 获取当前的旋转角度（通过计算时间差）
    const now = Date.now();
    const elapsed = (now - ark_music_background_rotation_start_time) / 1000; // 秒
    const rotationSinceStart = (elapsed / 10) * 360; // 10s是动画持续时间
    ark_music_background_rotation = ark_music_background_rotation_accumulated + rotationSinceStart;

    // 停止CSS动画
    ark_music_background.style.animationPlayState = 'paused';

    // 移除旋转类
    ark_music_background.classList.remove('rotating');

    // 应用当前的旋转角度（通过JavaScript设置transform）
    ark_music_background.style.transform = `rotate(${ark_music_background_rotation % 360}deg)`;

    // 记录累积的旋转角度
    ark_music_background_rotation_accumulated = ark_music_background_rotation;
}
