#include "base64url_code.h"
#include <cstring>
#include <vector>

// --- Base64URL 辅助代码实现 ---
// Base64URL 字符表：与标准 Base64 的区别是 '+' -> '-', '/' -> '_'
static const std::string base64url_chars = 
             "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
             "abcdefghijklmnopqrstuvwxyz"
             "0123456789-_";

// 解码用的反向查找表
static const int base64url_decode_table[256] = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, // 62 = '-'
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, // 0-9
    -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, // A-O
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, 63, // P-Z, 63 = '_'
    -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, // a-o
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1, // p-z
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
};

// Base64URL 编码实现
std::string base64url_encode(const std::string& input) {
    std::string ret;
    int i = 0;
    int j = 0;
    unsigned char char_array_3[3];
    unsigned char char_array_4[4];
    const unsigned char* bytes_to_encode = reinterpret_cast<const unsigned char*>(input.c_str());
    size_t in_len = input.length();

    while (in_len--) {
        char_array_3[i++] = *(bytes_to_encode++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for(i = 0; i < 4; i++)
                ret += base64url_chars[char_array_4[i]];
            i = 0;
        }
    }

    if (i) {
        for(j = i; j < 3; j++)
            char_array_3[j] = '\0';

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (j = 0; j < i + 1; j++)
            ret += base64url_chars[char_array_4[j]];

        // Base64URL 不添加 '=' 填充
    }
    return ret;
}

// Base64URL 解码实现
std::string base64url_decode(const std::string& input) {
    size_t in_len = input.length();
    std::string ret;
    std::vector<int> decoded_values;

    // 解码所有字符
    for (size_t i = 0; i < in_len; i++) {
        int val = base64url_decode_table[static_cast<unsigned char>(input[i])];
        if (val == -1) {
            // 遇到非法字符，跳过或返回空
            return "";
        }
        decoded_values.push_back(val);
    }

    // 每 4 个字符解码为 3 个字节
    size_t i = 0;
    while (i < decoded_values.size()) {
        // 至少需要 2 个字符才能解码
        if (decoded_values.size() - i < 2) break;

        unsigned char char_array_4[4] = {0, 0, 0, 0};
        unsigned char char_array_3[3] = {0, 0, 0};

        // 填充 char_array_4
        int valid_count = 0;
        for (int j = 0; j < 4 && (i + j) < decoded_values.size(); j++) {
            char_array_4[j] = decoded_values[i + j];
            valid_count++;
        }

        if (valid_count >= 4) {
            // 完整的 4 字符组
            char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
            char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
            char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

            ret += char_array_3[0];
            ret += char_array_3[1];
            ret += char_array_3[2];
            i += 4;
        } else if (valid_count == 3) {
            // 3 字符（原始 2 字节）
            char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
            char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
            ret += char_array_3[0];
            ret += char_array_3[1];
            i += 3;
        } else if (valid_count == 2) {
            // 2 字符（原始 1 字节）
            char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
            ret += char_array_3[0];
            i += 2;
        } else {
            break;
        }
    }

    return ret;
}
// --- Base64URL 辅助代码结束 ---

// --- 核心业务逻辑实现 ---
// 职责：根据 is_encode 决定编码或解码
std::string process_base64url_code(const std::string& input, bool is_encode) {
    if (input.empty()) {
        return "";
    }

    if (is_encode) {
        return base64url_encode(input);
    } else {
        return base64url_decode(input);
    }
}
