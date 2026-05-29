cmake_minimum_required(VERSION 3.22.1)

project(plawie_node_bridge LANGUAGES CXX)

add_library(plawie_node_bridge SHARED plawie_node_bridge.cpp)

target_compile_features(plawie_node_bridge PRIVATE cxx_std_17)
target_link_libraries(plawie_node_bridge PRIVATE log)

set(PLAWIE_LIBNODE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libnode.so")

if(EXISTS "${PLAWIE_LIBNODE_PATH}")
    add_library(plawie_node SHARED IMPORTED)
    set_target_properties(plawie_node PROPERTIES
        IMPORTED_LOCATION "${PLAWIE_LIBNODE_PATH}")
    target_link_libraries(plawie_node_bridge PRIVATE plawie_node)
    target_compile_definitions(plawie_node_bridge PRIVATE PLAWIE_NODE_HAS_LIBNODE=1)
else()
    target_compile_definitions(plawie_node_bridge PRIVATE PLAWIE_NODE_HAS_LIBNODE=0)
endif()
