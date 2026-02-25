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