//
// 监听池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 触控件 //
///////////

////////////
// 变量池 //
/////////

//////////////
// 监听程序 //
/////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// slide滑动 //
//////////////

////////////
// 变量池 //
/////////

/////////////
// 监听程序 //
////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 四圆点滑动 //
//////////////

////////////
// 变量池 //
/////////
/////////////
// 监听程序 //
////////////

slide.addEventListener('touchstart', function(e) {
    const btn = e.target.closest('.song_item_detail_btn')
    if (!btn) return

    const songItem = btn.closest('.slide > div')
    if (!songItem) return

    if (e.touches.length === 1) {
        e.preventDefault()
        const touch = e.touches[0]
        startSwipe(songItem, touch.clientX, touch.clientY)
    }
}, { passive: false })

slide.addEventListener('touchmove', function(e) {
    if (!swipeState.isActive) return

    e.preventDefault()
    const touch = e.touches[0]
    updateSwipe(touch.clientX, touch.clientY)
}, { passive: false })

slide.addEventListener('touchend', function(e) {
    if (!swipeState.isActive) return
    endSwipe()
})

slide.addEventListener('touchcancel', function(e) {
    if (!swipeState.isActive) return
    cancelSwipe()
})

slide.addEventListener('mousedown', function(e) {
    const btn = e.target.closest('.song_item_detail_btn')
    if (!btn) return

    const songItem = btn.closest('.slide > div')
    if (!songItem) return

    e.preventDefault()
    startSwipe(songItem, e.clientX, e.clientY)
})

document.addEventListener('mousemove', function(e) {
    if (!swipeState.isActive) return

    e.preventDefault()
    updateSwipe(e.clientX, e.clientY)
})

document.addEventListener('mouseup', function(e) {
    if (!swipeState.isActive) return
    endSwipe()
})

slide.addEventListener('click', function(e) {
    if (swipeState.preventClick) {
        e.stopPropagation()
        e.preventDefault()
        swipeState.preventClick = false
    }
})
