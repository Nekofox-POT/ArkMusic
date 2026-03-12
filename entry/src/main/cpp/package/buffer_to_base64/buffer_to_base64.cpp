#include "buffer_to_base64.h"
#include <cstring>

// --- Base64 辅助代码实现 ---
static const std::string base64_chars = 
             "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
             "abcdefghijklmnopqrstuvwxyz"
             "0123456789+/";

std::string base64_encode(unsigned char const* bytes_to_encode, size_t in_len) {
    std::string ret;
    int i = 0;
    int j = 0;
    unsigned char char_array_3[3];
    unsigned char char_array_4[4];

    while (in_len--) {
        char_array_3[i++] = *(bytes_to_encode++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for(i = 0; (i <4) ; i++)
                ret += base64_chars[char_array_4[i]];
            i = 0;
        }
    }

    if (i) {
        for(j = i; j < 3; j++)
            char_array_3[j] = '\0';

        char_array_4[0] = ( char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (j = 0; (j < i + 1); j++)
            ret += base64_chars[char_array_4[j]];

        while((i++ < 3))
            ret += '=';
    }
    return ret;
}
// --- Base64 辅助代码结束 ---

// --- 核心业务逻辑实现 ---
// 职责：从 napi_value 中提取数据，处理业务，返回 C++ 结果
std::string ProcessArrayBufferToBase64(napi_env env, napi_value arrayBuffer) {
    // 1. 获取 ArrayBuffer 的数据和长度
    void* buffer = nullptr;
    size_t bufferLength = 0;
    
    // 注意：错误处理这里简化了，实际项目中如果 napi 调用失败，可以抛出异常或返回空字符串
    napi_status status = napi_get_arraybuffer_info(env, arrayBuffer, &buffer, &bufferLength);
    
    if (status != napi_ok || buffer == nullptr) {
        // 在实际项目中，这里最好抛出一个 JS 异常或者返回特定的错误标记
        return ""; 
    }

    // 2. 执行 Base64 编码
    std::string base64Result = base64_encode(static_cast<unsigned char*>(buffer), bufferLength);

    // 3. 拼接 Data URL 前缀
    return "data:image/jpeg;base64," + base64Result;
}
