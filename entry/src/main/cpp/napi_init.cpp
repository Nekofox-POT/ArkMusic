#include <napi/native_api.h>
#include <string>
#include <cstring>

// --- Base64 辅助代码开始 ---
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

// 核心业务逻辑：接收 ArrayBuffer，返回 Base64 字符串
static napi_value EncodeImageToBase64(napi_env env, napi_callback_info info) {
    // 1. 获取参数数量和参数数组
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个 ArrayBuffer 参数");
        return nullptr;
    }

    // 2. 判断参数类型是否为 ArrayBuffer
    bool isArrayBuffer = false;
    napi_is_arraybuffer(env, args[0], &isArrayBuffer);
    if (!isArrayBuffer) {
        napi_throw_error(env, nullptr, "参数类型必须是 ArrayBuffer");
        return nullptr;
    }

    // 3. 获取 ArrayBuffer 的数据和长度
    void* buffer = nullptr;
    size_t bufferLength = 0;
    napi_status status = napi_get_arraybuffer_info(env, args[0], &buffer, &bufferLength);
    
    if (status != napi_ok || buffer == nullptr) {
        napi_throw_error(env, nullptr, "获取 ArrayBuffer 数据失败");
        return nullptr;
    }

    // 4. 执行 C++ 侧的 Base64 编码
    // 注意：这里直接操作原始内存，效率极高
    std::string base64Result = base64_encode(static_cast<unsigned char*>(buffer), bufferLength);

    // 5. 拼接 Data URL 前缀 (格式：data:image/jpeg;base64,xxxxx)
    std::string dataUrl = "data:image/jpeg;base64," + base64Result;

    // 6. 将 C++ string 转换为 napi_value 返回给 ArkTS
    napi_value result;
    napi_create_string_utf8(env, dataUrl.c_str(), dataUrl.length(), &result);

    return result;
}

// 模块初始化：将上面的函数暴露给 ArkTS
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // "encodeImageToBase64" 是 ArkTS 调用时的函数名
        {"encodeImageToBase64", nullptr, EncodeImageToBase64, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

// 模块注册信息
static napi_module nativeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry", // 模块名，必须和 CMakeLists.txt 中的 add_library(entry ...) 名字一致
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&nativeModule);
}
