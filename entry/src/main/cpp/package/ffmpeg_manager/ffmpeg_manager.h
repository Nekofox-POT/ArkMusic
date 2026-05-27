#ifndef FFMPEG_MANAGER_H
#define FFMPEG_MANAGER_H

#include <napi/native_api.h>
#include <string>

// 获取音频元信息（异步）
// 参数: 文件路径 (string)
// 返回: Promise<AudioMetadata>
napi_value GetAudioMetadata(napi_env env, napi_callback_info info);

// DSD 文件转 WAV（异步）
// 参数1: DSD 文件路径 (string)
// 参数2: 输出 WAV 文件路径 (string)
// 返回: Promise<void>
napi_value DsdToWav(napi_env env, napi_callback_info info);

// 批量 DSD 文件转 WAV（多线程并行，异步）
// 参数: Array<{inputPath: string, outputPath: string}>
// 返回: Promise<Array<{inputPath: string, success: boolean}>>
napi_value DsdToWavBatch(napi_env env, napi_callback_info info);

// 批量获取音频元信息（多线程并行，异步）
// 参数: 文件路径数组 (string[])
// 返回: Promise<object[]>
napi_value GetAudioMetadataBatch(napi_env env, napi_callback_info info);

#endif // FFMPEG_MANAGER_H
