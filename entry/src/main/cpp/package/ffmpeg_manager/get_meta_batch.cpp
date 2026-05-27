#include "get_meta_batch.h"

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

// --- 单文件元数据结果 ---
struct SingleMetaResult {
    bool success;
    std::string error_message;
    std::string file_path;

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

// --- 辅助函数：安全读取标签 ---
static std::string get_tag_batch(const AVDictionary* metadata, const char* key) {
    if (!metadata) { return ""; }
    const AVDictionaryEntry* entry = av_dict_get(metadata, key, nullptr, 0);
    return entry ? std::string(entry->value) : "";
}

// --- 辅助函数：提取文件名 ---
static std::string extract_filename_batch(const std::string& filePath) {
    size_t pos = filePath.find_last_of("/\\");
    if (pos != std::string::npos) { return filePath.substr(pos + 1); }
    return filePath;
}

// --- 单文件元数据提取（线程安全）---
static SingleMetaResult extract_single_meta(const std::string& file_path) {
    SingleMetaResult result;
    result.success = false;
    result.file_path = file_path;
    result.channels = 0;
    result.sample_rate = 0;
    result.bit_depth = 0;
    result.bitrate = 0;
    result.duration = 0.0;

    AVFormatContext* formatCtx = nullptr;

    if (avformat_open_input(&formatCtx, file_path.c_str(), nullptr, nullptr) != 0) {
        result.error_message = "无法打开音频文件";
        return result;
    }

    if (avformat_find_stream_info(formatCtx, nullptr) < 0) {
        avformat_close_input(&formatCtx);
        result.error_message = "无法获取流信息";
        return result;
    }

    int audioStreamIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audioStreamIndex < 0) {
        avformat_close_input(&formatCtx);
        result.error_message = "未找到音频流";
        return result;
    }

    AVStream* audioStream = formatCtx->streams[audioStreamIndex];
    AVCodecParameters* codecPar = audioStream->codecpar;

    result.filename = extract_filename_batch(file_path);
    result.channels = codecPar->ch_layout.nb_channels;
    result.sample_rate = codecPar->sample_rate;

    // 位深（DSD 特殊处理）
    if (codecPar->codec_id == AV_CODEC_ID_DSD_LSBF ||
        codecPar->codec_id == AV_CODEC_ID_DSD_MSBF ||
        codecPar->codec_id == AV_CODEC_ID_DSD_LSBF_PLANAR ||
        codecPar->codec_id == AV_CODEC_ID_DSD_MSBF_PLANAR) {
        result.bit_depth = 1;
    } else {
        int bits = codecPar->bits_per_raw_sample;
        if (bits <= 0) { bits = codecPar->bits_per_coded_sample; }
        if (bits <= 0) { bits = av_get_bytes_per_sample(static_cast<AVSampleFormat>(codecPar->format)) * 8; }
        result.bit_depth = bits;
    }

    // 比特率
    result.bitrate = 0;
    if (codecPar->bit_rate > 0) {
        result.bitrate = codecPar->bit_rate;
    } else if (formatCtx->bit_rate > 0) {
        result.bitrate = formatCtx->bit_rate;
    }

    // 时长
    result.duration = 0.0;
    if (formatCtx->duration > 0 && formatCtx->duration != AV_NOPTS_VALUE) {
        result.duration = static_cast<double>(formatCtx->duration) / AV_TIME_BASE;
    } else if (audioStream->duration > 0 && audioStream->duration != AV_NOPTS_VALUE) {
        result.duration = static_cast<double>(audioStream->duration) * av_q2d(audioStream->time_base);
    }

    // 元数据标签
    AVDictionary* metadata = formatCtx->metadata;
    result.title = get_tag_batch(metadata, "title");
    result.artist = get_tag_batch(metadata, "artist");
    result.composer = get_tag_batch(metadata, "composer");
    result.album = get_tag_batch(metadata, "album");
    result.album_artist = get_tag_batch(metadata, "album_artist");
    result.genre = get_tag_batch(metadata, "genre");

    avformat_close_input(&formatCtx);
    result.success = true;
    return result;
}

// --- 批量处理上下文 ---
struct BatchMetaContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::vector<std::string> input_paths;
    std::vector<SingleMetaResult> results;
};

// --- 辅助：设置对象字符串属性 ---
static void set_string_prop_batch(napi_env env, napi_value obj, const char* key, const std::string& val) {
    napi_value napiVal;
    napi_create_string_utf8(env, val.c_str(), val.length(), &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

// --- 辅助：设置对象数字属性 ---
static void set_number_prop_batch(napi_env env, napi_value obj, const char* key, double val) {
    napi_value napiVal;
    napi_create_double(env, val, &napiVal);
    napi_set_named_property(env, obj, key, napiVal);
}

// --- 辅助：将 SingleMetaResult 转换为 napi_value ---
static napi_value meta_result_to_napi(napi_env env, const SingleMetaResult& meta) {
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value success_val;
    napi_get_boolean(env, meta.success, &success_val);
    napi_set_named_property(env, obj, "success", success_val);
    set_string_prop_batch(env, obj, "filePath", meta.file_path);

    if (meta.success) {
        set_string_prop_batch(env, obj, "filename", meta.filename);
        set_number_prop_batch(env, obj, "channels", meta.channels);
        set_number_prop_batch(env, obj, "sampleRate", meta.sample_rate);
        set_number_prop_batch(env, obj, "bitDepth", meta.bit_depth);
        set_number_prop_batch(env, obj, "bitrate", static_cast<double>(meta.bitrate));
        set_number_prop_batch(env, obj, "duration", meta.duration);
        set_string_prop_batch(env, obj, "title", meta.title);
        set_string_prop_batch(env, obj, "artist", meta.artist);
        set_string_prop_batch(env, obj, "composer", meta.composer);
        set_string_prop_batch(env, obj, "album", meta.album);
        set_string_prop_batch(env, obj, "albumArtist", meta.album_artist);
        set_string_prop_batch(env, obj, "genre", meta.genre);
    } else {
        set_string_prop_batch(env, obj, "error", meta.error_message);
    }

    return obj;
}

// --- 线程工作函数：处理 [start, end) 范围的文件 ---
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

// --- NAPI 异步执行体 ---
static void ExecuteGetMetaBatch(napi_env env, void* data) {
    auto* ctx = static_cast<BatchMetaContext*>(data);
    const size_t total = ctx->input_paths.size();

    ctx->results.resize(total);

    // 确定线程数
    unsigned int thread_count = std::thread::hardware_concurrency();
    if (thread_count < 1) { thread_count = 1; }
    if (thread_count > 8) { thread_count = 8; } // 上限，避免 I/O 争抢
    if (thread_count > total) { thread_count = static_cast<unsigned int>(total); }

    std::mutex result_mutex;
    std::vector<std::thread> threads;

    // 按线程均分文件
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

    // 等待所有线程完成
    for (auto& t : threads) {
        t.join();
    }
}

// --- NAPI 完成回调 ---
static void CompleteGetMetaBatch(napi_env env, napi_status status, void* data) {
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

// 批量获取音频的元数据（多线程异步）
// 参数: 文件路径数组 (string[])
// 返回: Promise<object[]>
napi_value GetAudioMetadataBatch(napi_env env, napi_callback_info info) {
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
                           ExecuteGetMetaBatch, CompleteGetMetaBatch,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}
