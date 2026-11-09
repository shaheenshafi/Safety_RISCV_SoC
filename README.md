# Configurable Safety-Oriented RISC-V SoC for HV Battery Monitoring

## 1. Project Overview

**Dissertation title:**

Design and FPGA-Based Prototyping of a Configurable Safety-Oriented RISC-V System-on-Chip for Intelligent Health Monitoring in High-Voltage Battery Systems

This project develops and evaluates a safety-oriented System-on-Chip (SoC) based on two RISC-V Ibex processor cores. The architecture integrates safety mechanisms for detecting processor execution and data-path inconsistencies, containing faults, and controlling the system's transition to a safe state.

The SoC also hosts a bare-metal battery-monitoring application intended to demonstrate the architecture in a representative high-voltage battery monitoring context.

The project progresses through RTL development, simulation-based verification, FPGA synthesis and implementation, and preparation for physical FPGA validation.

**Target FPGA platform:** Digilent Arty A7-100T
**FPGA device:** `xc7a100tcsg324-1`
**FPGA implementation tool:** Xilinx Vivado 2026.1

This is a research and prototyping project. Successful simulation and FPGA implementation do not establish functional-safety certification or production readiness.

## 2. System Architecture

The architecture uses two Ibex RISC-V processor cores with supporting safety mechanisms.

Major architectural elements include:

- **Dual-core processing:** Two Ibex processor instances execute the battery-monitoring workload.
- **Dual-Core Lockstep and comparison:** Safety comparison mechanisms monitor corresponding processor activity and detect mismatches.
- **Paired data capture:** The paired data-capture stage captures and compares processor data transactions before allowing paired RAM transactions to proceed.
- **Safety execution supervisor:** Supervises execution and monitors safety-related activity, including heartbeat and timeout conditions.
- **Fault management:** Captures and manages detected safety faults, supports sticky fault reporting, and controls safe-state activation.
- **Response-error monitoring:** Detects relevant response-path inconsistencies.
- **MMIO protection:** Uses interlocking and replicated peripheral-path mechanisms for safety-relevant memory-mapped transactions.
- **Fault injection:** Dedicated test infrastructure supports evaluation of selected fault-detection and containment mechanisms.
- **Battery-monitoring application:** Provides a representative embedded workload for the SoC.

The RTL is organized into two principal areas:

| Directory | Responsibility |
|---|---|
| `rtl/bringup/` | SoC integration, processor wrappers, platform top-levels and FPGA targets |
| `rtl/safety/` | Safety mechanisms, comparison logic, fault management and transaction protection |

The Arty A7 implementation uses the top-level module `safety_riscv_soc_arty_a7`.

## 3. Battery-Monitoring Application

The Stage 5 application provides a bare-metal workload for demonstrating the SoC with battery-monitoring data.

The firmware and platform support are maintained under:

- `sw/stage5/` — application, platform support, startup and build scripts
- `data/` — generated firmware memory images
- `docs/stage5/` — application architecture, data model, workload and verification documentation

The application includes battery data handling, monitoring functionality and verification scenarios. Generated VMEM images are used by the simulation environment.

Relevant documentation:

- [Battery application architecture](docs/stage5/battery_application_architecture.md)
- [Battery data model](docs/stage5/battery_data_model.md)
- [Battery workload specification](docs/stage5/battery_workload_spec.md)
- [Battery application verification](docs/stage5/battery_application_verification.md)
- [Platform bare-metal HAL](docs/stage5/platform_baremetal_hal.md)

## 4. Repository Structure

```text
Safety_RISCV_SoC_Stage5/
|
|-- rtl/
|   |-- bringup/          SoC integration and FPGA platform RTL
|   `-- safety/           Safety mechanism RTL
|
|-- sw/
|   `-- stage5/           Battery-monitoring firmware and platform support
|
|-- tb/                   SystemVerilog testbenches
|
|-- sim/                  Simulation harnesses
|
|-- data/                 Firmware and test VMEM images
|
|-- docs/
|   |-- stage5/           Battery application documentation
|   |-- stage6/           Regression and FPGA implementation evidence
|   `-- project_tracking/ Project tracking material
|
|-- logs/                 Simulation and FPGA implementation logs
|
|-- build/                Simulation build outputs
|
|-- vivado_build/         Vivado implementation runs and reports
|
|-- archive/              Retained historical project material
|
|-- README.md             Project overview
`-- README.txt            Historical Stage 5 double-fault package notes

## 5. Development Environment

| Tool / Technology | Purpose |
|---|---|
| Verilog | Synthesizable RTL implementation |
| SystemVerilog | Testbenches and verification assertions |
| Ibex | RISC-V processor core |
| FuseSoC | Core and build configuration management |
| Verilator | RTL simulation |
| GTKWave | Simulation waveform inspection |
| RISC-V GCC toolchain | Firmware compilation |
| Xilinx Vivado 2026.1 | FPGA synthesis and implementation |
| Digilent Arty A7-100T | Target FPGA development board |

The synthesizable design RTL is maintained in Verilog. SystemVerilog is used for verification and testbench code.

Environment and setup information is maintained in [DEVELOPMENT_SETUP.md](docs/DEVELOPMENT_SETUP.md).

## 6. Simulation and Verification Results

The Stage 6 regression baseline records eight passing verification groups:
six principal simulation targets and two separately executed Stage 4F
fault-containment scenarios.

1. Stage 5 basic SoC simulation
2. Stage 5 HAL simulation
3. Battery-monitoring integration simulation
4. Supervisor timeout detection
5. Native Ibex double-fault detection
6. Response-error monitor verification
7. Supervisor-to-RAM containment
8. Supervisor-to-MMIO containment

The six principal targets are listed in
`logs/stage2_final_regression_o2_20261108/results.txt`.
The RAM and MMIO containment scenarios are documented in their
separate run logs in the same directory.

Key recorded battery-monitoring results include:

- Core A and Core B each processed 14 records.
- Each core produced 28 result words.
- Diagnostic mask: `0x0000003F`.
- Matching checksums: `0xF7152312`.
- Stale PASS invalidation was exercised.
- 42 accepted heartbeat updates were observed.
- Final sequence: `0x0000002A`.
- Final safety fault status: NONE.

The supervisor and fault-containment tests also exercised timeout handling, RAM/MMIO containment, native Ibex double-fault detection, sticky fault capture and safe-state activation.

These results establish the recorded digital simulation baseline. They are not evidence of physical fault coverage, silicon validation or certification.

**Detailed evidence:** [Stage 6 Regression Baseline](docs/stage6/STEP2_REGRESSION_BASELINE.md)

## 7. FPGA Synthesis and Implementation

The Arty A7-100T target was synthesized and taken through placement and routing using Vivado 2026.1.

**Current implementation baseline**

- Top module: `safety_riscv_soc_arty_a7`
- FPGA part: `xc7a100tcsg324-1`
- Clock constraint: 50 MHz (20 ns)
- Implementation workspace: `vivado_arty_a7_50mhz`
- Design state: Fully Routed

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

### Routing and timing

The 50 MHz implementation reached the **Fully Routed** design state. All 11,123 routable nets were fully routed, with zero routing errors.

| Timing metric | Routed result |
|---|---:|
| Clock period constraint | 20 ns (50 MHz) |
| WNS | +0.013 ns |
| TNS | 0 ns |
| Setup failing endpoints | 0 of 8,595 |
| WHS | +0.074 ns |
| THS | 0 ns |
| Hold failing endpoints | 0 of 8,595 |
| Worst pulse-width slack | +9.500 ns |
| Pulse-width failing endpoints | 0 |

The reported setup and hold checks meet the 50 MHz constraint. The setup margin is only **+0.013 ns**, so this result should not be interpreted as evidence of broad timing margin or a validated maximum operating frequency.

### Historical 100 MHz implementation attempt

An earlier implementation attempt used a 10 ns (100 MHz) constraint. It reached the Fully Routed state but did not meet timing:

| Timing metric | Historical result |
|---|---:|
| Clock period constraint | 10 ns |
| WNS | -9.178 ns |
| TNS | -21,083.062 ns |
| Setup failing endpoints | 7,000 |
| Hold failing endpoints | 0 |
| Worst hold slack | +0.037 ns |

This is retained as historical implementation evidence; it is not the current 50 MHz baseline.

### DRC and methodology findings

The final routed DRC report records one `CFGBVS-1` warning, two `CHECK-3` reporting-limit warnings, and 2,000 reported `REQP-1839` BRAM asynchronous-control entries. The report indicates that the rule reporting limit was reached, so 2,000 is the reported count, not a proven upper bound on the total findings.

The methodology report records 14 warning instances: one `LUTAR-1`, eight `SYNTH-6`, and five `TIMING-18`. These findings remain documented and have not been waived or suppressed.

**Detailed evidence:** [Stage 6 FPGA Implementation Evidence](docs/stage6/STEP3_FPGA_IMPLEMENTATION_EVIDENCE.md)

The generated bitstream is identified by SHA-256
`561714dd1adbaf8c41d69587a7383f4f9550603208a7f0084fe2269d0ea62e83`.
Its identity has been verified, but it has not been validated on or programmed into the physical FPGA.

## 8. Known Limitations and Outstanding Validation

The following limitations remain:

- The 50 MHz routed setup margin is small (+0.013 ns); the maximum achievable operating frequency has not been established.
- The 100 MHz historical implementation attempt did not meet its timing constraint.
- The `REQP-1839` BRAM asynchronous-control DRC findings remain unresolved. The expanded report lists 2,000 entries and indicates that the reporting limit was reached.
- The `CFGBVS-1` warning remains open until configuration-voltage properties are verified against the official board documentation.
- The `LUTAR-1` reset warning remains a limitation: positive recovery/removal timing checks do not prove glitch-free asynchronous reset behaviour.
- The `SYNTH-6` and `TIMING-18` methodology warnings remain documented.
- The bitstream hash is verified, but physical FPGA programming and application execution have not been demonstrated.
- Hardware-level fault-injection and containment testing remain pending.
- No ISO 26262 certification or production-readiness claim is made.

The current evidence supports a passing digital simulation baseline, successful FPGA synthesis and routing at a 50 MHz constraint, and a generated bitstream whose hash has been verified. It does not establish physical hardware operation or safety certification.

## 9. Technical Documentation and Evidence

| Document | Description |
|---|---|
| [Development Setup](docs/DEVELOPMENT_SETUP.md) | Development environment and setup |
| [Project Progress](docs/PROGRESS.md) | Project progress record |
| [Project Tracker](docs/PROJECT_TRACKER.md) | Project tracking |
| [Stage 4F Profile Policy](docs/STAGE4F_PROFILE_POLICY.md) | Safety profile policy |
| [Stage 4G Hardening](docs/STAGE4G_HARDENING.md) | Hardening documentation |
| [Battery Application Architecture](docs/stage5/battery_application_architecture.md) | Application architecture |
| [Battery Application Verification](docs/stage5/battery_application_verification.md) | Application verification |
| [Stage 6 RTL Baseline Hashes](docs/stage6/RTL_BASELINE_SHA256.txt) | RTL baseline integrity reference |
| [Stage 6 Regression Baseline](docs/stage6/STEP2_REGRESSION_BASELINE.md) | Simulation regression evidence |
| [Stage 6 FPGA Evidence](docs/stage6/STEP3_FPGA_IMPLEMENTATION_EVIDENCE.md) | Synthesis, routing, timing and DRC evidence |

## 10. Project Status

| Area | Status |
|---|---|
| Dual-Ibex SoC RTL integration | Implemented |
| Safety mechanisms and containment RTL | Implemented |
| Battery-monitoring firmware | Implemented |
| Recorded simulation regression baseline | Passed |
| FPGA synthesis | Completed |
| FPGA placement and routing | Completed |
| 50 MHz routed timing checks | Met; +0.013 ns setup slack |
| Historical 100 MHz timing attempt | Not met |
| Physical FPGA validation | Pending |
| Hardware fault-injection validation | Pending |
| Functional-safety certification | Not established |

---

**Project scope:** Academic research and FPGA-based prototyping of a configurable safety-oriented RISC-V SoC for high-voltage battery monitoring.
