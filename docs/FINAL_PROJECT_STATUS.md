# Final Project Status and Handover

**Project:** Safety-Oriented RISC-V SoC for High-Voltage Battery Monitoring
**Status date:** 8 November 2026
**Target platform:** Digilent Arty A7-100T
**FPGA device:** `xc7a100tcsg324-1`

## 1. Project Objective

The project develops and evaluates a configurable safety-oriented RISC-V System-on-Chip using dual Ibex processor cores.

The architecture integrates processor comparison, paired data capture, safety supervision, fault detection and containment, and a bare-metal battery-monitoring application.

The work covers RTL development, simulation-based verification, FPGA synthesis and implementation, and preparation for physical FPGA validation.

## 2. Implementation Status

| Work area | Status |
|---|---|
| Dual-Ibex SoC integration | Implemented |
| Safety mechanism RTL | Implemented |
| Paired data-capture integration | Implemented |
| Safety supervisor and fault management | Implemented |
| MMIO and RAM fault containment | Implemented |
| Battery-monitoring firmware | Implemented |
| Simulation regression baseline | Passed |
| Arty A7 synthesis | Completed |
| FPGA placement and routing | Completed |
| 100 MHz timing closure | Not met |
| Physical FPGA validation | Pending |
| Hardware fault-injection validation | Pending |

## 3. Simulation Verification

The Stage 6 regression baseline records eight passing regression groups.

Verified scenarios include:

- Stage 5 basic SoC operation.
- Stage 5 HAL operation.
- Battery-monitoring integration.
- Supervisor RAM and MMIO containment.
- Supervisor timeout detection.
- Native Ibex double-fault detection.
- Response-error monitoring.
- Safety fault capture and safe-state containment.

### Battery-monitoring results

- Core A processed 14 records.
- Core B processed 14 records.
- Each core produced 28 result words.
- Diagnostic mask: `0x0000003F`.
- Matching checksums: `0xF7152312`.
- Stale PASS invalidation was exercised.
- Accepted heartbeat updates: 42.
- Final sequence: `0x0000002A`.
- Final safety fault status: NONE.

These are digital simulation results. They do not establish physical fault coverage or hardware validation.

**Evidence:** [Stage 6 Regression Baseline](stage6/STEP2_REGRESSION_BASELINE.md)

## 4. FPGA Implementation Results

**Tool:** Xilinx Vivado 2026.1
**Top module:** `safety_riscv_soc_arty_a7`
**Implementation run:** `arty_a7_timing_opt2`
**Clock constraint:** 100 MHz (10 ns)

### Synthesis utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUTs | 7,509 | 63,400 | 11.84% |
| Registers | 4,202 | 126,800 | 3.31% |
| BRAM tiles | 8 | 135 | 5.93% |
| DSP | 0 | 240 | 0% |

### Placed utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUTs | 7,839 | 63,400 | 12.36% |
| Slice registers | 4,202 | 126,800 | 3.31% |
| DSP | 0 | 240 | 0% |

### Routing

- Design state: Fully Routed.
- Routable nets fully routed: 11,205.
- Routing errors: 0.

### Routed timing

| Metric | Result |
|---|---:|
| Clock period constraint | 10 ns |
| WNS | -9.178 ns |
| TNS | -21,083.062 ns |
| Setup failing endpoints | 7,000 |
| Hold failing endpoints | 0 |
| Worst hold slack | +0.037 ns |

**Timing constraints are not met.**

The 100 MHz clock is a design constraint, not a demonstrated operating frequency. The maximum achievable operating frequency has not been established.

## 5. Outstanding DRC Findings

The routed DRC report records:

- One `CFGBVS-1` warning concerning missing configuration-voltage properties.
- Two `CHECK-3` warnings concerning reporting limits.
- Twenty-one `REQP-1839` warnings concerning asynchronous-control signals in the fan-in to BRAM address pins.

The BRAM findings were investigated at the netlist connectivity level. The identified source-register Q outputs reach the corresponding BRAM address-pin fan-in cones. This does not demonstrate memory corruption or establish the behaviour under every reset condition.

No speculative voltage-property settings or RTL changes have been made to suppress these findings.

The warnings remain documented for appropriate follow-up assessment.

## 6. Physical Validation and Limitations

The following activities remain outstanding:

1. Verify FPGA configuration-voltage properties against the official Arty A7 board documentation.
2. Assess the outstanding BRAM asynchronous-control DRC warnings.
3. Establish a suitable timing target and achieve timing closure if required.
4. Generate and review a programming bitstream.
5. Program the physical Arty A7-100T board.
6. Validate application execution on hardware.
7. Conduct hardware-level fault-injection and containment testing.

No physical FPGA execution, hardware fault-injection campaign, ISO 26262 certification, or production-readiness claim is established by the current evidence.

## 7. Evidence and Documentation Index

| Document | Purpose |
|---|---|
| [Project README](../README.md) | Main project overview |
| [Development Setup](DEVELOPMENT_SETUP.md) | Development environment |
| [Stage 5 Application Architecture](stage5/battery_application_architecture.md) | Battery application architecture |
| [Stage 5 Application Verification](stage5/battery_application_verification.md) | Application verification |
| [Stage 6 RTL Baseline Hashes](stage6/RTL_BASELINE_SHA256.txt) | RTL baseline integrity |
| [Stage 6 Regression Baseline](stage6/STEP2_REGRESSION_BASELINE.md) | Simulation evidence |
| [Stage 6 FPGA Implementation Evidence](stage6/STEP3_FPGA_IMPLEMENTATION_EVIDENCE.md) | Synthesis, routing, timing and DRC evidence |

## 8. Final Handover Statement

The project has established a dual-Ibex safety-oriented SoC implementation, a battery-monitoring firmware workload, a recorded passing digital simulation regression baseline, and a completed FPGA synthesis and routed implementation attempt for the Arty A7-100T.

The FPGA implementation is fully routed, but the applied 100 MHz timing constraint is not met. Outstanding DRC findings and physical validation activities remain open.

The current deliverable should therefore be regarded as a **simulation-verified and FPGA-implemented research prototype, pending timing assessment and physical hardware validation**.

---
