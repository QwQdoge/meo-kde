if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    cmake_minimum_required(VERSION 3.21)
    project(MeoApplicationStyle LANGUAGES CXX)

    set(CMAKE_AUTOMOC ON)
    set(CMAKE_CXX_STANDARD 20)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
    include(CTest)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Test)

# Widgets and QML renderers share constexpr metrics, not a QML runtime.
find_path(meoui_design_tokens_include NAMES meodesigntokens.h PATH_SUFFIXES include/MeoUI)
if(NOT meoui_design_tokens_include)
    if(NOT EXISTS "${MEOUI_SOURCE_DIR}/runtime/meodesigntokens.h")
        message(FATAL_ERROR
            "Meo application style requires installed MeoUI design-token headers or "
            "MEOUI_SOURCE_DIR pointing to a MeoUI checkout.")
    endif()
    set(meoui_design_tokens_include "${MEOUI_SOURCE_DIR}/runtime")
endif()
add_library(meoui_style_tokens INTERFACE)
target_include_directories(meoui_style_tokens INTERFACE "${meoui_design_tokens_include}")
target_link_libraries(meoui_style_tokens INTERFACE Qt6::Core)
set(meoui_tokens_target meoui_style_tokens)

add_library(meostyle MODULE
    src/meostyle.cpp
    src/meostyle.h
    src/meostylecontent.cpp
    src/meostylecontent.h
    src/meostylegeometry.cpp
    src/meostyleitem.h
    src/meostyletab.h
    src/meostylehelper.cpp
    src/meostylehelper.h
    src/meostyleplugin.cpp
    src/meostyleplugin.h
    meostyle.json
)
target_link_libraries(meostyle PRIVATE ${meoui_tokens_target} Qt6::Core Qt6::Gui Qt6::Widgets)
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

add_executable(meo-style-geometry-smoke
    tests/geometry-smoke.cpp
    src/meostyle.cpp
    src/meostylegeometry.cpp
    src/meostylehelper.cpp
    src/meostylehelper.h
    src/meostyle.h
)
target_include_directories(meo-style-geometry-smoke PRIVATE src)
target_link_libraries(meo-style-geometry-smoke PRIVATE
    ${meoui_tokens_target}
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Test
)
add_test(NAME meo-style-geometry-smoke COMMAND meo-style-geometry-smoke)
set_tests_properties(meo-style-geometry-smoke PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

install(TARGETS meostyle
    LIBRARY DESTINATION "${QT6_INSTALL_PLUGINS}/styles"
)
install(TARGETS meo-style-gallery
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)

# Explicit real-display acceptance, never run automatically by CTest.
add_executable(meo-style-live-gallery EXCLUDE_FROM_ALL tests/live-gallery.cpp)
target_link_libraries(meo-style-live-gallery PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets)
