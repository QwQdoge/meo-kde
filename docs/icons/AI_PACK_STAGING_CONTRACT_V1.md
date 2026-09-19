# Meo AI Icon Pack Staging Contract v1

This is the hand-off boundary between Meo Account's consented image job and
Meo Icon Studio's local, atomic pack commit. It deliberately does not expose a
provider token, raw Account credential, or full prompt in a persistent record.

## User-visible path

1. Settings asks Account for the available approved styles.
2. The user selects one style and a bounded application set; Account performs
   any required consent before generation begins.
3. Account generates one approved, color-neutral material image for the selected
   style, stages it locally, and binds it to every selected canonical identity.
   It does not ask a provider to redraw each application logo.
4. Studio renders the exact final canonical-identity previews locally, then
   preflights the complete staging manifest and commits every icon in
   one transaction. `Undo` restores normal FreeDesktop lookup.

The first two steps may be asynchronous, but Settings must never block its UI
thread while it waits for a provider. A normal repeat run is a single style-card
tap after the user's separate Account consent has been granted; it is not a
free-form prompt editor disguised as a theme picker. One pack means one material
request, not one provider round trip per app.

## Attested staging schema 2

```json
{
  "schema": 2,
  "packId": "account-job-safe-id",
  "styleId": "service-catalog-style-id",
  "provider": "account-managed-provider-id",
  "model": "image-model-id",
  "promptRecipeVersion": "v2",
  "items": [
    {
      "desktopId": "org.example.App.desktop",
      "image": "material.png",
      "imageSha256": "64-lowercase-hex-characters",
      "sourceIconHash": "64-lowercase-hex-characters",
      "shape": "circle",
      "prompt": "meo-style:paper:v2"
    },
    {
      "desktopId": "org.example.Other.desktop",
      "image": "material.png",
      "imageSha256": "the-same-material-hash",
      "sourceIconHash": "a-different-canonical-identity-hash",
      "shape": "circle",
      "prompt": "meo-style:paper:v2"
    }
  ]
}
```

`image` is relative to the manifest's staging directory; path traversal,
missing assets, over-large assets, invalid image formats, unsupported shape
names, duplicate desktop IDs, fully transparent/oversized decoded rasters, and
hash mismatches are rejected before commit.
The maximum pack size is 128 only as a parser ceiling. Product UI must use a
bounded visible application set and Account's own quota/concurrency policy.

`sourceIconHash` is the SHA-256 of decoded canonical original artwork:

- a first-party app uses its reviewed color identity;
- another application uses its installed original artwork, never an existing
  `MeoUser`, `MeoSymbols`, or fallback-generated asset.

Studio recalculates it immediately before committing. If the app has updated
while Account was generating, the entire pack is rejected rather than applying
artwork for an obsolete identity. `imageSha256` likewise prevents an image in
the local staging directory from being swapped after Account completed it.

Every item may point to the same approved material.png; its hash is still
present on every item so the manifest remains independently verifiable. The
provider receives no app artwork, brand logo, or full per-app prompt. Studio
uses the material only inside the locally reviewed or installed canonical
identity alpha, internal cuts, and structural masks.

Account must obtain that value from Studio's explicit, read-only description
interface, for example:

```text
meo-app-icon-studio --describe --app org.meo.settings.desktop
```

The returned `canonicalIdentityHash` is intentionally distinct from
`desktopEntryHash`: the latter fingerprints launcher metadata and must never be
used to bind a generated image. The caller requests only the selected bounded
application IDs, rather than asking the visible-app list to rasterise every
installed icon.

## Legacy schema 1

Schema 1 has no source/image integrity requirement so existing developer
fixtures and the historical single-image bridge remain debuggable. Studio
records such commits as `legacy-unverified`. They are not permitted to claim
the production one-tap AI experience and must not be emitted by a new Account
style-pack job.

## Commit record and rollback

Studio writes a non-secret `GenerationManifest` only after all items commit.
It records distinct values for:

- original `sourceIconHashes`;
- attested `stagedImageHashes`;
- normalized local `generatedAssetHashes`;
- final `outputHashes` at every delivered icon size.

The record includes style, provider/model identifiers, palette, selected
shape, contract version, and prompt recipe version, but omits full prompts and
all secrets. A failure restores the manifest, overlay state, generated assets,
managed desktop fallback entries, Dock compatibility state, and the active KDE
icon-theme pointer.

## Preview

Before committing, Settings invokes the Studio preview action with the staged
pack and a private preview directory. The command performs the same schema-2
image and current-canonical-identity preflight as commit, renders 128px final
launcher previews, and writes no overlay, desktop entry, Dock setting, cache,
provenance, or icon-theme state. The private preview directory is disposable.
A successful preview is not an apply result; commit repeats the preflight
immediately before its atomic snapshot.

## Required Account integration before release

Account must expose a versioned style catalog and a pack job API rather than
looping image preparation and generation one app at a time. The job must bind
the chosen style, provider/model, shape, app IDs, canonical source hashes,
rate/quota admission, and consent ticket atomically; it generates one
style-material image, stages a schema-2 manifest in a 0700 directory, and
supports status/cancel/release. Settings may then hand its manifest path to
Studio. Until that service exists, the renderer is capable of validating a pack
but the full Pixel-like one-tap path is intentionally not advertised as
complete.
