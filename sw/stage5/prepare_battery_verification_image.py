#!/usr/bin/env python3
"""Create a battery simulation image seeded with a stale prior-run PASS.

The checked-in application VMEM is generated from the freshly linked ELF.
This helper preserves that image and creates a second VMEM containing old
.noinit result records plus a valid-looking old summary. The simulation must
prove that startup invalidates this stale PASS before profile MMIO activity.
"""

from __future__ import annotations

import argparse
from datetime import datetime
import os
from pathlib import Path
import re
import shutil
import sys

GOLDEN_CHECKSUM = 0xF7152312
SUMMARY_WORD_ADDRESS = 0x00000FF0  # RAM byte offset 0x3FC0 / 4
RESULT_WORD_ADDRESS = 0x0000025A   # RAM byte offset 0x0968 / 4

EXPECTED_FLAGS = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
    0x25, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]


def rol32(value: int, amount: int) -> int:
    value &= 0xFFFFFFFF
    return ((value << amount) | (value >> (32 - amount))) & 0xFFFFFFFF


def calculate_golden_checksum() -> int:
    checksum = 0xA5A5A5A5
    for sequence, flags in enumerate(EXPECTED_FLAGS, start=1):
        checksum = rol32(checksum, 5) ^ sequence
        checksum = rol32(checksum, 5) ^ flags
    return checksum & 0xFFFFFFFF


def highest_vmem_word(text: str) -> int:
    """Return the highest addressed data word in a simple SRecord VMEM."""
    cursor = None
    highest = -1
    for raw_line in text.splitlines():
        line = raw_line.split("//", 1)[0].strip()
        if not line or line.startswith("/*") or line.startswith("*"):
            continue
        tokens = line.split()
        if not tokens:
            continue
        if tokens[0].startswith("@"):  # VMEM address directive
            cursor = int(tokens[0][1:], 16)
            tokens = tokens[1:]
        if cursor is None:
            continue
        for token in tokens:
            if not re.fullmatch(r"[0-9A-Fa-f]{8}", token):
                raise ValueError(f"Unexpected VMEM token: {token}")
            highest = max(highest, cursor)
            cursor += 1
    return highest


def format_words(words: list[int]) -> str:
    return " ".join(f"{word & 0xFFFFFFFF:08X}" for word in words)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--normal-output", required=True, type=Path)
    parser.add_argument("--stale-pass-output", required=True, type=Path)
    args = parser.parse_args()

    if not args.source.is_file():
        print(f"ERROR: Freshly generated VMEM not found: {args.source}", file=sys.stderr)
        return 2

    calculated = calculate_golden_checksum()
    if calculated != GOLDEN_CHECKSUM:
        print(
            f"ERROR: Independent golden checksum calculation changed: 0x{calculated:08X}",
            file=sys.stderr,
        )
        return 2

    source_text = args.source.read_text(encoding="ascii")
    highest = highest_vmem_word(source_text)
    if highest >= RESULT_WORD_ADDRESS:
        print(
            "ERROR: Firmware image overlaps the reserved .noinit result buffer; "
            f"highest word=0x{highest:X}",
            file=sys.stderr,
        )
        return 2

    args.normal_output.parent.mkdir(parents=True, exist_ok=True)
    args.stale_pass_output.parent.mkdir(parents=True, exist_ok=True)

    # Preserve any existing checked-in simulation images before refreshing them.
    prior_images = [path for path in (args.normal_output, args.stale_pass_output)
                    if path.is_file()]
    backup_dir = None
    if prior_images:
        backup_root = Path(os.environ.get(
            "STAGE5_BACKUP_ROOT",
            "/mnt/e/Dissertation/Stage5_Code_Review/backups"
        ))
        backup_dir = backup_root / (
            "battery_vmem_refresh_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        )
        for old_image in prior_images:
            backup_path = backup_dir / old_image.relative_to(old_image.parents[1])
            backup_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(old_image, backup_path)

    shutil.copyfile(args.source, args.normal_output)

    # Simulate a prior, apparently successful execution in retained RAM.
    stale_result_words: list[int] = []
    for sequence, flags in enumerate(EXPECTED_FLAGS, start=1):
        stale_result_words.extend([sequence, flags])

    stale_summary_words = [
        0x42545053,       # old PASS marker
        0x0000000D,       # old Safety profile status
        0x0000000E,       # old processed sample count
        0x0000003F,       # old aggregate diagnostic mask
        GOLDEN_CHECKSUM,  # old rolling checksum
        0x00000000,       # old application failure code
        0x00000000,       # old hardware fault status
        0x00000021,       # old heartbeat sequence snapshot
        0x00000021,       # old heartbeat count snapshot
    ]

    stale_text = source_text.rstrip() + "\n"
    stale_text += f"@{RESULT_WORD_ADDRESS:08X} {format_words(stale_result_words)}\n"
    stale_text += f"@{SUMMARY_WORD_ADDRESS:08X} {format_words(stale_summary_words)}\n"
    args.stale_pass_output.write_text(stale_text, encoding="ascii")

    print("PASS: Fresh battery firmware VMEM copied to the repository data directory")
    print("PASS: Independent golden checksum recalculated as 0xF7152312")
    print("PASS: Stale prior-run result records seeded at RAM byte offset 0x00000968")
    print("PASS: Stale PASS summary seeded at RAM byte offset 0x00003FC0")
    if backup_dir is not None:
        print("Previous simulation images backed up to:", backup_dir)
    print("Normal VMEM:", args.normal_output)
    print("Stale-PASS verification VMEM:", args.stale_pass_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
