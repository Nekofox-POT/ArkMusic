#include "ffmpeg_manager.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
#include <libavutil/samplefmt.h>
}

#include <cstdint>

struct GetMetaContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::string file_path;
    bool success;
    std::string error_message;

    std::string filename;
    int channels;
    int sample_rate;
    int bit_depth;
    int64_t bitrate;
    double duration;
    std::string title;
    std::string artist;
    std::string composer;
    std::string album;
    std::string album_artist;
    std::string genre;
};

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

static void ExecuteGetMeta(napi_env env, void* data) {
    auto* ctx = static_cast<GetMetaContext*>(data);

    AVFormatContext* formatCtx = nullptr;

    if (avformat_open_input(&formatCtx, ctx->file_path.c_str(), nullptr, nullptr) != 0) {
        ctx->success = false;
        ctx->error_message = "无法打开音频文件";
        return;
    }

    if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
        avformat_close_input(&formatCtx);
        ctx->success = false;
        ctx->error_message = "无法获取流信息";
        return;
    }

    int audioStreamIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audioStreamIndex < 0) {
        avformat_close_input(&formatCtx);
        ctx->success = false;
        ctx->error_message = "未找到音频流";
        return;
    }

    AVStream* audioStream = formatCtx->streams[audioStreamIndex];
    AVCodecParameters* codecPar = audioStream->codecpar;

    ctx->filename = extract_filename(ctx->file_path);
    ctx->channels = codecPar->ch_layout.nb_channels;
    ctx->sample_rate = codecPar->sample_rate;
    // 获取位深：优先使用原始样本位深，其次编码位深，最后用解码格式推算
    // DSD 特殊处理：avformat_find_stream_info 解码探测时可能覆写 bits_per_raw_sample，
    // 导致报成解码输出格式的位深（如 U8=8bit），而 DSD 本身是 1bit
    if (codecPar->codec_id == AV_CODEC_ID_DSD_LSBF ||
        codecPar->codec_id == AV_CODEC_ID_DSD_MSBF ||
        codecPar->codec_id == AV_CODEC_ID_DSD_LSBF_PLANAR ||
        codecPar->codec_id == AV_CODEC_ID_DSD_MSBF_PLANAR) {
        ctx->bit_depth = 1;
    } else {
        int bits = codecPar->bits_per_raw_sample;
        if (bits <= 0) {
            bits = codecPar->bits_per_coded_sample;
        }
        if (bits <= 0) {
            bits = av_get_bytes_per_sample(static_cast<AVSampleFormat>(codecPar->format)) * 8;
        }
        ctx->bit_depth = bits;
    }

    ctx->bitrate = 0;
    if (codecPar->bit_rate > 0) {
        ctx->bitrate = codecPar->bit_rate;
    } else if (formatCtx->bit_rate > 0) {
        ctx->bitrate = formatCtx->bit_rate;
    }

    ctx->duration = 0.0;
    if (formatCtx->duration > 0 && formatCtx->duration != AV_NOPTS_VALUE) {
        ctx->duration = static_cast<double>(formatCtx->duration) / AV_TIME_BASE;
    } else if (audioStream->duration > 0 && audioStream->duration != AV_NOPTS_VALUE) {
        ctx->duration = static_cast<double>(audioStream->duration) * av_q2d(audioStream->time_base);
    }

    AVDictionary* metadata = formatCtx->metadata;
    ctx->title = get_tag(metadata, "title");
    ctx->artist = get_tag(metadata, "artist");
    ctx->composer = get_tag(metadata, "composer");
    ctx->album = get_tag(metadata, "album");
    ctx->album_artist = get_tag(metadata, "album_artist");
    ctx->genre = get_tag(metadata, "genre");

    avformat_close_input(&formatCtx);
    ctx->success = true;
}

static void set_string_prop(napi_env env, napi_value obj, const char* key, const std::string& val) {
    napi_value napiVal;
    napi_create_string_utf8(env, val.c_str(), val.length(), &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

static void set_number_prop(napi_env env, napi_value obj, const char* key, double val) {
    napi_value napiVal;
    napi_create_double(env, val, &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

static void CompleteGetMeta(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<GetMetaContext*>(data);

    if (status == napi_ok && ctx->success) {
        napi_value result;
        napi_create_object(env, &result);

        set_string_prop(env, result, "filename", ctx->filename);
        set_number_prop(env, result, "channels", ctx->channels);
        set_number_prop(env, result, "sampleRate", ctx->sample_rate);
        set_number_prop(env, result, "bitDepth", ctx->bit_depth);
        set_number_prop(env, result, "bitrate", static_cast<double>(ctx->bitrate));
        set_number_prop(env, result, "duration", ctx->duration);
        set_string_prop(env, result, "title", ctx->title);
        set_string_prop(env, result, "artist", ctx->artist);
        set_string_prop(env, result, "composer", ctx->composer);
        set_string_prop(env, result, "album", ctx->album);
        set_string_prop(env, result, "albumArtist", ctx->album_artist);
        set_string_prop(env, result, "genre", ctx->genre);

        napi_resolve_deferred(env, ctx->deferred, result);
    } else {
        napi_value error;
        std::string msg = ctx->success ? "获取元数据失败" : ctx->error_message;
        napi_create_string_utf8(env, msg.c_str(), msg.length(), &error);
        napi_reject_deferred(env, ctx->deferred, error);
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

// 获取音频的元数据（异步）
// 参数: 文件路径 (string)
// 返回: Promise<object>
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

    // 4. 创建异步上下文
    auto* ctx = new GetMetaContext();
    ctx->file_path = filePath;
    ctx->success = false;
    ctx->channels = 0;
    ctx->sample_rate = 0;
    ctx->bit_depth = 0;
    ctx->bitrate = 0;
    ctx->duration = 0.0;

    // 5. 创建 Promise
    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    // 6. 创建异步工作项
    napi_value resource_name;
    napi_create_string_utf8(env, "GetAudioMetadata", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           ExecuteGetMeta, CompleteGetMeta,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}
