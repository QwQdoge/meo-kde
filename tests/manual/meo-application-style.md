> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

# Meo Application Style manual acceptance

Use a disposable user or the staging prefix; do not alter the active desktop
session while testing.

1. Start the gallery with the staged plugin path and confirm normal, disabled,
   checked, and keyboard-focus states in light and dark palettes.
2. Run `QT_STYLE_OVERRIDE=Meo dolphin` with only the staged plugin path and
   inspect tree/list selection, headers, scroll bars, menus, and text clipping.
3. Open System Settings, Dolphin, Kate, Konsole, Gwenview, and Ark after a
   normal package installation. In System Settings → Colors & Themes →
   Application Style, confirm that **Meo** is listed and its preview renders.
4. Repeat at 125%, 150%, and 200% scale; verify focus, indicator alignment,
   text baselines, and menu geometry.
