cmake_minimum_required(VERSION 3.22)
project(DaiJishowCore VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Find system SQLite3 (built into macOS, iOS, watchOS; or NDK/bundled on Android)
find_package(SQLite3 REQUIRED)

add_library(daijishow_core STATIC
    core/dj_storage/storage.cpp
    core/dj_nlp/romaji.cpp
    core/dj_graph/fisheye.cpp
    core/dj_state/session_state.cpp
    core/dj_capi.cpp
)

target_include_directories(daijishow_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/core/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/core
)

target_link_libraries(daijishow_core PUBLIC SQLite::SQLite3)

if(NOT MSVC)
    target_compile_options(daijishow_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Native CLI Test Harness & Benchmark Tool
add_executable(dj_cli tools/dj_cli.cpp)
target_link_libraries(dj_cli PRIVATE daijishow_core)
