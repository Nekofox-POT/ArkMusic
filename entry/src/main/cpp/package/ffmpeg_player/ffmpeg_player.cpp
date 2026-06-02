#include "ffmpeg_player.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
}

#include <ohaudio/native_audiorenderer.h>
#include <ohaudio/native_audiostreambuilder.h>

#include <cstdint>
#include <cmath>
#include <cstring>
#include <cstdlib>
#include <mutex>
#include <atomic>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ============================================================================
// EQ 常量
// ============================================================================
static const float GEQ_FREQS[10] = {
    31.0f, 62.0f, 125.0f, 250.0f, 500.0f,
    1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
};

enum EqMode {
    EQ_OFF = 0,
    EQ_GEQ = 1,
    EQ_PEQ = 2
};

enum PeqType {
    PEQ_PEAK     = 0,
    PEQ_HIGHPASS = 1,
    PEQ_LOWSHELF = 2,
    PEQ_NOTCH    = 3
};

struct PeqBand {
    bool enabled = false;
    float freq = 1000.0f;
    float gain = 0.0f;      // dB, -12 ~ 12
    float q = 1.0f;
    int type = PEQ_PEAK;
};

// ============================================================================
// Biquad 滤波器状态（每声道独立）
// ============================================================================
struct BiquadState {
    float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
    float a1 = 0.0f, a2 = 0.0f;
    float x1 = 0.0f, x2 = 0.0f;
    float y1 = 0.0f, y2 = 0.0f;
};

// ============================================================================
// 计算 PEQ biquad 系数（RBJ 公式）
// ============================================================================
static void calc_biquad_peak(BiquadState* st, float freq, float sample_rate, float gain_db, float q) {
    float A = powf(10.0f, gain_db / 40.0f);
    float w0 = 2.0f * (float)M_PI * freq / sample_rate;
    float cos_w0 = cosf(w0);
    float sin_w0 = sinf(w0);
    float alpha = sin_w0 / (2.0f * q);

    float b0 =  1.0f + alpha * A;
    float b1 = -2.0f * cos_w0;
    float b2 =  1.0f - alpha * A;
    float a0 =  1.0f + alpha / A;
    float a1_ = -2.0f * cos_w0;
    float a2_ =  1.0f - alpha / A;

    st->b0 = b0 / a0;
    st->b1 = b1 / a0;
    st->b2 = b2 / a0;
    st->a1 = a1_ / a0;
    st->a2 = a2_ / a0;
}

static void calc_biquad_highpass(BiquadState* st, float freq, float sample_rate, float q) {
    float w0 = 2.0f * (float)M_PI * freq / sample_rate;
    float cos_w0 = cosf(w0);
    float sin_w0 = sinf(w0);
    float alpha = sin_w0 / (2.0f * q);

    float b0 = (1.0f + cos_w0) / 2.0f;
    float b1 = -(1.0f + cos_w0);
    float b2 = (1.0f + cos_w0) / 2.0f;
    float a0 =  1.0f + alpha;
    float a1_ = -2.0f * cos_w0;
    float a2_ =  1.0f - alpha;

    st->b0 = b0 / a0;
    st->b1 = b1 / a0;
    st->b2 = b2 / a0;
    st->a1 = a1_ / a0;
    st->a2 = a2_ / a0;
}

static void calc_biquad_lowshelf(BiquadState* st, float freq, float sample_rate, float gain_db, float q) {
    float A = powf(10.0f, gain_db / 40.0f);
    float w0 = 2.0f * (float)M_PI * freq / sample_rate;
    float cos_w0 = cosf(w0);
    float sin_w0 = sinf(w0);
    float alpha = sin_w0 / (2.0f * q);
    float sqrt_A = sqrtf(A);
    float two_sqrtA_alpha = 2.0f * sqrt_A * alpha;

    float b0 =  A * ((A + 1.0f) - (A - 1.0f) * cos_w0 + two_sqrtA_alpha);
    float b1 =  2.0f * A * ((A - 1.0f) - (A + 1.0f) * cos_w0);
    float b2 =  A * ((A + 1.0f) - (A - 1.0f) * cos_w0 - two_sqrtA_alpha);
    float a0 =  (A + 1.0f) + (A - 1.0f) * cos_w0 + two_sqrtA_alpha;
    float a1_ = -2.0f * ((A - 1.0f) + (A + 1.0f) * cos_w0);
    float a2_ =  (A + 1.0f) + (A - 1.0f) * cos_w0 - two_sqrtA_alpha;

    st->b0 = b0 / a0;
    st->b1 = b1 / a0;
    st->b2 = b2 / a0;
    st->a1 = a1_ / a0;
    st->a2 = a2_ / a0;
}

static void calc_biquad_notch(BiquadState* st, float freq, float sample_rate, float q) {
    float w0 = 2.0f * (float)M_PI * freq / sample_rate;
    float cos_w0 = cosf(w0);
    float sin_w0 = sinf(w0);
    float alpha = sin_w0 / (2.0f * q);

    float b0 =  1.0f;
    float b1 = -2.0f * cos_w0;
    float b2 =  1.0f;
    float a0 =  1.0f + alpha;
    float a1_ = -2.0f * cos_w0;
    float a2_ =  1.0f - alpha;

    st->b0 = b0 / a0;
    st->b1 = b1 / a0;
    st->b2 = b2 / a0;
    st->a1 = a1_ / a0;
    st->a2 = a2_ / a0;
}

// 重置 biquad 状态（清除历史值）
static void reset_biquad(BiquadState* st) {
    st->b0 = 1.0f; st->b1 = 0.0f; st->b2 = 0.0f;
    st->a1 = 0.0f; st->a2 = 0.0f;
    st->x1 = 0.0f; st->x2 = 0.0f;
    st->y1 = 0.0f; st->y2 = 0.0f;
}

// 处理单个采样点通过一个 biquad
static inline float process_biquad(BiquadState* st, float x) {
    float y = st->b0 * x + st->b1 * st->x1 + st->b2 * st->x2
            - st->a1 * st->y1 - st->a2 * st->y2;
    st->x2 = st->x1;
    st->x1 = x;
    st->y2 = st->y1;
    st->y1 = y;
    return y;
}

// ============================================================================
// 播放器状态
// ============================================================================
enum PlayState {
    STATE_IDLE    = 0,
    STATE_READY   = 1,
    STATE_PLAYING = 2,
    STATE_PAUSED  = 3
};

// 每个声道一帧的 biquad 状态（最多 10 段 EQ × 8 声道）
#define MAX_EQ_BANDS 10
#define MAX_CHANNELS 8

struct ChannelEqState {
    BiquadState bands[MAX_EQ_BANDS];
};

// ============================================================================
// 播放器上下文（全局单例）
// ============================================================================
struct PlayerContext {
    // OHAudio
    OH_AudioRenderer* renderer = nullptr;

    // FFmpeg 解码
    AVFormatContext* format_ctx = nullptr;
    AVCodecContext* codec_ctx = nullptr;
    AVStream* audio_stream = nullptr;
    int audio_stream_index = -1;
    AVPacket* packet = nullptr;
    AVFrame* frame = nullptr;

    // 状态
    std::atomic<bool> start_ready{false};
    std::atomic<int> play_state{STATE_IDLE};
    std::mutex state_mutex;

    // 输出格式
    int output_sample_rate = 0;
    int output_sample_fmt = 0;       // OH_AudioStream_SampleFormat
    int channels = 0;
    int bytes_per_sample = 2;        // 输出每采样字节数
    int64_t duration_ms = 0;
    bool is_dsd = false;

    // 位置追踪
    std::atomic<int64_t> total_frames_written{0};
    int64_t seek_target_ms = -1;
    std::mutex seek_mutex;

    // ArkTS 时间回调
    napi_threadsafe_function time_callback = nullptr;
    int64_t last_callback_time_ms = 0;

    // ArkTS 准备就绪回调（JS 线程调用，存 napi_ref）
    napi_ref ready_callback_ref = nullptr;

    // ArkTS 状态回调（TSFN，可从音频线程调用）
    napi_threadsafe_function status_callback = nullptr;
    std::atomic<bool> ended_naturally{false};  // 是否自然播放完毕

    // EQ/PEQ
    std::atomic<int> eq_mode{EQ_OFF};
    float eq_gains[10] = {0.0f};
    PeqBand peq_bands[10];
    ChannelEqState eq_state[MAX_CHANNELS];
    std::mutex eq_mutex;
    bool eq_dirty = true;            // 需要重新计算 biquad 系数

    // Resample 缓冲区
    AVFrame* resampled_frame = nullptr;
    int resample_buf_samples = 0;
};
static PlayerContext g_player;

// ============================================================================
// 辅助：判断是否为 DSD codec
// ============================================================================
static bool is_dsd_codec(AVCodecID codec_id) {
    return codec_id == AV_CODEC_ID_DSD_LSBF ||
           codec_id == AV_CODEC_ID_DSD_MSBF ||
           codec_id == AV_CODEC_ID_DSD_LSBF_PLANAR ||
           codec_id == AV_CODEC_ID_DSD_MSBF_PLANAR;
}

// ============================================================================
// 辅助：FFmpeg sample_fmt → OHAudio sample format
// ============================================================================
static int ffmpeg_fmt_to_ohaudio(AVSampleFormat fmt) {
    switch (fmt) {
        case AV_SAMPLE_FMT_U8:   case AV_SAMPLE_FMT_U8P:
            return AUDIOSTREAM_SAMPLE_U8;
        case AV_SAMPLE_FMT_S16:  case AV_SAMPLE_FMT_S16P:
            return AUDIOSTREAM_SAMPLE_S16LE;
        case AV_SAMPLE_FMT_S32:  case AV_SAMPLE_FMT_S32P:
            return AUDIOSTREAM_SAMPLE_S32LE;
        case AV_SAMPLE_FMT_FLT:  case AV_SAMPLE_FMT_FLTP:
            return AUDIOSTREAM_SAMPLE_F32LE;
        case AV_SAMPLE_FMT_S64:  case AV_SAMPLE_FMT_S64P:
            return AUDIOSTREAM_SAMPLE_S32LE;  // 降级
        case AV_SAMPLE_FMT_DBL:  case AV_SAMPLE_FMT_DBLP:
            return AUDIOSTREAM_SAMPLE_F32LE;  // 降级
        default:
            return AUDIOSTREAM_SAMPLE_S16LE;
    }
}

// ============================================================================
// 辅助：OHAudio sample format → 每采样字节数
// ============================================================================
static int ohaudio_bytes_per_sample(int fmt) {
    switch (fmt) {
        case AUDIOSTREAM_SAMPLE_U8:   return 1;
        case AUDIOSTREAM_SAMPLE_S16LE: return 2;
        case AUDIOSTREAM_SAMPLE_S24LE: return 3;
        case AUDIOSTREAM_SAMPLE_S32LE: return 4;
        case AUDIOSTREAM_SAMPLE_F32LE: return 4;
        default: return 2;
    }
}

// ============================================================================
// 释放播放器资源
// ============================================================================
static void release_player() {
    PlayerContext* ctx = &g_player;

    if (ctx->renderer) {
        OH_AudioRenderer_Stop(ctx->renderer);
        OH_AudioRenderer_Release(ctx->renderer);
        ctx->renderer = nullptr;
    }

    av_packet_free(&ctx->packet);
    av_frame_free(&ctx->frame);
    av_frame_free(&ctx->resampled_frame);
    avcodec_free_context(&ctx->codec_ctx);
    avformat_close_input(&ctx->format_ctx);

    ctx->format_ctx = nullptr;
    ctx->codec_ctx = nullptr;
    ctx->audio_stream = nullptr;
    ctx->audio_stream_index = -1;
    ctx->packet = nullptr;
    ctx->frame = nullptr;
    ctx->resampled_frame = nullptr;
    ctx->resample_buf_samples = 0;

    ctx->play_state = STATE_IDLE;
    ctx->total_frames_written = 0;
    ctx->seek_target_ms = -1;
    ctx->is_dsd = false;
    ctx->output_sample_rate = 0;
    ctx->channels = 0;
    ctx->duration_ms = 0;
}

// ============================================================================
// 重新计算 EQ biquad 系数
// ============================================================================
static void rebuild_eq_coefficients() {
    PlayerContext* ctx = &g_player;
    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    int sr = ctx->output_sample_rate;
    if (sr <= 0) { sr = 44100; }

    int eq = ctx->eq_mode.load();
    int ch = ctx->channels;
    if (ch <= 0) { ch = 2; }
    if (ch > MAX_CHANNELS) { ch = MAX_CHANNELS; }

    for (int c = 0; c < ch; c++) {
        for (int i = 0; i < MAX_EQ_BANDS; i++) {
            reset_biquad(&ctx->eq_state[c].bands[i]);
        }
    }

    if (eq == EQ_GEQ) {
        for (int c = 0; c < ch; c++) {
            for (int i = 0; i < MAX_EQ_BANDS; i++) {
                calc_biquad_peak(&ctx->eq_state[c].bands[i],
                    GEQ_FREQS[i], (float)sr, ctx->eq_gains[i], 1.41f);
            }
        }
    } else if (eq == EQ_PEQ) {
        for (int c = 0; c < ch; c++) {
            for (int i = 0; i < MAX_EQ_BANDS; i++) {
                if (!ctx->peq_bands[i].enabled) { continue; }
                BiquadState* st = &ctx->eq_state[c].bands[i];
                switch (ctx->peq_bands[i].type) {
                    case PEQ_PEAK:
                        calc_biquad_peak(st, ctx->peq_bands[i].freq, (float)sr,
                            ctx->peq_bands[i].gain, ctx->peq_bands[i].q);
                        break;
                    case PEQ_HIGHPASS:
                        calc_biquad_highpass(st, ctx->peq_bands[i].freq, (float)sr,
                            ctx->peq_bands[i].q);
                        break;
                    case PEQ_LOWSHELF:
                        calc_biquad_lowshelf(st, ctx->peq_bands[i].freq, (float)sr,
                            ctx->peq_bands[i].gain, ctx->peq_bands[i].q);
                        break;
                    case PEQ_NOTCH:
                        calc_biquad_notch(st, ctx->peq_bands[i].freq, (float)sr,
                            ctx->peq_bands[i].q);
                        break;
                }
            }
        }
    }

    ctx->eq_dirty = false;
}

// ============================================================================
// 对浮点 buffer 应用 EQ
// ============================================================================
static void apply_eq_float(float* samples, int frame_count, int channels) {
    PlayerContext* ctx = &g_player;
    int eq = ctx->eq_mode.load();

    if (eq == EQ_OFF || ctx->is_dsd) { return; }

    if (ctx->eq_dirty) {
        rebuild_eq_coefficients();
    }

    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    int total_samples = frame_count * channels;
    for (int i = 0; i < total_samples; i++) {
        int ch = i % channels;
        float x = samples[i];
        for (int b = 0; b < MAX_EQ_BANDS; b++) {
            BiquadState* st = &ctx->eq_state[ch].bands[b];
            if (st->b0 == 1.0f && st->b1 == 0.0f && st->b2 == 0.0f &&
                st->a1 == 0.0f && st->a2 == 0.0f) {
                continue;  // 未激活的 band
            }
            x = process_biquad(st, x);
        }
        samples[i] = x;
    }
}

// ============================================================================
// 重采样帧（最近邻插值，参考 dsd_to_wav.cpp 的 convert_frame）
// ============================================================================
static AVFrame* resample_frame(AVFrame* src, int dst_rate) {
    PlayerContext* ctx = &g_player;
    int src_rate = src->sample_rate;
    if (src_rate == dst_rate) { return src; }

    int channels = src->ch_layout.nb_channels;
    int64_t delay = (int64_t)src->nb_samples * dst_rate / src_rate;
    int dst_nb = (int)delay;
    if (dst_nb < 1) { dst_nb = 1; }

    // 检查缓冲区是否足够大
    if (!ctx->resampled_frame || ctx->resample_buf_samples < dst_nb) {
        av_frame_free(&ctx->resampled_frame);
        ctx->resampled_frame = av_frame_alloc();
        ctx->resampled_frame->format = AV_SAMPLE_FMT_FLT;
        av_channel_layout_copy(&ctx->resampled_frame->ch_layout, &src->ch_layout);
        ctx->resampled_frame->sample_rate = dst_rate;
        ctx->resampled_frame->nb_samples = dst_nb;
        av_frame_get_buffer(ctx->resampled_frame, 0);
        ctx->resample_buf_samples = dst_nb;
    } else {
        ctx->resampled_frame->nb_samples = dst_nb;
        av_channel_layout_copy(&ctx->resampled_frame->ch_layout, &src->ch_layout);
        ctx->resampled_frame->sample_rate = dst_rate;
    }

    AVFrame* dst = ctx->resampled_frame;
    int src_fmt = src->format;
    bool is_planar = av_sample_fmt_is_planar((AVSampleFormat)src_fmt);

    for (int ch = 0; ch < channels; ch++) {
        float* d = (float*)dst->data[0];
        uint8_t* s = is_planar ? src->data[ch] : src->data[0];
        int s_stride = is_planar ? 1 : channels;
        int s_idx = is_planar ? 0 : ch;

        for (int i = 0; i < dst_nb; i++) {
            int si = (int)((int64_t)i * src_rate / dst_rate);
            if (si >= src->nb_samples) { si = src->nb_samples - 1; }

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

// ============================================================================
// 将解码帧（FLT 格式）转换为目标 OHAudio 格式并复制到 buffer
// 返回填充的字节数
// ============================================================================
static int convert_and_copy_to_buffer(AVFrame* src_float, uint8_t* buffer, int buffer_size,
                                       int channels, int dst_fmt) {
    int frame_count = src_float->nb_samples;
    float* src = (float*)src_float->data[0];

    switch (dst_fmt) {
        case AUDIOSTREAM_SAMPLE_F32LE: {
            int required = frame_count * channels * 4;
            if (required > buffer_size) {
                frame_count = buffer_size / (channels * 4);
                required = frame_count * channels * 4;
            }
            memcpy(buffer, src, required);
            return required;
        }
        case AUDIOSTREAM_SAMPLE_S16LE: {
            int required = frame_count * channels * 2;
            if (required > buffer_size) {
                frame_count = buffer_size / (channels * 2);
                required = frame_count * channels * 2;
            }
            int16_t* dst = (int16_t*)buffer;
            int total = frame_count * channels;
            for (int i = 0; i < total; i++) {
                float v = src[i] * 32767.0f;
                if (v > 32767.0f) { v = 32767.0f; }
                if (v < -32768.0f) { v = -32768.0f; }
                dst[i] = (int16_t)v;
            }
            return required;
        }
        case AUDIOSTREAM_SAMPLE_S32LE: {
            int required = frame_count * channels * 4;
            if (required > buffer_size) {
                frame_count = buffer_size / (channels * 4);
                required = frame_count * channels * 4;
            }
            int32_t* dst = (int32_t*)buffer;
            int total = frame_count * channels;
            for (int i = 0; i < total; i++) {
                float v = src[i] * 2147483647.0f;
                if (v > 2147483647.0f) { v = 2147483647.0f; }
                if (v < -2147483648.0f) { v = -2147483648.0f; }
                dst[i] = (int32_t)v;
            }
            return required;
        }
        case AUDIOSTREAM_SAMPLE_U8: {
            int required = frame_count * channels;
            if (required > buffer_size) {
                frame_count = buffer_size / channels;
                required = frame_count * channels;
            }
            uint8_t* dst = (uint8_t*)buffer;
            int total = frame_count * channels;
            for (int i = 0; i < total; i++) {
                float v = src[i] * 128.0f + 128.0f;
                if (v > 255.0f) { v = 255.0f; }
                if (v < 0.0f) { v = 0.0f; }
                dst[i] = (uint8_t)v;
            }
            return required;
        }
        default: {
            // 默认按 S16LE 处理
            int required = frame_count * channels * 2;
            if (required > buffer_size) {
                frame_count = buffer_size / (channels * 2);
                required = frame_count * channels * 2;
            }
            int16_t* dst = (int16_t*)buffer;
            int total = frame_count * channels;
            for (int i = 0; i < total; i++) {
                float v = src[i] * 32767.0f;
                if (v > 32767.0f) { v = 32767.0f; }
                if (v < -32768.0f) { v = -32768.0f; }
                dst[i] = (int16_t)v;
            }
            return required;
        }
    }
}

// ============================================================================
// 执行 seek
// ============================================================================
static void perform_seek(PlayerContext* ctx) {
    std::lock_guard<std::mutex> lock(ctx->seek_mutex);
    if (ctx->seek_target_ms < 0) { return; }

    int64_t target_ms = ctx->seek_target_ms;
    ctx->seek_target_ms = -1;

    int64_t seek_target = av_rescale_q(
        target_ms * (AV_TIME_BASE / 1000),
        AV_TIME_BASE_Q,
        ctx->audio_stream->time_base);

    av_seek_frame(ctx->format_ctx, ctx->audio_stream_index,
                  seek_target, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(ctx->codec_ctx);

    ctx->total_frames_written = (int64_t)target_ms * ctx->output_sample_rate / 1000;
}

// ============================================================================
// 通知 ArkTS 时间回调
// ============================================================================
static void notify_time_callback(PlayerContext* ctx) {
    if (!ctx->time_callback) { return; }

    int64_t current_ms = ctx->total_frames_written.load() * 1000 / ctx->output_sample_rate;
    if (current_ms - ctx->last_callback_time_ms < 50) { return; }  // 节流 ~50ms
    ctx->last_callback_time_ms = current_ms;

    // 通过 threadsafe function 回调 ArkTS
    napi_call_threadsafe_function(ctx->time_callback, &current_ms, napi_tsfn_blocking);
}

// ============================================================================
// 通知 ArkTS 状态回调（TSFN，可从任意线程调用）
// ============================================================================
static void notify_status_callback(PlayerContext* ctx, const char* status) {
    if (!ctx->status_callback) { return; }

    // 复制字符串到堆上，TSFN 回调中释放
    char* status_copy = strdup(status);
    if (!status_copy) { return; }
    napi_call_threadsafe_function(ctx->status_callback, status_copy, napi_tsfn_blocking);
}

// ============================================================================
// 状态回调的 TSFN 调用函数
// ============================================================================
static void status_callback_tsfn(napi_env env, napi_value js_callback, void* context, void* data) {
    char* status = (char*)data;
    if (!status) { return; }

    napi_value arg;
    napi_create_string_utf8(env, status, NAPI_AUTO_LENGTH, &arg);

    napi_value result;
    napi_call_function(env, nullptr, js_callback, 1, &arg, &result);

    free(status);
}

// ============================================================================
// OHAudio 写数据回调
// ============================================================================
static OH_AudioData_Callback_Result on_write_data(
    OH_AudioRenderer* renderer, void* user_data,
    void* buffer, int32_t buffer_size) {

    PlayerContext* ctx = &g_player;

    // 1. 检查状态
    int state = ctx->play_state.load();
    if (state != STATE_PLAYING) {
        memset(buffer, 0, buffer_size);
        return AUDIO_DATA_CALLBACK_RESULT_VALID;
    }

    // 2. 处理 seek
    if (ctx->seek_target_ms >= 0) {
        perform_seek(ctx);
    }

    // 3. 解码 + 填充 buffer
    uint8_t* out_buf = (uint8_t*)buffer;
    int out_buf_remaining = buffer_size;
    int total_filled = 0;
    int out_fmt = ctx->output_sample_fmt;
    int ch = ctx->channels;
    int dst_rate = ctx->output_sample_rate;

    while (out_buf_remaining > 0) {
        // 先尝试从解码器取帧
        int ret = avcodec_receive_frame(ctx->codec_ctx, ctx->frame);
        if (ret == AVERROR(EAGAIN)) {
            // 需要新的 packet
            ret = av_read_frame(ctx->format_ctx, ctx->packet);
            if (ret == AVERROR_EOF) {
                // 刷新解码器
                avcodec_send_packet(ctx->codec_ctx, nullptr);
                // 继续循环尝试取剩余帧
                ret = avcodec_receive_frame(ctx->codec_ctx, ctx->frame);
                if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) {
                    // 播放完毕
                    if (total_filled > 0) {
                        memset(out_buf, 0, out_buf_remaining);
                    }
                    ctx->play_state = STATE_IDLE;
                    ctx->ended_naturally = true;
                    notify_status_callback(ctx, "complete");
                    return AUDIO_DATA_CALLBACK_RESULT_VALID;
                }
                // fall through: 有最后几帧数据
            } else if (ret < 0) {
                // 读取错误，填充静音
                memset(out_buf, 0, out_buf_remaining);
                total_filled = buffer_size;
                break;
            } else if (ctx->packet->stream_index != ctx->audio_stream_index) {
                av_packet_unref(ctx->packet);
                continue;
            } else {
                ret = avcodec_send_packet(ctx->codec_ctx, ctx->packet);
                av_packet_unref(ctx->packet);
                if (ret < 0) { continue; }
                continue;  // 循环回去 receive
            }
        } else if (ret < 0) {
            memset(out_buf, 0, out_buf_remaining);
            total_filled = buffer_size;
            break;
        }

        // 有解码帧，处理
        AVFrame* proc_frame = ctx->frame;

        // 重采样（如果需要）
        if (dst_rate != proc_frame->sample_rate) {
            proc_frame = resample_frame(proc_frame, dst_rate);
        }

        // 要求输出格式统一为 FLT（resample_frame 已输出 FLT）
        // 如果不需要重采样但原始帧不是 FLT，需要先转为 FLT
        AVFrame* float_frame = proc_frame;
        AVFrame* temp_float = nullptr;
        if (proc_frame->format != AV_SAMPLE_FMT_FLT && proc_frame->format != AV_SAMPLE_FMT_FLTP) {
            temp_float = resample_frame(proc_frame, proc_frame->sample_rate);  // 仅格式转换，不重采样
            float_frame = temp_float;
        }

        // 应用 EQ（在 FLT 域处理）
        int frame_count = float_frame->nb_samples;
        if (float_frame->data[0]) {
            apply_eq_float((float*)float_frame->data[0], frame_count, ch);
        }

        // 转换到目标格式并复制
        int filled = convert_and_copy_to_buffer(
            float_frame, out_buf, out_buf_remaining, ch, out_fmt);
        total_filled += filled;
        out_buf += filled;
        out_buf_remaining -= filled;

        // 更新位置（只计算通过 resample 或直接输出的帧）
        ctx->total_frames_written += frame_count;

        av_frame_unref(ctx->frame);
    }

    // 4. 通知 ArkTS
    if (total_filled > 0) {
        notify_time_callback(ctx);
    }

    return AUDIO_DATA_CALLBACK_RESULT_VALID;
}

// ============================================================================
// 创建 OHAudio renderer
// ============================================================================
static bool create_ohaudio_renderer(PlayerContext* ctx) {
    OH_AudioStreamBuilder* builder = nullptr;
    OH_AudioStream_Result result;

    result = OH_AudioStreamBuilder_Create(&builder, AUDIOSTREAM_TYPE_RENDERER);
    if (result != AUDIOSTREAM_SUCCESS) { return false; }

    OH_AudioStreamBuilder_SetSamplingRate(builder, ctx->output_sample_rate);
    OH_AudioStreamBuilder_SetChannelCount(builder, ctx->channels);
    OH_AudioStreamBuilder_SetSampleFormat(builder, (OH_AudioStream_SampleFormat)ctx->output_sample_fmt);
    OH_AudioStreamBuilder_SetEncodingType(builder, AUDIOSTREAM_ENCODING_TYPE_RAW);
    OH_AudioStreamBuilder_SetLatencyMode(builder, AUDIOSTREAM_LATENCY_MODE_NORMAL);
    OH_AudioStreamBuilder_SetRendererInfo(builder, AUDIOSTREAM_USAGE_MUSIC);
    OH_AudioStreamBuilder_SetRendererWriteDataCallback(builder, on_write_data, nullptr);

    result = OH_AudioStreamBuilder_GenerateRenderer(builder, &ctx->renderer);
    OH_AudioStreamBuilder_Destroy(builder);

    return result == AUDIOSTREAM_SUCCESS;
}

// ============================================================================
// set_audio 异步上下文
// ============================================================================
struct SetAudioContext {
    napi_async_work async_work;
    napi_deferred deferred;
    napi_env env;
    std::string file_path;
    bool success;
    std::string error_message;

    // set_audio 时将提取的播放器参数存于此，Complete 阶段使用
    // 实际直接在 execute 里操作 g_player
};

// ============================================================================
// set_audio 异步执行：验证文件 + 初始化解码器 + 创建 renderer
// ============================================================================
static void execute_set_audio(napi_env env, void* data) {
    auto* ctx = static_cast<SetAudioContext*>(data);

    // 先释放旧的播放器
    release_player();
    // 重置 EQ 状态
    {
        PlayerContext* p = &g_player;
        std::lock_guard<std::mutex> lock(p->eq_mutex);
        memset(p->eq_state, 0, sizeof(p->eq_state));
        for (int c = 0; c < MAX_CHANNELS; c++) {
            for (int i = 0; i < MAX_EQ_BANDS; i++) {
                reset_biquad(&p->eq_state[c].bands[i]);
            }
        }
        p->eq_dirty = true;
    }

    PlayerContext* player = &g_player;

    // 1. 打开文件
    AVFormatContext* format_ctx = nullptr;
    if (avformat_open_input(&format_ctx, ctx->file_path.c_str(), nullptr, nullptr) != 0) {
        ctx->success = false;
        ctx->error_message = "无法打开音频文件";
        return;
    }

    if (avformat_find_stream_info(format_ctx, nullptr) < 0) {
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "无法获取流信息";
        return;
    }

    // 2. 查找音频流
    int audio_idx = av_find_best_stream(format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_idx < 0) {
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "未找到音频流";
        return;
    }

    AVStream* audio_stream = format_ctx->streams[audio_idx];
    AVCodecParameters* codec_par = audio_stream->codecpar;

    // 3. 查找并打开解码器
    const AVCodec* decoder = avcodec_find_decoder(codec_par->codec_id);
    if (!decoder) {
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "找不到解码器";
        return;
    }

    AVCodecContext* codec_ctx = avcodec_alloc_context3(decoder);
    if (!codec_ctx) {
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "无法分配解码器上下文";
        return;
    }

    if (avcodec_parameters_to_context(codec_ctx, codec_par) < 0) {
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "无法复制解码参数";
        return;
    }

    // 请求解码器输出 FLT 格式（方便 EQ 处理和后续转换）
    codec_ctx->request_sample_fmt = AV_SAMPLE_FMT_FLT;

    if (avcodec_open2(codec_ctx, decoder, nullptr) < 0) {
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&format_ctx);
        ctx->success = false;
        ctx->error_message = "无法打开解码器";
        return;
    }

    // 4. 确定输出格式
    int channels = codec_ctx->ch_layout.nb_channels;
    int src_rate = codec_ctx->sample_rate;
    bool is_dsd = is_dsd_codec(codec_par->codec_id);

    int out_rate = src_rate;
    int out_fmt;

    if (is_dsd) {
        // DSD: 176.4kHz F32LE
        out_rate = 176400;
        out_fmt = AUDIOSTREAM_SAMPLE_F32LE;
    } else if (src_rate > 192000) {
        // 高采样率无损：按家族降采样
        if (src_rate % 44100 == 0) {
            out_rate = 176400;
        } else if (src_rate % 48000 == 0) {
            out_rate = 192000;
        }
        out_fmt = AUDIOSTREAM_SAMPLE_F32LE;
    } else {
        // 普通音频：匹配源格式
        out_fmt = ffmpeg_fmt_to_ohaudio(codec_ctx->sample_fmt);
    }

    // 5. 保存解码器状态
    player->format_ctx = format_ctx;
    player->codec_ctx = codec_ctx;
    player->audio_stream = audio_stream;
    player->audio_stream_index = audio_idx;
    player->channels = channels;
    player->output_sample_rate = out_rate;
    player->output_sample_fmt = out_fmt;
    player->bytes_per_sample = ohaudio_bytes_per_sample(out_fmt);
    player->is_dsd = is_dsd;

    // 6. 计算总时长
    double duration_sec = 0.0;
    if (format_ctx->duration > 0 && format_ctx->duration != AV_NOPTS_VALUE) {
        duration_sec = static_cast<double>(format_ctx->duration) / AV_TIME_BASE;
    } else if (audio_stream->duration > 0 && audio_stream->duration != AV_NOPTS_VALUE) {
        duration_sec = static_cast<double>(audio_stream->duration) * av_q2d(audio_stream->time_base);
    }
    player->duration_ms = static_cast<int64_t>(duration_sec * 1000.0);

    // 7. 分配 packet 和 frame
    player->packet = av_packet_alloc();
    player->frame = av_frame_alloc();
    if (!player->packet || !player->frame) {
        release_player();
        ctx->success = false;
        ctx->error_message = "无法分配数据包/帧";
        return;
    }

    // 8. 创建 OHAudio renderer
    if (!create_ohaudio_renderer(player)) {
        release_player();
        ctx->success = false;
        ctx->error_message = "无法创建音频渲染器";
        return;
    }

    // 9. 重建 EQ 系数（因为 output_sample_rate 可能变了）
    player->eq_dirty = true;
    rebuild_eq_coefficients();

    player->play_state = STATE_READY;
    ctx->success = true;
}

static void complete_set_audio(napi_env env, napi_status status, void* data) {
    auto* ctx = static_cast<SetAudioContext*>(data);

    if (status == napi_ok && ctx->success) {
        // 如果 start_ready 为 true，自动开始播放
        if (g_player.start_ready.load()) {
            OH_AudioRenderer_Start(g_player.renderer);
            g_player.play_state = STATE_PLAYING;
            g_player.ended_naturally = false;
            notify_status_callback(&g_player, "playing");
        }

        // 通知准备就绪回调
        if (g_player.ready_callback_ref) {
            napi_value callback;
            napi_get_reference_value(env, g_player.ready_callback_ref, &callback);
            napi_value unused;
            napi_call_function(env, nullptr, callback, 0, nullptr, &unused);
        }

        napi_value result;
        napi_get_boolean(env, true, &result);
        napi_resolve_deferred(env, ctx->deferred, result);
    } else {
        napi_value error;
        std::string msg = ctx->success ? "设置音频失败" : ctx->error_message;
        napi_create_string_utf8(env, msg.c_str(), msg.length(), &error);
        napi_reject_deferred(env, ctx->deferred, error);
    }

    napi_delete_async_work(env, ctx->async_work);
    delete ctx;
}

// ============================================================================
// NAPI: set_audio(path: string) → Promise<boolean>
// ============================================================================
napi_value set_audio(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个文件路径字符串");
        return nullptr;
    }

    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_string) {
        napi_throw_error(env, nullptr, "参数类型必须是字符串");
        return nullptr;
    }

    size_t str_size = 0;
    napi_status stat = napi_get_value_string_utf8(env, args[0], nullptr, 0, &str_size);
    if (stat != napi_ok || str_size == 0) {
        napi_throw_error(env, nullptr, "字符串解析失败");
        return nullptr;
    }

    std::string file_path(str_size, '\0');
    napi_get_value_string_utf8(env, args[0], &file_path[0], str_size + 1, &str_size);

    auto* ctx = new SetAudioContext();
    ctx->env = env;
    ctx->file_path = file_path;
    ctx->success = false;

    napi_value promise;
    napi_create_promise(env, &ctx->deferred, &promise);

    napi_value resource_name;
    napi_create_string_utf8(env, "SetAudio", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_async_work(env, nullptr, resource_name,
                           execute_set_audio, complete_set_audio,
                           ctx, &ctx->async_work);

    napi_queue_async_work(env, ctx->async_work);

    return promise;
}

// ============================================================================
// NAPI: playing() — 播放
// ============================================================================
napi_value playing(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    int state = ctx->play_state.load();

    if (state == STATE_READY || state == STATE_PAUSED) {
        if (ctx->renderer) {
            OH_AudioRenderer_Start(ctx->renderer);
            ctx->play_state = STATE_PLAYING;
            ctx->ended_naturally = false;
            notify_status_callback(ctx, "playing");
        }
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: pause() — 暂停
// ============================================================================
napi_value pause(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;

    if (ctx->play_state.load() == STATE_PLAYING) {
        if (ctx->renderer) {
            OH_AudioRenderer_Pause(ctx->renderer);
            ctx->play_state = STATE_PAUSED;
            notify_status_callback(ctx, "pause");
        }
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: seek(time_ms: int) — 跳转
// ============================================================================
napi_value seek(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) { return nullptr; }

    int64_t target_ms = 0;
    napi_get_value_int64(env, args[0], &target_ms);

    PlayerContext* ctx = &g_player;
    ctx->seek_target_ms = target_ms;

    // 立即触发 seek（在下次写回调前完成）
    perform_seek(ctx);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: get_current_time() → int (ms)
// ============================================================================
napi_value get_current_time(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;

    if (ctx->output_sample_rate <= 0) {
        napi_value result;
        napi_create_int64(env, 0, &result);
        return result;
    }

    int64_t current_ms = ctx->total_frames_written.load() * 1000 / ctx->output_sample_rate;

    napi_value result;
    napi_create_int64(env, current_ms, &result);
    return result;
}

// ============================================================================
// NAPI: register_time_callback(callback: function)
// ============================================================================
static void time_callback_tsfn(napi_env env, napi_value js_callback, void* context, void* data) {
    int64_t time_ms = *(int64_t*)data;

    napi_value arg;
    napi_create_int64(env, time_ms, &arg);

    napi_value result;
    napi_call_function(env, nullptr, js_callback, 1, &arg, &result);
}

napi_value register_time_callback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个回调函数");
        return nullptr;
    }

    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_function) {
        napi_throw_error(env, nullptr, "参数类型必须是函数");
        return nullptr;
    }

    // 释放旧的 tsfn
    if (g_player.time_callback) {
        napi_release_threadsafe_function(g_player.time_callback, napi_tsfn_release);
        g_player.time_callback = nullptr;
    }

    napi_value resource_name;
    napi_create_string_utf8(env, "TimeCallback", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(env, args[0], nullptr, resource_name,
                                     0, 1, nullptr, nullptr, nullptr,
                                     time_callback_tsfn, &g_player.time_callback);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: set_start_ready(ready: boolean)
// ============================================================================
napi_value set_start_ready(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) { return nullptr; }

    bool ready = false;
    napi_get_value_bool(env, args[0], &ready);
    g_player.start_ready.store(ready);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: switch_eq() — 切换 EQ 模式（循环） → 返回当前模式 int
// ============================================================================
napi_value switch_eq(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    int current = ctx->eq_mode.load();
    int next = (current + 1) % 3;  // 0→1→2→0
    ctx->eq_mode.store(next);
    ctx->eq_dirty = true;

    napi_value result;
    napi_create_int32(env, next, &result);
    return result;
}

// ============================================================================
// NAPI: set_eq(gains: number[]) — 设置 10 段 GEQ 增益值
// ============================================================================
napi_value set_eq(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个长度为10的浮点数数组");
        return nullptr;
    }

    bool is_array = false;
    napi_is_array(env, args[0], &is_array);
    if (!is_array) {
        napi_throw_error(env, nullptr, "参数类型必须是数组");
        return nullptr;
    }

    uint32_t length = 0;
    napi_get_array_length(env, args[0], &length);
    if (length != 10) {
        napi_throw_error(env, nullptr, "数组长度必须为10");
        return nullptr;
    }

    PlayerContext* ctx = &g_player;
    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    for (uint32_t i = 0; i < 10; i++) {
        napi_value elem;
        napi_get_element(env, args[0], i, &elem);

        double val = 0.0;
        napi_get_value_double(env, elem, &val);
        if (val < -12.0) { val = -12.0; }
        if (val > 12.0) { val = 12.0; }
        ctx->eq_gains[i] = (float)val;
    }

    ctx->eq_dirty = true;

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: set_peq(params: [enabled, freq, gain, q, type][10])
// ============================================================================
napi_value set_peq(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个长度为10的二维数组");
        return nullptr;
    }

    bool is_array = false;
    napi_is_array(env, args[0], &is_array);
    if (!is_array) {
        napi_throw_error(env, nullptr, "参数类型必须是数组");
        return nullptr;
    }

    uint32_t length = 0;
    napi_get_array_length(env, args[0], &length);
    if (length != 10) {
        napi_throw_error(env, nullptr, "数组长度必须为10");
        return nullptr;
    }

    PlayerContext* ctx = &g_player;
    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    for (uint32_t i = 0; i < 10; i++) {
        napi_value band_arr;
        napi_get_element(env, args[0], i, &band_arr);

        bool is_band_array = false;
        napi_is_array(env, band_arr, &is_band_array);
        if (!is_band_array) { continue; }

        uint32_t band_len = 0;
        napi_get_array_length(env, band_arr, &band_len);
        if (band_len < 5) { continue; }

        // [enabled, freq, gain, q, type]
        napi_value v_enabled, v_freq, v_gain, v_q, v_type;
        napi_get_element(env, band_arr, 0, &v_enabled);
        napi_get_element(env, band_arr, 1, &v_freq);
        napi_get_element(env, band_arr, 2, &v_gain);
        napi_get_element(env, band_arr, 3, &v_q);
        napi_get_element(env, band_arr, 4, &v_type);

        bool enabled = false;
        napi_get_value_bool(env, v_enabled, &enabled);
        ctx->peq_bands[i].enabled = enabled;

        double freq = 1000.0;
        napi_get_value_double(env, v_freq, &freq);
        ctx->peq_bands[i].freq = (float)freq;

        double gain = 0.0;
        napi_get_value_double(env, v_gain, &gain);
        if (gain < -12.0) { gain = -12.0; }
        if (gain > 12.0) { gain = 12.0; }
        ctx->peq_bands[i].gain = (float)gain;

        double q = 1.0;
        napi_get_value_double(env, v_q, &q);
        ctx->peq_bands[i].q = (float)q;

        int32_t type = 0;
        napi_get_value_int32(env, v_type, &type);
        if (type < 0) { type = 0; }
        if (type > 3) { type = 3; }
        ctx->peq_bands[i].type = type;
    }

    ctx->eq_dirty = true;

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: get_eq() → number[10]
// ============================================================================
napi_value get_eq(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    napi_value result;
    napi_create_array_with_length(env, 10, &result);

    for (int i = 0; i < 10; i++) {
        napi_value val;
        napi_create_double(env, (double)ctx->eq_gains[i], &val);
        napi_set_element(env, result, i, val);
    }

    return result;
}

// ============================================================================
// NAPI: get_peq() → [boolean, number, number, number, number][10]
// ============================================================================
napi_value get_peq(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    std::lock_guard<std::mutex> lock(ctx->eq_mutex);

    napi_value result;
    napi_create_array_with_length(env, 10, &result);

    for (int i = 0; i < 10; i++) {
        napi_value band;
        napi_create_array_with_length(env, 5, &band);

        napi_value v_e, v_f, v_g, v_q, v_t;
        napi_get_boolean(env, ctx->peq_bands[i].enabled, &v_e);
        napi_create_double(env, (double)ctx->peq_bands[i].freq, &v_f);
        napi_create_double(env, (double)ctx->peq_bands[i].gain, &v_g);
        napi_create_double(env, (double)ctx->peq_bands[i].q, &v_q);
        napi_create_int32(env, ctx->peq_bands[i].type, &v_t);

        napi_set_element(env, band, 0, v_e);
        napi_set_element(env, band, 1, v_f);
        napi_set_element(env, band, 2, v_g);
        napi_set_element(env, band, 3, v_q);
        napi_set_element(env, band, 4, v_t);

        napi_set_element(env, result, i, band);
    }

    return result;
}

// ============================================================================
// NAPI: get_start_ready() → boolean
// ============================================================================
napi_value get_start_ready(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_get_boolean(env, g_player.start_ready.load(), &result);
    return result;
}

// ============================================================================
// NAPI: register_ready_callback(callback: function)
// ============================================================================
napi_value register_ready_callback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个回调函数");
        return nullptr;
    }

    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_function) {
        napi_throw_error(env, nullptr, "参数类型必须是函数");
        return nullptr;
    }

    // 释放旧的回调
    if (g_player.ready_callback_ref) {
        napi_delete_reference(env, g_player.ready_callback_ref);
        g_player.ready_callback_ref = nullptr;
    }

    napi_create_reference(env, args[0], 1, &g_player.ready_callback_ref);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: register_status_callback(callback: function)
// ============================================================================
napi_value register_status_callback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个回调函数");
        return nullptr;
    }

    napi_valuetype valuetype;
    napi_typeof(env, args[0], &valuetype);
    if (valuetype != napi_function) {
        napi_throw_error(env, nullptr, "参数类型必须是函数");
        return nullptr;
    }

    // 释放旧的 tsfn
    if (g_player.status_callback) {
        napi_release_threadsafe_function(g_player.status_callback, napi_tsfn_release);
        g_player.status_callback = nullptr;
    }

    napi_value resource_name;
    napi_create_string_utf8(env, "StatusCallback", NAPI_AUTO_LENGTH, &resource_name);

    napi_create_threadsafe_function(env, args[0], nullptr, resource_name,
                                     0, 1, nullptr, nullptr, nullptr,
                                     status_callback_tsfn, &g_player.status_callback);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: get_status() → string ("playing" / "pause" / "complete")
// ============================================================================
napi_value get_status(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    int state = ctx->play_state.load();
    const char* status_str = "pause";  // 默认

    if (state == STATE_PLAYING) {
        status_str = "playing";
    } else if (state == STATE_IDLE && ctx->ended_naturally.load()) {
        status_str = "complete";
    }
    // STATE_PAUSED / STATE_READY / other IDLE → "pause"

    napi_value result;
    napi_create_string_utf8(env, status_str, NAPI_AUTO_LENGTH, &result);
    return result;
}
