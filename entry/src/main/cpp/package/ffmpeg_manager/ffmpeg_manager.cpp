#include "ffmpeg_manager.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
#include <libavutil/samplefmt.h>
}

#include <cstdint>

// --- 辅助函数：安全地从 AVDictionary 中读取标签 ---
static std::string get_tag(const AVDictionary* metadata, const char* key) {
    if (!metadata) {
        return "";
    }
    const AVDictionaryEntry* entry = av_dict_get(metadata, key, nullptr, 0);
    return entry ? std::string(entry->value) : "";
}

// --- 辅助函数：提取文件名（不含路径）---
static std::string extract_filename(const std::string& filePath) {
    size_t pos = filePath.find_last_of("/\\");
    if (pos != std::string::npos) {
        return filePath.substr(pos + 1);
    }
    return filePath;
}

// --- 辅助函数：设置对象上的字符串属性 ---
static void set_string_prop(napi_env env, napi_value obj, const char* key, const std::string& val) {
    napi_value napiVal;
    napi_create_string_utf8(env, val.c_str(), val.length(), &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

// --- 辅助函数：设置对象上的数字属性 ---
static void set_number_prop(napi_env env, napi_value obj, const char* key, double val) {
    napi_value napiVal;
    napi_create_double(env, val, &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

// 获取音频的元数据
// 分为两个部分
// 第一个部分是基础数据，包括 [声道, 采样率, 位深, 比特率, 时长]
// 第二个部分是制作数据，包括 [文件名, 标题, 歌手, 作曲家, 专辑名, 专辑作家, 流派]
napi_value GetAudioMetadata(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个文件路径字符串");
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

    std::string filePath(strSize, '\0');
    napi_get_value_string_utf8(env, args[0], &filePath[0], strSize + 1, &strSize);

    // 4. 创建返回对象
    napi_value result;
    napi_create_object(env, &result);

    // 5. 提取文件名
    std::string filename = extract_filename(filePath);
    set_string_prop(env, result, "filename", filename);

    // 6. 打开文件
    AVFormatContext* formatCtx = nullptr;
    if (avformat_open_input(&formatCtx, filePath.c_str(), nullptr, nullptr) != 0) {
        napi_throw_error(env, nullptr, "无法打开音频文件");
        return nullptr;
    }

    // 7. 获取流信息
    if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
        avformat_close_input(&formatCtx);
        napi_throw_error(env, nullptr, "无法获取流信息");
        return nullptr;
    }

    // 8. 查找音频流
    int audioStreamIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audioStreamIndex < 0) {
        avformat_close_input(&formatCtx);
        napi_throw_error(env, nullptr, "未找到音频流");
        return nullptr;
    }

    AVStream* audioStream = formatCtx->streams[audioStreamIndex];
    AVCodecParameters* codecPar = audioStream->codecpar;

    // 9. 提取基础数据
    int channels = codecPar->ch_layout.nb_channels;
    int sampleRate = codecPar->sample_rate;
    int bitDepth = av_get_bytes_per_sample(static_cast<AVSampleFormat>(codecPar->format)) * 8;

    // 比特率：优先使用音频流的，否则使用全局的
    int64_t bitrate = 0;
    if (codecPar->bit_rate > 0) {
        bitrate = codecPar->bit_rate;
    } else if (formatCtx->bit_rate > 0) {
        bitrate = formatCtx->bit_rate;
    }

    // 时长（秒）：优先使用容器时长，否则使用流的时长
    double duration = 0.0;
    if (formatCtx->duration > 0 && formatCtx->duration != AV_NOPTS_VALUE) {
        duration = static_cast<double>(formatCtx->duration) / AV_TIME_BASE;
    } else if (audioStream->duration > 0 && audioStream->duration != AV_NOPTS_VALUE) {
        duration = static_cast<double>(audioStream->duration) * av_q2d(audioStream->time_base);
    }

    set_number_prop(env, result, "channels", channels);
    set_number_prop(env, result, "sampleRate", sampleRate);
    set_number_prop(env, result, "bitDepth", bitDepth);
    set_number_prop(env, result, "bitrate", static_cast<double>(bitrate));
    set_number_prop(env, result, "duration", duration);

    // 10. 提取制作数据
    AVDictionary* metadata = formatCtx->metadata;

    set_string_prop(env, result, "title", get_tag(metadata, "title"));
    set_string_prop(env, result, "artist", get_tag(metadata, "artist"));
    set_string_prop(env, result, "composer", get_tag(metadata, "composer"));
    set_string_prop(env, result, "album", get_tag(metadata, "album"));
    set_string_prop(env, result, "albumArtist", get_tag(metadata, "album_artist"));
    set_string_prop(env, result, "genre", get_tag(metadata, "genre"));

    // 11. 清理
    avformat_close_input(&formatCtx);

    return result;
}
