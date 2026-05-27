#ifndef GET_META_BATCH_H
#define GET_META_BATCH_H

#include <napi/native_api.h>
#include <string>
#include <vector>

// 批量获取音频元信息（多线程并行，异步）
// 参数: 文件路径数组 (string[])
// 返回: Promise<object[]>
napi_value GetAudioMetadataBatch(napi_env env, napi_callback_info info);

#endif // GET_META_BATCH_H
