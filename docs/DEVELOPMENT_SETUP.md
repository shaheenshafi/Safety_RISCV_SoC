# Development Setup

This file records the development environment used for the dissertation.

The purpose is to keep track of what was installed, where things are located and what has been verified.

---

## 1. Main Dissertation Project

Windows project location:

    E:\Dissertation\Safety_RISCV_SoC

WSL path:

    /mnt/e/Dissertation/Safety_RISCV_SoC

Main project folders:

    rtl/
    tb/
    sw/
    data/
    constraints/
    vivado/
    docs/

The dissertation Git repository is maintained in this project directory.

---

## 2. Ibex Repository

Ibex is being used as the RISC-V processor core for the project.

The original Ibex copy was downloaded under Windows:

    C:\Users\shahe\ibex

It was also accessible from WSL through:

    /mnt/c/Users/shahe/ibex

Building directly from the Windows-mounted location caused permission/build issues.

A Linux-native working copy was therefore created at:

    /home/shaheen/src/ibex

The Linux-native copy is currently used for Ibex simulation and development.

The Ibex source is kept separate from the dissertation Git repository.

---

## 3. Python Environment

A Linux-native Python virtual environment was created for the Ibex/FuseSoC development tools.

Location:

    ~/.venvs/safety-riscv

The environment is activated when working with the current Ibex/FuseSoC setup.

---

## 4. Main Tools Verified

### Verilator

Version:

    5.032

Used for RTL simulation of the Ibex system.

---

### FuseSoC

Version:

    2.4.7

Used for building and running the Ibex Simple System.

---

### RISC-V GCC

Compiler:

    riscv32-unknown-elf-gcc

Version:

    GCC 10.2.0

The compiler is used to build software that runs on the Ibex RV32 processor.

Toolchain location:

    ~/tools/riscv32/lowrisc-toolchain-rv32imcb-20220524-1/

The toolchain `bin` directory is added to PATH.

---

### srec_cat

Version:

    1.64

Used to convert the compiled firmware binary into the VMEM memory image used by the Simple System.

---

### libelf-dev

Installed because it was required during the Ibex build.

---

### Python packaging

The Python `packaging` module was installed because it was required by the development environment.

---

## 5. Ibex Simple System

The Ibex Simple System was successfully built using FuseSoC and Verilator.

The system used for the baseline test was:

    lowrisc:ibex:ibex_simple_system

The simulation executable was generated under the Ibex build directory.

---

## 6. Baseline Firmware Test

The official Ibex Simple System `hello_test` firmware was used as the initial test.

Firmware source/build directory:

    ~/src/ibex/examples/sw/simple_system/hello_test

Build command:

    make -C examples/sw/simple_system/hello_test

The build generated:

    hello_test.vmem

The generated VMEM file was approximately 3.2 KB.

---

## 7. Baseline Simulation

The generated firmware was loaded into the Simple System simulator using:

    --raminit=examples/sw/simple_system/hello_test/hello_test.vmem

The simulation completed normally and terminated through a software request.

Last verified result:

    Executed cycles:       13268
    Cycles:                  477
    Instructions Retired:    261

This confirms that the complete baseline flow is working:

    RISC-V source
          ↓
    RISC-V GCC
          ↓
    Firmware binary
          ↓
    srec_cat
          ↓
    hello_test.vmem
          ↓
    Ibex Simple System
          ↓
    Verilator
          ↓
    Firmware execution

---

## 8. Important Note

The Ibex Simple System and `hello_test` are only being used to validate the development environment.

They are not the final dissertation system.

The next development phase will create our own SoC in:

    E:\Dissertation\Safety_RISCV_SoC

The external Ibex repository will continue to be used as the processor IP/reference.

---

## 9. Git Practice

The dissertation project is maintained using Git.

The external Ibex repository is not copied into the dissertation repository.

Generated build files, simulation outputs and tool-generated directories should not be committed unless specifically required.

The project should maintain commits at meaningful milestones, for example:

    baseline: project setup
    baseline: Ibex simulation environment validated
    feat: initial SoC integration
    feat: DCLS comparator
    feat: safety manager
    feat: fault injection
    feat: battery workload
    feat: FPGA prototype

---

## 10. Current Status

The development environment is ready.

The Ibex baseline has been successfully validated.

The next task is to inspect the Ibex Simple System architecture and begin the custom SoC implementation.