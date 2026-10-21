# Project Progress

## Project

**Title:** Design and FPGA-Based Prototyping of a Configurable Safety-Oriented RISC-V System-on-Chip for HV Battery Systems

**Research Area:** Reconfigurable Computing

---

## Current Status

Stages 1–4F have established the Ibex-based SoC, redundant execution channels,
transaction-level DCLS, selected fault injection, sticky fault management,
safe-state reaction, runtime profiles/MMIO interlock and application-level
execution supervision.

Stage 4G pre-FPGA hardening has passed the focused Verilator simulation tests. It adds configurable
RAM depth, full-address range checking, registered bus-error responses for
guarded invalid accesses, and RAM request inhibition on DCLS mismatch or safe
state. Simulation does not establish FPGA synthesis, timing closure, or hardware
operation.

## 1. Project Definition

The dissertation is focused on developing a configurable safety-oriented RISC-V SoC and validating it through FPGA prototyping and controlled fault injection.

The main idea is to use an Ibex RISC-V core as the processing element and build the safety mechanisms around it.

The HV battery system will be used as a representative automotive workload for demonstrating the safety mechanisms.

The battery monitoring application itself is not intended to be the main research contribution.

---

## 2. Literature Review

A literature review of approximately 60+ papers was completed covering:

- Functional Safety and ISO 26262
- Safety-critical processors and SoCs
- RISC-V safety
- Lockstep architectures
- Hardware redundancy
- FPGA-based validation
- Fault injection
- Runtime reconfiguration
- Battery monitoring systems

The main research gap identified is the limited evidence of a unified and reusable platform combining:

- RISC-V processing
- configurable safety mechanisms
- FPGA prototyping
- systematic fault injection
- representative automotive workload

The project will focus on implementing and evaluating such a platform.

---

## 3. Initial Safety Architecture

The current planned architecture includes:

- Ibex RISC-V Core A
- Ibex RISC-V Core B
- Dual-Core Lockstep (DCLS)
- DCLS comparator
- Safety Configuration Controller
- Watchdog
- Execution/progress timeout
- Fault Manager
- Diagnostic Fault Logger
- Safe-State Controller
- Fault indication
- Representative HV battery monitoring workload

Runtime configuration will be implemented using configuration registers/profiles.

FPGA Dynamic Partial Reconfiguration is not part of the current scope.

---

## 4. Fault Model

The initial fault-injection scope includes controlled faults such as:

- Core/register bit flip
- Memory bit flip
- Execution-control/PC corruption
- Comparator mismatch
- Execution/progress related fault

The objective is to check whether the safety mechanisms detect the fault and generate the expected response.

Detection and reaction latency will be measured where applicable.

---

## 5. Verification Approach

The planned verification approach includes:

- RTL simulation
- SystemVerilog testbench
- Self-checking tests
- SystemVerilog Assertions (SVA)
- Functional coverage
- Controlled fault injection
- FPGA-based validation

---

## 6. Quantitative Evaluation

The final system will be evaluated using measurable parameters.

### Safety

- Fault detection effectiveness
- Fault detection/reaction latency
- Correct safe-state response
- Undetected or incorrectly handled faults

### Hardware

- LUT utilization
- Flip-flop utilization
- BRAM utilization
- Maximum operating frequency
- Timing results
- Safety hardware overhead

### Performance

- Firmware execution time
- Safety mechanism overhead
- Runtime configuration overhead

A baseline configuration will be compared with safety-enabled configurations to quantify the safety, hardware and performance trade-offs.

---

## 7. Development Environment

The development environment has been successfully established using:

- Windows
- VS Code
- WSL2 / Ubuntu
- Git
- Ibex
- Verilator
- FuseSoC
- RISC-V GCC
- srec_cat
- Vivado for FPGA development

The actual dissertation project is maintained separately from the external Ibex repository.

---

## 8. Ibex Baseline Validation

A Linux-native copy of the Ibex repository was created because the initial build from the Windows-mounted filesystem resulted in permission/build issues.

Working Ibex location:

    /home/shaheen/src/ibex

The Ibex Simple System was successfully built using Verilator and FuseSoC.

The RISC-V RV32 GCC toolchain was installed and verified.

The Ibex `hello_test` firmware was successfully compiled and converted into:

    hello_test.vmem

The firmware was then loaded into the Ibex Simple System simulator.

The simulation completed normally with:

    Terminating simulation by software request.

Simulation result:

    Executed cycles:       13268
    Cycles:                  477
    Instructions Retired:    261

This confirms that the Ibex RISC-V core, simulator, firmware toolchain and memory-image flow are working.

---

## 9. Current Milestone

### Milestone 1 - Baseline RISC-V Environment Validated

Completed:

- Project structure
- Git repository
- Development environment
- Ibex setup
- Verilator setup
- FuseSoC setup
- RV32 GCC setup
- Firmware compilation
- VMEM generation
- Successful Ibex firmware execution

---

## 10. Current Stage and Next Steps

### Stage 4G — Pre-FPGA hardening

Implemented and simulation-tested:
- Configurable shared-wrapper RAM depth; Stage 4F uses 4096 words (16 KiB) per core.
- Full-address checks for RAM accesses to prevent out-of-range address aliasing.
- Registered bus-error responses and sticky fault routing for invalid guarded accesses.
- Stage 4F RAM request inhibition on DCLS mismatch or safe state.
- Stage 4E compatibility with the new wrapper interface.

Verified simulation tests:
- Stage 4F normal heartbeat integration: six heartbeat updates, both core success markers, no unexpected faults.
- Stage 4F `+supervisor_timeout_test`: supervisor fault `0x03`, sticky fault and safe state.
- Stage 4E MMIO firmware regression: nine accepted MMIO transactions, both success markers, no DCLS/interlock faults.
- Stage 4F `+address_guard_test`: valid upper boundary, below-base and above-limit checks, blocked invalid write, registered data error and fault `0x02`.
- Stage 4F `+instruction_guard_test`: invalid fetch blocked from RAM, registered instruction error and fault `0x01`.
- Stage 4F `+dcls_store_inhibit_test`: both RAM paths inhibited before the clock edge on divergent write data.

The focused Stage 4G tests use testbench-forced internal signals. They validate
address decoding, error response timing, fault routing and request inhibition;
they do not establish a full firmware-level exception flow for deliberately
invalid accesses.

### Remaining work
1. Review and commit this milestone after final source/diff checks.
2. Synthesize in Vivado and measure actual memory inference, FPGA resource use and timing.
3. Implement the representative battery monitoring workload.
4. Expand fault injection, assertions, coverage and quantitative evaluation.
5. Validate the design on the target FPGA before claiming a hardware prototype.

No FPGA synthesis, bitstream, physical-board demo, or ISO 26262 certification
has been established by the current simulation results.
