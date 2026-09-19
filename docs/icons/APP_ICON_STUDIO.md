# Meo Application Icon Studio

Meo Icon Studio has three intentionally separate asset tracks:

- application identity can be Original, Meo Color, Monochrome, or a reviewed AI pack;
- `MeoSymbols` owns KDE Actions, Status, Devices, Places, Categories, MIME, and other system semantics;
- live network, volume, battery, authentication, and similar state retain their normal KDE meaning and are never replaced by an AI application pack.

## Theme lookup and fallback

The primary application path is a user-level FreeDesktop icon overlay:

```text
MeoUser       -> MeoSymbols     -> breeze -> hicolor
MeoUserDark   -> MeoSymbolsDark -> breeze-dark -> breeze -> hicolor
```

The overlay contains only assets for the current Meo application pack. It is
used only where the desktop entry's `Icon=` value is a unique, non-absolute
theme icon name. The manifest records this as `overlay-name` together with the
collision audit. It prevents a stale user `.desktop` copy from shadowing an
upstream update to `Exec`, Actions, MIME types, or `DBusActivatable`.

The icon theme namespace is global: an `apps/foo` asset is not isolated from a
system lookup for `foo`. An icon name shared by multiple launchers or by
`MeoSymbols`, a known KDE/FDO semantic alias such as `system-users`, an
absolute icon path, or a runtime-private icon therefore does not use the
overlay. The studio instead uses the narrow, manifest-owned desktop-entry
fallback when it can safely do so, or leaves the application as Original. This
is a semantic safety boundary, not a coverage shortcut.

`Original` means removing Meo's overlay asset or managed fallback and letting
ordinary FreeDesktop/KDE lookup resolve the currently installed artwork. It
does not restore a saved PNG, redraw an approximation, mask the artwork, or
place it inside a Meo container. Its shape is consequently `follow-original`.

## Rendering contract

The canonical rendering source is the Meo Icon Contract v1. Its 48-unit grid
defines composition and named geometry parameters; 32, 22, and 16-pixel
optical masters are emitted as native fixed directories for small-size
readability. Hand-authored
geometry may not contain unexplained magic constants. Generated SVG/raster
coordinates may contain finite precision values when they are reproducible
from the contract. Optical correction is explicit and reviewed rather than an
untracked per-icon adjustment.

Supported container shapes are Circle, Pixel flower, Squircle, and Rounded
square. Meo Color and Monochrome preserve a reviewed identity glyph inside the
selected shape. The application renderer does not add a second opaque well to
the Plasma task manager.

For first-party identities, Monochrome means one dynamic foreground tint plus
real transparent cuts in the reviewed glyph; it is not a three-grey simulated
logo. The neutral shape surface is part of the selected launcher treatment,
not an alternate application mark. It is a named dynamic neutral elevation:
surface + (onSurface - surface) / 6, so the selected Circle, Pixel flower,
Squircle, or Rounded shape remains distinguishable in both light and dark
schemes without introducing a second brand colour. A third-party fallback can
retain limited tonal detail until its mono glyph is explicitly reviewed.

The first-party P0 source sheet is
`assets/icons/application-identities/manifest.json`. It assigns unique private
names to Settings, Account, OmniStore, and Welcome, and supplies reviewed mono
glyphs plus 16/22/32 optical color masters for those identities. For Meo Color,
the renderer uses the reviewed color source directly and renders the three
small masters at native-size oversampling; it does not make a slow full-system
icon scan or downscale a 128px fallback for these P0 identities. Their color
Original SVGs are installed by the
owning application package, not `meo-icons`: an application-only upgrade must
be able to refresh Original independently of the system-symbol theme. System
subpages (for example Wi-Fi, volume, display, battery, and `dialog-password`)
remain semantic KDE assets and are not entries in that source sheet.

The initial user-pack scope is deliberately four launchable P0 identities:
Settings, the Account launcher, OmniStore, and Welcome. Quick Repair joins
only after it has a normal package/upgrade owner and can prove a user-session
identity. Installer, the retired standalone Dock, and Login/greeter remain
fixed system-branding or KDE-semantic surfaces; they never enter `MeoUser` or
an AI application pack.

## AI packs

The renderer is offline and never receives provider credentials. Meo Settings
uses the separately consented Account broker to request images, stages every
item, validates and previews the complete pack, then calls `--ai-pack` for one
atomic commit. Failure restores the previous manifest, active theme pointer,
overlay assets, fallback entries, cache state, and staged pack state.

Each committed pack has a non-secret `GenerationManifest` containing a pack
ID, contract version, approved style ID, provider/model identifiers,
generation time, original-identity, staged-image, normalized-asset, and
output hashes, shape, palette, and prompt recipe version. It deliberately
excludes provider tokens and the full prompt.

The production Account hand-off uses staging schema 2. Every item contains a
`sourceIconHash` for the exact original identity seen at generation time and
an `imageSha256` for the staged result. Studio rejects an updated application
identity or a swapped staging image before it writes anything. Schema 1 is
readable only for legacy developer fixtures and is recorded as
`legacy-unverified`; it cannot satisfy the one-tap production acceptance gate.
The exact hand-off, rollback, and Account service requirements live in
[`AI_PACK_STAGING_CONTRACT_V1.md`](AI_PACK_STAGING_CONTRACT_V1.md).

AI output is treated as source-neutral material, not a replacement logo. The
renderer applies that texture to the current reviewed/installed canonical mark
and preserves its silhouette, internal cuts, and negative space before placing
it inside the selected shape. Dynamic-color changes can recolor an already
committed pack locally; they do not make a new provider request.
An optional reviewed aiStructuralMaskSource preserves small canonical
transparent cuts that a colour-only Original would otherwise lose under AI
material; it has no palette or generated-shape authority.
`--managed-only` refreshes only existing Meo application assets.

## Ownership and acceptance

Settings treats `/usr/bin/meo-app-icon-studio` as the production executable;
a developer's `~/.local/bin` helper cannot shadow it. Release packaging must
own that executable and all runtime dependencies before this feature is
advertised.

Static tests prove renderer, manifest, and backend behavior only. Release
acceptance additionally requires a fresh package installation and upgrade in
an isolated Plasma VM, with the real `org.kde.plasma.icontasks` task manager
showing Original, Meo Color, Monochrome, approved AI pack, undo, mode switch,
and fallback behavior without changing KDE's live system-semantic icons.

## Package and ISO ownership gate

`meo-icons` owns `MeoSymbols` and `MeoSymbolsDark`; an ArchISO profile must
not also copy those same paths into `airootfs` as unmanaged files. Otherwise a
normal `pacman` dependency install correctly fails with `exists in filesystem`.
The remedy is to remove the duplicate staged input, not use `--overwrite` or
silently skip package ownership.

Every candidate ISO/VM gate must prove all three layers separately:

1. `pacman -Qo` identifies the package owner of the Studio executable and its
   reviewed identity manifest;
2. `pacman -Qkk` reports no altered Studio or `meo-icons` files;
3. the running Plasma session resolves the installed assets through the normal
   theme chain.

An output-only developer ISO may exercise the first two layers with an
explicitly local unsigned test repository, but it is never evidence of a
signed repository, normal installer, `pacman -Syu`, or release acceptance.
