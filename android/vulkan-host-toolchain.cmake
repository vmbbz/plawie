# vulkan-host-toolchain.cmake
#
# Host toolchain for building vulkan-shaders-gen.exe on Windows x64.
# Used by ggml-vulkan/CMakeLists.txt when cross-compiling for Android
# (CMAKE_CROSSCOMPILING=TRUE) and GGML_VULKAN is enabled.
#
# Prerequisites (one-time machine setup):
#   winget install LLVM.LLVM          -- provides clang / clang++
#
# Windows SDK rc.exe (resource compiler) is required by CMake's Windows-Clang
# platform file. Included with Visual Studio Build Tools or Windows SDK.
#
# This file is referenced from fllama/src/CMakeLists.txt via
# GGML_VULKAN_SHADERS_GEN_TOOLCHAIN cache variable.

set(CMAKE_C_COMPILER   "C:/Program Files/LLVM/bin/clang.exe")
set(CMAKE_CXX_COMPILER "C:/Program Files/LLVM/bin/clang++.exe")
set(CMAKE_RC_COMPILER  "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/rc.exe")
