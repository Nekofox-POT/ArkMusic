//
// 像素分析
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifndef PIXEL_COUNT_H
#define PIXEL_COUNT_H

#include <napi/native_api.h>
#include <cstdint>
#include <string>
#include <vector>

// 计算图片像素平均亮度值
// 参数: ArrayBuffer (RGBA 像素数据), 宽度, 高度
// 返回: 亮度值 (0-255)
uint32_t get_pixel_light(napi_env env, napi_value array_buffer, int width, int height);

// 计算图片主色调
// 参数: ArrayBuffer (RGBA 像素数据), 宽度, 高度
// 返回: 十六进制颜色字符串，如 "#66ccff"
std::string get_pixel_color(napi_env env, napi_value array_buffer, int width, int height);

// 计算图片三分主色
// 参数: ArrayBuffer (RGBA 像素数据), 宽度, 高度
// 返回: 十六进制颜色字符串数组，如 ["#66ccff", "#ee0000", "#00cccc"]
std::vector<std::string> get_pixel_dominant(napi_env env, napi_value array_buffer, int width, int height);

#endif // PIXEL_COUNT_H
