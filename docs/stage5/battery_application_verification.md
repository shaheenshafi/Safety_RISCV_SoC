# Stage 5C — Battery Monitoring Application Verification Record

**Version:** 0.1
**Status:** Simulation verification completed
**Verification platform:** Verilator 5.032
**Target architecture:** RV32IM / ILP32
**Simulation framework:** FuseSoC / Edalize

## 1. Verification Objective

Verify the integration of the Stage 5A battery diagnostic workload
with the Stage 5B bare-metal platform and dual-core RISC-V SoC.

The verification covers:
- Host-level diagnostic engine unit tests.
- Target-specific firmware compilation and linking.
- Firmware memory layout and boot-address requirements.
- Independent Core A and Core B battery result writes.
- Summary data and aggregate diagnostic results.
- Heartbeat servicing and supervisor timing.
- Regression of existing Stage5 smoke-test and HAL applications.

This record documents simulation and software test evidence. It
does not establish functional-safety certification.

## 2. Host-Level Unit Testing

The diagnostic engine and shared dataset were compiled using native
GCC with strict warning checks:

    gcc -std=c11 -Wall -Wextra -Werror -pedantic

The unit test executable completed successfully.

### 2.1 Scenario results

| Sequence | Scenario | Expected flags | Result |
|---:|---|---:|---|
| 1 | Nominal operation | `0x00` | PASS |
| 2 | Undervoltage | `0x01` | PASS |
| 3 | Overvoltage | `0x02` | PASS |
| 4 | Discharge overcurrent | `0x04` | PASS |
| 5 | Charge overcurrent | `0x08` | PASS |
| 6 | Undertemperature | `0x10` | PASS |
| 7 | Overtemperature | `0x20` | PASS |
| 8 | Combined abnormalities | `0x25` | PASS |
| 9 | Undervoltage boundary | `0x00` | PASS |
| 10 | Overvoltage boundary | `0x00` | PASS |
| 11 | Discharge-current boundary | `0x00` | PASS |
| 12 | Charge-current boundary | `0x00` | PASS |
| 13 | Minimum-temperature boundary | `0x00` | PASS |
| 14 | Maximum-temperature boundary | `0x00` | PASS |

### 2.2 Additional unit checks

The following checks also passed:

- Reference threshold configuration accepted.
- Invalid threshold configurations rejected.
- Null threshold configuration rejected.
- Aggregate diagnostic mask equals `0x3F`.
- Reserved diagnostic bits remain zero.
- `INT32_MIN` charge-current sample correctly detected as charge
  overcurrent with `INT32_MAX` configured as the positive charge
  current magnitude limit.

**Host unit-test result: PASS — 14/14 scenarios.**

## 3. Target Firmware Build Verification

The diagnostic engine and dataset were separately cross-compiled
using the RISC-V LowRISC toolchain.

The target configuration was:

| Option | Configuration |
|---|---|
| ISA | `rv32im` |
| ABI | `ilp32` |
| Code model | `medany` |
| Runtime | Freestanding |
| Built-in functions | Disabled |

Both object files were reported as ELF32 RISC-V objects.

Expected symbols were present:
- `battery_thresholds_validate`
- `battery_diagnose_sample`
- `battery_reference_thresholds`
- `battery_test_dataset`

No undefined symbols were reported for the diagnostic engine or
dataset objects.

### 3.1 Complete firmware build

The battery application was linked with:
- Stage5 startup assembly.
- Existing platform HAL implementation.
- Battery application entry point.
- Battery diagnostic engine.
- Battery measurement dataset.

Strict compiler warnings were enabled.

**Build result: PASS.**

### 3.2 Boot and firmware image

| Property | Verified value |
|---|---:|
| ELF entry point | `0x00100080` |
| Ibex boot address | `0x00100000` |
| VMEM word offset | `@00000020` |

The generated image was converted into 32-bit VMEM format and
used as the firmware image for the battery simulation target.

## 4. Memory Layout Verification

Each core has an independent 16 KiB RAM instance.

### 4.1 Memory allocation

| Region | Start address | End address (exclusive) | Size |
|---|---:|---:|---:|
| Application RAM | `0x00100000` | `0x00103000` | 12 KiB |
| Stack RAM | `0x00103000` | `0x00103FC0` | 4,032 bytes |
| Summary/result RAM | `0x00103FC0` | `0x00104000` | 64 bytes |

### 4.2 Per-sample result buffer

The linker places `battery_results` at:

| Property | Value |
|---|---:|
| CPU address | `0x00100968` |
| RAM interface offset | `0x00000968` |
| Size | 112 bytes |
| End address (exclusive) | `0x001009D8` |

The result buffer is assigned to a dedicated `.noinit` section.
It is not cleared by the startup BSS loop.

The linker includes assertions to prevent BSS overlap and to ensure
that the result buffer remains within application RAM.

### 4.3 Summary region

The application uses nine 32-bit words in the reserved 64-byte region
beginning at `0x00103FC0`.

| Word | Description | Value at PASS publication |
|---:|---|---:|
| 0 | Application marker | `0x42545053` |
| 1 | Profile status | `0x0000000D` |
| 2 | Processed sample count | `14` |
| 3 | Aggregate diagnostic flags | `0x0000003F` |
| 4 | Rolling result checksum | Core A/B equal |
| 5 | Application failure code | `0` |
| 6 | Hardware fault status | `0` |
| 7 | Heartbeat sequence snapshot | `18` |
| 8 | Heartbeat count snapshot | `18` |

The PASS marker is written after the summary fields.

## 5. Dual-Core Simulation Verification

The dedicated FuseSoC target is:

    battery_sim

The simulation executes the same battery firmware image independently
on Core A and Core B.

The testbench monitors both cores' RAM write interfaces using the
RAM byte-offset address convention.

### 5.1 Individual result verification

For each core, the testbench verifies:
- Fourteen sequence-number writes.
- Fourteen diagnostic-flag writes.
- The expected value of every sequence number.
- The expected value of every diagnostic flag.
- A total of 28 result-word writes.

| Verification item | Core A | Core B |
|---|---:|---:|
| Sequence records observed | 14/14 | 14/14 |
| Diagnostic records observed | 14/14 | 14/14 |
| Result words observed | 28/28 | 28/28 |

Both per-sample result bitmaps were complete.

### 5.2 Summary verification

Both cores successfully published their summary regions.

The testbench verified:
- PASS marker.
- Safety profile status `0x0D`.
- Processed sample count of 14.
- Aggregate diagnostic mask `0x3F`.
- Zero application failure code.
- Zero hardware fault status.
- Heartbeat sequence snapshot of 18.
- Heartbeat count snapshot of 18.

The Core A and Core B rolling result checksums matched.

### 5.3 Heartbeat and execution-supervisor verification

The simulation testbench monitored the accepted heartbeat updates.

| Check | Expected condition | Result |
|---|---|---|
| First heartbeat | Sequence 1 within 256 cycles | PASS |
| Minimum interval | At least 4 cycles | PASS |
| Maximum interval | No more than 256 cycles | PASS |
| Sequence progression | Increment by one | PASS |
| Core A/B transaction | Matching MMIO writes | PASS |

The summary captures heartbeat sequence/count 18 when the PASS
summary is published. The application then continues servicing
the supervisor in its idle loop.

At the end of the 6,000-cycle simulation:

| Measurement | Result |
|---|---:|
| Accepted heartbeat updates | 33 |
| Final heartbeat sequence | `0x00000021` |
| Simulation cycles | 6,000 |

### 5.4 Safety-profile and fault checks

The simulation verified:
- Safety profile selected and valid.
- DCLS enabled.
- Fault injection disabled.
- No unexpected sticky instruction or data fault.
- No watchdog early-service fault.
- No watchdog timeout.
- No progress timeout.
- No MMIO-interlock fault.
- No DCLS mismatch.
- No safe-state request.

**Battery dual-core integration result: PASS.**

## 6. Complete Stage5 Regression

All three Stage5 FuseSoC simulation targets were executed in one
regression run.

| Target | Description | Result |
|---|---|---|
| `sim` | Stage5 firmware smoke test | PASS |
| `hal_sim` | Bare-metal platform HAL integration | PASS |
| `battery_sim` | Battery-monitoring dual-core integration | PASS |

### 6.1 Smoke-test regression

- Core A and Core B result: `0x0000000C`.
- Selected profile: Basic.
- DCLS disabled as expected for Basic profile.
- Simulation cycles: 56.
- No illegal decodes or illegal exceptions.
- No safety fault.

The smoke-test firmware build also reproduced its validated
reference VMEM image.

### 6.2 HAL regression

- Safety profile confirmed.
- DCLS enabled.
- Six accepted heartbeat updates.
- Final heartbeat sequence: `0x00000006`.
- Simulation cycles: 1,200.
- No safety fault.

The HAL firmware build also reproduced its validated reference
VMEM image.

### 6.3 Battery application regression

- Fourteen scenarios verified on each core.
- Twenty-eight result words verified per core.
- Aggregate diagnostic mask: `0x3F`.
- Core A/B checksums matched.
- Thirty-three accepted heartbeat updates.
- Final heartbeat sequence: `0x00000021`.
- Simulation cycles: 6,000.
- No safety fault.

**Complete Stage5 regression result: PASS — 3/3 targets.**

## 7. Verification Conclusions

The available host-test, target-build and simulation results support
the following conclusions:

1. The threshold-based battery diagnostic engine passed the fourteen
   defined deterministic scenarios and its additional boundary checks.
2. The battery application firmware links for the intended RV32IM
   target and retains the required boot entry point.
3. The result-buffer and summary-region memory allocation satisfies
   the implemented linker checks.
4. Both RISC-V cores independently executed the same battery workload
   and produced the expected sequence and diagnostic-flag writes.
5. The application aggregate diagnostic mask was `0x3F` on both cores.
6. The Core A and Core B result checksums matched.
7. The existing heartbeat interface operated within its configured
   timing window during the tested simulation.
8. The existing smoke-test and HAL simulation regressions continued
   to pass after the Stage5C integration changes.

These are software and RTL simulation results for the defined
workload and test conditions. They do not establish exhaustive
verification of all firmware, hardware, fault combinations or
environmental operating conditions.

## 8. Limitations and Safety Qualification

The workload processes deterministic software-generated measurement
data. It does not implement physical sensing, ADC acquisition,
cell balancing, SOC/SOH estimation or actuator control.

The battery thresholds are illustrative simulation assumptions.
They are not validated product operating limits.

The dual-core architecture uses the existing observable transaction
comparison and MMIO interlock. This verification does not establish
full internal-retirement-level lockstep.

No claim is made of ISO 26262 compliance, ASIL achievement, certified
battery protection capability or functional-safety certification.

Further verification, fault-injection analysis, hardware validation
and safety lifecycle evidence would be required for any product
safety claim.
