# CMakeLists.txt for LocalSend HarmonyOS
cmake_minimum_required(VERSION 3.4.1)
project(localsend_napi)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

# 包含头文件目录
include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
)

# ============================================================================
# NAPI 模块
# ============================================================================

add_library(entry SHARED 
    localsend.cpp
    localsend_native.cpp
)

# 链接库
target_link_libraries(entry 
    PUBLIC 
    libace_napi.z.so
    libhilog_ndk.z.so
)

# ============================================================================
# 编译选项
# ============================================================================

target_compile_options(entry PRIVATE
    -Wall
    -Wextra
    -fvisibility=hidden
)

# C++17 标准
set_target_properties(entry PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
