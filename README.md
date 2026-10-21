# Configurable Safety-Oriented RISC-V SoC for HV Battery Systems

M.Tech Embedded Systems dissertation project.

## Objective

Develop a configurable safety-oriented RISC-V SoC using Ibex, redundant
execution channels, transaction-level DCLS, selected safety mechanisms and
controlled fault injection. An HV battery monitoring workload is planned as
the representative application.

## Repository

- `rtl/` — SoC and safety RTL
- `tb/` — SystemVerilog testbenches
- `sw/` — RISC-V firmware and workloads
- `data/` — firmware images and input data
- `docs/` — progress and design documentation
- `vivado/`, `constraints/` — FPGA project and constraints

## Current Status

Stages 1–4F cover Ibex integration, redundant channels, transaction-level DCLS,
selected fault injection, fault management, safe-state reaction, runtime
profiles/MMIO interlock and application-level execution supervision.

Stage 4G adds configurable RAM depth, full-address range checking, registered
bus-error responses for guarded invalid accesses and RAM request inhibition on
DCLS mismatch or safe state. The current Stage 4E compatibility and Stage
4F/4G simulation regressions have passed.

See `docs/PROGRESS.md` for milestone status. FPGA synthesis, resource/timing
validation, bitstream generation, physical-board demonstration and the battery
monitoring workload remain outstanding. Simulation success is not evidence of
FPGA implementation or ISO 26262 certification.
