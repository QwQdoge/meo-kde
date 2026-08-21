cmake_minimum_required(VERSION 3.21)
project(MeoSystem VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml)
find_package(KF6NetworkManagerQt REQUIRED)
find_package(KF6BluezQt REQUIRED)
find_package(KF6Solid REQUIRED)
find_package(KF6PulseAudioQt REQUIRED)
find_package(KF6GuiAddons REQUIRED)
find_package(LibTaskManager REQUIRED)

# `scripts/validate.sh` configures this directory directly.  Bring in the
# shared generator there as well as from the top-level native build so the QML
# plugin and its import are tested together.
if(NOT TARGET Meo::DynamicColorCore)
    include(GNUInstallDirs)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../third_party/material-color-utilities"
                     "${CMAKE_CURRENT_BINARY_DIR}/material-color-utilities")
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../dynamic-color"
                     "${CMAKE_CURRENT_BINARY_DIR}/dynamic-color")
endif()

add_library(meosystemplugin MODULE
    meosystemplugin.cpp
    systemstatehub.cpp
    systemstatehub.h
    dynamiccolorprovider.cpp
    dynamiccolorprovider.h
    platformcontroller.cpp
    platformcontroller.h
    mediacontroller.cpp
    mediacontroller.h
)
set_target_properties(meosystemplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Meo/System"
)
target_link_libraries(meosystemplugin PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Meo::DynamicColorCore
    KF6::NetworkManagerQt
    KF6::BluezQt
    KF6::Solid
    KF6::PulseAudioQt
    KF6::GuiAddons
)

add_executable(meo-system-state-smoke
    systemstate-smoke.cpp
    systemstatehub.cpp
    systemstatehub.h
    platformcontroller.cpp
    platformcontroller.h
    mediacontroller.cpp
    mediacontroller.h
)
target_link_libraries(meo-system-state-smoke PRIVATE
    Qt6::Core
    Qt6::DBus
    KF6::NetworkManagerQt
    KF6::BluezQt
    KF6::Solid
    KF6::PulseAudioQt
    KF6::GuiAddons
)

add_executable(meo-task-role-smoke task-role-smoke.cpp)
target_link_libraries(meo-task-role-smoke PRIVATE Qt6::Core Qt6::Gui PW::LibTaskManager)

configure_file(qmldir "${CMAKE_BINARY_DIR}/qml/Meo/System/qmldir" COPYONLY)

include(GNUInstallDirs)
install(TARGETS meosystemplugin
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
install(FILES qmldir
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
