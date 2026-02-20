// 初始化颜色
process_bar.style.backgroundColor = get_color();
process_bar_two.style.backgroundColor = get_color();

// 监听music_range变化，动态调整process_bar宽度（以中心点为基准）
music_range.addEventListener('input', function () {
	const min = Number(music_range.min);
	const max = Number(music_range.max);
	const value = Number(music_range.value);
	const percent = (value - min) / (max - min); // 0~1
	// left始终为0，宽度为进度百分比
	process_bar.style.left = '0';
	process_bar.style.width = (percent * 100) + '%';
	if (process_bar_two) {
		process_bar_two.style.left = '0';
		process_bar_two.style.width = (percent * 100) + '%';
	}
});

// 初始化一次
(function () {
	const min = Number(music_range.min);
	const max = Number(music_range.max);
	const value = Number(music_range.value);
	const percent = (value - min) / (max - min);
	process_bar.style.left = '0';
	process_bar.style.width = (percent * 100) + '%';
	if (process_bar_two) {
		process_bar_two.style.left = '0';
		process_bar_two.style.width = (percent * 100) + '%';
	}
})();