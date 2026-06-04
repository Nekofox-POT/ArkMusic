//
// 像素亮度计算
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifndef PIXEL_LIGHT_COUNT_H
#define PIXEL_LIGHT_COUNT_H

#include <napi/native_api.h>
#include <cstdint>

// 计算图片像素平均亮度值
// 参数: ArrayBuffer (RGBA 像素数据), 宽度, 高度
// 返回: 亮度值 (0-255)
uint32_t pixel_light_count(napi_env env, napi_value array_buffer, int width, int height);

#endif // PIXEL_LIGHT_COUNT_H
