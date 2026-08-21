cmake_minimum_required(VERSION 3.21)
project(MeoKDENative VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(CTest)

option(MEO_BUILD_APPLICATION_STYLE "Build the Meo Qt Widgets application style" ON)
set(MEOUI_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../meo-ui" CACHE PATH
    "Path to the MeoUI source tree used for the shared token runtime")

add_subdirectory(third_party/material-color-utilities)
add_subdirectory(dynamic-color)
add_subdirectory(system)
add_subdirectory(decoration)
if(MEO_BUILD_APPLICATION_STYLE)
    add_subdirectory(application-style)
endif()
