#ifndef IMAGE_COLOR_UTILS_H
#define IMAGE_COLOR_UTILS_H

#include <napi/native_api.h>
#include <cstdint> // 包含 uint32_t

// 返回一个 32位的颜色值
uint32_t calculate_average_color(napi_env env, napi_value array_buffer, int width, int height);

#endif // IMAGE_COLOR_UTILS_H
