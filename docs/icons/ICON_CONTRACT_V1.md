# Meo Icon Contract v1

This is the authoring contract for Meo application identities. It is not a
replacement for the `MeoSymbols` system-semantic contract: Actions, Status,
Devices, Places, Categories, MIME, authentication, and live state remain in
their own semantic icon track.

The machine-readable source is
[`tools/icons/meo_icon_contract_v1.json`](../../tools/icons/meo_icon_contract_v1.json).

## Coordinate system

The canonical vector composition is **48u × 48u**. A unit is a named design
unit, not a promise that every final raster coordinate will be an integer.
Delivery rasterization is allowed to use deterministic finite precision.

| Token | Value | Meaning |
| --- | ---: | --- |
| `canvas` | `48u` | Canonical composition space |
| `container` | `40u` | Shared application silhouette box |
| `containerInset` | `4u` | `(48u - 40u) / 2` |
| `foreground` | `24u` | Normal identity optical box |
| `pixelForeground` | `22u` | Pixel-flower optical box |
| `squircleRadius` | `12u` | Squircle corner radius |
| `roundedRadius` | `8u` | Rounded-square corner radius |
| `flowerCenterRadius` | `12u` | Pixel flower central disk |
| `flowerLobeRadius` | `8u` | Pixel flower lobes |
| `flowerLobeOffset` | `12u` | Lobe center offset |
| `flowerDiagonal` | `1 / sqrt(2)` | Diagonal lobe multiplier |

The Pixel flower fits exactly inside the 40u container along the cardinal axes:
`12u + 8u = 20u`, the container radius. Its diagonal positions use the named
`1 / sqrt(2)` term; no copied decimal approximation is permitted.

## Authoring and optical correction

Hand-authored source may use named integer-u tokens, named rational
expressions, and named radicals. Do not write unexplained literals such as
`0.84`, `0.31`, or `0.70710678` into source geometry. Generated SVG or raster
output may contain finite decimal coordinates if its generator can reconstruct
them from this contract.

Small icons are not merely a scaled 48u master. They may have explicitly
reviewed optical masters at 32, 22, and 16 px. A correction must be named by
the component/shape it addresses, recorded alongside the source, and reviewed
at the affected size; untracked `1.5 px` or `1.7 px` tweaks are not allowed.
The user overlay delivers native 16, 22, 32, 128, 256, and 512 px directories.
Reviewed small masters render at a deterministic 8× oversampling factor before
their native-size raster is written; the 48u canonical vector remains the
large-artwork source of truth.

## Application variants

- **Original** removes Meo's overlay/fallback and follows the installed
  artwork; the shape is `follow-original`.
- **Meo Color** retains the approved silhouette/internal cuts and applies the
  selected Meo material recipe inside a contract shape.
- **Monochrome** uses a human-reviewed mono glyph plus the selected shape.
  Reviewed first-party glyphs use one dynamic foreground tint and real
  transparent negative space. Its neutral container is the named dynamic
  elevation surface + (onSurface - surface) / 6, so a chosen shape remains
  legible in both light and dark schemes without becoming a second brand
  colour. Unreviewed third-party fallbacks may retain controlled tonal layers
  until a reviewed glyph exists.
- **Approved AI** may vary material/texture only after staging and validation;
  it cannot choose a new canonical identity shape.

This contract deliberately does not make a brand derivative redistributable.
First-party identities can be authored fully; third-party artwork is subject
to its license/trademark policy and defaults to Original unless the user has
locally opted into a permitted transformation.
