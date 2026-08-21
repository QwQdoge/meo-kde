find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui)
find_package(KF6Config REQUIRED)

add_library(meo-dynamic-color-core STATIC
    dynamiccolors.cpp
    dynamiccolors.h
)
set_target_properties(meo-dynamic-color-core PROPERTIES POSITION_INDEPENDENT_CODE ON)
add_library(Meo::DynamicColorCore ALIAS meo-dynamic-color-core)
target_link_libraries(meo-dynamic-color-core PUBLIC
    Qt6::Core
    Qt6::Gui
    KF6::ConfigCore
    Meo::MaterialColorUtilities
)
target_include_directories(meo-dynamic-color-core PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
)

add_executable(meo-dynamic-colors main.cpp)
target_link_libraries(meo-dynamic-colors PRIVATE Meo::DynamicColorCore)

install(TARGETS meo-dynamic-colors
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

add_executable(meo-dynamic-colors-smoke smoke.cpp)
target_link_libraries(meo-dynamic-colors-smoke PRIVATE Meo::DynamicColorCore)
add_test(NAME meo-dynamic-colors-smoke COMMAND meo-dynamic-colors-smoke)
