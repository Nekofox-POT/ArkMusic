#include "ffmpeg_manager.h"

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
#include <cstdio>
#include <hilog/log.h>
#include <mutex>
#include <atomic>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ---- 调试日志宏（hilog） ----
#define FFMPEG_LOG_DOMAIN 0x0001
#define FFMPEG_LOG_TAG "ffmpeg_manager"
// 用 OH_LOG_Print 代替 fprintf(stderr)，鸿蒙原生日志系统才能看到
#define FF_LOG(fmt, ...) \
    OH_LOG_Print(LOG_APP, LOG_INFO, FFMPEG_LOG_DOMAIN, FFMPEG_LOG_TAG, fmt, ##__VA_ARGS__)

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

static void calc_biquad_lowpass(BiquadState* st, float freq, float sample_rate, float q) {
    float w0 = 2.0f * (float)M_PI * freq / sample_rate;
    float cos_w0 = cosf(w0);
    float sin_w0 = sinf(w0);
    float alpha = sin_w0 / (2.0f * q);

    float b0 = (1.0f - cos_w0) / 2.0f;
    float b1 =  1.0f - cos_w0;
    float b2 = (1.0f - cos_w0) / 2.0f;
    float a0 =  1.0f + alpha;
    float a1_ = -2.0f * cos_w0;
    float a2_ =  1.0f - alpha;

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
    std::atomic<bool> auto_start{false};
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
    int32_t last_callback_time_ms = 0;

    // ArkTS 准备就绪回调（JS 线程调用，存 napi_ref）
    napi_ref ready_callback_ref = nullptr;

    // ArkTS 状态回调（TSFN，可从音频线程调用）
    napi_threadsafe_function status_callback = nullptr;
    std::atomic<bool> ended_naturally{false};  // 是否自然播放完毕

    // 调试：首次解码日志标记（每次 set_audio 重置）
    bool first_frame_logged = false;
    bool first_callback_logged = false;

    // EQ/PEQ
    std::atomic<int> eq_mode{EQ_OFF};
    float eq_gains[10] = {0.0f};
    PeqBand peq_bands[10];
    ChannelEqState eq_state[MAX_CHANNELS];
    std::mutex eq_mutex;
    bool eq_dirty = true;            // 需要重新计算 biquad 系数

    // 抗混叠低通滤波器（重采样降采前使用，4 级联 Biquad，每声道独立）
    // 用于替换最近邻插值的粗暴降采，避免超声噪声混叠到可听频段
    BiquadState aa_lpf[MAX_CHANNELS][4];
    int aa_lpf_src_rate = 0;
    int aa_lpf_dst_rate = 0;
    bool aa_lpf_need_init = true;

    // 重采样中间缓冲区（避免每帧 malloc：平面→交织→滤波→降采）
    float* aa_work_buf = nullptr;
    int aa_work_buf_capacity = 0;  // 单位：float 个数

    // Resample 缓冲区
    AVFrame* resampled_frame = nullptr;
    int resample_buf_samples = 0;

    // 部分帧缓冲：当 OHAudio buffer 不够装完整帧时，剩余采样暂存于此
    // 存储的是已转换为目标格式的字节数据
    uint8_t* pending_data = nullptr;
    int pending_size = 0;       // 待写入字节数
    int pending_capacity = 0;
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

// 有损格式 → 无原生位深概念 → 输出统一 16bit
static bool is_lossy_codec(AVCodecID codec_id) {
    switch (codec_id) {
        case AV_CODEC_ID_MP3:       case AV_CODEC_ID_MP2:
        case AV_CODEC_ID_AAC:       case AV_CODEC_ID_AAC_LATM:
        case AV_CODEC_ID_VORBIS:    case AV_CODEC_ID_OPUS:
        case AV_CODEC_ID_WMAV1:     case AV_CODEC_ID_WMAV2:
        case AV_CODEC_ID_WMAPRO:
        case AV_CODEC_ID_RA_144:    case AV_CODEC_ID_RA_288:
        case AV_CODEC_ID_COOK:      case AV_CODEC_ID_ATRAC3:
        case AV_CODEC_ID_SPEEX:     case AV_CODEC_ID_AMR_NB:
        case AV_CODEC_ID_AMR_WB:
            return true;
        default: return false;
    }
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

    delete[] ctx->pending_data;
    ctx->pending_data = nullptr;
    ctx->pending_size = 0;
    ctx->pending_capacity = 0;

    // 重置抗混叠滤波状态（下次 set_audio 时根据新采样率重新初始化）
    memset(ctx->aa_lpf, 0, sizeof(ctx->aa_lpf));
    ctx->aa_lpf_src_rate = 0;
    ctx->aa_lpf_dst_rate = 0;
    ctx->aa_lpf_need_init = true;

    delete[] ctx->aa_work_buf;
    ctx->aa_work_buf = nullptr;
    ctx->aa_work_buf_capacity = 0;

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
// 初始化抗混叠低通滤波器（4 级联 Biquad，用于降采前滤除超声成分）
// cutoff 按 target Nyquist * 0.9（留 10% 过渡带避免边缘混叠）
// ============================================================================
static void init_aa_filter(PlayerContext* ctx, int src_rate, int dst_rate) {
    if (src_rate == dst_rate) { return; }

    // 只在降采样时启用；升采样不需要抗混叠
    if (dst_rate > src_rate) { return; }

    int ch = ctx->channels;
    if (ch <= 0) { ch = 2; }
    if (ch > MAX_CHANNELS) { ch = MAX_CHANNELS; }

    float nyquist = dst_rate * 0.5f;
    float cutoff = nyquist * 0.9f;       // 截止频率 = 目标 Nyquist 的 90%
    // 使用 4 级联，Q 值递增，获得更平坦的通带 + 更陡的滚降
    float q_values[4] = { 0.5f, 0.7f, 0.9f, 1.1f };

    for (int c = 0; c < ch; c++) {
        for (int i = 0; i < 4; i++) {
            calc_biquad_lowpass(&ctx->aa_lpf[c][i],
                cutoff, (float)src_rate, q_values[i]);
        }
    }

    ctx->aa_lpf_src_rate = src_rate;
    ctx->aa_lpf_dst_rate = dst_rate;
    ctx->aa_lpf_need_init = false;

    FF_LOG("aa_filter init: cutoff=%{public}.0f Hz, src=%{public}d, dst=%{public}d",
            (double)cutoff, src_rate, dst_rate);
}

// ============================================================================
// 对单帧应用抗混叠低通滤波器（在降采前调用）
// ============================================================================
static void apply_aa_filter(float* interleaved, int frame_count, int channels) {
    PlayerContext* ctx = &g_player;

    if (ctx->aa_lpf_need_init) { return; }

    int total_samples = frame_count * channels;
    for (int i = 0; i < total_samples; i++) {
        int ch = i % channels;
        float x = interleaved[i];
        // 4 级联低通，逐步滤除超声
        for (int stage = 0; stage < 4; stage++) {
            BiquadState* st = &ctx->aa_lpf[ch][stage];
            x = process_biquad(st, x);
        }
        interleaved[i] = x;
    }
}

// ============================================================================
// 重采样帧（先交织→滤波→线性插值降采，三步分离避免缓冲区溢出）
// ============================================================================
static AVFrame* resample_frame(AVFrame* src, int dst_rate) {
    PlayerContext* ctx = &g_player;
    int src_rate = src->sample_rate;
    // 只有当源采样率和目标采样率一致且源格式已是交织 FLT 时才跳过。
    // FLTP（平面 float）也不行 —— data[0] 只有单声道，convert_and_copy_to_buffer 按交织读取
    // 会导致只读到一半采样加垃圾数据，表现为加速+断音。
    if (src_rate == dst_rate && src->format == AV_SAMPLE_FMT_FLT) {
        return src;
    }

    int channels = src->ch_layout.nb_channels;
    int64_t delay = (int64_t)src->nb_samples * dst_rate / src_rate;
    int dst_nb = (int)delay;
    if (dst_nb < 1) { dst_nb = 1; }

    // 检查输出 buffer 是否够大
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
    float* dst_data = (float*)dst->data[0];
    int src_fmt = src->format;
    bool is_planar = av_sample_fmt_is_planar((AVSampleFormat)src_fmt);

    // 如果是降采样且抗混叠滤波尚未初始化，先初始化
    if (dst_rate < src_rate) {
        if (ctx->aa_lpf_need_init ||
            ctx->aa_lpf_src_rate != src_rate ||
            ctx->aa_lpf_dst_rate != dst_rate) {
            init_aa_filter(ctx, src_rate, dst_rate);
        }
    }

    // --- 分配/确保中间工作 buffer（大小 = src->nb_samples × channels）---
    int work_floats = src->nb_samples * channels;
    if (!ctx->aa_work_buf || ctx->aa_work_buf_capacity < work_floats) {
        delete[] ctx->aa_work_buf;
        ctx->aa_work_buf = new float[work_floats];
        ctx->aa_work_buf_capacity = work_floats;
    }
    float* work = ctx->aa_work_buf;

    // --- 第一步：平面→交织（写入 work buffer，不会溢出 dst）---
    for (int ch = 0; ch < channels; ch++) {
        uint8_t* s = is_planar ? src->data[ch] : src->data[0];
        int s_stride = is_planar ? 1 : channels;
        int s_idx = is_planar ? 0 : ch;

        for (int i = 0; i < src->nb_samples; i++) {
            float val = 0.0f;
            switch (src_fmt) {
                case AV_SAMPLE_FMT_FLT:
                case AV_SAMPLE_FMT_FLTP:
                    val = ((float*)s)[i * s_stride + s_idx]; break;
                case AV_SAMPLE_FMT_S32:
                case AV_SAMPLE_FMT_S32P:
                    val = ((int32_t*)s)[i * s_stride + s_idx] / 2147483648.0f; break;
                case AV_SAMPLE_FMT_S16:
                case AV_SAMPLE_FMT_S16P:
                    val = ((int16_t*)s)[i * s_stride + s_idx] / 32768.0f; break;
                case AV_SAMPLE_FMT_U8:
                case AV_SAMPLE_FMT_U8P:
                    val = (((uint8_t*)s)[i * s_stride + s_idx] - 128) / 128.0f; break;
                case AV_SAMPLE_FMT_DBL:
                case AV_SAMPLE_FMT_DBLP:
                    val = (float)((double*)s)[i * s_stride + s_idx]; break;
                case AV_SAMPLE_FMT_S64:
                case AV_SAMPLE_FMT_S64P:
                    val = ((int64_t*)s)[i * s_stride + s_idx] / 9223372036854775808.0f; break;
                default: break;
            }
            work[i * channels + ch] = val;
        }
    }

    // --- 第二步：降采前在源率域应用抗混叠低通 ---
    if (dst_rate < src_rate) {
        apply_aa_filter(work, src->nb_samples, channels);
        // 滤波后重新计算 work_floats（nb_samples 未变，但以防万一）
    }

    // --- 第三步：线性插值从 work → dst_data ---
    if (src_rate != dst_rate) {
        float ratio = (float)src_rate / (float)dst_rate;
        for (int i = 0; i < dst_nb; i++) {
            float src_pos = (float)i * ratio;
            int si0 = (int)src_pos;
            int si1 = si0 + 1;
            if (si1 >= src->nb_samples) { si1 = src->nb_samples - 1; }
            float frac = src_pos - (float)si0;

            for (int ch = 0; ch < channels; ch++) {
                float v0 = work[si0 * channels + ch];
                float v1 = work[si1 * channels + ch];
                dst_data[i * channels + ch] = v0 + frac * (v1 - v0);
            }
        }
    } else {
        // 速率一致：直接 memcpy（平面→交织的最终结果）
        memcpy(dst_data, work, work_floats * sizeof(float));
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
        case AUDIOSTREAM_SAMPLE_S24LE: {
            // 24-bit packed LE: 3 bytes per sample
            int required = frame_count * channels * 3;
            if (required > buffer_size) {
                frame_count = buffer_size / (channels * 3);
                required = frame_count * channels * 3;
            }
            uint8_t* dst8 = (uint8_t*)buffer;
            int total = frame_count * channels;
            for (int i = 0; i < total; i++) {
                float v = src[i] * 8388607.0f;  // 2^23 - 1
                if (v >  8388607.0f) { v =  8388607.0f; }
                if (v < -8388608.0f) { v = -8388608.0f; }
                int32_t sample = (int32_t)v;
                *dst8++ = (uint8_t)(sample & 0xFF);
                *dst8++ = (uint8_t)((sample >> 8) & 0xFF);
                *dst8++ = (uint8_t)((sample >> 16) & 0xFF);
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

    int32_t current_ms = (int32_t)(ctx->total_frames_written.load() * 1000 / ctx->output_sample_rate);
    if (abs(current_ms - ctx->last_callback_time_ms) < 50) { return; }  // 节流 ~50ms
    ctx->last_callback_time_ms = current_ms;

    // 堆分配 int32，避免栈变量在非阻塞 TSFN 中被销毁
    int32_t* data = new int32_t(current_ms);
    napi_call_threadsafe_function(ctx->time_callback, data, napi_tsfn_blocking);
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

    // ---- 首次回调：打印运行时 buffer 大小（排查用） ----
    if (!ctx->first_callback_logged) {
        ctx->first_callback_logged = true;
        FF_LOG("on_write_data first call: buffer_size=%{public}d, out_fmt=%{public}d, out_rate=%{public}d, ch=%{public}d, bps=%{public}d",
               buffer_size, ctx->output_sample_fmt, ctx->output_sample_rate, ctx->channels, ctx->bytes_per_sample);
    }

    // 3. 解码 + 填充 buffer
    uint8_t* out_buf = (uint8_t*)buffer;
    int out_buf_remaining = buffer_size;
    int total_filled = 0;
    int out_fmt = ctx->output_sample_fmt;
    int ch = ctx->channels;
    int dst_rate = ctx->output_sample_rate;
    int bytes_per_frame = ch * ctx->bytes_per_sample;

    // 3a. 先写完上次截断遗留的数据
    if (ctx->pending_size > 0) {
        int copy = ctx->pending_size;
        if (copy > out_buf_remaining) { copy = out_buf_remaining; }
        memcpy(out_buf, ctx->pending_data, copy);
        out_buf += copy;
        out_buf_remaining -= copy;
        total_filled += copy;
        ctx->total_frames_written += copy / bytes_per_frame;

        if (copy < ctx->pending_size) {
            // 还没写完，前移剩余数据
            memmove(ctx->pending_data, ctx->pending_data + copy, ctx->pending_size - copy);
            ctx->pending_size -= copy;
            // buffer 满，直接返回
            if (total_filled > 0) { notify_time_callback(ctx); }
            return AUDIO_DATA_CALLBACK_RESULT_VALID;
        }
        ctx->pending_size = 0;
    }

    while (out_buf_remaining > 0) {
        // 先尝试从解码器取帧
        int ret = avcodec_receive_frame(ctx->codec_ctx, ctx->frame);
        if (ret == AVERROR(EAGAIN)) {
            // 需要新的 packet
            ret = av_read_frame(ctx->format_ctx, ctx->packet);
            if (ret == AVERROR_EOF) {
                // 刷新解码器
                avcodec_send_packet(ctx->codec_ctx, nullptr);
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
                continue;
            }
        } else if (ret < 0) {
            memset(out_buf, 0, out_buf_remaining);
            total_filled = buffer_size;
            break;
        }

        // 有解码帧，处理
        AVFrame* proc_frame = ctx->frame;

        // ---- 首次解码帧：打印实际格式 ----
        if (!ctx->first_frame_logged) {
            ctx->first_frame_logged = true;
            const char* actual_fmt = av_get_sample_fmt_name((AVSampleFormat)proc_frame->format);
            FF_LOG("first decoded frame: %{public}d Hz / %{public}s / %{public}d ch / %{public}d samples",
                   proc_frame->sample_rate, actual_fmt,
                   proc_frame->ch_layout.nb_channels, proc_frame->nb_samples);
        }

        // 重采样（如果需要）
        if (dst_rate != proc_frame->sample_rate) {
            proc_frame = resample_frame(proc_frame, dst_rate);
        }

        // 只要不是交织 FLT 就需要格式转换
        AVFrame* float_frame = proc_frame;
        AVFrame* temp_float = nullptr;
        if (proc_frame->format != AV_SAMPLE_FMT_FLT) {
            temp_float = resample_frame(proc_frame, proc_frame->sample_rate);
            float_frame = temp_float;
        }

        // 应用 EQ（在 FLT 域处理）
        int frame_count = float_frame->nb_samples;
        if (float_frame->data[0]) {
            apply_eq_float((float*)float_frame->data[0], frame_count, ch);
        }

        // 检查整帧是否能放入剩余 buffer
        int frame_out_bytes = frame_count * bytes_per_frame;
        if (frame_out_bytes <= out_buf_remaining) {
            // 整帧完整写入
            int filled = convert_and_copy_to_buffer(
                float_frame, out_buf, out_buf_remaining, ch, out_fmt);
            total_filled += filled;
            out_buf += filled;
            out_buf_remaining -= filled;
            ctx->total_frames_written += filled / bytes_per_frame;
        } else {
            // buffer 不够装整帧 —— 先转换到 pending buffer，再分次写出
            // 确保 pending buffer 够大
            if (ctx->pending_capacity < frame_out_bytes) {
                delete[] ctx->pending_data;
                ctx->pending_data = new uint8_t[frame_out_bytes];
                ctx->pending_capacity = frame_out_bytes;
            }
            // 完整转换到 pending buffer
            int full_bytes = convert_and_copy_to_buffer(
                float_frame, ctx->pending_data, frame_out_bytes, ch, out_fmt);
            ctx->pending_size = full_bytes;

            // 写出能放下的部分
            int copy = full_bytes;
            if (copy > out_buf_remaining) { copy = out_buf_remaining; }
            memcpy(out_buf, ctx->pending_data, copy);
            total_filled += copy;
            ctx->total_frames_written += copy / bytes_per_frame;

            if (copy < full_bytes) {
                // 还没写完，前移剩余数据
                memmove(ctx->pending_data, ctx->pending_data + copy, full_bytes - copy);
                ctx->pending_size = full_bytes - copy;
            } else {
                ctx->pending_size = 0;
            }

            av_frame_unref(ctx->frame);
            break;  // buffer 满，下个回调继续
        }

        av_frame_unref(ctx->frame);
    }

    // 4. 通知 ArkTS
    if (total_filled > 0) {
        notify_time_callback(ctx);
    }

    return AUDIO_DATA_CALLBACK_RESULT_VALID;
}

// ============================================================================
// OHAudio 音频中断回调：系统/其他软件打断播放时触发
// ============================================================================
static void on_audio_interrupt(OH_AudioRenderer* renderer, void* user_data,
                                OH_AudioInterrupt_ForceType type, OH_AudioInterrupt_Hint hint) {
    PlayerContext* ctx = &g_player;

    // 系统强中断（如来电）且建议暂停/停止 → 暂停并回调 pause 状态
    if (type == AUDIOSTREAM_INTERRUPT_FORCE &&
        (hint == AUDIOSTREAM_INTERRUPT_HINT_PAUSE || hint == AUDIOSTREAM_INTERRUPT_HINT_STOP)) {
        if (ctx->play_state.load() == STATE_PLAYING && ctx->renderer) {
            OH_AudioRenderer_Pause(ctx->renderer);
            ctx->play_state = STATE_PAUSED;
            notify_status_callback(ctx, "pause");
            FF_LOG("Audio interrupted by system, paused (hint=%{public}d)", (int)hint);
        }
    }
    // AUDIOSTREAM_INTERRUPT_HINT_RESUME: 中断结束，保持暂停让用户手动恢复
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
    OH_AudioStreamBuilder_SetLatencyMode(builder, AUDIOSTREAM_LATENCY_MODE_FAST);
    OH_AudioStreamBuilder_SetRendererInfo(builder, AUDIOSTREAM_USAGE_MUSIC);
    OH_AudioStreamBuilder_SetRendererWriteDataCallback(builder, on_write_data, nullptr);
    OH_AudioStreamBuilder_SetRendererInterruptCallback(builder, on_audio_interrupt, nullptr);

    // 调试日志：OHAudio 实际配置
    const char* fmt_names[] = {"U8","S16LE","S24LE","S32LE","F32LE"};
    const char* fmt_name = (ctx->output_sample_fmt >= 0 && ctx->output_sample_fmt <= 4)
                           ? fmt_names[ctx->output_sample_fmt] : "???";
    FF_LOG("OHAudio config: %{public}d Hz / %{public}s / %{public}d ch / %{public}d bps",
            ctx->output_sample_rate, fmt_name, ctx->channels, ctx->bytes_per_sample);

    result = OH_AudioStreamBuilder_GenerateRenderer(builder, &ctx->renderer);
    OH_AudioStreamBuilder_Destroy(builder);

    if (result != AUDIOSTREAM_SUCCESS) {
        FF_LOG("OHAudio renderer create FAILED: %{public}d", result);
    }
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
    bool auto_start = true;       // 载入后是否自动播放
    int64_t start_time = 0;       // 载入后跳转目标时间(ms)

    // set_audio 时将提取的播放器参数存于此，Complete 阶段使用
    // 实际直接在 execute 里操作 g_player
};

// ============================================================================
// set_audio 异步执行：验证文件 + 初始化解码器 + 创建 renderer
// ============================================================================
static void execute_set_audio(napi_env env, void* data) {
    auto* ctx = static_cast<SetAudioContext*>(data);

    PlayerContext* player = &g_player;

    // 载入新歌曲前，先回调 pause 状态通知 ArkTS 层
    if (player->play_state.load() == STATE_PLAYING) {
        notify_status_callback(player, "pause");
    }

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

    // 解码器实际输出格式（可能与文件原始格式不同！解码器可能输出 planar）
    const char* dec_fmt_name = av_get_sample_fmt_name(codec_ctx->sample_fmt);
    bool dec_is_planar = av_sample_fmt_is_planar(codec_ctx->sample_fmt);
    FF_LOG("decoder output: %{public}d Hz / %{public}s (%{public}s) / %{public}d ch",
            src_rate, dec_fmt_name, dec_is_planar ? "planar" : "interleaved", channels);

    int out_rate = src_rate;
    int out_fmt;
    bool lossy = is_lossy_codec(codec_par->codec_id);

    if (is_dsd) {
        // DSD: 解码器输出 fltp @ DSD率/8（例如 DSD64→352.8kHz）
        // DSD 噪声整形将量化噪声推入超声段（>50kHz），不做抗混叠滤波直接降采会混叠
        // 两级策略：352.8k→176.4k (family 44100)，或按需降采到安全上限
        if (src_rate <= 192000) {
            out_rate = src_rate;  // 无需降采
        } else if (src_rate <= 384000) {
            // DSD64 典型：352.8k → 176.4k
            out_rate = (src_rate % 44100 == 0) ? src_rate / 2 : 192000;
        } else {
            // DSD128/256：多级降采到安全上限
            out_rate = (src_rate % 44100 == 0) ? 352800 : 384000;
        }
        out_fmt = AUDIOSTREAM_SAMPLE_F32LE;
    } else if (lossy) {
        // 有损格式无原生位深 → 强制 16-bit S16LE
        out_rate = src_rate;
        out_fmt = AUDIOSTREAM_SAMPLE_S16LE;
    } else if (src_rate > 192000) {
        // 高采样率无损：按家族降采样，输出 F32LE
        if (src_rate % 44100 == 0) {
            out_rate = 176400;
        } else if (src_rate % 48000 == 0) {
            out_rate = 192000;
        }
        out_fmt = AUDIOSTREAM_SAMPLE_F32LE;
    } else {
        // 普通无损：使用文件的原始采样格式（codec_par，而非解码器 codec_ctx）
        AVSampleFormat file_fmt = (AVSampleFormat)codec_par->format;
        int raw_bits = codec_par->bits_per_raw_sample;
        if (file_fmt == AV_SAMPLE_FMT_NONE) {
            // 回退：根据 bits_per_raw_sample 推断
            if (raw_bits <= 8)       file_fmt = AV_SAMPLE_FMT_U8;
            else if (raw_bits <= 16) file_fmt = AV_SAMPLE_FMT_S16;
            else                     file_fmt = AV_SAMPLE_FMT_S32;
        }
        // S32 容器但实际只有 24-bit → 用 S24LE 节省带宽
        if (file_fmt == AV_SAMPLE_FMT_S32 && raw_bits == 24) {
            out_fmt = AUDIOSTREAM_SAMPLE_S24LE;
        } else {
            out_fmt = ffmpeg_fmt_to_ohaudio(file_fmt);
        }
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
    player->first_frame_logged = false;
    player->first_callback_logged = false;

    // ---------- 调试日志：打印源格式与输出格式 ----------
    {
        // 容器/文件原始参数 (codec_par)，解码器输出参数 (codec_ctx)，最终 OHAudio 输出
        int container_rate = codec_par->sample_rate;  // 容器采样率（DSD64 = 2822400）
        const char* container_fmt = av_get_sample_fmt_name((AVSampleFormat)codec_par->format);
        const char* file_fmt_str = (codec_par->format == AV_SAMPLE_FMT_NONE) ? "DSD(1-bit)" : container_fmt;
        const char* dec_fmt_name3 = av_get_sample_fmt_name(codec_ctx->sample_fmt);
        const char* out_fmt_str[] = {"U8","S16LE","S24LE","S32LE","F32LE"};
        const char* out_fmt_name = (out_fmt >= 0 && out_fmt < 5) ? out_fmt_str[out_fmt] : "???";
        const AVCodec* codec_info = avcodec_find_decoder(codec_par->codec_id);
        const char* codec_name = codec_info ? codec_info->name : "unknown";

        FF_LOG("====== set_audio ======");
        FF_LOG("codec      : %{public}s %{public}s%{public}s",
                codec_name, is_dsd ? "(DSD)" : "", lossy ? "(lossy→S16)" : "");
        FF_LOG("container  : %{public}d Hz / %{public}s / %{public}d ch / %{public}d bit",
                container_rate, file_fmt_str, channels,
                is_dsd ? 1 : codec_par->bits_per_raw_sample);
        FF_LOG("decoder    : %{public}d Hz / %{public}s / %{public}d ch",
                src_rate, dec_fmt_name3, channels);
        FF_LOG("out        : %{public}d Hz / %{public}s / %{public}d ch / %{public}d bps",
                out_rate, out_fmt_name, channels, player->bytes_per_sample);
        FF_LOG("resample   : %{public}s (container→dec=%{public}s, dec→out=%{public}s)",
                (out_rate != src_rate || container_rate != src_rate) ? "YES" : "no",
                (container_rate != src_rate) ? "YES" : "no",
                (out_rate != src_rate) ? "YES" : "no");
        FF_LOG("duration   : %{public}lld ms",
                (long long)player->duration_ms);
        FF_LOG("==============================");
    }

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
        // 1. 执行跳转（如果指定了开始时间）
        if (ctx->start_time > 0) {
            g_player.seek_target_ms = ctx->start_time;
            perform_seek(&g_player);
        }

        // 2. 通知准备就绪回调
        if (g_player.ready_callback_ref) {
            napi_value callback;
            napi_get_reference_value(env, g_player.ready_callback_ref, &callback);
            napi_value unused;
            napi_call_function(env, nullptr, callback, 0, nullptr, &unused);
        }

        // 3. 如果 auto_start 为 true，自动开始播放
        if (ctx->auto_start) {
            OH_AudioRenderer_Start(g_player.renderer);
            g_player.play_state = STATE_PLAYING;
            g_player.ended_naturally = false;
            notify_status_callback(&g_player, "playing");
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
// NAPI: set_audio(path: string, auto_start?: boolean, time?: number) → Promise<boolean>
// ============================================================================
napi_value set_audio(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
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

    // 解析可选参数 auto_start（默认 true）
    bool auto_start = true;
    if (argc >= 2) {
        napi_valuetype vt;
        napi_typeof(env, args[1], &vt);
        if (vt == napi_boolean) {
            napi_get_value_bool(env, args[1], &auto_start);
        }
    }

    // 解析可选参数 time（默认 0，即不跳转）
    int64_t start_time = 0;
    if (argc >= 3) {
        napi_valuetype vt;
        napi_typeof(env, args[2], &vt);
        if (vt == napi_number) {
            napi_get_value_int64(env, args[2], &start_time);
        }
    }

    // 检查文件是否存在，不存在直接返回 false
    {
        FILE* test_file = fopen(file_path.c_str(), "r");
        if (!test_file) {
            napi_value promise;
            napi_deferred deferred;
            napi_create_promise(env, &deferred, &promise);

            napi_value result;
            napi_get_boolean(env, false, &result);
            napi_resolve_deferred(env, deferred, result);

            return promise;
        }
        fclose(test_file);
    }

    auto* ctx = new SetAudioContext();
    ctx->env = env;
    ctx->file_path = file_path;
    ctx->success = false;
    ctx->auto_start = auto_start;
    ctx->start_time = start_time;

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
    if (!ctx->format_ctx || !ctx->codec_ctx || !ctx->audio_stream) {
        // 播放器未初始化，无法 seek
        napi_value result;
        napi_get_undefined(env, &result);
        return result;
    }

    ctx->seek_target_ms = target_ms;

    // 只在非播放状态直接执行 seek（此时无并发解码，安全）。
    // 播放中时，on_write_data 音频线程会在下次回调中处理 seek。
    int state = ctx->play_state.load();
    if (state != STATE_PLAYING) {
        perform_seek(ctx);
    }

    // 通知 ArkTS 时间回调（复用 time_callback，发送跳转目标时间）
    if (ctx->time_callback) {
        int32_t* data = new int32_t((int32_t)target_ms);
        napi_call_threadsafe_function(ctx->time_callback, data, napi_tsfn_blocking);
    }

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
        napi_create_int32(env, 0, &result);
        return result;
    }

    int32_t current_ms = (int32_t)(ctx->total_frames_written.load() * 1000 / ctx->output_sample_rate);

    napi_value result;
    napi_create_int32(env, current_ms, &result);
    return result;
}

// ============================================================================
// NAPI: register_time_callback(callback: function)
// ============================================================================
static void time_callback_tsfn(napi_env env, napi_value js_callback, void* context, void* data) {
    int32_t time_ms = *(int32_t*)data;
    delete (int32_t*)data;  // 释放堆分配的 int32

    napi_value arg;
    napi_create_int32(env, time_ms, &arg);

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
// NAPI: switch_eq(mode: int) — 设置 EQ 模式（0=OFF, 1=GEQ, 2=PEQ）
// ============================================================================
napi_value switch_eq(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "需要传入一个整数参数 (0/1/2)");
        return nullptr;
    }

    int32_t mode = 0;
    napi_get_value_int32(env, args[0], &mode);

    // 越界丢弃不修改
    if (mode < 0 || mode > 2) {
        napi_value result;
        napi_get_undefined(env, &result);
        return result;
    }

    PlayerContext* ctx = &g_player;
    ctx->eq_mode.store(mode);
    ctx->eq_dirty = true;

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ============================================================================
// NAPI: get_eq_mode() — 获取当前 EQ 模式 → int (0/1/2)
// ============================================================================
napi_value get_eq_mode(napi_env env, napi_callback_info info) {
    PlayerContext* ctx = &g_player;
    int mode = ctx->eq_mode.load();

    napi_value result;
    napi_create_int32(env, mode, &result);
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
