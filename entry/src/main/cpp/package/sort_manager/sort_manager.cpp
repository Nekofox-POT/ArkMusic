#include "sort_manager.h"
#include <algorithm>
#include <locale>
#include <cstring>
#include <stdexcept>

// 字符分类权重
enum CharWeight {
    PUNCTUATION = 0,
    DIGIT = 1,
    LETTER = 2,
    CHINESE = 3
};

// UTF-8 解码：从一个 UTF-8 字节序列中读取一个 Unicode 码点，推进指针
static uint32_t decode_utf8(const char*& p) {
    unsigned char c = static_cast<unsigned char>(*p++);
    if (c < 0x80) {
        return c;
    }

    uint32_t cp;
    int len;
    if ((c & 0xE0) == 0xC0) {
        cp = c & 0x1F;
        len = 1;
    } else if ((c & 0xF0) == 0xE0) {
        cp = c & 0x0F;
        len = 2;
    } else if ((c & 0xF8) == 0xF0) {
        cp = c & 0x07;
        len = 3;
    } else {
        return c;
    }

    while (len--) {
        cp = (cp << 6) | (static_cast<unsigned char>(*p++) & 0x3F);
    }
    return cp;
}

// 将字符串完全解码为码点序列
static std::vector<uint32_t> decode_all(const std::string& s) {
    std::vector<uint32_t> result;
    const char* p = s.c_str();
    const char* end = p + s.size();
    while (p < end) {
        result.push_back(decode_utf8(p));
    }
    return result;
}

// 获取字符权重（与 ArkTS 端 getCharWeight 逻辑一致）
static int get_char_weight(uint32_t cp) {
    // 空字符兜底
    if (cp == 0) {
        return CHINESE;
    }

    // 符号
    if ((cp >= 33 && cp <= 47) ||
        (cp >= 58 && cp <= 64) ||
        (cp >= 91 && cp <= 96) ||
        (cp >= 123 && cp <= 126)) {
        return PUNCTUATION;
    }

    // 数字
    if (cp >= 48 && cp <= 57) {
        return DIGIT;
    }

    // 字母
    if ((cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122)) {
        return LETTER;
    }

    // 中文
    if ((cp >= 0x4E00 && cp <= 0x9FFF) ||
        (cp >= 0x3400 && cp <= 0x4DBF) ||
        (cp >= 0x20000 && cp <= 0x2A6DF)) {
        return CHINESE;
    }

    return PUNCTUATION;
}

// 将单个码点编码回 UTF-8 字节串（用于 locale 比较）
static std::string cp_to_utf8(uint32_t cp) {
    std::string result;
    if (cp < 0x80) {
        result += static_cast<char>(cp);
    } else if (cp < 0x800) {
        result += static_cast<char>(0xC0 | (cp >> 6));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
        result += static_cast<char>(0xE0 | (cp >> 12));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
        result += static_cast<char>(0xF0 | (cp >> 18));
        result += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
        result += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        result += static_cast<char>(0x80 | (cp & 0x3F));
    }
    return result;
}

// BCP 47 格式转 POSIX 格式（"zh-CN" -> "zh_CN.UTF-8"）
static std::string bcp47_to_posix(const std::string& bcp47) {
    std::string result;
    for (char c : bcp47) {
        result += (c == '-') ? '_' : c;
    }
    result += ".UTF-8";
    return result;
}

// 核心排序函数
std::vector<std::string> sort_string_array(const std::vector<std::string>& arr) {
    if (arr.empty()) {
        return {};
    }

    // 1. 预解码所有字符串，避免重复解码
    std::vector<std::pair<std::vector<uint32_t>, std::string>> pairs;
    pairs.reserve(arr.size());
    for (const auto& s : arr) {
        pairs.emplace_back(decode_all(s), s);
    }

    // 2. 尝试获取 locale 比较器（中文拼音排序）
    const std::collate<char>* coll = nullptr;
    std::locale loc;
    try {
        loc = std::locale(bcp47_to_posix("zh-CN").c_str());
        coll = &std::use_facet<std::collate<char>>(loc);
    } catch (...) {
        try {
            loc = std::locale("zh_CN");
            coll = &std::use_facet<std::collate<char>>(loc);
        } catch (...) {
            coll = nullptr;
        }
    }

    // 3. 排序
    std::sort(pairs.begin(), pairs.end(), [&](const auto& a, const auto& b) {
        const auto& va = a.first;
        const auto& vb = b.first;
        size_t min_len = std::min(va.size(), vb.size());

        for (size_t i = 0; i < min_len; i++) {
            int wa = get_char_weight(va[i]);
            int wb = get_char_weight(vb[i]);

            // 类型不同，按权重排序
            if (wa != wb) {
                return wa < wb;
            }

            // 类型相同，组内比较
            if (wa == LETTER) {
                // 字母：不区分大小写
                uint32_t la = va[i];
                uint32_t lb = vb[i];
                if (la >= 'A' && la <= 'Z') la += 32;
                if (lb >= 'A' && lb <= 'Z') lb += 32;
                if (la != lb) return la < lb;
            } else if (wa == CHINESE && coll) {
                // 中文：使用 locale 拼音比较
                std::string sa = cp_to_utf8(va[i]);
                std::string sb = cp_to_utf8(vb[i]);
                long cmp = coll->compare(sa.data(), sa.data() + sa.size(),
                                         sb.data(), sb.data() + sb.size());
                if (cmp != 0) return cmp < 0;
            } else {
                // 符号/数字：按码点比较
                if (va[i] != vb[i]) return va[i] < vb[i];
            }
        }

        // 前面字符一致，短的在前
        return va.size() < vb.size();
    });

    // 4. 提取排序后的原始字符串
    std::vector<std::string> result;
    result.reserve(pairs.size());
    for (auto& p : pairs) {
        result.push_back(std::move(p.second));
    }
    return result;
}
