target_color = 'rgb(244, 198, 206)'
target_bgcolor = 'rgba(0,0,0,0.4)'

// 更新SVG 颜色的函数
function updateSvgColors() {
  // 1. 找到所有 class 包含 'svg_color' 的元素
  const elements = document.querySelectorAll('.svg_color');

  // 2. 遍历这些元素
  elements.forEach(element => {
    // 3. 修改 fill 样式
    // 方式 A: 直接修改 style 属性 (优先级最高)
    element.style.fill = target_bgcolor;

  });
}

// 修改颜色的函数
function change_color(newColor) {
  target_color = newColor;
  updateSvgColors();
}
// 获取颜色的函数
function get_color() {
  return target_color;
}

// 这是底色的
function change_bgcolor(newColor) {
  target_bgcolor = newColor;
  updateSvgColors();
}
function get_bgcolor() {
  return target_bgcolor;
}