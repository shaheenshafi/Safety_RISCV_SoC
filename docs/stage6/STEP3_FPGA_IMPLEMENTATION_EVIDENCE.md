# Stage 6 — Step 3: FPGA Implementation Evidence

Date: 2026-11-08
Target: Digilent Arty A7-100T
FPGA part: xc7a100tcsg324-1
Top module: safety_riscv_soc_arty_a7
Implementation run: arty_a7_timing_opt2
Tool: Vivado 2026.1

## 1. Purpose

This document records the synthesis and FPGA implementation results
for the Stage 6 Arty A7-100T integration.

The simulation baseline is documented separately in:

`docs/stage6/STEP2_REGRESSION_BASELINE.md`

## 2. Synthesis results

Vivado synthesis completed successfully.

- Synthesis run: completed.
- Synthesis errors: 0.
- Synthesis warnings: 3.
- Synthesis exit code: 0.
- Synthesis LUT utilization: 7,509 / 63,400 (11.84%).
- Synthesis register utilization: 4,202 / 126,800 (3.31%).
- Block RAM tiles: 8 / 135 (5.93%).
- DSP utilization: 0 / 240.

These are synthesis results, not routed implementation utilization.

## 3. Placed and routed implementation

The Vivado implementation run reached the Fully Routed design state.

Placed resource utilization:

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| Slice LUTs | 7,839 | 63,400 | 12.36% |
| Slice registers | 4,202 | 126,800 | 3.31% |
| DSPs | 0 | 240 | 0% |

Routing status:

- Fully routed nets: 11,205.
- Nets with routing errors: 0.
- Routed checkpoint:
  `safety_riscv_soc_arty_a7_routed.dcp`

The implementation completed routing, but this does not establish
timing closure or successful physical FPGA operation.

## 4. Routed timing analysis

The primary clock constraint is 100 MHz (10 ns period).

Routed timing results:

| Metric | Result |
|---|---:|
| Worst negative slack (WNS) | -9.178 ns |
| Total negative slack (TNS) | -21,083.062 ns |
| Setup failing endpoints | 7,000 |
| Hold failing endpoints | 0 |
| Worst hold slack | +0.037 ns |
| Hold total violation | 0 ns |
| Setup timing status | NOT MET |

The routed implementation does not meet the 100 MHz timing constraint.
The existence of a routed checkpoint must not be interpreted as timing
closure or as evidence of an achievable operating frequency.

Timing optimization is outside the scope of this implementation
evidence record.

## 5. Routed design rule checks

The routed DRC report records:

| Rule | Severity | Count |
|---|---|---:|
| CFGBVS-1 | Warning | 1 |
| CHECK-3 | Warning | 2 |
| REQP-1839 | Warning | 21 |

### 5.1 CFGBVS-1

The configuration bank voltage properties CFGBVS and CONFIG_VOLTAGE
are not specified in the current design.

These properties have not been assigned because the correct values
must first be verified against the board configuration documentation.

### 5.2 REQP-1839 — RAMB36 asynchronous control

Vivado reports asynchronous set/reset register sources in the
combinational fan-in of BRAM address control pin ADDRARDADDR[14].

The routed report contains 21 source-register entries:
- Core A: word 10, bit 0.
- Core B: word 10, bits 0, 1, and 10 through 27.

A routed-checkpoint connectivity investigation confirmed that all
21 reported register Q outputs reach their corresponding BRAM
ADDRARDADDR[14] pin through the netlist fanout cone.

This establishes netlist connectivity. It does not demonstrate
memory corruption, prove a sensitized functional path during reset,
or establish the occurrence of incorrect RAM reads or writes.

The warning remains open for a dedicated reset-behaviour assessment.
No RTL changes have been made to suppress the warning.

### 5.3 CHECK-3

The report indicates that the REQP-1839 reporting limit was reached.
The DRC summary lists 21 REQP-1839 warnings.

## 6. Evidence locations

Implementation run directory:

`vivado_build/arty_a7_timing_opt2/`

Key report artifacts:
- `safety_riscv_soc_arty_a7_utilization_placed.rpt`
- `safety_riscv_soc_arty_a7_timing_summary_routed.rpt`
- `safety_riscv_soc_arty_a7_route_status.rpt`
- `safety_riscv_soc_arty_a7_drc_routed.rpt`
- `safety_riscv_soc_arty_a7_routed.dcp`

The files are located under the corresponding Vivado `impl_1`
run directory.

## 7. Limitations

The current evidence establishes:
- Successful RTL synthesis.
- Successful placement and routing.
- Zero reported routing errors.
- Routed design resource utilization.
- Routed timing analysis results.
- DRC warning classification and register-to-BRAM connectivity.

The current evidence does not establish:
- Timing closure at 100 MHz.
- A validated maximum operating frequency.
- Resolution of the BRAM asynchronous-control warning.
- Physical FPGA execution.
- Hardware fault-injection performance.
- Safety certification or production readiness.

No bitstream generation or FPGA programming is included in this
implementation evidence.

## 8. Final status

Stage 6 Step 3 — FPGA synthesis and implementation:
IMPLEMENTATION COMPLETED; TIMING NOT MET.

The design has a fully routed implementation checkpoint, with
outstanding timing and DRC concerns.

Physical FPGA validation remains pending.
