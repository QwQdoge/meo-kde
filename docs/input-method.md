# Input method integration

Meo styles the candidate window supplied by an input-method framework; it does
not implement an input method, invent active-engine state, or replace Plasma's
virtual-keyboard ownership. This keeps the result compatible with any engine
that uses the supported framework UI.

## Fcitx 5

The package provides `MeoInputMethod-Light` and `MeoInputMethod-Dark` Classic
UI fallback themes plus `/etc/xdg/fcitx5/conf/classicui.conf`. When the helper
enables or synchronises an already selected Meo theme, it generates the
user-local `MeoInputMethod-Dynamic` theme from the active colour scheme's exact
`[MeoMaterial]` roles and selects that generated theme. A non-Meo Fcitx theme
is never selected or replaced by `--sync`.

The static framework skins mirror MeoUI's MD3 shape and spacing tokens: the
candidate surface uses a 24-pixel capsule asset, the selected item uses a
17-pixel capsule asset, and the visible inset is 7 pixels. Page buttons and the
Classic UI menu use matching vector icons, container pairs, and outline roles;
the dark fallback therefore does not inherit the default light menu. Fcitx's
margin names are easy to misread: `ContentMargin` is popup padding,
`TextMargin` spaces each candidate, while `Highlight/Margin` expands the
highlight around the measured text rectangle. It is therefore 8 pixels of
selection padding, not the 17-pixel asset radius. With a typical 19-pixel font
height, the official Fcitx
layout becomes `19 + 2*8 + 2*7 = 49` pixels for the popup and
`19 + 2*8 = 35` pixels for the selected capsule. The selected dynamic theme
uses SVG assets throughout, retaining the curves through Fcitx's nine-slice
renderer without an image-conversion dependency. See the
[Fcitx theme documentation](https://fcitx-im.org/wiki/Special%3AMyLanguage/Fcitx_5_Theme)
and [Classic UI layout source](https://github.com/fcitx/fcitx5/blob/master/src/ui/classic/inputwindow.cpp).

Fcitx Classic UI and the IBus GTK panel do not expose a shared reliable
reduced-motion API, so selection styling changes immediately rather than
adding a decorative animation.

Only the theme-selection keys are written. Candidate orientation, font, paging,
accent preference, preedit behaviour, engine list, shortcuts, and per-engine
settings remain Fcitx defaults or the user's existing choices. The same capsule therefore works with
horizontal and vertical candidate layouts and with compatible engines such as
Pinyin, Rime, Mozc, Hangul, and emoji.

Existing `~/.config/fcitx5/conf/classicui.conf` files take precedence. To opt
an existing user configuration into the Meo presentation without changing its
engines, run:

```bash
meo-input-method --enable fcitx5
```

On Plasma Wayland, select **Fcitx 5** under **System Settings → Keyboard →
Virtual Keyboard**. KWin then owns the process and candidate-popup protocol.
The helper deliberately does not make that compositor-level choice, start or
stop Fcitx, or set global `GTK_IM_MODULE` / `QT_IM_MODULE` variables. Keeping
native Wayland text-input available avoids forcing a toolkit fallback across
every app; install the normal Fcitx GTK/Qt integration packages only when an
XWayland or legacy application needs them.

## IBus

IBus uses a GTK candidate panel—the same family of panel used in GNOME. Its
custom-theme setting can select a private GTK theme without changing the GTK
theme of ordinary applications. Enable the Meo bridge with:

```bash
meo-input-method --enable ibus
```

The helper reads the active KDE colour-scheme file and renders a user-local
`MeoInputMethod` GTK 3 theme. It consumes `surfaceContainer/onSurface`,
`primary/onPrimary`, `primaryContainer/onPrimaryContainer`,
`secondaryContainer/onSecondaryContainer`, `onSurfaceVariant`, and `outline`
directly from `[MeoMaterial]`; it does not infer an on-container colour from an
unrelated KDE colour set. A later `meo-theme-mode light` or `meo-theme-mode
dark` refreshes already selected Meo Fcitx and IBus themes automatically;
`meo-input-method --sync` does the same after another colour-scheme change.

IBus's stock GTK panel applies selected-candidate foreground/background through
Pango attributes on its labels. The custom GTK theme therefore guarantees the
rounded outer popup and rounded paging-button states, plus the exact paired
selected colours, but it does **not** claim that the selected candidate's Pango
background rectangle itself has rounded corners. That would require replacing
the stock IBus panel rather than styling its supported presentation surface.

No IBus font, candidate orientation, engine list, shortcut, preedit policy, or
daemon lifecycle is changed.

## Compatibility boundary

Only a framework that exposes its candidate UI to Fcitx Classic UI or the IBus
GTK panel can receive this styling. Engines inside either framework share the
result. An IME with its own independently rendered window cannot be globally
reskinned safely; its native UI remains authoritative. Use one input-method
framework per session rather than running Fcitx 5 and IBus simultaneously.

Static validation covers the configuration, all referenced SVG assets, exact
`MeoMaterial` propagation, isolated helper rendering, non-Meo sync guards, and
the D-Bus reload/query result handling. A real candidate-popup acceptance test
still requires a logged-in Plasma session, an enabled engine, and both native
Wayland and XWayland sample applications.
