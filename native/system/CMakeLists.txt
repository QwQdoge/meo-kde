cmake_minimum_required(VERSION 3.21)
project(MeoSystem VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Network Qml)
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
    sessionactionclient.cpp
    sessionactionclient.h
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
    Qt6::Network
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
    Qt6::Network
    KF6::NetworkManagerQt
    KF6::BluezQt
    KF6::Solid
    KF6::PulseAudioQt
    KF6::GuiAddons
)

add_executable(meo-task-role-smoke task-role-smoke.cpp)
target_link_libraries(meo-task-role-smoke PRIVATE Qt6::Core Qt6::Gui PW::LibTaskManager)

add_executable(meo-session-actiond
    sessionaction-main.cpp
    sessionactionservice.cpp
    sessionactionservice.h
)
target_link_libraries(meo-session-actiond PRIVATE Qt6::Core Qt6::DBus)

configure_file(qmldir "${CMAKE_BINARY_DIR}/qml/Meo/System/qmldir" COPYONLY)

# Keep QML tooling on the same contract as the runtime registrations above.
# The plugin deliberately uses provider callbacks so the process-wide KDE
# backends retain C++ ownership; qmltyperegistrar is used here only to emit the
# static type description consumed by qmllint, qmlls and IDEs.
qt6_extract_metatypes(meosystemplugin OUTPUT_FILES meosystem_metatypes_file)
set(meosystem_qmltypes "${CMAKE_BINARY_DIR}/qml/Meo/System/plugins.qmltypes")
set(meosystem_registration_stub "${CMAKE_CURRENT_BINARY_DIR}/meosystem_qmltyperegistrations.cpp")
add_custom_command(
    OUTPUT "${meosystem_qmltypes}" "${meosystem_registration_stub}"
    COMMAND $<TARGET_FILE:Qt6::qmltyperegistrar>
        --generate-qmltypes=${meosystem_qmltypes}
        --import-name=Meo.System
        --major-version=1
        --minor-version=0
        -o ${meosystem_registration_stub}
        "${meosystem_metatypes_file}"
    DEPENDS "${meosystem_metatypes_file}" Qt6::qmltyperegistrar
    COMMENT "Generating Meo.System QML type metadata"
    VERBATIM
)
add_custom_target(meosystem-qmltypes ALL
    DEPENDS "${meosystem_qmltypes}" "${meosystem_registration_stub}"
)

include(GNUInstallDirs)
install(TARGETS meosystemplugin
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
install(TARGETS meo-session-actiond RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES org.meo.SessionAction1.service
    DESTINATION "${CMAKE_INSTALL_DATADIR}/dbus-1/services"
)
install(FILES qmldir
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
install(FILES "${meosystem_qmltypes}"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
