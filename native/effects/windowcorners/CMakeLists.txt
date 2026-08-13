cmake_minimum_required(VERSION 3.21)
project(MeoWindowCorners VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Widgets DBus Quick)
find_package(KWin 6.0 REQUIRED)
find_package(KF6Config REQUIRED)

add_library(meowindowcorners MODULE
    windowcornerseffect.cpp
    windowcornerseffect.h
)

target_link_libraries(meowindowcorners PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KWin::kwin
    KF6::ConfigCore
)

set_target_properties(meowindowcorners PROPERTIES
    OUTPUT_NAME "org.meo.windowcorners"
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin/kwin/effects/plugins"
)

include(GNUInstallDirs)
install(TARGETS meowindowcorners
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/plugins/kwin/effects/plugins"
)
