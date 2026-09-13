cmake_minimum_required(VERSION 3.21)
project(MeoLockScreenBridge VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CTest)
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick Test)

# This is deliberately a presentation-only QML bridge.  KScreenLocker keeps
# ownership of every greeter surface, all input grabs, and PAM authentication.
add_library(meolockscreenplugin MODULE
    meolockscreenplugin.cpp
    screencoordinator.cpp
    screencoordinator.h
)
set_target_properties(meolockscreenplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Meo/KScreenLocker"
)
target_link_libraries(meolockscreenplugin PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
)

add_executable(meo-lockscreen-screen-coordinator-test
    tests/screencoordinator-test.cpp
    screencoordinator.cpp
    screencoordinator.h
)
target_link_libraries(meo-lockscreen-screen-coordinator-test PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Test
)
add_test(NAME meo-lockscreen-screen-coordinator
    COMMAND meo-lockscreen-screen-coordinator-test
)

configure_file(qmldir "${CMAKE_BINARY_DIR}/qml/Meo/KScreenLocker/qmldir" COPYONLY)

# Emit type metadata so qmllint checks this boundary just as strictly as the
# rest of MeoKDE's QML modules.
qt6_extract_metatypes(meolockscreenplugin OUTPUT_FILES meolockscreen_metatypes_file)
set(meolockscreen_qmltypes "${CMAKE_BINARY_DIR}/qml/Meo/KScreenLocker/plugins.qmltypes")
set(meolockscreen_registration_stub "${CMAKE_CURRENT_BINARY_DIR}/meolockscreen_qmltyperegistrations.cpp")
add_custom_command(
    OUTPUT "${meolockscreen_qmltypes}" "${meolockscreen_registration_stub}"
    COMMAND $<TARGET_FILE:Qt6::qmltyperegistrar>
        --generate-qmltypes=${meolockscreen_qmltypes}
        --import-name=Meo.KScreenLocker
        --major-version=1
        --minor-version=0
        -o ${meolockscreen_registration_stub}
        "${meolockscreen_metatypes_file}"
    DEPENDS "${meolockscreen_metatypes_file}" Qt6::qmltyperegistrar
    COMMENT "Generating Meo.KScreenLocker QML type metadata"
    VERBATIM
)
add_custom_target(meolockscreen-qmltypes ALL
    DEPENDS "${meolockscreen_qmltypes}" "${meolockscreen_registration_stub}"
)

include(GNUInstallDirs)
install(TARGETS meolockscreenplugin
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/KScreenLocker"
)
install(FILES qmldir
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/KScreenLocker"
)
install(FILES "${meolockscreen_qmltypes}"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qt6/qml/Meo/KScreenLocker"
)
