//
// 函数池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 音量更改 //
////////////
function set_vol(value = null) {
    if (value !== null) {
        vol_range.value = value
    }
    console.log(vol_range.value)
    vol_range_show.style.width = `${vol_range.value / vol_range.max * 150}px`
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 播放方式更改 //
///////////////
function set_play_mode(value) {
    if (value === "play_only") {
        play_forlist_button.classList.add('hidden')
        play_order_button.classList.add('hidden')
        play_disorder_button.classList.add('hidden')
        play_only_button.classList.remove('hidden')
    } else if (value === "play_forlist") {
        play_only_button.classList.add('hidden')
        play_order_button.classList.add('hidden')
        play_disorder_button.classList.add('hidden')
        play_forlist_button.classList.remove('hidden')
    } else if (value === "play_order") {
        play_only_button.classList.add('hidden')
        play_forlist_button.classList.add('hidden')
        play_disorder_button.classList.add('hidden')
        play_order_button.classList.remove('hidden')
    } else if (value === "play_disorder") {
        play_only_button.classList.add('hidden')
        play_forlist_button.classList.add('hidden')
        play_order_button.classList.add('hidden')
        play_disorder_button.classList.remove('hidden')
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 喜欢的歌的更改 //
/////////////////
function set_like(value) {
    if (value) {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.classList.add('svg_active_color')
            tmp.style.fill = active_color
        })
        player_like_button.style.transition = 'transform 0.15s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        player_like_button.style.transform = 'scale(1.2)'
    } else {
        player_like_button.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.classList.remove('svg_active_color')
            tmp.style.fill = background_color
        })
        player_like_button.style.transition = 'transform 0.15s ease'
        player_like_button.style.transform = 'scale(0.8)'
    }
    setTimeout(() => {player_like_button.style.transform = 'scale(1)'}, 150)

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 封面转圈 //
////////////

// 变量 //
let meta_img_rotate_current_rotation = 0
let meta_img_rotate_rotation_speed = 45 // 每秒旋转45度，即8秒一圈
let meta_img_rotate_last_timestamp = null
let meta_img_rotate_animation_id = null
let meta_img_rotate_is_snapping = false

// 主函数 //
function set_meta_img_rotate() {
    if (play_status) {

        player_meta_img.classList.add('active')
        meta_img_rotate_last_timestamp = performance.now()
        set_meta_img_rotate_play(play_status)

    } else {

        if (meta_img_rotate_animation_id) {
            cancelAnimationFrame(meta_img_rotate_animation_id)
            meta_img_rotate_animation_id = null
        }
        // 归位到最近的90度倍数
        set_meta_img_rotate_pause()

    }
}

// 旋转函数 //
function set_meta_img_rotate_play() {
    const now = performance.now()
    const deltaTime = (now - meta_img_rotate_last_timestamp) / 1000 // 转换为秒
    meta_img_rotate_last_timestamp = now

    // 增加旋转角度（不使用 %360，让角度持续累积以避免跳变）
    meta_img_rotate_current_rotation = meta_img_rotate_current_rotation + meta_img_rotate_rotation_speed * deltaTime

    // 应用旋转（清除transition以避免与归位冲突）
    if (!meta_img_rotate_is_snapping) {
        player_meta_img.style.transition = ''
        player_meta_img.style.transform = `rotate(${meta_img_rotate_current_rotation}deg)`
    }

    meta_img_rotate_animation_id = requestAnimationFrame(set_meta_img_rotate_play)

}

// 暂停旋转函数 //
function set_meta_img_rotate_pause() {
    meta_img_rotate_is_snapping = true

    // 找到最近的90度倍数
    const snapAngle = Math.round(meta_img_rotate_current_rotation / 90) * 90

    // 计算需要旋转的角度差
    const angleDiff = snapAngle - meta_img_rotate_current_rotation

    // 计算过渡时间（每90度需要0.5秒）
    const transitionTime = Math.abs(angleDiff) / 90 * 0.5

    // 设置过渡并归位
    player_meta_img.style.transition = `transform ${transitionTime}s cubic-bezier(0.4, 0, 0.2, 1)`
    player_meta_img.style.transform = `rotate(${snapAngle}deg)`

    // 更新当前角度
    meta_img_rotate_current_rotation = snapAngle

    // 过渡完成后清除标记并移除active类（变回默认圆角）
    setTimeout(() => {
        meta_img_rotate_is_snapping = false
        player_meta_img.style.transition = ''
        player_meta_img.classList.remove('active')
    }, transitionTime * 1000)
}