//
// ark专属更新池
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 上级监听 //
/////////////
window.addEventListener('message', function(event) {

    func = event.data.action

    // 返回手势
    if (func === 'back_gesture') {router_back()}

    // 数据库更新，重新加载当前页面
    if (func === 'songs_update') {
        load_page(page)
    }

});
