#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$SCRIPT_DIR/apps/battery_monitor"

CC="${RISCV_CC:-riscv32-unknown-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv32-unknown-elf-objcopy}"
READELF="${RISCV_READELF:-riscv32-unknown-elf-readelf}"
NM="${RISCV_NM:-riscv32-unknown-elf-nm}"
SIZE="${RISCV_SIZE:-riscv32-unknown-elf-size}"
SREC_CAT="${SREC_CAT:-srec_cat}"

for tool in "$CC" "$OBJCOPY" "$READELF" "$NM" "$SIZE" "$SREC_CAT"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: Required tool not found: $tool"
        exit 1
    }
done

mkdir -p "$BUILD_DIR"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

ELF="$BUILD_DIR/battery_monitor.elf"
BIN="$BUILD_DIR/battery_monitor.bin"
VMEM="$BUILD_DIR/battery_monitor.vmem"
MAP="$BUILD_DIR/battery_monitor.map"

"$CC" \
    -std=c11 -Wall -Wextra -Werror \
    -march=rv32im -mabi=ilp32 -mcmodel=medany \
    -msmall-data-limit=0 -ffreestanding -fno-builtin \
    -nostdlib -nostartfiles \
    -I"$SCRIPT_DIR/platform" \
    -I"$APP_DIR" \
    -T "$SCRIPT_DIR/linker/stage5.ld" \
    "-Wl,-Map=$MAP" \
    "$SCRIPT_DIR/startup/start.S" \
    "$SCRIPT_DIR/platform/platform.c" \
    "$APP_DIR/main.c" \
    "$APP_DIR/battery_monitor.c" \
    "$APP_DIR/battery_dataset.c" \
    -o "$ELF"

"$READELF" -h "$ELF" |
    grep -q 'Entry point address:.*0x100080' || {
        echo "ERROR: Firmware entry point is not 0x00100080"
        exit 1
    }

RESULT_SYMBOL="$("$NM" -S -n "$ELF" |
    awk '$NF == "battery_results" {print $1, $2; exit}')"

if [[ -z "$RESULT_SYMBOL" ]]; then
    echo "ERROR: battery_results symbol not found"
    exit 1
fi

read -r RESULT_ADDR_HEX RESULT_SIZE_HEX <<< "$RESULT_SYMBOL"

RESULT_START=$((16#$RESULT_ADDR_HEX))
RESULT_SIZE=$((16#$RESULT_SIZE_HEX))

if (( RESULT_START != 0x00100968 )); then
    echo "ERROR: battery_results address is not 0x00100968"
    printf 'Actual address: 0x%08X\\n' "$RESULT_START"
    exit 1
fi

if (( RESULT_SIZE != 112 )); then
    echo "ERROR: battery_results is not exactly 112 bytes"
    printf 'Actual size: %u bytes\\n' "$RESULT_SIZE"
    exit 1
fi

RESULT_END=$((RESULT_START + RESULT_SIZE))

APP_START=$((0x00100000))
APP_END=$((0x00103000))

if (( RESULT_START < APP_START || RESULT_END > APP_END )); then
    echo "ERROR: Per-sample result buffer is outside application RAM"
    printf 'Address: 0x%08X, End: 0x%08X\n' \
        "$RESULT_START" "$RESULT_END"
    exit 1
fi

"$OBJCOPY" -O binary "$ELF" "$BIN"

"$SREC_CAT" "$BIN" \
    -binary -offset 0x80 -byte-swap 4 \
    -o "$VMEM" -vmem 32

python3 "$SCRIPT_DIR/prepare_battery_verification_image.py" \
    --source "$VMEM" \
    --normal-output "$REPO_ROOT/data/stage5_battery_monitor.vmem" \
    --stale-pass-output "$REPO_ROOT/data/stage5_battery_monitor_stale_pass.vmem"

echo "PASS: Battery firmware linked successfully"
echo "PASS: Firmware entry point is 0x00100080"
echo "PASS: Per-core result buffer is 112 bytes in application RAM"
printf 'Result buffer address: 0x%08X\n' "$RESULT_START"
printf 'Result buffer end    : 0x%08X\n' "$RESULT_END"

echo
echo "========== FIRMWARE SIZE =========="
"$SIZE" "$ELF"

echo
echo "Generated files:"
echo "  ELF : $ELF"
echo "  BIN : $BIN"
echo "  VMEM: $VMEM"
echo "  MAP : $MAP"
