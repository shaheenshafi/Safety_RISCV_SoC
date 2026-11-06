# Stage5 Battery Firmware Correctness — Stage 1

## Changes

1. The application writes `BATTERY_MARKER_RUNNING` as the first summary-region write in `main()`, before profile-control or heartbeat MMIO operations.
2. Summary words 1–8 are cleared before the application enters the Safety profile. A RISC-V `fence rw, rw` orders the invalidation and final PASS/FAIL publication.
3. The firmware checks the calculated rolling checksum against the independent expected value `0xF7152312` and reports failure code 6 if it differs.
4. The battery simulation checks each core's checksum independently against `0xF7152312`, in addition to checking Core A/Core B equality.
5. The battery simulation image is generated from the freshly built ELF and seeded with stale prior-run result and PASS-summary contents. The testbench requires RUNNING to be the first summary marker and requires words 1–8 to be cleared before profile-control MMIO.

## Golden checksum

The expected value is independently calculated from the fourteen documented sequence/diagnostic-flag pairs using the documented rolling operation: rotate left by five bits and XOR the sequence, then rotate left by five bits and XOR the diagnostic flags. Starting value: `0xA5A5A5A5`. Result: `0xF7152312`.

## Validity rule

The `.noinit` per-sample result records are valid only when the current application run has successfully written the PASS marker after replacing every record and publishing the completed summary. A RUNNING or FAIL marker invalidates retained result contents.

## Build and simulation

Run `bash sw/stage5/build_battery_monitor.sh` before `battery_sim`. The build script updates `data/stage5_battery_monitor.vmem` and creates `data/stage5_battery_monitor_stale_pass.vmem`, which intentionally preloads stale retained-RAM data for the freshness regression.

This is firmware and simulation verification; it is not a hardware power-loss test or a functional-safety certification claim.
