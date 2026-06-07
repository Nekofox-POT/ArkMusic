//
// 函数池（播放器专用，UI交互型）
// 后端调用的更新函数（set_play_mode, set_like）已移至 update.js
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 音量更改 //
////////////
function set_vol(value = null) {
    if (value !== null) {
        vol_range.value = value
    }
    vol_range_show.style.left = `${(vol_range.value / vol_range.max * 150) - 150}px`
    vol_value.textContent = vol_range.value
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 封面转圈 //
////////////

// 变量 //
let meta_img_rotate_current_rotation = 0
// 为了让封面转速减慢一倍，这里从45度/秒改为22.5度/秒
let meta_img_rotate_rotation_speed = 22.5 // 每秒旋转22.5度，即16秒一圈
let meta_img_rotate_last_timestamp = null
let meta_img_rotate_animation_id = null
let meta_img_rotate_is_snapping = false

// 主函数 //
function set_meta_img_rotate(status) {
    if (status) {

        player_meta_img.classList.add('active')
        music_bar_meta_img.classList.add('active')
        meta_img_rotate_last_timestamp = performance.now()
        set_meta_img_rotate_play(status)

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
        music_bar_meta_img.style.transition = ''
        player_meta_img.style.transform = `rotate(${meta_img_rotate_current_rotation}deg)`
        music_bar_meta_img.style.transform = `rotate(${meta_img_rotate_current_rotation}deg)`
    }

    meta_img_rotate_animation_id = requestAnimationFrame(set_meta_img_rotate_play)

}

// 暂停旋转函数 //
function set_meta_img_rotate_pause() {
    meta_img_rotate_is_snapping = true

    // 找到最近的90度倍数
    const snapAngle = Math.round(meta_img_rotate_current_rotation / 360) * 360

    // 计算需要旋转的角度差
    const angleDiff = snapAngle - meta_img_rotate_current_rotation

    // 计算过渡时间（每90度需要0.5秒）
    const transitionTime = Math.abs(angleDiff) / 90 * 0.5

    // 设置过渡并归位
    player_meta_img.style.transition = `transform ${transitionTime}s cubic-bezier(0.4, 0, 0.2, 1)`
    music_bar_meta_img.style.transition = `transform ${transitionTime}s cubic-bezier(0.4, 0, 0.2, 1)`
    player_meta_img.style.transform = `rotate(${snapAngle}deg)`
    music_bar_meta_img.style.transform = `rotate(${snapAngle}deg)`

    // 更新当前角度
    meta_img_rotate_current_rotation = snapAngle

    // 过渡完成后清除标记并移除active类（变回默认圆角）
    setTimeout(() => {
        meta_img_rotate_is_snapping = false
        player_meta_img.style.transition = ''
        music_bar_meta_img.style.transition = ''
        // 如果在1000ms后play_status为true，则不执行这个计时器
        if (!play_status) {
            player_meta_img.classList.remove('active')
            music_bar_meta_img.classList.remove('active')
        }
    }, transitionTime * 1000)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 睡眠定时状态同步 //
/////////////////////

function set_sleep_timer_status(is_timed, timed, wait_end) {
    sleep_timer_is_active = is_timed
    sleep_timer_wait_end = wait_end
    if (is_timed) {
        // 定时中：图标显示激活色
        sleep_timer_icon.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.style.fill = active_color
            tmp.classList.add('svg_active_color')
        })
    } else {
        // 未定时：图标恢复默认色
        sleep_timer_icon.querySelectorAll('.svg_color').forEach(tmp => {
            tmp.style.fill = background_color
            tmp.classList.remove('svg_active_color')
        })
    }
}
