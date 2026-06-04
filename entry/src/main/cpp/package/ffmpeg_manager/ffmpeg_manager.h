#ifndef FFMPEG_MANAGER_H
#define FFMPEG_MANAGER_H

#include <napi/native_api.h>
#include <string>

// 获取音频元信息（异步，自动识别单文件/批量）
// 参数: 文件路径 (string) 或 文件路径数组 (string[])
// 返回: Promise<AudioMetadata | AudioMetadata[]>
napi_value get_audio_metadata(napi_env env, napi_callback_info info);

// DSD 文件转 WAV（异步）
// 参数1: DSD 文件路径 (string)
// 参数2: 输出 WAV 文件路径 (string)
// 返回: Promise<void>
napi_value dsd_to_wav(napi_env env, napi_callback_info info);

// --- FFmpeg 播放器 ---

// 设置音频文件（异步验证 + 初始化解码器 + 创建 OHAudio renderer）
// 参数1: 文件路径 (string)
// 参数2: 是否自动播放 (boolean, 可选, 默认 true)
// 参数3: 起始跳转时间(ms) (number, 可选, 默认 0)
// 返回: Promise<boolean>
napi_value set_audio(napi_env env, napi_callback_info info);

// 播放
napi_value playing(napi_env env, napi_callback_info info);

// 暂停
napi_value pause(napi_env env, napi_callback_info info);

// 跳转到指定播放时间
// 参数: 毫秒时间戳 (int)
napi_value seek(napi_env env, napi_callback_info info);

// 主动查询当前播放时间
// 返回: 毫秒时间戳 (int)
napi_value get_current_time(napi_env env, napi_callback_info info);

// 注册播放时间回调
// 参数: 回调函数 (function)，回调参数为毫秒时间戳 (int)
napi_value register_time_callback(napi_env env, napi_callback_info info);

// 注册准备就绪回调
// 参数: 回调函数 (function)，无参数
napi_value register_ready_callback(napi_env env, napi_callback_info info);

// 注册播放状态回调
// 参数: 回调函数 (function)，回调参数为状态字符串 ("playing" / "pause" / "complete")
napi_value register_status_callback(napi_env env, napi_callback_info info);

// 主动获取当前播放状态
// 返回: 状态字符串 ("playing" / "pause" / "complete")
napi_value get_status(napi_env env, napi_callback_info info);

// --- EQ/PEQ ---

// 设置 EQ 模式
// 参数: 模式 int (0=OFF, 1=GEQ, 2=PEQ)，越界无效
napi_value switch_eq(napi_env env, napi_callback_info info);

// 获取当前 EQ 模式
// 返回: 当前模式 int (0/1/2)
napi_value get_eq_mode(napi_env env, napi_callback_info info);

// 设置 10 段 GEQ 增益值
// 参数: float[10]，每段 -12.0 ~ 12.0 (dB)
napi_value set_eq(napi_env env, napi_callback_info info);

// 设置 10 个 PEQ 参数
// 参数: [enabled(bool), freq(float), gain(float), q(float), type(int)][10]
napi_value set_peq(napi_env env, napi_callback_info info);

// 获取当前 GEQ 增益值
// 返回: number[10]
napi_value get_eq(napi_env env, napi_callback_info info);

// 获取当前 PEQ 参数
// 返回: [boolean, number, number, number, number][10]
napi_value get_peq(napi_env env, napi_callback_info info);

#endif // FFMPEG_MANAGER_H
