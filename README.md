# Safety-Oriented RISC-V SoC - working model

Design and FPGA prototype of a configurable safety-oriented RISC-V SoC for
representative HV-battery monitoring. Two Ibex cores run the same firmware;
external safety logic compares them, supervises progress, latches faults and
forces a safe state.

Target: Digilent Arty A7-100T (`xc7a100tcsg324-1`), Vivado 2026.1.

## Layout

| Path | Content | Language |
| --- | --- | --- |
| `rtl/soc/` | SoC top and the per-core channel (Ibex, RAM, guards) | Verilog |
| `rtl/safety/` | Comparator, capture stage, monitors, injectors, fault manager, supervisor, MMIO configuration | Verilog |
| `rtl/board/` | Arty A7 wrapper and clock/reset generation | Verilog |
| `ip/ibex/` | Ibex processor and lowRISC primitives, third-party, unchanged | SystemVerilog |
| `constraints/` | Pin and clock constraints | XDC |
| `fw/src/`, `fw/images/` | Firmware sources and memory images | C, assembly, VMEM |
| `tb/unit/`, `tb/soc/` | Self-checking testbenches | SystemVerilog |
| `tb/uvm/`, `tb/sva/` | UVM environment and assertions | SystemVerilog |
| `scripts/vivado/` | Project generator and regression runner | Tcl |
| `results/` | Evidence: regression summaries, reports, bitstream records | |
| `build/` | Generated Vivado project; safe to delete | |

## Quick start

In the Vivado Tcl Console:

    source E:/Dissertation/Working_Model_RISCV/scripts/vivado/create_project.tcl
    source E:/Dissertation/Working_Model_RISCV/scripts/vivado/run_regression.tcl

To run one test in the GUI: Sources > Simulation Sources, right-click a
simulation set, Make Active, then Flow Navigator > Run Simulation >
Run Behavioral Simulation.

See `docs/MIGRATION.md` for where each file came from.
