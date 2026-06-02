#include "ffmpeg_player.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/dict.h>
#include <libavutil/samplefmt.h>
}

#include <cstdint>
#include <thread>
#include <mutex>
#include <algorithm>
#include <cstdio>

// ============================================================================
// 共享辅助函数
// ============================================================================

// 安全读取 AVDictionary 标签
static std::string get_tag(const AVDictionary* metadata, const char* key) {
    if (!metadata) { return ""; }
    const AVDictionaryEntry* entry = av_dict_get(metadata, key, nullptr, 0);
    return entry ? std::string(entry->value) : "";
}

// 提取文件名（不含路径）
static std::string extract_filename(const std::string& file_path) {
    size_t pos = file_path.find_last_of("/\\");
    if (pos != std::string::npos) { return file_path.substr(pos + 1); }
    return file_path;
}

// 位深修正：有损格式无原生位深概念，统一上报 16bit
static bool is_lossy_codec(AVCodecID codec_id) {
    switch (codec_id) {
        case AV_CODEC_ID_MP3:
        case AV_CODEC_ID_MP2:
        case AV_CODEC_ID_AAC:
        case AV_CODEC_ID_AAC_LATM:
        case AV_CODEC_ID_VORBIS:
        case AV_CODEC_ID_OPUS:
        case AV_CODEC_ID_WMAV1:
        case AV_CODEC_ID_WMAV2:
        case AV_CODEC_ID_WMAPRO:
        case AV_CODEC_ID_RA_144:
        case AV_CODEC_ID_RA_288:
        case AV_CODEC_ID_COOK:
        case AV_CODEC_ID_ATRAC3:
        case AV_CODEC_ID_SPEEX:
        case AV_CODEC_ID_AMR_NB:
        case AV_CODEC_ID_AMR_WB:
            return true;
        default:
            return false;
    }
}

// 将秒数转换为 "分:秒" 格式的 duration_format
static std::string make_duration_format(int64_t duration_ms) {
    int total_sec = (int)(duration_ms / 1000);
    char buf[32];
    snprintf(buf, sizeof(buf), "%d:%02d", total_sec / 60, total_sec % 60);
    return std::string(buf);
}

// ============================================================================
// 单文件元数据结果
// ============================================================================
struct SingleMetaResult {
    bool success;
    std::string error_message;
    std::string file_path;

    std::string filename;
    int channels;
    int sample_rate;
    int bit_depth;
    int64_t bitrate;
    int64_t duration;                // ms 精度时间戳
    std::string duration_format;     // "分:秒"
    std::string title;
    std::string artist;
    std::string composer;
    std::string album;
    std::string album_artist;
    std::string genre;
};

// ============================================================================
// 单文件元数据提取（线程安全）
// ============================================================================
static SingleMetaResult extract_single_meta(const std::string& file_path) {
    SingleMetaResult result;
    result.success = false;
    result.file_path = file_path;
    result.channels = 0;
    result.sample_rate = 0;
    result.bit_depth = 0;
    result.bitrate = 0;
    result.duration = 0;

    AVFormatContext* format_ctx = nullptr;

    if (avformat_open_input(&format_ctx, file_path.c_str(), nullptr, nullptr) != 0) {
        result.error_message = "无法打开音频文件";
        return result;
    }

    if (avformat_find_stream_info(format_ctx, nullptr) < 0) {
        avformat_close_input(&format_ctx);
        result.error_message = "无法获取流信息";
        return result;
    }

    int audio_stream_index = av_find_best_stream(format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_index < 0) {
        avformat_close_input(&format_ctx);
        result.error_message = "未找到音频流";
        return result;
    }

    AVStream* audio_stream = format_ctx->streams[audio_stream_index];
    AVCodecParameters* codec_par = audio_stream->codecpar;

    result.filename = extract_filename(file_path);
    result.channels = codec_par->ch_layout.nb_channels;
    result.sample_rate = codec_par->sample_rate;

    // 位深
    if (codec_par->codec_id == AV_CODEC_ID_DSD_LSBF ||
        codec_par->codec_id == AV_CODEC_ID_DSD_MSBF ||
        codec_par->codec_id == AV_CODEC_ID_DSD_LSBF_PLANAR ||
        codec_par->codec_id == AV_CODEC_ID_DSD_MSBF_PLANAR) {
        result.bit_depth = 1;
    } else {
        int bits = codec_par->bits_per_raw_sample;
        if (bits <= 0) { bits = codec_par->bits_per_coded_sample; }
        if (bits <= 0) { bits = av_get_bytes_per_sample(static_cast<AVSampleFormat>(codec_par->format)) * 8; }
        result.bit_depth = bits;
    }

    // 有损格式修正位深
    if (is_lossy_codec(codec_par->codec_id)) {
        result.bit_depth = 16;
    }

    // 比特率
    result.bitrate = 0;
    if (codec_par->bit_rate > 0) {
        result.bitrate = codec_par->bit_rate;
    } else if (format_ctx->bit_rate > 0) {
        result.bitrate = format_ctx->bit_rate;
    }

    // 时长：提取秒数后转为 ms 精度 + "分:秒" 格式
    double duration_sec = 0.0;
    if (format_ctx->duration > 0 && format_ctx->duration != AV_NOPTS_VALUE) {
        duration_sec = static_cast<double>(format_ctx->duration) / AV_TIME_BASE;
    } else if (audio_stream->duration > 0 && audio_stream->duration != AV_NOPTS_VALUE) {
        duration_sec = static_cast<double>(audio_stream->duration) * av_q2d(audio_stream->time_base);
    }
    result.duration = static_cast<int64_t>(duration_sec * 1000.0);
    result.duration_format = make_duration_format(result.duration);

    // 元数据标签
    AVDictionary* metadata = format_ctx->metadata;
    result.title = get_tag(metadata, "title");
    result.artist = get_tag(metadata, "artist");
    result.composer = get_tag(metadata, "composer");
    result.album = get_tag(metadata, "album");
    result.album_artist = get_tag(metadata, "album_artist");
    result.genre = get_tag(metadata, "genre");

    avformat_close_input(&format_ctx);
    result.success = true;
    return result;
}

// ============================================================================
// NAPI 辅助：设置对象属性
// ============================================================================
static void set_string_prop(napi_env env, napi_value obj, const char* key, const std::string& val) {
    napi_value napi_val;
    napi_create_string_utf8(env, val.c_str(), val.length(), &napi_val);
    napi_set_named_property(env, obj, key, napi_val);
}

static void set_number_prop(napi_env env, napi_value obj, const char* key, double val) {
    napi_value napi_val;
    napi_create_double(env, val, &napi_val);
    napi_set_named_property(env, obj, key, napi_val);
}

static void set_int64_prop(napi_env env, napi_value obj, const char* key, int64_t val) {
    napi_value napi_val;
    napi_create_int64(env, val, &napi_val);
    napi_set_named_property(env, obj, key, napi_val);
}

// ============================================================================
// 将 SingleMetaResult 转为 napi_value
// ============================================================================
static napi_value meta_result_to_napi(napi_env env, const SingleMetaResult& meta) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value success_val;
    napi_get_boolean(env, meta.success, &success_val);
    napi_set_named_property(env, obj, "success", success_val);
    set_string_prop(env, obj, "filePath", meta.file_path);

    if (meta.success) {
        set_string_prop(env, obj, "filename", meta.filename);
        set_number_prop(env, obj, "channels", meta.channels);
        set_number_prop(env, obj, "sampleRate", meta.sample_rate);
        set_number_prop(env, obj, "bitDepth", meta.bit_depth);
        set_number_prop(env, obj, "bitrate", static_cast<double>(meta.bitrate));
        set_int64_prop(env, obj, "duration", meta.duration);
        set_string_prop(env, obj, "durationFormat", meta.duration_format);
        set_string_prop(env, obj, "title", meta.title);
        set_string_prop(env, obj, "artist", meta.artist);
        set_string_prop(env, obj, "composer", meta.composer);
        set_string_prop(env, obj, "album", meta.album);
        set_string_prop(env, obj, "albumArtist", meta.album_artist);
        set_string_prop(env, obj, "genre", meta.genre);
    } else {
        set_string_prop(env, obj, "error", meta.error_message);
    }

    return obj;
}

// ============================================================================
// 单文件异步上下文
// ============================================================================
struct GetMetaContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::string file_path;
    SingleMetaResult result;
};

// ============================================================================
// 单文件异步工作流
// ============================================================================
static void execute_get_meta(napi_env env, void* data) {
    auto* ctx = static_cast<GetMetaContext*>(data);
    ctx->result = extract_single_meta(ctx->file_path);
}

static void complete_get_meta(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<GetMetaContext*>(data);

    if (status == napi_ok) {
        napi_value obj = meta_result_to_napi(env, ctx->result);
        napi_resolve_deferred(env, ctx->deferred, obj);
    } else {
        napi_value error;
        std::string msg = "获取元数据失败";
        napi_create_string_utf8(env, msg.c_str(), msg.length(), &error);
        napi_reject_deferred(env, ctx->deferred, error);
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

static napi_value get_audio_metadata_single(napi_env env, napi_callback_info info) {
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
    size_t str_size = 0;
    napi_status stat = napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_size);
    if (stat != napi_ok || str_size == 0) {
        napi_throw_error(env, nullptr, "字符串解析失败");
        return nullptr;
    }

    std::string file_path(str_size, '\0');
    napi_get_value_string_utf8(env, args[0], &file_path[0], str_size + 1, &str_size);

    // 4. 创建异步上下文
    auto* ctx = new GetMetaContext();
    ctx->file_path = file_path;

    // 5. 创建 Promise
    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    // 6. 创建异步工作项
    napi_value resource_name;
    napi_create_string_utf8(env, "GetAudioMetadata", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           execute_get_meta, complete_get_meta,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}

// ============================================================================
// 批量异步上下文
// ============================================================================
struct BatchMetaContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::vector<std::string> input_paths;
    std::vector<SingleMetaResult> results;
};

// ============================================================================
// 批量多线程工作流
// ============================================================================
static void worker_thread(const std::vector<std::string>* paths,
                          std::vector<SingleMetaResult>* results,
                          size_t start, size_t end,
                          std::mutex* result_mutex) {
    for (size_t i = start; i < end; i++) {
        SingleMetaResult meta = extract_single_meta((*paths)[i]);
        {
            std::lock_guard<std::mutex> lock(*result_mutex);
            (*results)[i] = meta;
        }
    }
}

static void execute_get_meta_batch(napi_env env, void* data) {
    auto* ctx = static_cast<BatchMetaContext*>(data);
    const size_t total = ctx->input_paths.size();

    ctx->results.resize(total);

    unsigned int thread_count = std::thread::hardware_concurrency();
    if (thread_count < 1) { thread_count = 1; }
    if (thread_count > 8) { thread_count = 8; }
    if (thread_count > total) { thread_count = static_cast<unsigned int>(total); }

    std::mutex result_mutex;
    std::vector<std::thread> threads;

    size_t chunk_size = total / thread_count;
    size_t remainder = total % thread_count;
    size_t offset = 0;

    for (unsigned int t = 0; t < thread_count; t++) {
        size_t count = chunk_size + (t < remainder ? 1 : 0);
        if (count == 0) { continue; }
        threads.emplace_back(worker_thread,
            &ctx->input_paths, &ctx->results,
            offset, offset + count,
            &result_mutex);
        offset += count;
    }

    for (auto& t : threads) {
        t.join();
    }
}

static void complete_get_meta_batch(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<BatchMetaContext*>(data);

    if (status == napi_ok) {
        napi_value result_array;
        napi_create_array_with_length(env, ctx->results.size(), &result_array);

        for (size_t i = 0; i < ctx->results.size(); i++) {
            napi_value obj = meta_result_to_napi(env, ctx->results[i]);
            napi_set_element(env, result_array, i, obj);
        }

        napi_resolve_deferred(env, ctx->deferred, result_array);
    } else {
        napi_value error;
        std::string msg = "批量获取元数据失败";
        napi_create_string_utf8(env, msg.c_str(), msg.length(), &error);
        napi_reject_deferred(env, ctx->deferred, error);
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

static napi_value get_audio_metadata_batch(napi_env env, napi_callback_info info) {
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

    if (length == 0) {
        napi_throw_error(env, nullptr, "文件路径数组不能为空");
        return nullptr;
    }

    // 4. 提取文件路径列表
    std::vector<std::string> paths;
    paths.reserve(length);
    for (uint32_t i = 0; i < length; i++) {
        napi_value elem;
        napi_get_element(env, args[0], i, &elem);

        size_t str_size = 0;
        napi_status s = napi_get_value_string_utf8(env, elem, nullptr, 0, &str_size);
        if (s != napi_ok) { continue; }

        std::string str(str_size, '\0');
        napi_get_value_string_utf8(env, elem, &str[0], str_size + 1, &str_size);
        paths.push_back(str);
    }

    if (paths.empty()) {
        napi_throw_error(env, nullptr, "文件路径数组解析后为空");
        return nullptr;
    }

    // 5. 创建异步上下文
    auto* ctx = new BatchMetaContext();
    ctx->input_paths = std::move(paths);

    // 6. 创建 Promise
    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    // 7. 创建异步工作项
    napi_value resource_name;
    napi_create_string_utf8(env, "GetAudioMetadataBatch", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           execute_get_meta_batch, complete_get_meta_batch,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}

// ============================================================================
// GetAudioMetadata 入口：自动识别单文件/批量
// ============================================================================
napi_value GetAudioMetadata(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入文件路径字符串或字符串数组");
        return nullptr;
    }

    // 判断参数类型
    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);

    if (valuetype == napi_string) {
        return get_audio_metadata_single(env, info);
    }

    bool is_array = false;
    napi_is_array(env, args[0], &is_array);
    if (is_array) {
        return get_audio_metadata_batch(env, info);
    }

    napi_throw_error(env, nullptr, "参数类型必须是字符串或字符串数组");
    return nullptr;
}
