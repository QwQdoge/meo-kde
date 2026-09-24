cmake_minimum_required(VERSION 3.21)
project(MeoSystem VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(CTest)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Network Qml Test)
find_package(KF6NetworkManagerQt REQUIRED)
find_package(KF6BluezQt REQUIRED)
find_package(KF6Solid REQUIRED)
find_package(KF6PulseAudioQt REQUIRED)
find_package(KF6GuiAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6I18n REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(Plasma REQUIRED)

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
    performancecontroller.cpp
    performancecontroller.h
    taskmanagercontroller.cpp
    taskmanagercontroller.h
    sessionactionclient.cpp
    sessionactionclient.h
    mediacontroller.cpp
    mediacontroller.h
    weathercache.cpp
    weathercache.h
    desktopwidgetbridge.cpp
    desktopwidgetbridge.h
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
    KF6::I18n
    Plasma::Plasma
)

add_executable(meo-system-state-smoke
    systemstate-smoke.cpp
    systemstatehub.cpp
    systemstatehub.h
    platformcontroller.cpp
    platformcontroller.h
    performancecontroller.cpp
    performancecontroller.h
    taskmanagercontroller.cpp
    taskmanagercontroller.h
    mediacontroller.cpp
    mediacontroller.h
    weathercache.cpp
    weathercache.h
    desktopwidgetbridge.cpp
    desktopwidgetbridge.h
)
target_link_libraries(meo-system-state-smoke PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Network
    KF6::NetworkManagerQt
    KF6::BluezQt
    KF6::Solid
    KF6::PulseAudioQt
    KF6::GuiAddons
    KF6::I18n
    Plasma::Plasma
)

if(BUILD_TESTING)
    add_executable(meo-weather-cache-test
        tests/weathercache-test.cpp
        weathercache.cpp
        weathercache.h
    )
    target_include_directories(meo-weather-cache-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_compile_definitions(meo-weather-cache-test PRIVATE
        MEO_I18N_LOCALE_DIR="${CMAKE_BINARY_DIR}/translations/locale"
    )
    target_link_libraries(meo-weather-cache-test PRIVATE Qt6::Core Qt6::Test KF6::I18n)
    add_test(NAME meo-weather-cache COMMAND meo-weather-cache-test)
    set_tests_properties(meo-weather-cache PROPERTIES
        ENVIRONMENT "LANG=zh_CN.UTF-8;LC_ALL=zh_CN.UTF-8;LANGUAGE=zh_CN"
    )

    add_executable(meo-performance-controller-test
        tests/performancecontroller-test.cpp
        performancecontroller.cpp
        performancecontroller.h
    )
    target_include_directories(meo-performance-controller-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_link_libraries(meo-performance-controller-test PRIVATE Qt6::Core Qt6::Network Qt6::Test)
    add_test(NAME meo-performance-controller COMMAND meo-performance-controller-test)

    add_executable(meo-task-manager-controller-test
        tests/taskmanagercontroller-test.cpp
        taskmanagercontroller.cpp
        taskmanagercontroller.h
    )
    target_include_directories(meo-task-manager-controller-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_link_libraries(meo-task-manager-controller-test PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
    add_test(NAME meo-task-manager-controller COMMAND meo-task-manager-controller-test)

    add_executable(meo-desktop-widget-bridge-test
        tests/desktopwidgetbridge-test.cpp
        desktopwidgetbridge.cpp
        desktopwidgetbridge.h
    )
    target_include_directories(meo-desktop-widget-bridge-test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_link_libraries(meo-desktop-widget-bridge-test PRIVATE
        Qt6::Core Qt6::Test KF6::I18n Plasma::Plasma)
    add_test(NAME meo-desktop-widget-bridge COMMAND meo-desktop-widget-bridge-test)
endif()

add_executable(meo-task-role-smoke task-role-smoke.cpp)
target_link_libraries(meo-task-role-smoke PRIVATE Qt6::Core Qt6::Gui PW::LibTaskManager)

add_executable(meo-system-monitor systemmonitor-main.cpp)
target_link_libraries(meo-system-monitor PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)

add_executable(meo-session-actiond
    sessionaction-main.cpp
    sessionactionservice.cpp
    sessionactionservice.h
)
target_link_libraries(meo-session-actiond PRIVATE Qt6::Core Qt6::DBus KF6::I18n)

add_executable(meo-weather-refresh weatherrefresh.cpp weathercache.cpp weathercache.h)
target_link_libraries(meo-weather-refresh PRIVATE Qt6::Core Qt6::Network KF6::I18n)

# scripts/validate.sh configures native/system directly before the full native
# build. Compile the same KI18n catalogs in that standalone configuration so
# focused system tests do not silently fall back to English.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../translations"
                     "${CMAKE_BINARY_DIR}/translations")
endif()

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
# With Unix Makefiles, both this target and meosystemplugin own the
# qt6_extract_metatypes intermediate.  Order them explicitly so parallel
# recursive make cannot launch two moc --collect-json writers for the same
# JSON file.
add_dependencies(meosystem-qmltypes meosystemplugin)

include(GNUInstallDirs)
install(TARGETS meosystemplugin
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
install(TARGETS meo-session-actiond meo-weather-refresh meo-system-monitor RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../../data/applications/org.meo.systemmonitor.desktop"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
)
install(FILES org.meo.SessionAction1.service
    DESTINATION "${CMAKE_INSTALL_DATADIR}/dbus-1/services"
)
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/../../defaults/systemd/meo-weather-refresh.service"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../defaults/systemd/meo-weather-refresh.timer"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/systemd/user"
)
install(FILES qmldir
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
install(FILES "${meosystem_qmltypes}"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/System"
)
