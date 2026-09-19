# Plasma QML uses KI18n's gettext catalogs.  Keeping them in the native build
# makes `cmake --install` place the compiled .mo files beside other KDE
# catalogs instead of leaving a developer-only TS file in the source tree.
find_package(KF6I18n 6.0 REQUIRED)

ki18n_install("${CMAKE_CURRENT_SOURCE_DIR}/../../translations")

# These native QObject producers return their text directly to QML and desktop
# notifications. Make a focused target build compile the matching gettext
# catalog too, so it never relies on an unrelated default build to create the
# .mo file installed by KI18n.
foreach(meo_i18n_consumer IN ITEMS
        meosystemplugin
        meo-system-state-smoke
        meo-weather-cache-test
        meo-desktop-widget-bridge-test
        meo-session-actiond)
    if(TARGET "${meo_i18n_consumer}")
        add_dependencies("${meo_i18n_consumer}" pofiles)
    endif()
endforeach()

if(BUILD_TESTING)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Test)
    find_program(MEO_QMLTESTRUNNER_QT6_EXECUTABLE NAMES qmltestrunner
        PATHS /usr/lib/qt6/bin
        NO_DEFAULT_PATH
        REQUIRED
    )

    add_executable(meo-i18n-catalog-test
        meoi18ncatalog-test.cpp
    )
    add_dependencies(meo-i18n-catalog-test pofiles)
    target_compile_definitions(meo-i18n-catalog-test PRIVATE
        MEO_I18N_LOCALE_DIR="${CMAKE_CURRENT_BINARY_DIR}/locale"
    )
    target_link_libraries(meo-i18n-catalog-test PRIVATE
        Qt6::Test
        KF6::I18n
    )
    add_test(NAME meo-i18n-catalog-test COMMAND meo-i18n-catalog-test)
    set_tests_properties(meo-i18n-catalog-test PROPERTIES
        ENVIRONMENT "LANG=zh_CN.UTF-8;LC_ALL=zh_CN.UTF-8;LANGUAGE=zh_CN"
    )

    add_test(NAME meo-i18n-qml-context-test
        COMMAND "${MEO_QMLTESTRUNNER_QT6_EXECUTABLE}"
            -import "${CMAKE_CURRENT_SOURCE_DIR}/../../qml"
            -input "${CMAKE_CURRENT_SOURCE_DIR}/../../tests/i18n"
    )
    set_tests_properties(meo-i18n-qml-context-test PROPERTIES
        ENVIRONMENT "LANG=zh_CN.UTF-8;LC_ALL=zh_CN.UTF-8;LANGUAGE=zh_CN;QT_QPA_PLATFORM=offscreen;XDG_DATA_DIRS=${CMAKE_CURRENT_BINARY_DIR}:/usr/local/share:/usr/share"
    )
endif()
