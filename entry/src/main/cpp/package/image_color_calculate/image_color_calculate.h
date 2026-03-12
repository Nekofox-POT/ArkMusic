#ifndef IMAGE_COLOR_UTILS_H
#define IMAGE_COLOR_UTILS_H

#include <napi/native_api.h>
#include <cstdint> // 包含 uint32_t

// 返回一个 32位的颜色值
uint32_t CalculateAverageColor(napi_env env, napi_value arrayBuffer, int width, int height);

#endif // IMAGE_COLOR_UTILS_H
