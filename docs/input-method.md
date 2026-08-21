# Input method integration

Meo styles the candidate window supplied by an input-method framework; it does
not implement an input method, invent active-engine state, or replace Plasma's
virtual-keyboard ownership. This keeps the result compatible with any engine
that uses the supported framework UI.

## Fcitx 5

The package provides `MeoInputMethod-Light` and `MeoInputMethod-Dark` Classic
UI themes plus `/etc/xdg/fcitx5/conf/classicui.conf`. The themes turn the
candidate window and selected candidate into compact rounded surfaces. Their
surface, tonal container, content, and outline values are derived from the
matching Meo KDE colour schemes.

The static framework skins mirror MeoUI's MD3 shape and spacing tokens: the
candidate surface uses a 24-pixel capsule asset, the selected item uses a
17-pixel capsule asset, and the visible inset is 7 pixels. Fcitx's margin names
are easy to misread: `ContentMargin` is popup padding, `TextMargin` spaces each
candidate, while `Highlight/Margin` expands the highlight around the measured
text rectangle. It is therefore 8 pixels of selection padding, not the
17-pixel asset radius. With a typical 19-pixel font height, the official Fcitx
layout becomes `19 + 2*8 + 2*7 = 49` pixels for the popup and
`19 + 2*8 = 35` pixels for the selected capsule. The PNG/SVG assets retain the
actual curves through Fcitx's nine-slice renderer. See the
[Fcitx theme documentation](https://fcitx-im.org/wiki/Special%3AMyLanguage/Fcitx_5_Theme)
and [Classic UI layout source](https://github.com/fcitx/fcitx5/blob/master/src/ui/classic/inputwindow.cpp).

Fcitx Classic UI and the IBus GTK panel do not expose a shared reliable
reduced-motion API, so selection styling changes immediately rather than
adding a decorative animation.

Only the light theme, dark theme, and automatic light/dark selection keys are
supplied. Candidate orientation, font, paging, accent preference, preedit
behaviour, engine list, shortcuts, and per-engine settings remain Fcitx
defaults or the user's existing choices. The same capsule therefore works with
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
`MeoInputMethod` GTK 3 theme. It maps Window surface/content, Selection
tonal-container, and inactive foreground/outline roles into the IBus GTK
colour names. A later `meo-theme-mode light` or `meo-theme-mode dark` refreshes
an already enabled IBus theme automatically; `meo-input-method --sync` does the
same after another colour-scheme change.

No IBus font, candidate orientation, engine list, shortcut, preedit policy, or
daemon lifecycle is changed.

## Compatibility boundary

Only a framework that exposes its candidate UI to Fcitx Classic UI or the IBus
GTK panel can receive this styling. Engines inside either framework share the
result. An IME with its own independently rendered window cannot be globally
reskinned safely; its native UI remains authoritative. Use one input-method
framework per session rather than running Fcitx 5 and IBus simultaneously.

Static validation covers the configuration, semantic CSS template, helper
syntax, and dry-run rendering path. A real candidate-popup acceptance test
still requires a logged-in Plasma session, an enabled engine, and both native
Wayland and XWayland sample applications.
