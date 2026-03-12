#include "image_color_calculate.h"
#include <vector>

// 修改返回逻辑：返回一个 uint32_t 整数
uint32_t CalculateAverageColor(napi_env env, napi_value arrayBuffer, int width, int height) {
    // 默认返回黑色 0xFF000000 (ARGB)
    uint32_t defaultColor = 0xFF000000;

    // 1. 获取 ArrayBuffer 数据
    void* buffer = nullptr;
    size_t bufferLength = 0;
    napi_status status = napi_get_arraybuffer_info(env, arrayBuffer, &buffer, &bufferLength);

    if (status != napi_ok || buffer == nullptr || width <= 0 || height <= 0) {
        return defaultColor;
    }

    // 2. 校验数据长度 (假设 RGBA 格式)
    size_t expectedLength = static_cast<size_t>(width) * height * 4;
    if (bufferLength < expectedLength) {
        return defaultColor; 
    }

    // 3. 遍历像素计算总和
    unsigned char* data = static_cast<unsigned char*>(buffer);
    uint64_t sumR = 0, sumG = 0, sumB = 0, sumA = 0;
    size_t pixelCount = width * height;

    for (size_t i = 0; i < pixelCount; i++) {
        size_t idx = i * 4;
        sumR += data[idx];     // Red
        sumG += data[idx + 1]; // Green
        sumB += data[idx + 2]; // Blue
        sumA += data[idx + 3]; // Alpha
    }

    // 4. 计算平均的 R, G, B 值
    uint8_t avgR = static_cast<uint8_t>(sumR / pixelCount);
    uint8_t avgG = static_cast<uint8_t>(sumG / pixelCount);
    uint8_t avgB = static_cast<uint8_t>(sumB / pixelCount);

    // 5. 计算亮度值（标准亮度公式）
    // L = 0.299 * R + 0.587 * G + 0.114 * B
    uint8_t luminance = static_cast<uint8_t>(
        0.299 * avgR + 0.587 * avgG + 0.114 * avgB
    );

    // 6. 返回亮度值（0-255）
    return static_cast<uint32_t>(luminance);
}
