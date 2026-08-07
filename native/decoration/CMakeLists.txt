cmake_minimum_required(VERSION 3.21)
project(MeoDecoration VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6CoreAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6ColorScheme REQUIRED)
find_package(KDecoration3 REQUIRED)

add_library(meodecoration MODULE
    meodecoration.cpp
    meodecoration.h
    meobutton.cpp
    meobutton.h
)

target_link_libraries(meodecoration PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::ColorScheme
    KDecoration3::KDecoration
)

set_target_properties(meodecoration PROPERTIES
    OUTPUT_NAME "org.meo.decoration"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/org.kde.kdecoration3"
)

include(GNUInstallDirs)
install(TARGETS meodecoration
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/plugins/org.kde.kdecoration3"
)
