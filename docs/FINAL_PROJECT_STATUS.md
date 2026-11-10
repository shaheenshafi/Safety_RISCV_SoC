# Final Project Status and Handover

**Project:** Safety-Oriented RISC-V SoC for High-Voltage Battery Monitoring
**Status date:** 9 November 2026
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
| Standalone Vivado 50 MHz synthesis and routing | Completed |
| FuseSoC 50 MHz synthesis and route-only implementation | Completed |
| 50 MHz routed timing checks | Met; +0.013 ns setup slack |
| Historical 100 MHz timing attempt | Not met |
| Physical FPGA validation | Pending |
| Hardware fault-injection validation | Pending |

## 3. Simulation Verification

The Stage 6 regression baseline records eight passing verification
groups: six principal simulation targets and two separately executed
Stage 4F containment scenarios.

Verified scenarios include:

- Stage 5 basic SoC operation.
- Stage 5 HAL operation.
- Battery-monitoring integration.
- Supervisor timeout detection.
- Native Ibex double-fault detection.
- Response-error monitoring.
- Supervisor-to-RAM containment.
- Supervisor-to-MMIO containment.

The six principal targets are listed in
`logs/stage2_final_regression_o2_20261108/results.txt`.
The two containment scenarios have separate passing run logs in
the same evidence directory.

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
**FPGA part:** `xc7a100tcsg324-1`
**Standalone Vivado implementation workspace:** `vivado_arty_a7_50mhz`
**Independent FuseSoC build root:** `validation_stage6_50mhz/fusesoc_build/`
**Clock constraint:** 50 MHz (20 ns)

Two independent 50 MHz implementation evidence sets are retained. The standalone Vivado implementation has a separately generated bitstream whose hash is recorded below. The fresh FuseSoC target `synth_100t_50mhz` completed synthesis and routing using a controlled route-only Tcl driver. That run produced a routed DCP and reports, but no bitstream. Its checkpoint SHA-256 is `fb491c64a43ae338a8e420750c764e93e6acb7b8efd0a264cf6c1f0b684d953c`.
Both runs report +0.013 ns WNS and +0.074 ns WHS. The setup margin is minimal; it must not be interpreted as robust timing closure.

### Synthesis utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 7,409 | 63,400 | 11.69% |
| Slice registers | 4,201 | 126,800 | 3.31% |
| BRAM tiles | 8 | 135 | 5.93% |
| DSPs | 0 | 240 | 0% |

### Routed utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 7,452 | 63,400 | 11.75% |
| Slice registers | 4,201 | 126,800 | 3.31% |
| BRAM tiles | 8 | 135 | 5.93% |
| DSPs | 0 | 240 | 0% |

### Routing

- Design state: Fully Routed.
- Routable nets fully routed: 11,123 of 11,123.
- Logical nets: 13,917.
- Routing errors: 0.

### Routed timing at 50 MHz

| Metric | Result |
|---|---:|
| Clock period constraint | 20 ns |
| WNS | +0.013 ns |
| TNS | 0 ns |
| Setup failing endpoints | 0 of 8,595 |
| WHS | +0.074 ns |
| THS | 0 ns |
| Hold failing endpoints | 0 of 8,595 |
| Worst pulse-width slack | +9.500 ns |
| Pulse-width failing endpoints | 0 |

The routed setup and hold checks meet the 50 MHz constraint. The worst setup slack is only +0.013 ns; this is a small margin and does not establish the maximum achievable operating frequency or timing robustness across other conditions.

### Historical 100 MHz attempt

An earlier 100 MHz (10 ns) implementation attempt reached the Fully Routed state but failed its timing constraint:

| Metric | Historical result |
|---|---:|
| WNS | -9.178 ns |
| TNS | -21,083.062 ns |
| Setup failing endpoints | 7,000 |
| Hold failing endpoints | 0 |
| Worst hold slack | +0.037 ns |

This is historical evidence and is not the current 50 MHz implementation baseline.

## 5. Outstanding DRC and Methodology Findings

The final routed DRC report (`vivado_arty_a7_50mhz/reports/final_drc_20261109_full_reqp.rpt`) records:

| Rule | Severity | Reported entries |
|---|---|---:|
| `CFGBVS-1` | Warning | 1 |
| `CHECK-3` | Warning | 2 |
| `REQP-1839` | Warning | 2,000 |

The expanded report states that the REQP-1839 reporting limit was reached. Therefore, 2,000 is the number of entries reported in this artifact; it must not be treated as a proven exact total or an upper bound.

The BRAM findings concern asynchronous set/reset register sources in the combinational fan-in to BRAM address pin `ADDRARDADDR[14]`. Netlist connectivity investigations confirmed that the reported register Q outputs reach the corresponding BRAM address-pin fan-in cones. This does not demonstrate memory corruption or prove that a functional corruption path is sensitized during reset.

The methodology report (`vivado_arty_a7_50mhz/reports/final_methodology_20261109.rpt`) records 14 warning instances:

- `LUTAR-1`: 1 — LUT drives asynchronous reset.
- `SYNTH-6`: 8 — RAM output registers were not merged into the BRAM blocks.
- `TIMING-18`: 5 — missing input/output delays for reset and LED outputs.

The reset assessment found recovery and removal timing checks met for the inspected reset synchronizer stages in both cores. This does not prove the absence of short asynchronous reset pulses or glitch-free reset behaviour. The `LUTAR-1` warning remains a residual limitation.

No speculative configuration-voltage settings, DRC waivers, or RTL changes have been applied to suppress these findings.

## 6. Physical Validation and Limitations

The following activities remain outstanding:

1. Verify FPGA configuration-voltage properties against the official Arty A7 board documentation before assigning `CFGBVS` and `CONFIG_VOLTAGE`.
2. Resolve or formally assess the outstanding BRAM asynchronous-control DRC findings.
3. Assess timing margin beyond the current 50 MHz constraint; the maximum achievable operating frequency has not been established.
4. Review bitstream suitability for the intended board configuration. The generated artifact's SHA-256 has been verified as `561714dd1adbaf8c41d69587a7383f4f9550603208a7f0084fe2269d0ea62e83`.
5. Obtain explicit authorization before programming the physical Arty A7-100T board.
6. Validate application execution on hardware.
7. Conduct hardware-level fault-injection and containment testing.

The bitstream hash verification establishes artifact identity only. It does not establish successful programming, physical execution, hardware fault coverage, ISO 26262 certification, or production readiness.

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

The standalone Vivado 50 MHz implementation and the independent FuseSoC 50 MHz route-only implementation both completed routing, with setup and hold checks met and a worst setup slack of +0.013 ns. The FuseSoC run did not generate a bitstream. The separately generated standalone bitstream remains identified by its recorded SHA-256. An earlier 100 MHz attempt did not meet timing. Outstanding DRC findings and physical validation activities remain open.

The current deliverable should therefore be regarded as a **simulation-verified and FPGA-implemented research prototype, with 50 MHz routed timing checks met, residual DRC/reset limitations, and physical hardware validation pending**.

---
