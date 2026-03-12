#include <napi/native_api.h>

#include "package/buffer_to_base64/buffer_to_base64.h" // 引用我们的头文件
#include "package/image_color_calculate/image_color_calculate.h"

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

// --- 模块初始化 ---
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // 暴露两个函数给 ArkTS
        {"encodeImageToBase64", nullptr, EncodeImageToBase64, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getImageAverageColor", nullptr, GetImageAverageColor, nullptr, nullptr, nullptr, napi_default, nullptr}
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