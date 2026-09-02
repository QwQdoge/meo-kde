# MeoStyle component map

This table maps visual concepts. It does not reuse QML renderers for Widgets.

| Qt Widget | MeoUI concept | Style status |
| --- | --- | --- |
| `QPushButton` | `MeoButton` | Meo surface, focus, default and flat states |
| `QToolButton` | `MeoIconButton` | Meo state layer, checked and split-menu container |
| `QCheckBox` | `MeoCheckbox` | Meo checked, indeterminate, disabled and focus indicator |
| `QRadioButton` | `MeoRadioButton` | Meo checked, disabled and focus indicator |
| `QLineEdit` / text editors | `MeoTextField` / `MeoTextArea` | Meo field frame and focus outline |
| `QComboBox` | `MeoChipDropdown` / exposed dropdown concept | Meo field/arrow; Breeze owns popup behaviour |
| `QSlider` | `MeoSlider` | Meo groove, active track, handle and focus state |
| `QProgressBar` | `MeoProgressBar` | Meo groove/content |
| `QTabBar` | `MeoTabs` | Meo rounded tab surface and active indicator |
| `QMenu` | `MeoMenu` | Meo menu-item state layer; Breeze owns popup window behaviour |
| Item views | `MeoDataTable` / `MeoListItem` | Meo default-delegate selection, hover and focus surface |
| `QScrollBar` | no duplicate QML control | Meo track, thumb and token metrics |

The shared `Meo::DesignTokens` source currently covers common metric/state
tokens. QPalette provides dynamic colour roles for both KDE light/dark and
accent changes.

`QStyle` cannot override an application-owned custom item delegate. A search
field is an ordinary `QLineEdit` unless first-party code explicitly supplies
its leading action/clear button (and may set `meo.role=search`); MeoStyle never
infers a search role from text or object names.
