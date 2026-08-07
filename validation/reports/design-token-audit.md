# Design token audit

| Area | Current authority | Meo KDE use | Status |
|---|---|---|---|
| Colour | MeoUI semantic roles | live Plasma accent/background mapped to MD3 primary, containers, outlines and content roles | implemented; HCT wallpaper extraction remains future work |
| Typography | MeoUI families/scale | bundled Roboto UI, Comfortaa brand and Material Symbols Rounded | implemented |
| Shape | MeoUI named shape roles | Shelf/popup/status surfaces consume named radii | partially migrated; launcher delegates still contain some numeric desktop dimensions |
| Spacing | MeoUI 2–48 dp scale | panel geometry and primary layout margins use named tokens | partially migrated |
| Motion | MeoUI durations/reduced motion | Shelf and popup transitions consume shared durations | implemented for primary shell transitions |
| Elevation | MeoUI surfaces/outlines | restrained opaque/translucent container hierarchy, one-pixel logical outline | implemented; blur intentionally deferred pending performance evidence |
| State layers | MeoUI state colours | active, hover and pressed task states | present; keyboard focus requires VM verification |

Desktop density is intentionally more compact than mobile MD3: 44 dp top bar,
48 dp Shelf targets, 52–58 dp primary quick controls and bounded 680 dp
launcher. Exact values are candidates until the DPI/VM matrix is captured.

