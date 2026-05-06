#ifndef FFMPEG_MANAGER_H
#define FFMPEG_MANAGER_H

#include <napi/native_api.h>
#include <string>

// 获取音频元信息
// 返回一个 napi_value 对象，包含基础数据和制作数据
napi_value GetAudioMetadata(napi_env env, napi_callback_info info);

#endif // FFMPEG_MANAGER_H
