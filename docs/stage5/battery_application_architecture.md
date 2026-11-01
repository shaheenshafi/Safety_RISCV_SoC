# Stage 5C — Battery Monitoring Application Architecture

**Version:** 0.2
**Status:** Implemented and simulation-verified

## 1. Objective

Integrate the Stage 5A deterministic battery-monitoring workload with
the Stage 5B bare-metal platform and Hardware Abstraction Layer (HAL).

The application demonstrates threshold-based battery measurement
diagnostics using integer arithmetic on the dual-core RISC-V SoC.

This is a representative embedded software workload, not a complete
production battery-management system.

## 2. Application Components

| Component | File | Responsibility |
|---|---|---|
| Application entry | `main.c` | Platform initialization and workload orchestration |
| Data types | `battery_types.h` | Measurement, threshold and result structures |
| Dataset | `battery_dataset.c/.h` | Fourteen deterministic measurement scenarios |
| Diagnostic engine | `battery_monitor.c/.h` | Threshold validation and sample diagnosis |
| Platform interface | Existing `platform.h/.c` | MMIO, profile selection and heartbeat services |

The battery diagnostic engine is independent of the hardware register
implementation. It does not access MMIO or modify hardware fault-manager
state.

## 3. Execution Architecture

Both RISC-V cores execute the same firmware image independently,
using separate 16 KiB RAM instances and the same deterministic dataset.

Each core performs the following sequence:

1. Executes startup code, initializes the stack and clears `.bss`.
2. Selects the Safety profile and verifies hardware readback.
3. Starts heartbeat servicing through the platform HAL.
4. Writes the application running marker.
5. Validates the reference threshold configuration.
6. Services the heartbeat before beginning the sample workload.
7. Diagnoses all fourteen samples and stores each result in local RAM.
8. Compares actual sample flags with the expected dataset flags.
9. Accumulates the application diagnostic mask and result checksum.
10. Services the heartbeat after workload completion.
11. Checks the processed sample count, aggregate flags and hardware
    fault status.
12. Publishes the application summary, including a heartbeat checkpoint
    during summary publication.
13. Writes the PASS marker last.
14. Continues servicing the hardware supervisor in the idle loop.

Both cores must execute matching externally observable MMIO
transactions. The existing MMIO interlock and DCLS mechanisms remain
responsible for their respective hardware-level checks.

## 4. Diagnostic Engine Interface

The implemented diagnostic interface is:

    int battery_thresholds_validate(
        const battery_thresholds_t *thresholds
    );

    uint32_t battery_diagnose_sample(
        const battery_sample_t *sample,
        const battery_thresholds_t *thresholds
    );

The diagnostic function returns a six-bit mask for the six conditions
defined in the Stage 5A workload specification.

The engine:
- Uses integer/fixed-point measurement values.
- Uses strict threshold comparisons.
- Evaluates each diagnostic condition independently.
- Does not access MMIO registers.
- Does not generate heartbeat transactions.
- Does not directly modify hardware fault-manager state.

For identical valid inputs, the diagnostic function produces
identical results.

## 5. Data and Result Storage

The shared firmware constants contain the reference thresholds and
fourteen test vectors. Each vector includes a measurement sample and
its expected diagnostic flags.

Each result record contains:
- Sample sequence number: 32 bits.
- Diagnostic flags: 32 bits.

The result structure is 8 bytes. Fourteen records require 112 bytes.

### 5.1 Per-core result buffer

The result buffer is a global volatile array placed in a dedicated
`.noinit` section.

| Property | Value |
|---|---:|
| CPU address | `0x00100968` |
| RAM interface byte offset | `0x00000968` |
| Size | 112 bytes |
| End address (exclusive) | `0x001009D8` |
| Records | 14 |
| Record size | 8 bytes |

The `.noinit` section is not cleared by startup BSS initialization.
The application overwrites every record before publishing its PASS
marker. A result record is considered valid only after the application
has written it.

The linker fixes the `.noinit` address and checks that `.bss` does not
overlap the buffer and that the buffer remains within application RAM.

### 5.2 Summary region

The existing 64-byte reserved result region begins at CPU address
`0x00103FC0`, corresponding to RAM interface byte offset `0x00003FC0`.

The application uses the first nine 32-bit words:

| Word | Offset | Meaning |
|---:|---:|---|
| 0 | `0x00` | Running, PASS or FAIL marker |
| 1 | `0x04` | Profile status |
| 2 | `0x08` | Number of processed samples |
| 3 | `0x0C` | Aggregate diagnostic flags |
| 4 | `0x10` | Rolling result checksum |
| 5 | `0x14` | Application failure code |
| 6 | `0x18` | Hardware fault status |
| 7 | `0x1C` | Heartbeat sequence snapshot |
| 8 | `0x20` | Heartbeat count snapshot |

Markers:
- Running: `0x42545231`
- PASS: `0x42545053`
- FAIL: `0xBAD50001`

The PASS marker is written last. The remaining words of the reserved
64-byte region are not used by this application.

Individual sample flags, the aggregate application diagnostic mask
and hardware fault-manager status remain separate quantities.

## 6. Heartbeat Integration

Heartbeat servicing is performed through the existing Stage 5B
platform HAL and shared heartbeat MMIO register at `0x00200010`.

The application issues:
- One initial heartbeat during `platform_heartbeat_start()`.
- One checkpoint after threshold validation.
- One heartbeat after each of the fourteen samples.
- One checkpoint after the sample loop.
- One checkpoint during summary publication.
- Further periodic heartbeats in the idle loop.

The summary heartbeat sequence and count are both 18 when the PASS
summary is published. Subsequent idle-loop servicing continues.

The simulation testbench checks:
- First heartbeat sequence value is 1.
- First heartbeat occurs within the initial 256-cycle window.
- Subsequent accepted heartbeat intervals are between 4 and 256
  cycles, inclusive.
- Both cores issue matching full-word heartbeat transactions.
- Heartbeat sequence values increment by one.

Heartbeat servicing is independent of battery diagnostic flag values.
It is an application-level progress checkpoint, not retirement-level
monitoring.

## 7. Verification Architecture

The battery application has a dedicated FuseSoC target:

`battery_sim`

The testbench monitors the independent RAM write interfaces of Core A
and Core B. It checks all fourteen sequence values and diagnostic
masks for each core, as well as both summary regions.

The testbench also checks:
- Safety profile selection and readback.
- DCLS enablement.
- Matching heartbeat MMIO transactions and sequence progression.
- Heartbeat service-window constraints.
- Core A and Core B result checksum equality.
- Absence of unexpected watchdog, progress, DCLS, MMIO-interlock and
  hardware fault-manager events.

The host unit tests independently exercise the diagnostic engine and
the deterministic dataset.

Detailed methods and results are recorded in
`battery_application_verification.md`.

## 8. Scope Limitations

The current workload uses deterministic software measurement data.
It does not implement:
- Physical sensor acquisition or ADC conversion.
- Cell balancing or thermal management control.
- State-of-charge or state-of-health estimation.
- Electrochemical battery modelling.
- Contactor, inverter or actuator control.
- A complete production BMS.

The numerical battery thresholds are illustrative simulation
assumptions, not product specifications or validated operating limits.

Simulation verification does not establish ISO 26262 compliance,
ASIL achievement or functional-safety certification.
