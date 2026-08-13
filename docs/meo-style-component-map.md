# MeoStyle component map

This table maps visual concepts. It does not reuse QML renderers for Widgets.

| Qt Widget | MeoUI concept | Initial style status |
| --- | --- | --- |
| `QPushButton` | `MeoButton` | P0 surface and focus |
| `QToolButton` | `MeoIconButton` | Fusion compatibility, P0 next |
| `QCheckBox` | `MeoCheckbox` | P0 indicator |
| `QRadioButton` | `MeoRadioButton` | P0 indicator |
| `QLineEdit` / text editors | `MeoTextField` / `MeoTextArea` | P0 frame |
| `QComboBox` | `MeoChipDropdown` / exposed dropdown concept | Fusion compatibility, P0 next |
| `QSlider` | `MeoSlider` | Fusion compatibility, P0 next |
| `QProgressBar` | `MeoProgressBar` | P0 groove/content |
| `QTabBar` | `MeoTabs` | Fusion compatibility, P0 next |
| `QMenu` | `MeoMenu` | Fusion compatibility, P0 next |
| Item views | `MeoDataTable` / `MeoListItem` | Palette compatibility, P0 next |
| `QScrollBar` | no duplicate QML control | token metrics, P0 painting next |

The shared `Meo::DesignTokens` source currently covers common metric/state
tokens. QPalette provides dynamic colour roles for both KDE light/dark and
accent changes.
