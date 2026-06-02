#include <napi/native_api.h>

#include "package/buffer_to_base64/buffer_to_base64.h" // 引用我们的头文件
#include "package/image_color_calculate/image_color_calculate.h"
#include "package/extract_filename/extract_filename.h"
#include "package/ffmpeg_player/ffmpeg_player.h"
#include "package/base64url_code/base64url_code.h"
#include "package/sort_manager/sort_manager.h"

// --- 功能1：Base64 编码 (完整代码，请替换原来的省略版本) ---
static napi_value EncodeImageToBase64(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个 ArrayBuffer 参数");
        return nullptr;
    }

    // 2. 校验参数类型
    bool isArrayBuffer = false;
    napi_is_arraybuffer(env, args[0], &isArrayBuffer);
    if (!isArrayBuffer) {
        napi_throw_error(env, nullptr, "参数类型必须是 ArrayBuffer");
        return nullptr;
    }

    // 3. 调用分离出去的业务逻辑函数 (引用你写的 package 里的函数)
    std::string resultStr = ProcessArrayBufferToBase64(env, args[0]);

    // 4. 错误检查
    if (resultStr.empty()) {
        napi_throw_error(env, nullptr, "Base64 编码失败或数据为空");
        return nullptr;
    }

    // 5. 将 C++ string 转换为 napi_value 返回
    napi_value result;
    napi_create_string_utf8(env, resultStr.c_str(), resultStr.length(), &result);

    return result;
}

// --- 功能2：计算平均色值 (新增) ---
static napi_value GetImageAverageColor(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "参数数量错误");
        return nullptr;
    }

    // 2. 校验与解析
    bool isArrayBuffer = false;
    napi_is_arraybuffer(env, args[0], &isArrayBuffer);
    if (!isArrayBuffer) {
        napi_throw_error(env, nullptr, "参数必须是 ArrayBuffer");
        return nullptr;
    }

    int width = 0, height = 0;
    napi_get_value_int32(env, args[1], &width);
    napi_get_value_int32(env, args[2], &height);

    // 3. 调用 C++ 业务逻辑，得到整数颜色值
    uint32_t colorValue = CalculateAverageColor(env, args[0], width, height);

    // 4. 将整数转换为 napi_value 返回
    napi_value result;
    // 使用 create_uint32 创建无符号 32 位整数
    napi_create_uint32(env, colorValue, &result);

    return result;
}

// --- 功能3：提取文件名（不带扩展名）---
static napi_value ExtractFilename(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个字符串参数");
        return nullptr;
    }

    // 2. 校验参数类型
    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_string) {
        napi_throw_error(env, nullptr, "参数类型必须是字符串");
        return nullptr;
    }

    // 3. 获取字符串内容
    size_t strSize = 0;
    napi_status status = napi_get_value_string_utf8(env, args[0], nullptr, 0, &strSize);
    if (status != napi_ok || strSize == 0) {
        napi_throw_error(env, nullptr, "字符串解析失败");
        return nullptr;
    }

    std::string pathStr(strSize, '\0');
    napi_get_value_string_utf8(env, args[0], &pathStr[0], strSize + 1, &strSize);

    // 4. 调用 C++ 业务逻辑函数
    std::string filename = ExtractFilenameWithoutExtension(pathStr);

    // 5. 将结果转换为 napi_value 返回
    napi_value result;
    napi_create_string_utf8(env, filename.c_str(), filename.length(), &result);

    return result;
}

// --- 功能4：Base64URL 编码/解码 ---
static napi_value Base64UrlCode(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "需要传入 string 和 boolean 两个参数");
        return nullptr;
    }

    // 2. 校验第一个参数类型
    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_string) {
        napi_throw_error(env, nullptr, "第一个参数类型必须是字符串");
        return nullptr;
    }

    // 3. 校验第二个参数类型
    napi_typeof(env, args[1], &valuetype);
    if (valuetype != napi_boolean) {
        napi_throw_error(env, nullptr, "第二个参数类型必须是布尔值");
        return nullptr;
    }

    // 4. 获取字符串内容
    size_t strSize = 0;
    napi_status status = napi_get_value_string_utf8(env, args[0], nullptr, 0, &strSize);
    if (status != napi_ok || strSize == 0) {
        napi_throw_error(env, nullptr, "字符串解析失败");
        return nullptr;
    }

    std::string inputStr(strSize, '\0');
    napi_get_value_string_utf8(env, args[0], &inputStr[0], strSize + 1, &strSize);

    // 5. 获取布尔值
    bool isEncode = false;
    napi_get_value_bool(env, args[1], &isEncode);

    // 6. 调用 C++ 业务逻辑函数
    std::string resultStr = ProcessBase64UrlCode(inputStr, isEncode);

    // 7. 将结果转换为 napi_value 返回
    napi_value result;
    napi_create_string_utf8(env, resultStr.c_str(), resultStr.length(), &result);

    return result;
}

// --- 功能6：字符串数组排序 ---
static napi_value SortStringArray(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入字符串数组参数");
        return nullptr;
    }

    // 2. 校验参数类型
    bool is_array = false;
    napi_is_array(env, args[0], &is_array);
    if (!is_array) {
        napi_throw_error(env, nullptr, "参数类型必须是数组");
        return nullptr;
    }

    // 3. 获取数组长度
    uint32_t length = 0;
    napi_get_array_length(env, args[0], &length);

    // 4. 提取为 std::vector<std::string>
    std::vector<std::string> input;
    input.reserve(length);
    for (uint32_t i = 0; i < length; i++) {
        napi_value elem;
        napi_get_element(env, args[0], i, &elem);

        // 两步法获取字符串：先拿长度，再读内容
        size_t str_size = 0;
        napi_status status = napi_get_value_string_utf8(env, elem, nullptr, 0, &str_size);
        if (status != napi_ok) {
            continue;
        }
        std::string str(str_size, '\0');
        napi_get_value_string_utf8(env, elem, &str[0], str_size + 1, &str_size);
        input.push_back(str);
    }

    // 5. 调用 C++ 排序
    std::vector<std::string> result = sort_string_array(input);

    // 6. 转换为 napi 数组返回
    napi_value output;
    napi_create_array_with_length(env, result.size(), &output);
    for (size_t i = 0; i < result.size(); i++) {
        napi_value elem;
        napi_create_string_utf8(env, result[i].c_str(), result[i].length(), &elem);
        napi_set_element(env, output, i, elem);
    }

    return output;
}

// --- 模块初始化 ---
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // 原有函数
        {"encodeImageToBase64", nullptr, EncodeImageToBase64, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getImageAverageColor", nullptr, GetImageAverageColor, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"extractFilename", nullptr, ExtractFilename, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getAudioMetadata", nullptr, GetAudioMetadata, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"base64urlCode", nullptr, Base64UrlCode, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sortStringArray", nullptr, SortStringArray, nullptr, nullptr, nullptr, napi_default, nullptr},
        // 播放器控制
        {"set_audio", nullptr, set_audio, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"playing", nullptr, playing, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"pause", nullptr, pause, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"seek", nullptr, seek, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"get_current_time", nullptr, get_current_time, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"register_time_callback", nullptr, register_time_callback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"set_start_ready", nullptr, set_start_ready, nullptr, nullptr, nullptr, napi_default, nullptr},
        // EQ/PEQ
        {"switch_eq", nullptr, switch_eq, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"set_eq", nullptr, set_eq, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"set_peq", nullptr, set_peq, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"get_eq", nullptr, get_eq, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"get_peq", nullptr, get_peq, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

// 模块注册
static napi_module nativeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&nativeModule);
}
