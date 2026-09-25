# Project Progress

## Project

**Title:** Design and FPGA-Based Prototyping of a Configurable Safety-Oriented RISC-V System-on-Chip for HV Battery Systems

**Research Area:** Reconfigurable Computing

---

## Current Status

The project definition and initial development environment setup are completed.

The baseline Ibex RISC-V environment has been successfully built and tested. RISC-V firmware was compiled, converted to a VMEM image and successfully executed on the Ibex Simple System using Verilator.

The actual dissertation SoC implementation is the next major phase.

---

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

## 10. Next Major Step

The next phase is to start the actual dissertation implementation.

The first step will be to study the Ibex Simple System structure and identify the minimum components required to create our own SoC.

After that, the implementation will proceed incrementally:

1. Custom SoC top level
2. Ibex integration
3. Memory and basic interfaces
4. Second Ibex core
5. DCLS comparator
6. Safety Manager
7. Watchdog
8. Execution/progress timeout
9. Fault logger
10. Safe-State Controller
11. Safety configuration
12. Battery monitoring workload
13. Fault injection
14. Verification
15. FPGA implementation
16. Quantitative evaluation

---

## Current Position

**The baseline processor environment is working.**

**The actual safety-oriented SoC implementation has not started yet.**