# Safety RISC-V SoC — Project Progress Tracker

**Project:** Design and FPGA-Based Prototyping of a Configurable Safety-Oriented RISC-V SoC for HV Battery Systems
**Repository:** `Safety_RISCV_SoC_Stage5`
**Active branch:** `stage5/battery-monitoring`
**Baseline commit:** `c7f2eeb` — Stage5 battery monitoring integration
**Last status update:** 2026-11-02
**FPGA target:** Digilent Arty A7-100T, Xilinx Artix-7 XC7A100T

## 1. Overall status


**Weighted project progress estimate: 62.25% (approximately 62%).**

This is a planning estimate, not a measured technical metric or a claim that the project is 62% validated. It is calculated from the work-package weights below. Implementation, simulation verification, FPGA implementation, physical-board validation and dissertation writing are scored separately so that passing simulation does not inflate hardware-readiness progress.

| Work package | Weight | Completion estimate | Weighted contribution | Status |
|---|---:|---:|---:|---|
| Requirements, scope and architecture | 10% | 90% | 9.00% | In progress — baseline established; final traceability/document review remains |
| Dual-Ibex SoC integration and local memories | 15% | 95% | 14.25% | In progress — integrated and simulated; FPGA integration remains |
| Safety mechanisms and fault management | 15% | 90% | 13.50% | In progress — DCLS, fault injection, supervisor, interlocks and containment implemented; verification breadth remains |
| HAL and battery-monitoring workload | 10% | 95% | 9.50% | Implemented and simulated — representative workload, not physical BMS acquisition |
| Simulation and verification | 15% | 80% | 12.00% | In progress — six-test regression passes; fault matrix, SVA and coverage remain |
| Vivado FPGA implementation (Arty A7-100T) | 15% | 0% | 0.00% | Pending — target fixed; complete implementation/bitstream not yet evidenced |
| FPGA board experiments and quantitative evaluation | 10% | 5% | 0.50% | Pending — no final board evidence or consolidated measured evaluation yet |
| Dissertation writing and final presentation | 10% | 35% | 3.50% | In progress — proposal/report material exists; final chapters and results pending |
| **Total** | **100%** |  | **62.25%** | **Implementation/simulation ahead of FPGA validation** |

### Visual work-package progress

The bars show each work package's own estimated completion, not its contribution to the total.

| Work package | Progress |
|---|---|
| Requirements and architecture | `█████████░` 90% |
| Dual-Ibex integration | `█████████▌` 95% |
| Safety mechanisms | `█████████░` 90% |
| HAL and battery workload | `█████████▌` 95% |
| Simulation and verification | `████████░░` 80% |
| Vivado FPGA implementation | `░░░░░░░░░░` 0% |
| Board experiments / evaluation | `▌░░░░░░░░░` 5% |
| Dissertation writing | `███▌░░░░░░` 35% |

## 2. Completed and verified baseline

### Architecture and RTL

- Two independent Ibex instances execute the same firmware image.
- Each core has its own local memory in the current Stage5 implementation.
- External transaction-level DCLS compares selected instruction/data request and response information; this is not full internal architectural-state lockstep.
- Safety infrastructure includes the DCLS comparator, fault injection, fault manager, execution supervisor, address guards, MMIO/RAM interlocks, safe-state control and diagnostic status/logging.
- The fixed FPGA target is Arty A7-100T / XC7A100T. Board-level implementation is not yet complete.

### Firmware and simulation

- Stage5 basic firmware smoke test passes on both cores.
- HAL dual-core integration passes in the Safety profile with DCLS enabled.
- Battery-monitoring workload passes with 14 sample records per core, matching checksums and diagnostic mask `0x3F`.
- Stage5D supervisor-to-MMIO and supervisor-to-RAM containment tests pass, in addition to the supervisor timeout test.
- The complete six-test regression suite passed on 2026-11-02 using Verilator 5.032 and Edalize 0.6.8.

See [`docs/stage5/stage5d_supervisor_containment_hardening.md`](docs/stage5/stage5d_supervisor_containment_hardening.md) for detailed test evidence and limitations.

## 3. Current blockers and open work

| Priority | Work item | Status | Exit evidence |
|---|---|---|---|
| High | Complete Stage5D documentation and review exact working-tree diff | In progress | Documentation reviewed; `git diff --check` clean; no unintended edits |
| High | Complete MMIO interlock mismatch/invalid-register test matrix | Pending | Directed tests for one-sided request and every relevant field mismatch |
| High | Configure Vivado project for Arty A7-100T | Pending | Reproducible project/build configuration and pin/clock constraints |
| High | Resolve/evaluate Ibex FPGA register-file mapping | Pending | Explicitly documented register-file choice; synthesis and timing results |
| High | Synthesize, implement and generate bitstream | Pending | Successful Vivado synthesis/implementation, timing and resource reports, bitstream |
| High | Program and validate Arty A7-100T | Pending | Clock/reset/IO bring-up, UART or other observable firmware output, board test record |
| Medium | Add fault injection during battery workload | Pending | Detection, response, diagnostic and recovery results captured |
| Medium | Add SVA and functional coverage | Pending | Assertions and coverage for fault/profile/containment scenarios |
| Medium | Quantitative safety-performance-cost evaluation | Pending | Reproducible latency, area, resource, timing and workload measurements |
| Medium | Clean FuseSoC/Edalize warnings | Technical debt | Core files relocated or paths corrected; supported Edalize flow adopted |
| Medium | Dissertation chapters, references, figures and results | In progress | Chapters reviewed against measured evidence and project scope |

## 4. Important interpretation constraints

- The battery workload is a representative software workload using simulated inputs; it is not a production BMS and does not demonstrate physical sensor acquisition, SOC/SOH/SOP estimation, balancing or contactor control.
- The supervisor currently receives an application-generated heartbeat for both watchdog and progress observation. Call this application-level heartbeat supervision; do not describe it as independent instruction-retirement or pipeline-progress monitoring.
- DCLS is external transaction-level comparison over selected observable interfaces, not full internal processor-state lockstep.
- Safety profiles are selected through configuration registers. No FPGA dynamic partial reconfiguration (DPR) is implemented.
- No certification, ASIL capability or ISO 26262 compliance claim is established by these simulations.
- Historical experimental FPGA figures must not be presented as final Arty A7-100T results without verifying the exact source revision, constraints and tool reports.

## 5. Progress scoring rules

Use these rules whenever the tracker is updated:

1. Score a work package only against its stated exit evidence. Code that exists but has not been built or tested should not receive the same score as a verified implementation.
2. Treat simulation and FPGA/physical validation as separate work packages. A passing Verilator test does not increase FPGA or board-validation completion.
3. A feature described as implemented must have identifiable source files and a reproducible test or build record where applicable.
4. Do not score expected results as completed results. Record measured values only with their source revision, tool version, configuration and test conditions.
5. Recalculate the overall estimate as `sum(weight × completion) / 100`. Keep the package weights fixed unless the project scope itself changes; record any change to weights in the revision history.
6. Reduce a score when a regression breaks previously passing evidence, and record the regression before increasing it again.

## 6. Update log

| Date | Update | Evidence / impact |
|---|---|---|
| 2026-11-02 | Stage5D supervisor containment hardening verified | Supervisor timeout, MMIO containment, RAM containment, Stage5 basic, HAL and battery simulations all passed. Weighted progress estimate set to 62.25%. |

## 7. Recommended next milestone

**Stage6 — FPGA platform integration on Arty A7-100T.** First establish a reproducible Vivado project, clock and pin constraints, and the Ibex register-file implementation suitable for the XC7A100T. Then run synthesis and implementation, inspect timing/resource reports, and only then program the board. Do not use earlier exploratory synthesis numbers as final project results without confirming their provenance.
