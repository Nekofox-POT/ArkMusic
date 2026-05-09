# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(ArkMusic)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include
                    ${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/include)

# 关键修改点：
# 1. 设置 C++ 标准为 C++14 或更高（推荐）
set(CMAKE_CXX_STANDARD 14)

add_library(
entry SHARED napi_init.cpp
package/buffer_to_base64/buffer_to_base64.cpp
package/image_color_calculate/image_color_calculate.cpp
package/extract_filename/extract_filename.cpp
package/ffmpeg_manager/ffmpeg_manager.cpp
package/base64url_code/base64url_code.cpp
package/sort_manager/sort_manager.cpp
package/dsd_to_wav/dsd_to_wav.cpp
)

# 关键修改点：
# 2. 链接必要的库
#    libace_napi.z.so：NAPI 接口支持
#    libc++.so：C++ 标准库支持 (string, vector 等)
#    使用 FFmpeg 动态库 (.so)，因为静态库 (.a) 未用 -fPIC 编译
target_link_libraries(entry PUBLIC
                      libace_napi.z.so
                      libc++.so
                      ${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavformat.so.62.12.101
                      ${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavcodec.so.62.28.101
                      ${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavutil.so.60.26.101
)

# 3. 将 FFmpeg 动态库复制到 libentry.so 的输出目录，确保运行时能找到
add_custom_command(TARGET entry POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavformat.so.62.12.101"
        "$<TARGET_FILE_DIR:entry>/libavformat.so.62"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavcodec.so.62.28.101"
        "$<TARGET_FILE_DIR:entry>/libavcodec.so.62"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${NATIVERENDER_ROOT_PATH}/package/ffmpeg_manager/ffmpeg_core/lib/libavutil.so.60.26.101"
        "$<TARGET_FILE_DIR:entry>/libavutil.so.60"
)
