cmake_minimum_required(VERSION 3.22.1)

project(plawie_node_bridge LANGUAGES C CXX)

set(PLAWIE_NDK_ROOT "${ANDROID_NDK}")
if(NOT PLAWIE_NDK_ROOT AND DEFINED CMAKE_ANDROID_NDK)
    set(PLAWIE_NDK_ROOT "${CMAKE_ANDROID_NDK}")
endif()

set(PLAWIE_CPUFEATURES_SOURCE
    "${PLAWIE_NDK_ROOT}/sources/android/cpufeatures/cpu-features.c")

if(EXISTS "${PLAWIE_CPUFEATURES_SOURCE}")
    add_library(plawie_cpufeatures SHARED "${PLAWIE_CPUFEATURES_SOURCE}")
    target_include_directories(plawie_cpufeatures PRIVATE
        "${PLAWIE_NDK_ROOT}/sources/android/cpufeatures")
else()
    message(FATAL_ERROR "Android cpufeatures source not found at ${PLAWIE_CPUFEATURES_SOURCE}")
endif()

add_library(plawie_node_bridge SHARED plawie_node_bridge.cpp)

target_compile_features(plawie_node_bridge PRIVATE cxx_std_17)

set(PLAWIE_LIBNODE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libnode.so")

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${PLAWIE_LIBNODE_PATH}")

if(NOT EXISTS "${PLAWIE_LIBNODE_PATH}")
    message(FATAL_ERROR
        "Native-first builds require the verified Android arm64 libnode.so at ${PLAWIE_LIBNODE_PATH}")
endif()

add_library(plawie_node SHARED IMPORTED)
set_target_properties(plawie_node PROPERTIES
    IMPORTED_LOCATION "${PLAWIE_LIBNODE_PATH}")
target_link_libraries(plawie_node_bridge PRIVATE plawie_node plawie_cpufeatures log)
target_compile_definitions(plawie_node_bridge PRIVATE PLAWIE_NODE_HAS_LIBNODE=1)
