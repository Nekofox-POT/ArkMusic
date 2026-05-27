#include "dsd_to_wav_batch.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
}

#include <cstdint>
#include <cmath>
#include <thread>
#include <mutex>
#include <vector>

// --- 单任务输入 ---
struct DsdTask {
    std::string input_path;
    std::string output_path;
};

// --- 单文件转换结果 ---
struct DsdResult {
    std::string input_path;
    bool success;
    std::string error_message;
};

// --- 将解码帧转换为 352800Hz / AV_SAMPLE_FMT_FLT 的帧 ---
static AVFrame* convert_frame(AVFrame* src, int src_rate, int dst_rate) {
    AVFrame* dst = av_frame_alloc();
    dst->format = AV_SAMPLE_FMT_FLT;
    av_channel_layout_copy(&dst->ch_layout, &src->ch_layout);
    dst->sample_rate = dst_rate;
    dst->nb_samples = (int)((int64_t)src->nb_samples * dst_rate / src_rate);
    if (dst->nb_samples < 1) dst->nb_samples = 1;
    av_frame_get_buffer(dst, 0);

    int channels = dst->ch_layout.nb_channels;
    int src_fmt = src->format;
    int dst_nb = dst->nb_samples;
    int src_nb = src->nb_samples;
    bool is_planar = av_sample_fmt_is_planar((AVSampleFormat)src_fmt);

    for (int ch = 0; ch < channels; ch++) {
        float* d = (float*)dst->data[0];
        uint8_t* s = is_planar ? src->data[ch] : src->data[0];
        int s_stride = is_planar ? 1 : channels;
        int s_idx = is_planar ? 0 : ch;

        for (int i = 0; i < dst_nb; i++) {
            int si = (int)((int64_t)i * src_rate / dst_rate);
            if (si >= src_nb) si = src_nb - 1;

            float val = 0.0f;
            switch (src_fmt) {
            case AV_SAMPLE_FMT_FLT:
            case AV_SAMPLE_FMT_FLTP:
                val = ((float*)s)[si * s_stride + s_idx]; break;
            case AV_SAMPLE_FMT_S32:
            case AV_SAMPLE_FMT_S32P:
                val = ((int32_t*)s)[si * s_stride + s_idx] / 2147483648.0f; break;
            case AV_SAMPLE_FMT_S16:
            case AV_SAMPLE_FMT_S16P:
                val = ((int16_t*)s)[si * s_stride + s_idx] / 32768.0f; break;
            case AV_SAMPLE_FMT_U8:
            case AV_SAMPLE_FMT_U8P:
                val = (((uint8_t*)s)[si * s_stride + s_idx] - 128) / 128.0f; break;
            case AV_SAMPLE_FMT_DBL:
            case AV_SAMPLE_FMT_DBLP:
                val = (float)((double*)s)[si * s_stride + s_idx]; break;
            case AV_SAMPLE_FMT_S64:
            case AV_SAMPLE_FMT_S64P:
                val = ((int64_t*)s)[si * s_stride + s_idx] / 9223372036854775808.0f; break;
            default: break;
            }
            d[i * channels + ch] = val;
        }
    }

    dst->pts = src->pts;
    return dst;
}

// --- 将解码后的帧送入编码器（必要时转换到 352.8kHz / FLT）---
static int encode_frame(AVCodecContext* enc_ctx, AVStream* out_stream,
                         AVFormatContext* out_fmt_ctx, AVFrame* frame,
                         int dec_rate) {
    static const int TARGET_RATE = 352800;
    AVFrame* converted = nullptr;

    if (frame->format != AV_SAMPLE_FMT_FLT || dec_rate != TARGET_RATE) {
        converted = convert_frame(frame, dec_rate, TARGET_RATE);
        frame = converted;
    }

    int ret = avcodec_send_frame(enc_ctx, frame);

    if (converted) {
        av_frame_free(&converted);
    }

    if (ret < 0) return ret;

    while (true) {
        AVPacket* out_pkt = av_packet_alloc();
        if (!out_pkt) return AVERROR(ENOMEM);

        ret = avcodec_receive_packet(enc_ctx, out_pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            av_packet_free(&out_pkt);
            return 0;
        }
        if (ret < 0) {
            av_packet_free(&out_pkt);
            return ret;
        }

        out_pkt->stream_index = out_stream->index;
        av_packet_rescale_ts(out_pkt, enc_ctx->time_base, out_stream->time_base);
        av_interleaved_write_frame(out_fmt_ctx, out_pkt);
        av_packet_free(&out_pkt);
    }

    return 0;
}

// --- 单文件 DSD→WAV 转换（完全独立的 FFmpeg 管道）---
static DsdResult convert_single_dsd(const DsdTask& task) {
    DsdResult result;
    result.input_path = task.input_path;
    result.success = false;

    AVFormatContext* in_fmt_ctx = nullptr;
    AVFormatContext* out_fmt_ctx = nullptr;
    AVCodecContext* dec_ctx = nullptr;
    AVCodecContext* enc_ctx = nullptr;
    AVStream* out_stream = nullptr;
    AVPacket* pkt = nullptr;
    AVFrame* frame = nullptr;
    int audio_stream_idx = -1;

    // 1. 打开输入文件
    if (avformat_open_input(&in_fmt_ctx, task.input_path.c_str(), nullptr, nullptr) < 0) {
        result.error_message = "无法打开输入文件";
        return result;
    }

    if (avformat_find_stream_info(in_fmt_ctx, nullptr) < 0) {
        result.error_message = "无法获取流信息";
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    // 2. 查找音频流
    audio_stream_idx = av_find_best_stream(in_fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_idx < 0) {
        result.error_message = "未找到音频流";
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    AVStream* in_stream = in_fmt_ctx->streams[audio_stream_idx];
    const AVCodec* decoder = avcodec_find_decoder(in_stream->codecpar->codec_id);
    if (!decoder) {
        result.error_message = "找不到解码器";
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    dec_ctx = avcodec_alloc_context3(decoder);
    if (!dec_ctx) {
        result.error_message = "无法分配解码器上下文";
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    if (avcodec_parameters_to_context(dec_ctx, in_stream->codecpar) < 0) {
        result.error_message = "无法复制解码参数";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    dec_ctx->request_sample_fmt = AV_SAMPLE_FMT_FLT;
    int dec_sample_rate = dec_ctx->sample_rate;

    if (avcodec_open2(dec_ctx, decoder, nullptr) < 0) {
        result.error_message = "无法打开解码器";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    dec_sample_rate = dec_ctx->sample_rate;

    // 3. 创建输出上下文 (WAV)
    if (avformat_alloc_output_context2(&out_fmt_ctx, nullptr, "wav", task.output_path.c_str()) < 0) {
        result.error_message = "无法创建输出上下文";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    // 4. 查找编码器 (PCM_F32LE)
    const AVCodec* encoder = avcodec_find_encoder(AV_CODEC_ID_PCM_F32LE);
    if (!encoder) {
        result.error_message = "找不到编码器";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    out_stream = avformat_new_stream(out_fmt_ctx, nullptr);
    if (!out_stream) {
        result.error_message = "无法创建输出流";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    enc_ctx = avcodec_alloc_context3(encoder);
    if (!enc_ctx) {
        result.error_message = "无法分配编码器上下文";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return result;
    }

    enc_ctx->sample_rate = 352800;
    av_channel_layout_default(&enc_ctx->ch_layout, dec_ctx->ch_layout.nb_channels);
    enc_ctx->sample_fmt = AV_SAMPLE_FMT_FLT;
    enc_ctx->time_base = AVRational{1, 352800};

    if (out_fmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
        enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    if (avcodec_open2(enc_ctx, encoder, nullptr) < 0) {
        result.error_message = "无法打开编码器";
        goto cleanup_all;
    }

    if (avcodec_parameters_from_context(out_stream->codecpar, enc_ctx) < 0) {
        result.error_message = "无法设置输出流参数";
        goto cleanup_all;
    }

    out_stream->time_base = enc_ctx->time_base;

    // 5. 打开输出文件
    if (avio_open(&out_fmt_ctx->pb, task.output_path.c_str(), AVIO_FLAG_WRITE) < 0) {
        result.error_message = "无法打开输出文件";
        goto cleanup_all;
    }

    if (avformat_write_header(out_fmt_ctx, nullptr) < 0) {
        result.error_message = "无法写入文件头";
        goto cleanup_all;
    }

    // 6. 读取、解码、编码、写入循环
    pkt = av_packet_alloc();
    frame = av_frame_alloc();
    if (!pkt || !frame) {
        result.error_message = "无法分配数据包/帧";
        goto cleanup_all;
    }

    while (av_read_frame(in_fmt_ctx, pkt) >= 0) {
        if (pkt->stream_index != audio_stream_idx) {
            av_packet_unref(pkt);
            continue;
        }

        if (avcodec_send_packet(dec_ctx, pkt) < 0) {
            av_packet_unref(pkt);
            continue;
        }

        while (avcodec_receive_frame(dec_ctx, frame) >= 0) {
            frame->pts = frame->best_effort_timestamp;
            encode_frame(enc_ctx, out_stream, out_fmt_ctx, frame, dec_sample_rate);
            av_frame_unref(frame);
        }

        av_packet_unref(pkt);
    }

    // 7. 刷新解码器
    avcodec_send_packet(dec_ctx, nullptr);
    while (avcodec_receive_frame(dec_ctx, frame) >= 0) {
        frame->pts = frame->best_effort_timestamp;
        encode_frame(enc_ctx, out_stream, out_fmt_ctx, frame, dec_sample_rate);
        av_frame_unref(frame);
    }

    // 8. 刷新编码器
    avcodec_send_frame(enc_ctx, nullptr);
    while (true) {
        AVPacket* out_pkt = av_packet_alloc();
        if (!out_pkt) break;

        int ret = avcodec_receive_packet(enc_ctx, out_pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            av_packet_free(&out_pkt);
            break;
        }
        if (ret < 0) {
            av_packet_free(&out_pkt);
            break;
        }

        out_pkt->stream_index = out_stream->index;
        av_packet_rescale_ts(out_pkt, enc_ctx->time_base, out_stream->time_base);
        av_interleaved_write_frame(out_fmt_ctx, out_pkt);
        av_packet_free(&out_pkt);
    }

    av_write_trailer(out_fmt_ctx);
    result.success = true;

cleanup_all:
    av_packet_free(&pkt);
    av_frame_free(&frame);
    if (out_fmt_ctx) {
        avio_closep(&out_fmt_ctx->pb);
    }
    avcodec_free_context(&enc_ctx);
    avformat_free_context(out_fmt_ctx);
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&in_fmt_ctx);

    if (!result.success && result.error_message.empty()) {
        result.error_message = "转换过程中发生错误";
    }
    return result;
}

// --- 批量处理上下文 ---
struct BatchDsdContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::vector<DsdTask> tasks;
    std::vector<DsdResult> results;
};

// --- 线程工作函数 ---
static void dsd_worker_thread(const std::vector<DsdTask>* tasks,
                               std::vector<DsdResult>* results,
                               size_t start, size_t end,
                               std::mutex* result_mutex) {
    for (size_t i = start; i < end; i++) {
        DsdResult res = convert_single_dsd((*tasks)[i]);
        {
            std::lock_guard<std::mutex> lock(*result_mutex);
            (*results)[i] = res;
        }
    }
}

// --- NAPI 异步执行体 ---
static void ExecuteDsdToWavBatch(napi_env env, void* data) {
    auto* ctx = static_cast<BatchDsdContext*>(data);
    const size_t total = ctx->tasks.size();

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
        threads.emplace_back(dsd_worker_thread,
            &ctx->tasks, &ctx->results,
            offset, offset + count,
            &result_mutex);
        offset += count;
    }

    for (auto& t : threads) {
        t.join();
    }
}

// --- NAPI 完成回调 ---
static void CompleteDsdToWavBatch(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<BatchDsdContext*>(data);

    if (status == napi_ok) {
        napi_value result_array;
        napi_create_array_with_length(env, ctx->results.size(), &result_array);

        for (size_t i = 0; i < ctx->results.size(); i++) {
            napi_value obj;
            napi_create_object(env, &obj);

            // inputPath
            napi_value path_val;
            napi_create_string_utf8(env, ctx->results[i].input_path.c_str(),
                                    ctx->results[i].input_path.length(), &path_val);
            napi_set_named_property(env, obj, "inputPath", path_val);

            // success
            napi_value success_val;
            napi_get_boolean(env, ctx->results[i].success, &success_val);
            napi_set_named_property(env, obj, "success", success_val);

            // error (if failed)
            if (!ctx->results[i].success) {
                napi_value err_val;
                napi_create_string_utf8(env, ctx->results[i].error_message.c_str(),
                                        ctx->results[i].error_message.length(), &err_val);
                napi_set_named_property(env, obj, "error", err_val);
            }

            napi_set_element(env, result_array, i, obj);
        }

        napi_resolve_deferred(env, ctx->deferred, result_array);
    } else {
        napi_value error;
        std::string msg = "批量 DSD 转换失败";
        napi_create_string_utf8(env, msg.c_str(), msg.length(), &error);
        napi_reject_deferred(env, ctx->deferred, error);
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

// 批量 DSD 文件转 WAV（多线程异步）
// 参数: Array<{inputPath: string, outputPath: string}>
// 返回: Promise<Array<{inputPath: string, success: boolean}>>
napi_value DsdToWavBatch(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入任务数组参数");
        return nullptr;
    }

    // 2. 校验数组类型
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
        napi_throw_error(env, nullptr, "任务数组不能为空");
        return nullptr;
    }

    // 4. 解析任务数组
    std::vector<DsdTask> tasks;
    tasks.reserve(length);

    for (uint32_t i = 0; i < length; i++) {
        napi_value elem;
        napi_get_element(env, args[0], i, &elem);

        // 校验元素是否为对象
        napi_valuetype val_type;
        napi_typeof(env, elem, &val_type);
        if (val_type != napi_object) {
            napi_throw_error(env, nullptr, "数组元素必须是对象");
            return nullptr;
        }

        DsdTask task;

        // 读取 inputPath
        napi_value ip_val;
        if (napi_get_named_property(env, elem, "inputPath", &ip_val) == napi_ok) {
            size_t str_size = 0;
            napi_get_value_string_utf8(env, ip_val, nullptr, 0, &str_size);
            task.input_path.resize(str_size);
            napi_get_value_string_utf8(env, ip_val, &task.input_path[0], str_size + 1, &str_size);
        }

        // 读取 outputPath
        napi_value op_val;
        if (napi_get_named_property(env, elem, "outputPath", &op_val) == napi_ok) {
            size_t str_size = 0;
            napi_get_value_string_utf8(env, op_val, nullptr, 0, &str_size);
            task.output_path.resize(str_size);
            napi_get_value_string_utf8(env, op_val, &task.output_path[0], str_size + 1, &str_size);
        }

        if (task.input_path.empty() || task.output_path.empty()) {
            napi_throw_error(env, nullptr, "任务的 inputPath 或 outputPath 为空");
            return nullptr;
        }

        tasks.push_back(std::move(task));
    }

    // 5. 创建异步上下文
    auto* ctx = new BatchDsdContext();
    ctx->tasks = std::move(tasks);

    // 6. 创建 Promise
    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    // 7. 创建异步工作项
    napi_value resource_name;
    napi_create_string_utf8(env, "DsdToWavBatch", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           ExecuteDsdToWavBatch, CompleteDsdToWavBatch,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}
