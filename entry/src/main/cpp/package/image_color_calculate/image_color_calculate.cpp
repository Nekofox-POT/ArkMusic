#include "image_color_calculate.h"
#include <vector>

// 修改返回逻辑：返回一个 uint32_t 整数
uint32_t calculate_average_color(napi_env env, napi_value array_buffer, int width, int height) {
    // 默认返回黑色 0xFF000000 (ARGB)
    uint32_t default_color = 0xFF000000;

    // 1. 获取 ArrayBuffer 数据
    void* buffer = nullptr;
    size_t buffer_length = 0;
    napi_status status = napi_get_arraybuffer_info(env, array_buffer, &buffer, &buffer_length);

    if (status != napi_ok || buffer == nullptr || width <= 0 || height <= 0) {
        return default_color;
    }

    // 2. 校验数据长度 (假设 RGBA 格式)
    size_t expected_length = static_cast<size_t>(width) * height * 4;
    if (buffer_length < expected_length) {
        return default_color;
    }

    // 3. 遍历像素计算总和
    unsigned char* data = static_cast<unsigned char*>(buffer);
    uint64_t sum_r = 0, sum_g = 0, sum_b = 0, sum_a = 0;
    size_t pixel_count = width * height;

    for (size_t i = 0; i < pixel_count; i++) {
        size_t idx = i * 4;
        sum_r += data[idx];     // Red
        sum_g += data[idx + 1]; // Green
        sum_b += data[idx + 2]; // Blue
        sum_a += data[idx + 3]; // Alpha
    }

    // 4. 计算平均的 R, G, B 值
    uint8_t avg_r = static_cast<uint8_t>(sum_r / pixel_count);
    uint8_t avg_g = static_cast<uint8_t>(sum_g / pixel_count);
    uint8_t avg_b = static_cast<uint8_t>(sum_b / pixel_count);

    // 5. 计算亮度值（标准亮度公式）
    // L = 0.299 * R + 0.587 * G + 0.114 * B
    uint8_t luminance = static_cast<uint8_t>(
        0.299 * avg_r + 0.587 * avg_g + 0.114 * avg_b
    );

    // 6. 返回亮度值（0-255）
    return static_cast<uint32_t>(luminance);
}
