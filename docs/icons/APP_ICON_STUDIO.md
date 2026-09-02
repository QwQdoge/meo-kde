# Meo Application Icon Studio

Meo's application-icon treatment is intentionally separate from the KDE system
icon theme. It must never replace names used for Status, Devices, Actions,
MIME, or other shared FreeDesktop icon contexts.

`meo-app-icon-studio` resolves each visible application's installed source
icon, renders 128, 256, and 512 px PNGs to the user's `hicolor` directory, and
assigns every rendered icon a unique `org.meo.iconstudio.app.<hash>` name. It
then updates only the user-local copy of that application's `.desktop` entry.
The global KDE icon-theme choice is not changed and `/usr/share` is never
written.

The generated `.desktop` entries are marked with
`X-Meo-IconStudio-Managed=true` and retain their original icon specification in
`X-Meo-IconStudio-SourceIcon`, so applying a different style always starts
from the upstream visual identity rather than an earlier generated image. A
reset restores an existing user override's prior `Icon=` value, or removes only
a local entry previously created by the studio. The manifest at
`~/.config/meo-icon-studio/manifest.json` records that ownership boundary.

Styles are:

- **Monet** — the default. Extract a palette-independent three-level symbol,
  retain the recognizable silhouette, internal cuts, and negative spaces, and
  recolor it from the active Material roles. A low-confidence opaque result
  falls back to the original artwork instead of becoming a featureless disk.
- **Original** — retain the original visual identity and colors in a subtle
  wallpaper-derived Material container.
- **Black & white** — retain the mark where possible on a high-contrast black
  or white container.

`pure` remains accepted only as a migration alias for `monet`.

Shapes are shared across all managed applications:

- **Circle** — the default Pixel themed-icon container.
- **Pixel flower** — an optional eight-lobed themed-icon mask.
- **Squircle** and **Rounded square** — alternate masks for users
  who prefer the same app identity with another coherent launcher geometry.

The selected silhouette belongs to the application artwork. Both the native
and standalone Meo Dock use transparent state layers plus running/attention
indicators instead of drawing another opaque well behind every icon.

The deterministic renderer runs locally. Its editable prompt is saved as a
local preference and is not transmitted by this tool. Meo Settings can also
prepare payload-bound Account consent for 1 to 128 apps, summarize the exact
provider/model/destination and total prompt size in one confirmation, then
stage all returned PNGs for whole-pack preview. `--ai-pack` commits that pack
only after Apply. It snapshots every affected desktop entry, hicolor asset,
Dock override, AI texture asset, and manifest, restoring all of them if any
item fails. The provider key never reaches Settings or this tool.

AI images are treated as complete artwork: they are fitted and clipped to the
chosen silhouette without adding another Material container. Their continuous
luminance/texture is cached without provider colors, then mapped through the
active Monet ramp. Wallpaper changes recolor the existing AI pack locally via
`--managed-only`; they do not spend another AI request or replace it with the
deterministic source icon.

Unless an explicit `--light`, `--dark`, or `--scheme` is supplied, the studio
reads KDE's active `ColorScheme` from `kdeglobals` and uses the matching Meo
light or dark dynamic palette. Applying a Meo palette through
`meo-dynamic-colors --apply` redraws only already-managed application icons;
it does not replace status or other global KDE icons.
