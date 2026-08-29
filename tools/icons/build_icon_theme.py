#!/usr/bin/env python3
"""Build the MeoSymbols Freedesktop icon theme from local Material sources."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

ROOT = Path(__file__).resolve().parents[2]
MAPPING = ROOT / "icons/mappings/icons.yaml"
SOURCE_ROOT = ROOT / "assets/material-symbols/rounded/24px"
THEMES = {
    "light": {
        "path": ROOT / "themes/icons/MeoSymbols",
        "name": "Meo Symbols",
        "inherits": "breeze,hicolor",
        "fallback_color": "#232629",
    },
    "dark": {
        "path": ROOT / "themes/icons/MeoSymbolsDark",
        "name": "Meo Symbols Dark",
        "inherits": "breeze-dark,breeze,hicolor",
        "fallback_color": "#fcfcfc",
    },
}
MANIFEST_MD = ROOT / "docs/icons/GENERATED_ICON_MANIFEST.md"
UPSTREAM = "https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/{name}/materialsymbolsrounded/{name}_24px.svg"
THEME_DIRS = ("actions", "apps", "categories", "devices", "emblems", "emotes", "mimetypes", "places", "status", "panel")
SYMBOLIC_DIRS = ("actions", "devices", "places", "status")


def default_output_dir() -> Path:
    output_root = Path(os.environ.get("MEO_OUTPUT_ROOT", "/home/shekong/Projects/outputs"))
    run_id = os.environ.get(
        "MEO_KDE_ICON_RUN_ID",
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ") + "-icon-theme",
    )
    return output_root / "meo-kde" / "validation" / run_id


def load_mapping() -> dict:
    import yaml

    with MAPPING.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def material_names(mapping: dict) -> set[str]:
    return {name for entries in mapping["icons"].values() for name in entries.values()}


def fetch_assets(mapping: dict) -> list[str]:
    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    for name in sorted(material_names(mapping)):
        destination = SOURCE_ROOT / f"{name}.svg"
        if destination.exists() and destination.stat().st_size > 0:
            continue
        try:
            with urllib.request.urlopen(UPSTREAM.format(name=name), timeout=30) as response:
                destination.write_bytes(response.read())
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
            failures.append(f"{name}: {error}")
            destination.unlink(missing_ok=True)
    return failures


def normalize_svg(source: Path, destination: Path, fallback_color: str) -> None:
    tree = ET.parse(source)
    root = tree.getroot()
    if root.tag.rsplit("}", 1)[-1] != "svg" or not root.get("viewBox"):
        raise ValueError(f"invalid SVG root or viewBox: {source}")
    for element in root.iter():
        local_name = element.tag.rsplit("}", 1)[-1].lower()
        if local_name in {"script", "image", "foreignobject"}:
            raise ValueError(f"unsupported SVG element {local_name}: {source}")
        for attribute, value in element.attrib.items():
            if "http://" in value or "https://" in value or "data:" in value:
                raise ValueError(f"external or embedded content in {source}")
    root.attrib.pop("width", None)
    root.attrib.pop("height", None)
    root.attrib.pop("fill", None)

    # KIconLoader recolors SVGs through the same current-color-scheme contract
    # used by Breeze.  A bare currentColor defaults to black in QtSvg and can
    # disappear on dark surfaces, even though the icon file resolves correctly.
    original_children = list(root)
    for child in original_children:
        root.remove(child)
    defs = ET.SubElement(root, f"{{{SVG_NS}}}defs", {"id": "meo-color-defs"})
    style = ET.SubElement(
        defs,
        f"{{{SVG_NS}}}style",
        {"type": "text/css", "id": "current-color-scheme"},
    )
    style.text = f".ColorScheme-Text {{ color:{fallback_color}; }}"
    colored_geometry = ET.SubElement(
        root,
        f"{{{SVG_NS}}}g",
        {"class": "ColorScheme-Text", "fill": "currentColor"},
    )
    for child in original_children:
        colored_geometry.append(child)
    destination.parent.mkdir(parents=True, exist_ok=True)
    tree.write(destination, encoding="utf-8", xml_declaration=False)


def directory_section(path: str, context: str) -> str:
    return f"\n[{path}]\nSize=24\nMinSize=16\nMaxSize=64\nType=Scalable\nContext={context}\n"


def write_index(theme: Path, config: dict[str, object]) -> None:
    scalable_names = [
        name for name in THEME_DIRS
        if any((theme / "scalable" / name).iterdir())
    ]
    symbolic_names = [
        name for name in SYMBOLIC_DIRS
        if any((theme / "symbolic" / name).iterdir())
    ]
    scalable = [f"scalable/{name}" for name in scalable_names]
    symbolic = [f"symbolic/{name}" for name in symbolic_names]
    content = [
        "[Icon Theme]",
        f"Name={config['name']}",
        "Comment=Material Symbols Rounded system icon theme for Meo Desktop",
        f"Inherits={config['inherits']}",
        "Example=folder",
        "FollowsColorScheme=false",
        f"Directories={','.join(scalable + symbolic)}",
    ]
    contexts = {
        "actions": "Actions", "apps": "Applications", "categories": "Categories",
        "devices": "Devices", "emblems": "Emblems", "emotes": "Emotes",
        "mimetypes": "MimeTypes", "places": "Places", "status": "Status", "panel": "Status",
    }
    for name in scalable_names:
        content.append(directory_section(f"scalable/{name}", contexts[name]))
    for name in symbolic_names:
        content.append(directory_section(f"symbolic/{name}", contexts[name]))
    (theme / "index.theme").write_text("\n".join(content), encoding="utf-8")


def build_variant(mapping: dict, theme: Path, config: dict[str, object]) -> dict:
    if theme.exists():
        shutil.rmtree(theme)
    for group in THEME_DIRS:
        (theme / "scalable" / group).mkdir(parents=True, exist_ok=True)
    for group in SYMBOLIC_DIRS:
        (theme / "symbolic" / group).mkdir(parents=True, exist_ok=True)
    written: dict[str, Path] = {}
    missing: list[str] = []
    for group, entries in mapping["icons"].items():
        for semantic, material in entries.items():
            source = SOURCE_ROOT / f"{material}.svg"
            destination = theme / "scalable" / group / f"{semantic}.svg"
            if not source.exists():
                missing.append(f"{semantic} -> {material}")
                continue
            normalize_svg(source, destination, str(config["fallback_color"]))
            written[semantic] = destination
            if group in SYMBOLIC_DIRS:
                symbolic = theme / "symbolic" / group / f"{semantic}-symbolic.svg"
                symbolic.symlink_to(Path("../../scalable") / group / destination.name)
                written[f"{semantic}-symbolic"] = symbolic
    aliases = 0
    for alias, target in mapping.get("aliases", {}).items():
        if target not in written:
            missing.append(f"alias {alias} -> {target}")
            continue
        target_path = written[target]
        destination = target_path.parent / f"{alias}.svg"
        destination.symlink_to(target_path.name)
        written[alias] = destination
        aliases += 1
    licenses = theme / "LICENSES"
    licenses.mkdir(parents=True, exist_ok=True)
    license_source = ROOT / "assets/licenses/Material-Symbols-Apache-2.0.txt"
    shutil.copy2(license_source, licenses / "Apache-2.0.txt")
    (licenses / "MATERIAL_SYMBOLS.md").write_text(
        "# Material Symbols Rounded\n\n"
        "Upstream: https://github.com/google/material-design-icons\n\n"
        "License: Apache-2.0. The source SVGs are downloaded verbatim into "
        "`assets/material-symbols/rounded/24px/`; the build removes fixed "
        "dimensions and applies neutral `currentColor` at the SVG root.\n",
        encoding="utf-8",
    )
    (licenses / "CUSTOM_MEO_ICONS.md").write_text(
        "# Custom Meo icons\n\nNo custom system SVGs are included in this phase.\n",
        encoding="utf-8",
    )
    (theme / "README.md").write_text(
        f"# {config['name']}\n\nA Material Symbols Rounded Freedesktop/KDE system icon theme. "
        "It covers system controls and settings only, inherits Breeze then "
        "hicolor, and deliberately does not override third-party app brands.\n",
        encoding="utf-8",
    )
    write_index(theme, config)
    return {"native": len(written) - aliases, "aliases": aliases, "missing": missing, "files": len(written)}


def build(mapping: dict) -> dict:
    results = [build_variant(mapping, config["path"], config) for config in THEMES.values()]
    first = results[0]
    for result in results[1:]:
        if result != first:
            raise ValueError("light and dark icon variants generated different inventories")
    return first


def validate() -> list[str]:
    issues: list[str] = []
    for config in THEMES.values():
        theme = config["path"]
        if not (theme / "index.theme").exists():
            issues.append(f"missing index.theme: {theme.name}")
            continue
        for svg in theme.rglob("*.svg"):
            if svg.is_symlink():
                if not svg.resolve().exists():
                    issues.append(f"broken alias: {theme.name}/{svg.relative_to(theme)}")
                continue
            try:
                root = ET.parse(svg).getroot()
                payload = svg.read_text(encoding="utf-8")
                if (not root.get("viewBox")
                        or 'id="current-color-scheme"' not in payload
                        or 'class="ColorScheme-Text"' not in payload
                        or 'fill="currentColor"' not in payload
                        or str(config["fallback_color"]) not in payload):
                    issues.append(f"invalid normalization: {theme.name}/{svg.relative_to(theme)}")
            except ET.ParseError as error:
                issues.append(f"invalid XML {theme.name}/{svg.relative_to(theme)}: {error}")
    return issues


def write_report(result: dict, issues: list[str], report: Path, report_md: Path) -> None:
    report.parent.mkdir(parents=True, exist_ok=True)
    report_md.parent.mkdir(parents=True, exist_ok=True)
    data = {**result, "validation_issues": issues}
    report.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    report_md.write_text(
        "# MeoSymbols core coverage\n\n"
        f"- Native Material Symbols: {result['native']}\n"
        f"- Aliases: {result['aliases']}\n"
        f"- Missing mappings: {len(result['missing'])}\n"
        f"- Validation issues: {len(issues)}\n",
        encoding="utf-8",
    )


def write_manifest(mapping: dict, manifest: Path) -> None:
    """Publish the exact generated-icon inventory for design review and packaging."""
    entries: list[dict[str, object]] = []
    for group, icons in mapping["icons"].items():
        for semantic, material in sorted(icons.items()):
            paths = [f"scalable/{group}/{semantic}.svg"]
            if group in SYMBOLIC_DIRS:
                paths.append(f"symbolic/{group}/{semantic}-symbolic.svg")
            entries.append({
                "kind": "material",
                "category": group,
                "semantic_name": semantic,
                "material_symbol": material,
                "theme_paths": paths,
                "source": f"assets/material-symbols/rounded/24px/{material}.svg",
            })
    for alias, target in sorted(mapping.get("aliases", {}).items()):
        target_entry = next((entry for entry in entries if entry["semantic_name"] == target), None)
        entries.append({
            "kind": "alias",
            "category": target_entry["category"] if target_entry else "unknown",
            "semantic_name": alias,
            "target": target,
            "material_symbol": target_entry["material_symbol"] if target_entry else None,
            "theme_paths": [f"alias of {target}"],
            "source": "symlink; no new SVG geometry",
        })
    payload = {
        "theme_variants": ["MeoSymbols", "MeoSymbolsDark"],
        "style": "Material Symbols Rounded",
        "license": "Apache-2.0",
        "policy": "System semantics only; third-party application brands are excluded.",
        "entries": entries,
    }
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    lines = [
        "# MeoSymbols generated icon manifest",
        "",
        "This is the review list for every generated system icon. Source geometry is",
        "Google Material Symbols Rounded under Apache-2.0; aliases add no new SVG.",
        "Third-party application brands are intentionally excluded.",
        "",
        "- Variants: `MeoSymbols` (light) and `MeoSymbolsDark` (dark)",
        f"- Material mappings: {sum(1 for entry in entries if entry['kind'] == 'material')}",
        f"- Semantic aliases: {sum(1 for entry in entries if entry['kind'] == 'alias')}",
        "",
        "| Type | KDE/Freedesktop name | Material source | Category |",
        "| --- | --- | --- | --- |",
    ]
    for entry in entries:
        source = entry.get("material_symbol") or entry.get("target") or "-"
        lines.append(
            f"| {entry['kind']} | `{entry['semantic_name']}` | `{source}` | {entry['category']} |"
        )
    MANIFEST_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--report", action="store_true")
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="directory for generated validation reports; defaults to global MeoKDE outputs",
    )
    args = parser.parse_args()
    output_dir = args.output_dir or default_output_dir()
    if args.clean:
        for config in THEMES.values():
            shutil.rmtree(config["path"], ignore_errors=True)
    if args.fetch:
        failures = fetch_assets(mapping)
        if failures:
            print("\n".join(failures), file=sys.stderr)
            return 1
    if args.check:
        issues = validate()
        if issues:
            print("\n".join(issues), file=sys.stderr)
            return 1
        return 0
    mapping = load_mapping()
    result = build(mapping)
    issues = validate()
    report = output_dir / "metrics" / "icon-coverage.json"
    report_md = output_dir / "reports" / "icon-coverage.md"
    manifest = output_dir / "metrics" / "icon-generation-manifest.json"
    write_report(result, issues, report, report_md)
    write_manifest(mapping, manifest)
    if args.report:
        print(report_md.read_text(encoding="utf-8"), end="")
    if result["missing"] or issues:
        print("\n".join(result["missing"] + issues), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
