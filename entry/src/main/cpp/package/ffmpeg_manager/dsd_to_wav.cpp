#include "ffmpeg_manager.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
}

#include <cstdint>
#include <cmath>

struct DsdToWavContext {
    napi_async_work async_work;
    napi_deferred deferred;
    std::string input_path;
    std::string output_path;
    bool success;
    std::string error_message;
};

// 将解码帧转换为 352800Hz / AV_SAMPLE_FMT_FLT 的帧
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

// 将解码后的帧送入编码器（必要时转换到 352.8kHz / FLT）
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

static void ExecuteDsdToWav(napi_env env, void* data) {
    auto* ctx = static_cast<DsdToWavContext*>(data);

    AVFormatContext* in_fmt_ctx = nullptr;
    AVFormatContext* out_fmt_ctx = nullptr;
    AVCodecContext* dec_ctx = nullptr;
    AVCodecContext* enc_ctx = nullptr;
    AVStream* out_stream = nullptr;
    AVPacket* pkt = nullptr;
    AVFrame* frame = nullptr;
    int audio_stream_idx = -1;

    // 1. 打开输入文件
    if (avformat_open_input(&in_fmt_ctx, ctx->input_path.c_str(), nullptr, nullptr) < 0) {
        ctx->success = false;
        ctx->error_message = "无法打开输入文件";
        return;
    }

    if (avformat_find_stream_info(in_fmt_ctx, nullptr) < 0) {
        ctx->success = false;
        ctx->error_message = "无法获取流信息";
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 2. 查找音频流
    audio_stream_idx = av_find_best_stream(in_fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_idx < 0) {
        ctx->success = false;
        ctx->error_message = "未找到音频流";
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    AVStream* in_stream = in_fmt_ctx->streams[audio_stream_idx];
    const AVCodec* decoder = avcodec_find_decoder(in_stream->codecpar->codec_id);
    if (!decoder) {
        ctx->success = false;
        ctx->error_message = "找不到解码器";
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    dec_ctx = avcodec_alloc_context3(decoder);
    if (!dec_ctx) {
        ctx->success = false;
        ctx->error_message = "无法分配解码器上下文";
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    if (avcodec_parameters_to_context(dec_ctx, in_stream->codecpar) < 0) {
        ctx->success = false;
        ctx->error_message = "无法复制解码参数";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 请求解码器输出 FLT 格式
    dec_ctx->request_sample_fmt = AV_SAMPLE_FMT_FLT;
    int dec_sample_rate = dec_ctx->sample_rate;

    if (avcodec_open2(dec_ctx, decoder, nullptr) < 0) {
        ctx->success = false;
        ctx->error_message = "无法打开解码器";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 解码器打开后 sample_rate 可能已更新
    dec_sample_rate = dec_ctx->sample_rate;

    // 3. 创建输出上下文 (WAV)
    if (avformat_alloc_output_context2(&out_fmt_ctx, nullptr, "wav", ctx->output_path.c_str()) < 0) {
        ctx->success = false;
        ctx->error_message = "无法创建输出上下文";
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 4. 查找编码器 (PCM_F32LE = 32bit float)
    const AVCodec* encoder = avcodec_find_encoder(AV_CODEC_ID_PCM_F32LE);
    if (!encoder) {
        ctx->success = false;
        ctx->error_message = "找不到编码器";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    out_stream = avformat_new_stream(out_fmt_ctx, nullptr);
    if (!out_stream) {
        ctx->success = false;
        ctx->error_message = "无法创建输出流";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    enc_ctx = avcodec_alloc_context3(encoder);
    if (!enc_ctx) {
        ctx->success = false;
        ctx->error_message = "无法分配编码器上下文";
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 强制 352.8kHz / 32bit float
    enc_ctx->sample_rate = 352800;
    av_channel_layout_default(&enc_ctx->ch_layout, dec_ctx->ch_layout.nb_channels);
    enc_ctx->sample_fmt = AV_SAMPLE_FMT_FLT;
    enc_ctx->time_base = AVRational{1, 352800};

    if (out_fmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
        enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    if (avcodec_open2(enc_ctx, encoder, nullptr) < 0) {
        ctx->success = false;
        ctx->error_message = "无法打开编码器";
        avcodec_free_context(&enc_ctx);
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    if (avcodec_parameters_from_context(out_stream->codecpar, enc_ctx) < 0) {
        ctx->success = false;
        ctx->error_message = "无法设置输出流参数";
        avcodec_free_context(&enc_ctx);
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    out_stream->time_base = enc_ctx->time_base;

    // 5. 打开输出文件
    if (avio_open(&out_fmt_ctx->pb, ctx->output_path.c_str(), AVIO_FLAG_WRITE) < 0) {
        ctx->success = false;
        ctx->error_message = "无法打开输出文件";
        avcodec_free_context(&enc_ctx);
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    if (avformat_write_header(out_fmt_ctx, nullptr) < 0) {
        ctx->success = false;
        ctx->error_message = "无法写入文件头";
        avio_closep(&out_fmt_ctx->pb);
        avcodec_free_context(&enc_ctx);
        avformat_free_context(out_fmt_ctx);
        avcodec_free_context(&dec_ctx);
        avformat_close_input(&in_fmt_ctx);
        return;
    }

    // 6. 读取、解码、编码、写入循环
    pkt = av_packet_alloc();
    frame = av_frame_alloc();
    if (!pkt || !frame) {
        ctx->success = false;
        ctx->error_message = "无法分配数据包/帧";
        goto cleanup;
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
        if (!out_pkt) goto cleanup;

        int ret = avcodec_receive_packet(enc_ctx, out_pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            av_packet_free(&out_pkt);
            break;
        }
        if (ret < 0) {
            av_packet_free(&out_pkt);
            goto cleanup;
        }

        out_pkt->stream_index = out_stream->index;
        av_packet_rescale_ts(out_pkt, enc_ctx->time_base, out_stream->time_base);
        av_interleaved_write_frame(out_fmt_ctx, out_pkt);
        av_packet_free(&out_pkt);
    }

    av_write_trailer(out_fmt_ctx);
    ctx->success = true;

cleanup:
    av_packet_free(&pkt);
    av_frame_free(&frame);
    avio_closep(&out_fmt_ctx->pb);
    avcodec_free_context(&enc_ctx);
    avformat_free_context(out_fmt_ctx);
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&in_fmt_ctx);

    if (!ctx->success && ctx->error_message.empty()) {
        ctx->error_message = "转换过程中发生错误";
    }
}

static void CompleteDsdToWav(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<DsdToWavContext*>(data);

    if (status == napi_ok) {
        if (ctx->success) {
            napi_value result;
            napi_get_undefined(env, &result);
            napi_resolve_deferred(env, ctx->deferred, result);
        } else {
            napi_value error;
            napi_create_string_utf8(env, ctx->error_message.c_str(), ctx->error_message.length(), &error);
            napi_reject_deferred(env, ctx->deferred, error);
        }
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

// DSD 文件转 WAV（异步）
// 参数1: DSD 文件路径 (string)
// 参数2: 输出 WAV 文件路径 (string)
// 返回: Promise<void>
napi_value DsdToWav(napi_env env, napi_callback_info info) {
    // 1. 获取参数
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "需要传入输入路径和输出路径两个字符串参数");
        return nullptr;
    }

    // 2. 校验参数类型
    for (int i = 0; i < 2; i++) {
        napi_valuetype valuetype;
        napi_typeof(env, args[i], &valuetype);
        if (valuetype != napi_string) {
            napi_throw_error(env, nullptr, "参数类型必须是字符串");
            return nullptr;
        }
    }

    // 3. 读取输入路径
    size_t strSize = 0;
    napi_status status = napi_get_value_string_utf8(env, args[0], nullptr, 0, &strSize);
    if (status != napi_ok || strSize == 0) {
        napi_throw_error(env, nullptr, "输入路径解析失败");
        return nullptr;
    }
    std::string inputPath(strSize, '\0');
    napi_get_value_string_utf8(env, args[0], &inputPath[0], strSize + 1, &strSize);

    // 4. 读取输出路径
    strSize = 0;
    status = napi_get_value_string_utf8(env, args[1], nullptr, 0, &strSize);
    if (status != napi_ok || strSize == 0) {
        napi_throw_error(env, nullptr, "输出路径解析失败");
        return nullptr;
    }
    std::string outputPath(strSize, '\0');
    napi_get_value_string_utf8(env, args[1], &outputPath[0], strSize + 1, &strSize);

    // 5. 创建异步上下文
    auto* ctx = new DsdToWavContext();
    ctx->input_path = inputPath;
    ctx->output_path = outputPath;
    ctx->success = false;

    // 6. 创建 Promise
    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    // 7. 创建异步工作项
    napi_value resource_name;
    napi_create_string_utf8(env, "DsdToWav", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           ExecuteDsdToWav, CompleteDsdToWav,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}
