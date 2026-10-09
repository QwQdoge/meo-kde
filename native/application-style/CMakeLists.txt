if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.21)
    project(MeoApplicationStyle LANGUAGES CXX)

    set(CMAKE_AUTOMOC ON)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    include(CTest)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Test)

# Pure compile-time design contract. Native applications never load MeoUI/QML.
find_path(meoui_design_include NAMES meodesigntokens.h
    HINTS "${MEOUI_SOURCE_DIR}/runtime" PATH_SUFFIXES include/MeoUI REQUIRED)

add_library(meostyle MODULE
    src/meostyle.cpp
    src/meostyle.h
    src/meostylehelper.cpp
    src/meostylehelper.h
    src/meostylemotion.cpp
    src/meostylemotion.h
    src/meostyleplugin.cpp
    src/meostyleplugin.h
    meostyle.json
)
target_include_directories(meostyle PRIVATE "${meoui_design_include}")
target_link_libraries(meostyle PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets)
set_target_properties(meostyle PROPERTIES
    PREFIX ""
    OUTPUT_NAME "meostyle"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qt-plugins/styles"
)

add_executable(meo-style-gallery gallery/main.cpp)
target_link_libraries(meo-style-gallery PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets)
set_target_properties(meo-style-gallery PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

add_executable(meo-style-smoke tests/style-smoke.cpp)
target_link_libraries(meo-style-smoke PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Test)
target_compile_definitions(meo-style-smoke PRIVATE
    MEO_STYLE_PLUGIN_ROOT="${CMAKE_BINARY_DIR}/qt-plugins"
)
add_test(NAME meo-style-smoke COMMAND meo-style-smoke)
set_tests_properties(meo-style-smoke PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

install(TARGETS meostyle
    LIBRARY DESTINATION "${QT6_INSTALL_PLUGINS}/styles"
)
install(TARGETS meo-style-gallery
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)
