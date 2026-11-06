#!/usr/bin/env python3
"""Safely register the Stage 6 paired data-capture RTL in Stage 4F-derived cores.

Run this from the repository root:
    python3 stage6_pairing_integration/update_pairing_manifests.py

Only existing manifest files are considered. A file is changed only when it
contains exactly one direct DCLS comparator source entry. No other manifest
content is rewritten.
"""
from pathlib import Path
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
if not (ROOT / "rtl/bringup").is_dir():
    print(f"ERROR: {ROOT} does not look like the project root (rtl/bringup missing).",
          file=sys.stderr)
    sys.exit(2)

TARGETS = [
    ROOT / "rtl/bringup/safety_riscv_soc_stage4f.core",
    ROOT / "rtl/bringup/safety_riscv_soc_stage4f_synth.core",
    ROOT / "rtl/bringup/safety_riscv_soc_stage5.core",
    ROOT / "rtl/bringup/safety_riscv_soc_arty_a7.core",
    ROOT / "rtl/bringup/safety_riscv_soc_stage4f_native_double_fault.core",
]
MARKER = "      - ../safety/dcls_comparator.v\n"
NEW_LINE = "      - ../safety/dcls_paired_data_capture_stage.v\n"

pending = []
errors = []
for path in TARGETS:
    if not path.is_file():
        print(f"SKIP (not present): {path.relative_to(ROOT)}")
        continue

    content = path.read_text()
    if NEW_LINE in content:
        print(f"OK (already registered): {path.relative_to(ROOT)}")
        continue

    count = content.count(MARKER)
    if count == 0:
        print(f"SKIP (no direct comparator source entry; check dependency): "
              f"{path.relative_to(ROOT)}")
        continue
    if count != 1:
        errors.append(
            f"{path.relative_to(ROOT)}: expected exactly one comparator source "
            f"entry, found {count}"
        )
        continue

    pending.append((path, content.replace(MARKER, MARKER + NEW_LINE, 1)))

if errors:
    print("No files were modified; resolve these manifest mismatches first:",
          file=sys.stderr)
    for item in errors:
        print(f"  - {item}", file=sys.stderr)
    sys.exit(2)

for path, updated in pending:
    path.write_text(updated)
    print(f"UPDATED: {path.relative_to(ROOT)}")

print(f"Manifest update complete: {len(pending)} additional file(s) updated.")
