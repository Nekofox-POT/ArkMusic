function switch_page(page = 1) {
    if (page === 3) {
        window.parent.postMessage({ type: 'files_get_all_songs' }, '*');
    }
    window.parent.postMessage({ type: 'page_switch', page: page }, '*');
}