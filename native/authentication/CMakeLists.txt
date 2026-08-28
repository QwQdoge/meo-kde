cmake_minimum_required(VERSION 3.21)
project(MeoAuthenticationAgent VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Qml Quick)
find_package(PolkitQt6-1 REQUIRED)
find_package(KF6WindowSystem REQUIRED)

qt_add_executable(meo-polkit-agent
    main.cpp
    authenticationcontroller.cpp
    authenticationcontroller.h
)

qt_add_resources(meo-polkit-agent "meo_authentication_qml"
    PREFIX "/"
    FILES
        qml/AuthenticationDialog.qml
)

target_link_libraries(meo-polkit-agent PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    PolkitQt6-1::Agent
    KF6::WindowSystem
)

include(GNUInstallDirs)
install(TARGETS meo-polkit-agent
    RUNTIME DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)
install(FILES
    data/plasma-polkit-agent.service
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/systemd/user"
)
install(FILES
    data/polkit-kde-authentication-agent-1.desktop
    DESTINATION "${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg/autostart"
)
install(FILES
    data/polkit-kde-authentication-agent-1.desktop
    DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    RENAME org.kde.polkit-kde-authentication-agent-1.desktop
)
