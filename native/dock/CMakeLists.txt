cmake_minimum_required(VERSION 3.21)
project(MeoDock VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml Quick QuickControls2 Test)
find_package(KF6Config REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(LayerShellQt REQUIRED)

qt_add_executable(meo-dock
    main.cpp
    dockconfig.cpp
    dockconfig.h
    dockwindowcontroller.cpp
    dockwindowcontroller.h
)

# Keep the shell QML embedded in the executable. MeoUI and MeoKDE remain
# independent runtime modules and are resolved through the normal QML import
# path (or the sibling-tree paths below for local development).
qt_add_resources(meo-dock meo_dock_qml
    PREFIX "/org/meo/dock/qml"
    FILES
        qml/Main.qml
        qml/DockIconDelegate.qml
        qml/DockPreviewIcon.qml
)

target_link_libraries(meo-dock PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    KF6::ConfigCore
    KF6::Kirigami
    KF6::WindowSystem
    PW::LibTaskManager
    LayerShellQt::Interface
)

if(EXISTS "${MEOUI_SOURCE_DIR}/out/build/release/MeoUI/qmldir")
    target_compile_definitions(meo-dock PRIVATE
        MEOUI_IMPORT_ROOT_PATH="${MEOUI_SOURCE_DIR}/out/build/release"
    )
endif()
target_compile_definitions(meo-dock PRIVATE
    MEO_KDE_IMPORT_ROOT_PATH="${CMAKE_CURRENT_SOURCE_DIR}/../../qml"
)

install(TARGETS meo-dock RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")

if(BUILD_TESTING)
    add_executable(meo-dock-config-test
        tst_dockconfig.cpp
        dockconfig.cpp
        dockconfig.h
    )
    target_link_libraries(meo-dock-config-test PRIVATE
        Qt6::Core Qt6::DBus Qt6::Test KF6::ConfigCore
    )
    add_test(NAME meo-dock-config COMMAND meo-dock-config-test)

    add_executable(meo-dock-taskmodel-test tst_taskmodel.cpp)
    target_link_libraries(meo-dock-taskmodel-test PRIVATE
        Qt6::Core Qt6::Gui Qt6::Test PW::LibTaskManager
    )
    add_test(NAME meo-dock-taskmodel COMMAND meo-dock-taskmodel-test)
endif()
