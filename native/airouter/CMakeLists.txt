cmake_minimum_required(VERSION 3.21)
project(MeoAIRouter LANGUAGES CXX)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(CTest)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui Test)
find_package(KF6Service REQUIRED)
find_package(KF6KIO REQUIRED)
find_package(KF6PulseAudioQt REQUIRED)

add_library(meo-ai-router-core STATIC router.cpp router.h)
target_include_directories(meo-ai-router-core PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(meo-ai-router-core PUBLIC Qt6::Core)

add_executable(meo-ai-router main.cpp service.cpp service.h)
target_link_libraries(meo-ai-router PRIVATE meo-ai-router-core Qt6::DBus Qt6::Gui KF6::Service KF6::KIOGui KF6::PulseAudioQt)

if(BUILD_TESTING)
    add_executable(meo-ai-router-test tests/router-test.cpp)
    target_link_libraries(meo-ai-router-test PRIVATE meo-ai-router-core Qt6::Test)
    add_test(NAME meo-ai-router COMMAND meo-ai-router-test)
endif()

include(GNUInstallDirs)
install(TARGETS meo-ai-router RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES org.meo.AIRouter1.service DESTINATION "${CMAKE_INSTALL_DATADIR}/dbus-1/services")
install(FILES org.meo.AIRouter.account-client.json DESTINATION "${CMAKE_INSTALL_DATADIR}/meo-account/clients"
        RENAME "org.meo.AIRouter.json")
