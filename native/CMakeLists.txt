cmake_minimum_required(VERSION 3.21)
project(MeoKDENative VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(system)
add_subdirectory(decoration)
add_subdirectory(effects/windowcorners)
