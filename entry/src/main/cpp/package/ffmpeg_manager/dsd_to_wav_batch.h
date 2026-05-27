#ifndef DSD_TO_WAV_BATCH_H
#define DSD_TO_WAV_BATCH_H

#include <napi/native_api.h>

// 批量 DSD 文件转 WAV（多线程并行，异步）
// 参数: Array<{inputPath: string, outputPath: string}>
// 返回: Promise<Array<{inputPath: string, success: boolean}>>
napi_value DsdToWavBatch(napi_env env, napi_callback_info info);

#endif // DSD_TO_WAV_BATCH_H
