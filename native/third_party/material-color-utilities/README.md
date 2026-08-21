# Material Color Utilities vendor notice

This directory contains the minimal C++ subset of
[`material-foundation/material-color-utilities`](https://github.com/material-foundation/material-color-utilities)
needed by Meo's dynamic Material 3 color generator.

- Upstream commit: `f05459ea2170f3be610f89a4ddeee8843c2deb61`
- Upstream license: Apache-2.0; a copy is included in [LICENSE](LICENSE).
- Imported areas: HCT/CAM16, dynamic-color roles, tonal palettes, contrast,
  dislike filtering, and `SchemeTonalSpot`.

The vendored `cpp/utils/utils.cc` replaces its optional Abseil formatting use
with standard C++ formatting. This keeps the Meo ISO generator self-contained;
the colour calculation is otherwise unmodified.
