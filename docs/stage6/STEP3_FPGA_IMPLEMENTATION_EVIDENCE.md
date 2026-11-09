# Stage 6 — Step 3: FPGA Implementation Evidence

Date: 2026-11-09
Target: Digilent Arty A7-100T
FPGA part: `xc7a100tcsg324-1`
Top module: `safety_riscv_soc_arty_a7`
Implementation workspace: `vivado_arty_a7_50mhz`
Tool: Vivado 2026.1

## 1. Purpose and scope

This document records the synthesis, routed implementation, timing, DRC, methodology, and bitstream-artifact evidence for the Stage 6 Arty A7-100T integration.

The simulation baseline is documented separately in:

`docs/stage6/STEP2_REGRESSION_BASELINE.md`

The current implementation baseline uses a 50 MHz (20 ns) primary clock constraint. An earlier 100 MHz attempt is retained as historical context and is not the current implementation baseline.

## 2. Synthesis results

Vivado synthesis completed successfully.

- Synthesis errors: 0.
- Synthesis LUT utilization: 7,409 / 63,400 (11.69%).
- Synthesis register utilization: 4,201 / 126,800 (3.31%).
- Block RAM tiles: 8 / 135 (5.93%).
- DSP utilization: 0 / 240.

These are synthesis results, not routed implementation utilization.

Detailed synthesis reports:

- `vivado_arty_a7_50mhz/reports/synthesis/utilization_synth.rpt`
- `vivado_arty_a7_50mhz/reports/synthesis/timing_summary_synth.rpt`

## 3. Placed and routed implementation

The Vivado implementation reached the Fully Routed design state for device `xc7a100tcsg324-1`.

### Routed resource utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 7,452 | 63,400 | 11.75% |
| Slice registers | 4,201 | 126,800 | 3.31% |
| Block RAM tiles | 8 | 135 | 5.93% |
| DSPs | 0 | 240 | 0% |

### Routing status

- Logical nets: 13,917.
- Nets not needing routing: 2,794.
- Routable nets: 11,123.
- Fully routed routable nets: 11,123.
- Nets with routing errors: 0.

Key implementation reports:

- `vivado_arty_a7_50mhz/reports/implementation/utilization_routed.rpt`
- `vivado_arty_a7_50mhz/reports/implementation/route_status.rpt`
- `vivado_arty_a7_50mhz/reports/implementation/clock_utilization.rpt`

The routed checkpoint is:

`vivado_arty_a7_50mhz/build/project/arty_a7_50mhz.runs/impl_1/`

## 4. Routed timing analysis — 50 MHz baseline

The primary clock constraint is 50 MHz (20 ns period).

| Metric | Routed result |
|---|---:|
| Clock period constraint | 20 ns |
| WNS | +0.013 ns |
| TNS | 0 ns |
| Setup failing endpoints | 0 of 8,595 |
| WHS | +0.074 ns |
| THS | 0 ns |
| Hold failing endpoints | 0 of 8,595 |
| WPWS | +9.500 ns |
| Pulse-width failing endpoints | 0 |

The overall design timing summary contains 12,081 endpoints. The clock-specific summary for `sys_clk_pin` contains 8,595 endpoints; the setup and hold endpoint counts above refer to that primary clock summary.

The routed setup and hold checks meet the 50 MHz constraint. The worst setup slack is only +0.013 ns, which is a very small margin. This result does not establish a validated maximum operating frequency or timing robustness across other conditions.

Detailed timing reports:

- `vivado_arty_a7_50mhz/reports/timing/timing_summary_routed.rpt`
- `vivado_arty_a7_50mhz/reports/timing/check_timing_routed_detailed.rpt`
- `vivado_arty_a7_50mhz/reports/timing/pre_bitstream_timing_audit.rpt`

### Historical 100 MHz attempt

An earlier implementation attempt used a 10 ns (100 MHz) constraint. It reached the Fully Routed state but did not meet timing:

| Metric | Historical result |
|---|---:|
| Clock period constraint | 10 ns |
| WNS | -9.178 ns |
| TNS | -21,083.062 ns |
| Setup failing endpoints | 7,000 |
| Hold failing endpoints | 0 |
| Worst hold slack | +0.037 ns |

This historical result is not the current 50 MHz implementation baseline.

## 5. Routed DRC findings

The final expanded DRC report is:

`vivado_arty_a7_50mhz/reports/final_drc_20261109_full_reqp.rpt`

Its summary reports 2,003 findings:

| Rule | Severity | Reported entries |
|---|---|---:|
| `CFGBVS-1` | Warning | 1 |
| `CHECK-3` | Warning | 2 |
| `REQP-1839` | Warning | 2,000 |

The report indicates that the `REQP-1839` reporting limit was reached. Accordingly, 2,000 is the number of entries in this report, not a proven exact total or upper bound on all findings.

### 5.1 CFGBVS-1

The configuration properties `CFGBVS` and `CONFIG_VOLTAGE` are not specified in the current design.

They have not been assigned because their correct values must first be verified against the actual Arty A7 board configuration and official board documentation.

### 5.2 REQP-1839 — RAMB36 asynchronous control

Vivado reports asynchronous set/reset register sources in the combinational fan-in of BRAM address pin `ADDRARDADDR[14]`.

The expanded report contains 2,000 reported entries. The routed-checkpoint connectivity investigation confirmed that the reported source-register Q outputs reach the corresponding BRAM address-pin fan-in cones.

This establishes netlist connectivity. It does not demonstrate memory corruption, prove a sensitized functional path during reset, or establish the occurrence of incorrect RAM reads or writes. The warning remains unresolved and is a significant technical limitation.

No RTL changes or DRC waivers have been applied to suppress the warning.

### 5.3 CHECK-3

Two `CHECK-3` warnings indicate that the DRC reporting limit was reached. The expanded report contains 2,000 `REQP-1839` entries; the exact total number of underlying BRAM findings is not established by this artifact.

## 6. Methodology findings and reset assessment

The final methodology report is:

`vivado_arty_a7_50mhz/reports/final_methodology_20261109.rpt`

It records 14 warning instances:

| Rule | Count | Description |
|---|---:|---|
| `LUTAR-1` | 1 | LUT drives asynchronous reset |
| `SYNTH-6` | 8 | RAM output register was not merged into the BRAM block |
| `TIMING-18` | 5 | Missing input/output delays |

The five `TIMING-18` warnings concern the reset input and four LED outputs. They remain documented; no unsupported interface delays have been invented to clear them.

The `LUTAR-1` warning identifies a LUT-driven asynchronous reset path to reset synchronizer stages. Recovery and removal timing checks were reported as met for the inspected stages in both cores. This does not prove the absence of short asynchronous reset pulses or glitch-free reset behaviour. The warning therefore remains a residual reset-hazard limitation.

The `SYNTH-6` warnings concern the RAM output-register implementation. They remain classified as methodology warnings; they have not been suppressed.

## 7. Bitstream artifact identity

A programming bitstream was generated separately from the routed implementation evidence documented above.

The artifact SHA-256 was independently checked against both the implementation-run `.bit` file and the FuseSoC-level `.bit` file. Both files had the same size (3,826,004 bytes) and the same SHA-256:

`561714dd1adbaf8c41d69587a7383f4f9550603208a7f0084fe2269d0ea62e83`

This records bitstream generation and artifact identity only. It does not establish that the bitstream has been validated for the board configuration, loaded onto the physical board, or used for successful hardware execution.

## 8. Limitations and final status

The current evidence establishes:

- Successful RTL synthesis.
- Successful placement and routing.
- Zero reported routing errors.
- Routed resource utilization.
- Setup and hold checks met against the 50 MHz (20 ns) constraint, with only +0.013 ns worst setup slack.
- A generated bitstream whose SHA-256 identity has been verified.
- DRC and methodology warning classification.
- Netlist connectivity evidence for the reported BRAM asynchronous-control warning.
- Recovery/removal timing checks met for the inspected reset synchronizer stages.

The current evidence does not establish:

- Timing closure at 100 MHz.
- A validated maximum operating frequency.
- Broad timing margin or robustness beyond the reported 50 MHz constraint.
- Resolution of the BRAM asynchronous-control warning.
- Glitch-free asynchronous reset behaviour.
- Validation of configuration-voltage properties.
- Physical FPGA programming or application execution.
- Hardware fault-injection performance.
- Safety certification or production readiness.

Stage 6 Step 3 — FPGA synthesis and implementation:

**IMPLEMENTATION COMPLETED; 50 MHz ROUTED TIMING CHECKS MET WITH VERY SMALL SETUP MARGIN; DRC AND RESET LIMITATIONS REMAIN OPEN.**

Physical FPGA validation remains pending.
