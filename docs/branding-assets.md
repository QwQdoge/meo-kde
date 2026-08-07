# MeoArch branding assets

The existing MeoArch identity is authoritative. No new logo or product mark is
introduced by Meo Desktop.

| Path | Type and dimensions | Scalable | Use |
| --- | --- | --- | --- |
| `assets/icons/Logo.svg` | MeoArch symbol, 864 x 389 view box | Yes | Installer hero, launcher and system branding |
| `assets/icons/Logo.png` | MeoArch symbol, 864 x 389 | No | Raster fallback currently used by the installer |
| `assets/icons/text logo.svg` | MeoArch symbol and word mark, 1116 x 174 view box | Yes | Wide branding placements |
| `assets/icons/text logo.png` | MeoArch symbol and word mark, 3347 x 520 | No | Raster fallback |
| `assets/icons/Meo.kra` | Krita source artwork | N/A | Editable source; never shipped as a runtime icon |
| `assets/wallpapers/installer_background.png` | Background, 1672 x 941 | No | Installer and initial Meo Desktop wallpaper |

Packaging installs the wallpaper from its existing top-level location rather
than maintaining another editable copy. The SVG symbol is preferred whenever
the target supports SVG. The installer retains the PNG fallback because its
current QML asset loader already validates that path.

Font assets under `assets/fonts` and `themes/MeoUI/assets/fonts` are UI
resources, not MeoArch brand marks. Their license files must remain alongside
packaging sources.
