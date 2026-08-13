cmake_minimum_required(VERSION 3.21)
project(MeoChromeBreeze VERSION 0.1.0 LANGUAGES CXX)

# This project intentionally builds against an exact upstream Breeze checkout.
# The checkout is prepared by ../../setup/build-meo-chrome-breeze.sh.
if(NOT DEFINED MEO_BREEZE_SOURCE OR NOT IS_DIRECTORY "${MEO_BREEZE_SOURCE}/kdecoration")
    message(FATAL_ERROR "Set MEO_BREEZE_SOURCE to the prepared KDE Breeze source tree.")
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Gui)
find_package(KF6 6.0 REQUIRED COMPONENTS ColorScheme Config CoreAddons GuiAddons I18n IconThemes)
find_package(KDecoration3 6.0 REQUIRED)

# Keep all Meo settings separate from the stock Breeze configuration. These
# generated build files are copies of the matching upstream inputs with only
# the KConfig file name redirected.
file(READ "${MEO_BREEZE_SOURCE}/kdecoration/breezesettingsdata.kcfg" meo_kcfg_data)
string(REPLACE "name=\"breezerc\"" "name=\"meochromebreezerc\"" meo_kcfg_data "${meo_kcfg_data}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/breezesettingsdata.kcfg" "${meo_kcfg_data}")
file(READ "${MEO_BREEZE_SOURCE}/kdecoration/breezesettings.kcfgc" meo_kcfg_control)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/breezesettings.kcfgc" "${meo_kcfg_control}")
file(READ "${MEO_BREEZE_SOURCE}/kdecoration/breezesettingsprovider.cpp" meo_settings_provider)
string(REPLACE "QStringLiteral(\"breezerc\")" "QStringLiteral(\"meochromebreezerc\")" meo_settings_provider "${meo_settings_provider}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/breezesettingsprovider.cpp" "${meo_settings_provider}")

add_library(meochromebreezecommon OBJECT
    "${MEO_BREEZE_SOURCE}/libbreezecommon/breezeboxshadowrenderer.cpp"
)
target_include_directories(meochromebreezecommon PUBLIC
    "${MEO_BREEZE_SOURCE}/libbreezecommon"
)
target_link_libraries(meochromebreezecommon PUBLIC Qt6::Core Qt6::Gui)
set_target_properties(meochromebreezecommon PROPERTIES POSITION_INDEPENDENT_CODE TRUE)

set(meochromebreeze_SRCS
    "${MEO_BREEZE_SOURCE}/kdecoration/breezebutton.cpp"
    "${MEO_BREEZE_SOURCE}/kdecoration/breezedecoration.cpp"
    "${CMAKE_CURRENT_BINARY_DIR}/breezesettingsprovider.cpp"
    "${MEO_BREEZE_SOURCE}/kdecoration/breezesettingsprovider.h"
    "${MEO_BREEZE_SOURCE}/kdecoration/breezeexceptionlist.cpp"
)
kconfig_add_kcfg_files(meochromebreeze_SRCS
    "${CMAKE_CURRENT_BINARY_DIR}/breezesettings.kcfgc"
)

add_library(meochromebreeze MODULE ${meochromebreeze_SRCS})
set_target_properties(meochromebreeze PROPERTIES OUTPUT_NAME org.meo.chromebreeze)
target_include_directories(meochromebreeze PRIVATE
    "${MEO_BREEZE_SOURCE}/kdecoration"
    "${MEO_BREEZE_SOURCE}/libbreezecommon"
    "${CMAKE_CURRENT_BINARY_DIR}"
)
target_link_libraries(meochromebreeze PRIVATE
    meochromebreezecommon
    Qt6::DBus
    KF6::ColorScheme
    KF6::ConfigGui
    KF6::CoreAddons
    KF6::GuiAddons
    KF6::I18n
    KF6::IconThemes
    KDecoration3::KDecoration
)
# Breeze 6.7 predates Qt's strict ASCII-conversion build flag.  Its original
# source is otherwise ABI-compatible with this Plasma installation.
target_compile_options(meochromebreeze PRIVATE -UQT_NO_CAST_FROM_ASCII)

install(TARGETS meochromebreeze DESTINATION "${KDE_INSTALL_PLUGINDIR}/${KDECORATION_PLUGIN_DIR}")
