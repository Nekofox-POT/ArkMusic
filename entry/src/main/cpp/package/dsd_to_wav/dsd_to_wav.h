#ifndef DSD_TO_WAV_H
#define DSD_TO_WAV_H

#include <napi/native_api.h>
#include <string>

// DSD 文件转 WAV（异步）
// 参数1: DSD 文件路径 (string)
// 参数2: 输出 WAV 文件路径 (string)
// 返回: Promise<void>
napi_value DsdToWav(napi_env env, napi_callback_info info);

#endif // DSD_TO_WAV_H
