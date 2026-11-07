# Stage 6 — Step 2: Final Regression Baseline

Date: 2026-11-08
Status: PASS
Branch: stage6/arty-a7-fpga-integration

## 1. Purpose

This document records the final simulation regression baseline
before FPGA operating-frequency evaluation.

The RTL architecture remains frozen against the source manifest:

`docs/stage6/RTL_BASELINE_SHA256.txt`

Reference RTL commit: c5898ff
FPGA target: Arty A7-100T
FPGA part: xc7a100tcsg324-1
Top module: safety_riscv_soc_arty_a7

## 2. Firmware configuration

Application:
`sw/stage5/apps/battery_monitor/main.c`

The application heartbeat checkpoint was moved to immediately
after successful validation of each sample, before aggregate
and checksum bookkeeping.

No RTL, testbench, or supervisor timeout changes were made.

Compiler:
riscv32-unknown-elf-gcc 10.2.0
crosstool-NG 1.24.0.498_5075e1f

Compiler optimization:
-O2

The optimization flag was supplied through a temporary compiler
wrapper using the existing RISCV_CC build-script override.
The canonical build script was not modified.

Reproduction:

Create /tmp/riscv-gcc-o2:

#!/usr/bin/env bash
exec "$HOME/tools/riscv32/lowrisc-toolchain-rv32imcb-20220524-1/bin/riscv32-unknown-elf-gcc" -O2 "$@"

Then execute:

RISCV_CC=/tmp/riscv-gcc-o2 bash sw/stage5/build_battery_monitor.sh

Firmware size:

Text: 1220 bytes
Data: 0 bytes
BSS: 116 bytes
Total: 1336 bytes

Firmware entry point: 0x00100080
Battery result buffer: 0x00100968
Battery result buffer size: 112 bytes

## 3. Firmware artifact hashes

battery_monitor.bin:
5214cc92c7ea567979c9058f6ea14c5f5f3561ac28405bb94a4bec799ca89c09

battery_monitor.elf:
81e258d70f2647ba7dbdc023e90465077b8450c85efcd628d09eb44c6da6cd16

battery_monitor.map:
bfe389b247f7af9d32bf6df2079a3cb30c5cc2eeb0869b200b83290bf2f8b623

data/stage5_battery_monitor.vmem:
777e9837f6d5fe4a1c2320ab55453f9064c6428637fc09fbb3cc38dda1bbf663

data/stage5_battery_monitor_stale_pass.vmem:
b9d040465d5c7d1780d72fda401189e3c040b0a267c10d3dd56f24e4435d44ff

## 4. Regression results

All eight required verification checks passed.

| Check | Testbench / scenario | Result |
|---|---|---|
| Stage 5 basic | safety_riscv_soc_stage5_tb | PASS |
| Stage 5 HAL | safety_riscv_soc_stage5_hal_tb | PASS |
| Battery integration | safety_riscv_soc_stage5_battery_tb | PASS |
| Supervisor RAM containment | Stage 4F RAM containment scenario | PASS |
| Supervisor MMIO containment | Stage 4F MMIO containment scenario | PASS |
| Supervisor timeout | safety_execution_supervisor_tb | PASS |
| Native double fault | safety_riscv_soc_stage4f_native_double_fault_tb | PASS |
| Response error monitor | dcls_response_error_monitor_tb | PASS |

The six principal simulation builds/runs and the two
additional Stage 4F containment scenarios are recorded in:

`logs/stage2_final_regression_o2_20261108/`

### 4.1 Battery integration evidence

Core A sample records: 14/14
Core B sample records: 14/14
Result words: 28 per core
Aggregate diagnostic mask: 0x0000003F
Core A/B checksums: MATCH
Independent golden checksum: 0xF7152312
Stale PASS invalidation: VERIFIED
Accepted heartbeat updates: 42
Final heartbeat sequence: 0x0000002A
Safety fault: NONE

### 4.2 Supervisor evidence

Supervisor simulation: 10 checks passed.

RAM containment:
- Core A RAM write blocked.
- Core B RAM write blocked.
- Supervisor fault code: 0x03.
- Sticky fault and safe state confirmed.

MMIO containment:
- MMIO injection authorisation blocked.
- Supervisor fault code: 0x03.
- Sticky fault and safe state confirmed.

### 4.3 Native double-fault evidence

- Genuine Ibex double-fault pulse observed on Core A.
- Genuine Ibex double-fault pulse observed on Core B.
- Independent sticky capture verified.
- Fault code: 0x04.
- Safe-state containment verified.

## 5. RTL integrity

The active FPGA RTL source baseline is recorded in:

`docs/stage6/RTL_BASELINE_SHA256.txt`

No RTL or testbench modifications were required to achieve
the final regression results.

## 6. Limitations and scope

These results establish simulation-level functional verification.

They do not establish:
- FPGA timing closure.
- Physical FPGA operation.
- Hardware fault-injection performance.
- Safety certification or production readiness.

These items remain part of the subsequent FPGA implementation
and hardware demonstration stages.

## 7. Final status

Step 2 — Final regression baseline: COMPLETE.

All eight required checks passed.

The project is ready to proceed to Step 3:
FPGA operating-frequency evaluation.
