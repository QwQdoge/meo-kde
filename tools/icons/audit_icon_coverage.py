#!/usr/bin/env python3
"""Report semantic icon references used by Meo source and KDE settings modules."""
from __future__ import annotations

import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
MAPPING = ROOT / "icons/mappings/icons.yaml"


def default_output_path() -> Path:
    output_root = Path(os.environ.get("MEO_OUTPUT_ROOT", "/home/shekong/Projects/outputs"))
    run_id = os.environ.get(
        "MEO_KDE_VALIDATION_RUN_ID",
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ") + "-icon-audit",
    )
    return output_root / "meo-kde" / "validation" / run_id / "metrics" / "icon-usage-audit.json"


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--output",
    type=Path,
    help="JSON output path; defaults to the canonical MeoKDE validation directory.",
)
arguments = parser.parse_args()
OUT = arguments.output or default_output_path()

mapping = yaml.safe_load(MAPPING.read_text(encoding="utf-8"))
known = {name for group in mapping["icons"].values() for name in group} | set(mapping.get("aliases", {}))
references: set[str] = set()
pattern = re.compile(r'(?:source:|icon\.name:|QIcon::fromTheme\()\s*"([^"]+)"')
for root in (ROOT / "plasmoids", ROOT / "qml", ROOT / "native"):
    for path in root.rglob("*"):
        if path.suffix not in {".qml", ".cpp", ".h"}:
            continue
        references.update(pattern.findall(path.read_text(encoding="utf-8", errors="ignore")))
kcm_icons: set[str] = set()
for path in Path("/usr/share/applications").glob("kcm*.desktop"):
    match = re.search(r"^Icon=(.+)$", path.read_text(encoding="utf-8", errors="ignore"), re.MULTILINE)
    if match:
        kcm_icons.add(match.group(1))
data = {
    "meo_references": sorted(references),
    "meo_references_known": sorted(references & known),
    "meo_references_breeze_fallback": sorted(references - known),
    "kcm_icons": sorted(kcm_icons),
    "kcm_icons_known": sorted(kcm_icons & known),
    "kcm_icons_breeze_fallback": sorted(kcm_icons - known),
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: len(value) for key, value in data.items()}, sort_keys=True))
