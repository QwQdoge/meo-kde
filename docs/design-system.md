# Meo Desktop design system

The canonical cross-renderer **metric token** source is the native MeoUI token runtime (`Meo::DesignTokens`). QML consumes the same runtime through the `MeoTokens` singleton, while `MeoTheme.qml` maps those stable metrics together with live semantic color, typography, motion, and application-facing roles for MeoUI components. Native MeoStyle links the same metric runtime directly.

This means there is one stable metric contract rather than separate QML and C++ numbers. Component-specific behavior and presentation still belong to their renderer, but a shared metric must not be copied into MeoStyle or individual applications when a named design token exists. The first exact cross-renderer Button/TextField/Menu relationships are recorded in `docs/meostyle-component-contract-v1.md`.

Installer, onboarding, and Meo Desktop applications import the shared `MeoUI 1.0` dynamic QML module. QML visual fixes are made in reusable MeoUI components; native Qt Widgets fixes are made in MeoStyle against the same design contract, not copied into every application.

## Principles

Usability, clarity, predictability, accessibility, consistency, responsiveness,
performance, polish, motion, and decoration are evaluated in that order.
Expressive color, motion, typography, and shapes establish hierarchy; they do
not hide controls or change familiar desktop behavior without evidence.

## Tokens

- Typography: Comfortaa is reserved for brand/display roles; Roboto is used for
  heading, title, body, label, and caption roles. Current UI sizes are 40/26/16
  for display and title, 18/15/14 for body, and 15/14/12 for labels.
- Spacing: stable component-independent spacing comes from the native Meo token
  runtime and is exposed to QML through `MeoTokens`/`MeoTheme`; application
  code must not maintain a competing spacing scale.
- Radius: small, medium, large, extra-large, and full/pill. Components consume
  the named Meo shape/control tokens appropriate to their renderer.
- Surfaces: background, surface, surface-container levels, elevated/popup,
  hover/state layer, selected, disabled, error, warning, and success.
- Motion: instant feedback, quick state change, standard navigation, and large
  transition durations come from the shared Meo design contract. Reduced motion
  must preserve state feedback while removing decorative movement.
- Targets: primary interactive controls are at least 44 effective pixels;
  keyboard focus is always visible and state never depends on color alone.

Layouts use `MeoWindowMetrics` rather than application-specific breakpoints.
The supported acceptance matrix is 1366x768, 1920x1080, and 2560x1440 at
100%, 125%, 150%, and 200% scaling where the runtime supports fractional
scaling.

Standard Qt Widgets/KDE application controls are rendered through MeoStyle
where QStyle provides a stable contract. Application-specific distribution
patches are reserved for top-level chrome or custom-painted/delegate surfaces
that cannot be corrected generically without breaking unrelated applications.
Plasma/shell-specific surfaces remain a separate integration layer and must
consume the same Meo design contract instead of redefining application tokens.
