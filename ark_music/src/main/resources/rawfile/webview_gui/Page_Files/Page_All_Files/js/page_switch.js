function page_switch(page = 1) {
    if (window.parent) {
        window.parent.postMessage({
            type: 'page_switch',
            page: page
        }, '*');
    }
}