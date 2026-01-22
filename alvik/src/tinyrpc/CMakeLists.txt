cmake_minimum_required(VERSION 3.20)

project(tinyrpc)


add_library(tinyrpc
    include/tinyrpc/tinyrpc.h
    include/tinyrpc/enet_transport.h
    src/enet_transport.cpp
)
target_include_directories(tinyrpc PRIVATE include )
target_include_directories(tinyrpc PUBLIC third_party/enet/include )
target_include_directories(tinyrpc PUBLIC third_party/ArduinoJson/src )