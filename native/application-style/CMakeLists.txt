find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Qml Test)

find_path(meoui_tokens_include NAMES meotokens.h PATH_SUFFIXES include/MeoUI)
find_library(meoui_tokens_library NAMES meoui_tokens PATH_SUFFIXES lib lib64)

if(NOT meoui_tokens_include OR NOT meoui_tokens_library)
    if(NOT EXISTS "${MEOUI_SOURCE_DIR}/runtime/meotokens.cpp")
        message(FATAL_ERROR
            "Meo application style requires the installed MeoUI token runtime or "
            "MEOUI_SOURCE_DIR pointing to a MeoUI checkout.")
    endif()
    add_library(meoui_style_tokens STATIC
        "${MEOUI_SOURCE_DIR}/runtime/meotokens.cpp"
        "${MEOUI_SOURCE_DIR}/runtime/meotokens.h"
    )
    set_target_properties(meoui_style_tokens PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_link_libraries(meoui_style_tokens PUBLIC Qt6::Core Qt6::Gui Qt6::Qml)
    target_include_directories(meoui_style_tokens PUBLIC "${MEOUI_SOURCE_DIR}/runtime")
    set(meoui_tokens_target meoui_style_tokens)
else()
    set(meoui_tokens_target "${meoui_tokens_library}")
endif()

add_library(meostyle MODULE
    src/meostyle.cpp
    src/meostyle.h
    src/meostylehelper.cpp
    src/meostylehelper.h
    src/meostyleplugin.cpp
    src/meostyleplugin.h
    meostyle.json
)
target_link_libraries(meostyle PRIVATE ${meoui_tokens_target} Qt6::Core Qt6::Gui Qt6::Widgets)
if(meoui_tokens_include)
    target_include_directories(meostyle PRIVATE "${meoui_tokens_include}")
endif()
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
