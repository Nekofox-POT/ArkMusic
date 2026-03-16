#ifndef EXTRACT_FILENAME_H
#define EXTRACT_FILENAME_H

#include <string>

// 从文件路径中提取文件名（不带扩展名）
// 示例："/path/to/file/name.txt" -> "name"
std::string ExtractFilenameWithoutExtension(const std::string& path);

#endif // EXTRACT_FILENAME_H
