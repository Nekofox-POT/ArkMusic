#ifndef BASE64_UTILS_H
#define BASE64_UTILS_H

#include <napi/native_api.h>
#include <string>

// Base64 编码函数声明
std::string base64_encode(unsigned char const* bytes_to_encode, size_t in_len);

// 核心业务逻辑函数声明：接收 ArrayBuffer，返回 Base64 字符串
// 注意：这里返回的是 C++ 的 std::string，由 napi_init.cpp 负责转成 napi_value
std::string ProcessArrayBufferToBase64(napi_env env, napi_value arrayBuffer);

#endif // BASE64_UTILS_H
