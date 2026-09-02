#!/usr/bin/env python3
"""Render MeoSymbols through Qt's active icon engine for visual acceptance."""

from __future__ import annotations

import argparse
from pathlib import Path

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QColor, QFont, QGuiApplication, QIcon, QImage, QPainter, QPalette


ROOT = Path(__file__).resolve().parents[2]

ICONS = (
    "preferences-system", "preferences-desktop-color", "preferences-system-network",
    "preferences-system-bluetooth", "preferences-system-power-management", "list-add",
    "list-remove", "edit-copy", "edit-paste", "edit-delete", "document-open",
    "document-save", "view-refresh", "application-menu", "view-grid", "view-list",
    "network-wireless", "network-wireless-disconnected", "network-wired", "network-vpn",
    "bluetooth-active", "bluetooth-disabled", "audio-volume-high", "audio-volume-muted",
    "battery-100", "battery-charging", "notifications", "notifications-disabled",
    "folder", "folder-open", "folder-remote", "user-home", "user-trash-empty",
    "computer-laptop", "smartphone", "scanner", "system-lock-screen", "system-shutdown",
    # Curated application layer: review these in the same circular-well context
    # used by the native Dock, rather than judging the raw SVG paths in isolation.
    "org.kde.dolphin", "utilities-terminal", "google-chrome", "firefox", "chatgpt",
    "claude-desktop", "com.visualstudio.code.oss", "obsidian", "spotify-client",
    "steam", "org.prismlauncher.PrismLauncher", "spectacle", "libreoffice-writer",
)


def pixmap_has_visible_pixels(icon: QIcon, size: int) -> bool:
    image = icon.pixmap(QSize(size, size)).toImage().convertToFormat(QImage.Format_RGBA8888)
    if image.isNull():
        return False
    for y in range(image.height()):
        for x in range(image.width()):
            if image.pixelColor(x, y).alpha() > 0:
                return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("light", "dark"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    app = QGuiApplication([])
    dark = args.mode == "dark"
    background = QColor("#141218" if dark else "#fffbfe")
    foreground = QColor("#e6e0e9" if dark else "#1c1b1f")
    palette = app.palette()
    for role in (QPalette.WindowText, QPalette.Text, QPalette.ButtonText, QPalette.ToolTipText):
        palette.setColor(role, foreground)
    palette.setColor(QPalette.Window, background)
    palette.setColor(QPalette.Base, background)
    app.setPalette(palette)
    QIcon.setThemeSearchPaths([str(ROOT / "themes" / "icons"), *QIcon.themeSearchPaths()])
    QIcon.setThemeName("MeoSymbolsDark" if dark else "MeoSymbols")

    columns = 5
    cell_width, cell_height = 210, 112
    rows = (len(ICONS) + columns - 1) // columns
    canvas = QImage(columns * cell_width, rows * cell_height, QImage.Format_ARGB32_Premultiplied)
    canvas.fill(background)
    painter = QPainter(canvas)
    painter.setRenderHint(QPainter.Antialiasing)
    painter.setPen(foreground)
    font = QFont("Roboto", 10)
    painter.setFont(font)

    missing: list[str] = []
    empty: list[str] = []
    for index, name in enumerate(ICONS):
        row, column = divmod(index, columns)
        left, top = column * cell_width, row * cell_height
        icon = QIcon.fromTheme(name)
        if icon.isNull():
            missing.append(name)
            continue
        if not pixmap_has_visible_pixels(icon, 48):
            empty.append(name)
            continue
        pixmap = icon.pixmap(QSize(48, 48))
        # Match the pale circular app wells of the Dock so contrast and visual
        # weight are reviewed at the size users actually see.
        painter.setPen(Qt.NoPen)
        painter.setBrush(QColor("#e9e1f2" if dark else "#f2ecf8"))
        painter.drawEllipse(left + (cell_width - 64) // 2, top + 4, 64, 64)
        painter.setPen(foreground)
        painter.drawPixmap(left + (cell_width - 48) // 2, top + 12, pixmap)
        painter.drawText(left + 8, top + 70, cell_width - 16, 34, Qt.AlignHCenter | Qt.AlignTop, name)
    painter.end()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    if not canvas.save(str(args.output)):
        raise RuntimeError(f"unable to save {args.output}")
    print(f"mode={args.mode} rendered={len(ICONS) - len(missing) - len(empty)} missing={len(missing)} empty={len(empty)} output={args.output}")
    if missing:
        print("missing=" + ",".join(missing))
    if empty:
        print("empty=" + ",".join(empty))
    return 1 if missing or empty else 0


if __name__ == "__main__":
    raise SystemExit(main())
