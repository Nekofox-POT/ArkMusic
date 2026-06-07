//
// 像素分析
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include "pixel_count.h"
#include <vector>
#include <map>
#include <algorithm>

// ============================================================================
// 内部结构 / 辅助函数
// ============================================================================

// 量化颜色键（用于直方图统计）
struct ColorKey {
    unsigned char r;
    unsigned char g;
    unsigned char b;

    bool operator<(const ColorKey& other) const {
        if (r != other.r) { return r < other.r; }
        if (g != other.g) { return g < other.g; }
        return b < other.b;
    }
};

// RGB → "#rrggbb" 十六进制字符串（小写）
static std::string rgb_to_hex(unsigned char r, unsigned char g, unsigned char b) {
    const char hex_chars[] = "0123456789abcdef";
    std::string result = "#";
    result += hex_chars[(r >> 4) & 0xF];
    result += hex_chars[r & 0xF];
    result += hex_chars[(g >> 4) & 0xF];
    result += hex_chars[g & 0xF];
    result += hex_chars[(b >> 4) & 0xF];
    result += hex_chars[b & 0xF];
    return result;
}

// 从 ArrayBuffer 提取像素数据
static bool get_pixel_data(napi_env env, napi_value array_buffer, int width, int height,
                           unsigned char*& out_data, size_t& out_count) {

    void* buffer = nullptr;
    size_t buffer_length = 0;
    napi_status status = napi_get_arraybuffer_info(env, array_buffer, &buffer, &buffer_length);

    if (status != napi_ok || buffer == nullptr || width <= 0 || height <= 0) {
        return false;
    }

    size_t expected_length = static_cast<size_t>(width) * height * 4;
    if (buffer_length < expected_length) {
        return false;
    }

    out_data = static_cast<unsigned char*>(buffer);
    out_count = static_cast<size_t>(width) * height;
    return true;
}

// ============================================================================
// 1. 计算图片像素平均亮度值 (0-255)
// ============================================================================
uint32_t get_pixel_light(napi_env env, napi_value array_buffer, int width, int height) {

    unsigned char* data = nullptr;
    size_t pixel_count = 0;

    if (!get_pixel_data(env, array_buffer, width, height, data, pixel_count)) {
        return 0;
    }

    uint64_t sum_r = 0, sum_g = 0, sum_b = 0;

    for (size_t i = 0; i < pixel_count; i++) {
        size_t idx = i * 4;
        sum_r += data[idx];     // Red
        sum_g += data[idx + 1]; // Green
        sum_b += data[idx + 2]; // Blue
    }

    uint8_t avg_r = static_cast<uint8_t>(sum_r / pixel_count);
    uint8_t avg_g = static_cast<uint8_t>(sum_g / pixel_count);
    uint8_t avg_b = static_cast<uint8_t>(sum_b / pixel_count);

    // L = 0.299 * R + 0.587 * G + 0.114 * B (BT.601)
    uint8_t luminance = static_cast<uint8_t>(
        0.299 * avg_r + 0.587 * avg_g + 0.114 * avg_b
    );

    return static_cast<uint32_t>(luminance);
}

// ============================================================================
// 2. 计算图片主色调 → "#rrggbb"
// ============================================================================
std::string get_pixel_color(napi_env env, napi_value array_buffer, int width, int height) {

    unsigned char* data = nullptr;
    size_t pixel_count = 0;

    if (!get_pixel_data(env, array_buffer, width, height, data, pixel_count)) {
        return "#000000";
    }

    // 颜色直方图（4 bit 量化 = 每通道 16 级）
    std::map<ColorKey, size_t> histogram;
    const int QUANT_SHIFT = 4;

    for (size_t i = 0; i < pixel_count; i++) {
        size_t idx = i * 4;
        unsigned char r = data[idx];
        unsigned char g = data[idx + 1];
        unsigned char b = data[idx + 2];
        unsigned char a = data[idx + 3];

        // 过滤透明像素
        if (a < 128) { continue; }
        // 过滤极暗像素（黑边）
        if (static_cast<int>(r) + g + b < 45) { continue; }

        ColorKey key;
        key.r = (r >> QUANT_SHIFT) << QUANT_SHIFT;
        key.g = (g >> QUANT_SHIFT) << QUANT_SHIFT;
        key.b = (b >> QUANT_SHIFT) << QUANT_SHIFT;
        histogram[key]++;
    }

    // 没有有效像素
    if (histogram.empty()) {
        return "#000000";
    }

    // 取频次最高的颜色
    auto max_it = std::max_element(histogram.begin(), histogram.end(),
        [](const auto& a, const auto& b) { return a.second < b.second; });

    return rgb_to_hex(max_it->first.r, max_it->first.g, max_it->first.b);
}

// ============================================================================
// 3. 计算图片三分主色 → ["#rrggbb", "#rrggbb", "#rrggbb"]
// ============================================================================
std::vector<std::string> get_pixel_dominant(napi_env env, napi_value array_buffer, int width, int height) {

    unsigned char* data = nullptr;
    size_t pixel_count = 0;

    if (!get_pixel_data(env, array_buffer, width, height, data, pixel_count)) {
        return {"#000000", "#000000", "#000000"};
    }

    std::map<ColorKey, size_t> histogram;
    const int QUANT_SHIFT = 4;

    for (size_t i = 0; i < pixel_count; i++) {
        size_t idx = i * 4;
        unsigned char r = data[idx];
        unsigned char g = data[idx + 1];
        unsigned char b = data[idx + 2];
        unsigned char a = data[idx + 3];

        if (a < 128) { continue; }
        if (static_cast<int>(r) + g + b < 45) { continue; }

        ColorKey key;
        key.r = (r >> QUANT_SHIFT) << QUANT_SHIFT;
        key.g = (g >> QUANT_SHIFT) << QUANT_SHIFT;
        key.b = (b >> QUANT_SHIFT) << QUANT_SHIFT;
        histogram[key]++;
    }

    // 按频次降序
    std::vector<std::pair<ColorKey, size_t>> sorted(histogram.begin(), histogram.end());
    std::sort(sorted.begin(), sorted.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });

    // 去重：跳过与已有结果色距过近的颜色（阈值 delta = 32）
    struct RgbColor { unsigned char r, g, b; };
    std::vector<RgbColor> result_colors;

    for (size_t i = 0; i < sorted.size(); i++) {
        unsigned char r = sorted[i].first.r;
        unsigned char g = sorted[i].first.g;
        unsigned char b = sorted[i].first.b;

        // 检查与已有结果的欧几里得色距
        bool too_close = false;
        for (const auto& existing : result_colors) {
            int dr = static_cast<int>(r) - static_cast<int>(existing.r);
            int dg = static_cast<int>(g) - static_cast<int>(existing.g);
            int db = static_cast<int>(b) - static_cast<int>(existing.b);
            if (dr * dr + dg * dg + db * db < 32 * 32) {
                too_close = true;
                break;
            }
        }

        if (!too_close) {
            result_colors.push_back({r, g, b});
        }

        if (result_colors.size() >= 3) { break; }
    }

    // 转换为 hex 字符串
    std::vector<std::string> result;
    for (const auto& c : result_colors) {
        result.push_back(rgb_to_hex(c.r, c.g, c.b));
    }

    // 不足 3 个用黑色补齐
    while (result.size() < 3) {
        result.push_back("#000000");
    }

    return result;
}
