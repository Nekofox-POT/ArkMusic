# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(ArkMusic)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

# 关键修改点：
# 1. 设置 C++ 标准为 C++14 或更高（推荐）
set(CMAKE_CXX_STANDARD 14)

add_library(
entry SHARED napi_init.cpp
package/buffer_to_base64/buffer_to_base64.cpp
package/image_color_calculate/image_color_calculate.cpp
package/extract_filename/extract_filename.cpp

)

# 关键修改点：
# 2. 链接必要的库
#    libace_napi.z.so：NAPI 接口支持
#    libc++.so：C++ 标准库支持 (string, vector 等)
target_link_libraries(entry PUBLIC
                      libace_napi.z.so
                      libc++.so
)
