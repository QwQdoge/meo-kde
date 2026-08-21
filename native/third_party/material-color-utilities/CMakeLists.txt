# Material Color Utilities is vendored from:
# https://github.com/material-foundation/material-color-utilities
# Commit: f05459ea2170f3be610f89a4ddeee8843c2deb61
# License: Apache-2.0 (see LICENSE).
#
# Keep this target deliberately small: Meo only needs the HCT, tonal-palette,
# and DynamicScheme implementation used for a standards-based MD3 scheme.
add_library(meo-material-color-utilities STATIC
    cpp/cam/cam.cc
    cpp/cam/hct.cc
    cpp/cam/hct_solver.cc
    cpp/cam/viewing_conditions.cc
    cpp/contrast/contrast.cc
    cpp/dislike/dislike.cc
    cpp/dynamiccolor/dynamic_color.cc
    cpp/dynamiccolor/dynamic_scheme.cc
    cpp/dynamiccolor/material_dynamic_colors.cc
    cpp/palettes/tones.cc
    cpp/scheme/scheme_tonal_spot.cc
    cpp/utils/utils.cc
)

add_library(Meo::MaterialColorUtilities ALIAS meo-material-color-utilities)

target_compile_features(meo-material-color-utilities PUBLIC cxx_std_20)
target_include_directories(meo-material-color-utilities PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
)
set_target_properties(meo-material-color-utilities PROPERTIES
    AUTOMOC OFF
    POSITION_INDEPENDENT_CODE ON
)
