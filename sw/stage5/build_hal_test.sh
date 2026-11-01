#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

CC="${RISCV_CC:-riscv32-unknown-elf-gcc}"
OBJCOPY="${RISCV_OBJCOPY:-riscv32-unknown-elf-objcopy}"
READELF="${RISCV_READELF:-riscv32-unknown-elf-readelf}"
SREC_CAT="${SREC_CAT:-srec_cat}"

for tool in "$CC" "$OBJCOPY" "$READELF" "$SREC_CAT"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: Required tool not found: $tool"
        exit 1
    }
done

mkdir -p "$BUILD_DIR"

"$CC" \
    -march=rv32im -mabi=ilp32 -mcmodel=medany \
    -msmall-data-limit=0 -ffreestanding -fno-builtin \
    -nostdlib -nostartfiles -Wall -Wextra -Werror \
    -I"$SCRIPT_DIR/platform" \
    -T "$SCRIPT_DIR/linker/stage5.ld" \
    "-Wl,-Map=$BUILD_DIR/hal_test.map" \
    "$SCRIPT_DIR/startup/start.S" \
    "$SCRIPT_DIR/platform/platform.c" \
    "$SCRIPT_DIR/apps/hal_test/main.c" \
    -o "$BUILD_DIR/hal_test.elf"

"$READELF" -h "$BUILD_DIR/hal_test.elf" |
    grep -q 'Entry point address:.*0x100080' || {
        echo "ERROR: Firmware entry point is not 0x00100080"
        exit 1
    }

"$OBJCOPY" -O binary "$BUILD_DIR/hal_test.elf" \
    "$BUILD_DIR/hal_test.bin"

"$SREC_CAT" "$BUILD_DIR/hal_test.bin" \
    -binary -offset 0x80 -byte-swap 4 \
    -o "$BUILD_DIR/stage5_hal_test.vmem" -vmem 32

cmp "$BUILD_DIR/stage5_hal_test.vmem" \
    "$ROOT_DIR/data/stage5_hal_test.vmem"

echo "PASS: HAL firmware entry point is 0x00100080"
echo "PASS: Generated VMEM matches the simulated reference image"
echo "Build outputs: $BUILD_DIR"
