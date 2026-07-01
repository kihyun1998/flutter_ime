# Standalone unit-test harness for the flutter_ime Windows plugin.
#
# It compiles the plugin's pure, side-effect-free logic (input-source token
# parsing) together with GoogleTest, so the parsing that guards against the
# std::stoul crash (issue #3) can be exercised directly without a Flutter
# engine, a plugin registrar, or a window.
#
# Configure, build & run (from repo root):
#   cmake -S windows/test -B build/win-test -G "Visual Studio 17 2022" -A x64
#   cmake --build build/win-test --config Debug
#   ctest --test-dir build/win-test -C Debug --output-on-failure

cmake_minimum_required(VERSION 3.14)
project(flutter_ime_windows_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- GoogleTest --------------------------------------------------------------
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/release-1.12.1.zip
)
# Match MSVC's dynamic CRT (/MD) so linking succeeds.
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

# --- The test executable -----------------------------------------------------
set(PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
add_executable(flutter_ime_windows_test
  "${PLUGIN_DIR}/input_source_token.cpp"
  "input_source_token_test.cpp"
)
target_include_directories(flutter_ime_windows_test PRIVATE "${PLUGIN_DIR}")
target_link_libraries(flutter_ime_windows_test PRIVATE GTest::gtest_main)

include(GoogleTest)
enable_testing()
gtest_discover_tests(flutter_ime_windows_test)
