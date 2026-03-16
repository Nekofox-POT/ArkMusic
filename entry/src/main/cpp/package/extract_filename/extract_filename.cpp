#include "extract_filename.h"
#include <algorithm>

std::string ExtractFilenameWithoutExtension(const std::string& path) {
    if (path.empty()) {
        return "";
    }

    // 1. 找到最后一个路径分隔符（支持 Unix '/' 和 Windows '\\'）
    size_t lastSlash = path.find_last_of("/\\");
    
    // 2. 提取文件名部分（从分隔符后一位开始，到字符串末尾）
    std::string filename;
    if (lastSlash == std::string::npos) {
        // 没有路径分隔符，整个字符串就是文件名
        filename = path;
    } else {
        // 有路径分隔符，提取分隔符后的部分
        filename = path.substr(lastSlash + 1);
    }

    // 3. 去掉文件扩展名（找到最后一个 '.'）
    size_t lastDot = filename.find_last_of('.');
    
    // 检查点是否是有效的扩展名分隔符（不能是文件名的第一个字符）
    if (lastDot != std::string::npos && lastDot > 0) {
        filename = filename.substr(0, lastDot);
    }

    return filename;
}
