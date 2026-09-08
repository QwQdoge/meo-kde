cmake_minimum_required(VERSION 3.21)
project(MeoDock VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)
include(CTest)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml Quick QuickControls2 Test)
find_package(KF6Config REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(LayerShellQt REQUIRED)

if(COMMAND qt_policy)
    qt_policy(SET QTP0001 NEW)
endif()

qt_add_executable(meo-dock
    main.cpp
    dockconfig.cpp
    dockconfig.h
    dockwindowcontroller.cpp
    dockwindowcontroller.h
)

# Compile the shell QML with qmlcachegen as part of the executable. MeoUI and
# MeoKDE remain independent runtime modules resolved through normal imports.
set_source_files_properties(qml/Main.qml PROPERTIES QT_RESOURCE_ALIAS Main.qml)
set_source_files_properties(qml/DockIconDelegate.qml PROPERTIES QT_RESOURCE_ALIAS DockIconDelegate.qml)
set_source_files_properties(qml/DockPreviewIcon.qml PROPERTIES QT_RESOURCE_ALIAS DockPreviewIcon.qml)
set_source_files_properties(qml/LaunchSurfaceWindow.qml PROPERTIES QT_RESOURCE_ALIAS LaunchSurfaceWindow.qml)

qt_add_qml_module(meo-dock
    URI org.meo.dock
    VERSION 1.0
    # KDE and MeoUI are shared runtime QML modules. Do not try to statically
    # link every plugin discovered from the developer machine's import path.
    NO_IMPORT_SCAN
    QML_FILES
        qml/Main.qml
        qml/DockIconDelegate.qml
        qml/DockPreviewIcon.qml
        qml/LaunchSurfaceWindow.qml
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

set(MEOUI_IMPORT_ROOT_PATH "" CACHE PATH
    "QML import root containing the built MeoUI module")
if(NOT MEOUI_IMPORT_ROOT_PATH
   AND EXISTS "${MEOUI_SOURCE_DIR}/out/build/release/MeoUI/qmldir")
    set(MEOUI_IMPORT_ROOT_PATH "${MEOUI_SOURCE_DIR}/out/build/release")
endif()
if(MEOUI_IMPORT_ROOT_PATH)
    target_compile_definitions(meo-dock PRIVATE
        MEOUI_IMPORT_ROOT_PATH="${MEOUI_IMPORT_ROOT_PATH}"
    )
endif()
set(MEO_KDE_IMPORT_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../qml" CACHE PATH
    "QML import root containing the MeoKDE module")
target_compile_definitions(meo-dock PRIVATE
    MEO_KDE_IMPORT_ROOT_PATH="${MEO_KDE_IMPORT_ROOT_PATH}"
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
