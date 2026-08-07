# Meo Desktop design system

`themes/MeoUI/MeoTheme.qml` is the executable source of truth for M3
Expressive application tokens. Installer, onboarding, and future Meo Desktop
applications import the shared `MeoUI 1.0` dynamic QML module. Visual fixes are
made there, not copied into each application.

## Principles

Usability, clarity, predictability, accessibility, consistency, responsiveness,
performance, polish, motion, and decoration are evaluated in that order.
Expressive color, motion, typography, and shapes establish hierarchy; they do
not hide controls or change familiar desktop behavior without evidence.

## Tokens

- Typography: Comfortaa is reserved for brand/display roles; Roboto is used for
  heading, title, body, label, and caption roles. Current UI sizes are 40/26/16
  for display and title, 18/15/14 for body, and 15/14/12 for labels.
- Spacing: 4, 8, 12, 16, 20, 24, 32, 40, and 48 dp.
- Radius: small, medium, large, extra-large, and full/pill. Components consume
  the named MeoTheme shape tokens.
- Surfaces: background, surface, surface-container levels, elevated/popup,
  hover/state layer, selected, disabled, error, warning, and success.
- Motion: instant feedback, quick state change, standard navigation, and large
  transition durations come from MeoTheme. Reduced motion must preserve state
  feedback while removing decorative movement.
- Targets: primary interactive controls are at least 44 effective pixels;
  keyboard focus is always visible and state never depends on color alone.

Layouts use `MeoWindowMetrics` rather than application-specific breakpoints.
The supported acceptance matrix is 1366x768, 1920x1080, and 2560x1440 at
100%, 125%, 150%, and 200% scaling where the runtime supports fractional
scaling.

Plasma shell surfaces remain upstream KDE widgets in the first implementation.
They are configured by the look-and-feel package. Any future custom launcher or
quick-settings visual component must first be implemented as a reusable MeoUI
pattern, then consumed by the Plasma integration.
