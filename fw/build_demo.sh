#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Build the board-demonstration firmware image
#   fw/images/stage5_battery_monitor_demo.vmem
#
# Same battery-monitoring application as the verified Safety-profile image,
# compiled with -DBATTERY_DEMO_DIAGNOSTIC (Diagnostic profile, fault injection
# authorised). Optimisation is -O2, as for the verified image.
#
# Run in WSL:   bash /mnt/e/Dissertation/Working_Model_RISCV/fw/build_demo.sh
# ------------------------------------------------------------------------------
set -euo pipefail

FW_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="$FW_DIR/src/stage5"
APP="$SRC/apps/battery_monitor"
BUILD="$FW_DIR/build/demo"
OUT="$FW_DIR/images/stage5_battery_monitor_demo.vmem"

# Locate the RISC-V toolchain: PATH first, then the lowRISC install location.
if ! command -v riscv32-unknown-elf-gcc >/dev/null 2>&1; then
    for d in "$HOME"/tools/riscv32/*/bin; do
        if [[ -x "$d/riscv32-unknown-elf-gcc" ]]; then
            export PATH="$d:$PATH"
            break
        fi
    done
fi

for tool in riscv32-unknown-elf-gcc riscv32-unknown-elf-objcopy \
            riscv32-unknown-elf-readelf riscv32-unknown-elf-size srec_cat python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: required tool not found: $tool"
        exit 1
    }
done

mkdir -p "$BUILD"
ELF="$BUILD/battery_monitor_demo.elf"
BIN="$BUILD/battery_monitor_demo.bin"
MAP="$BUILD/battery_monitor_demo.map"

riscv32-unknown-elf-gcc \
    -O2 -DBATTERY_DEMO_DIAGNOSTIC \
    -std=c11 -Wall -Wextra -Werror \
    -march=rv32im -mabi=ilp32 -mcmodel=medany \
    -msmall-data-limit=0 -ffreestanding -fno-builtin \
    -nostdlib -nostartfiles \
    -I"$SRC/platform" -I"$APP" \
    -T "$SRC/linker/stage5.ld" "-Wl,-Map=$MAP" \
    "$SRC/startup/start.S" \
    "$SRC/platform/platform.c" \
    "$APP/main.c" "$APP/battery_monitor.c" "$APP/battery_dataset.c" \
    -o "$ELF"

riscv32-unknown-elf-readelf -h "$ELF" |
    grep -q 'Entry point address:.*0x100080' || {
        echo "ERROR: firmware entry point is not 0x00100080"
        exit 1
    }

riscv32-unknown-elf-objcopy -O binary "$ELF" "$BIN"
srec_cat "$BIN" -binary -offset 0x80 -byte-swap 4 -o "$OUT" -vmem 32
python3 "$FW_DIR/../scripts/fw/pad_vmem.py" "$OUT"

echo
riscv32-unknown-elf-gcc --version | head -1
riscv32-unknown-elf-size "$ELF"
sha256sum "$OUT"
echo "PASS: demo firmware image written to $OUT"
