#ifndef BASE64URL_CODE_H
#define BASE64URL_CODE_H

#include <napi/native_api.h>
#include <string>

// Base64URL 编码函数声明
// 参数：input - 待编码的字符串
// 返回：Base64URL 编码后的字符串
std::string base64url_encode(const std::string& input);

// Base64URL 解码函数声明
// 参数：input - Base64URL 编码的字符串
// 返回：解码后的原始字符串
std::string base64url_decode(const std::string& input);

// 核心业务逻辑函数声明：根据 isEncode 决定编码或解码
// 参数：input - 待处理的字符串
// 参数：isEncode - true 为编码，false 为解码
// 返回：处理后的字符串
std::string ProcessBase64UrlCode(const std::string& input, bool isEncode);

#endif // BASE64URL_CODE_H
