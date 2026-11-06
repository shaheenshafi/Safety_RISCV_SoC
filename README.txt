STAGE5 PRIORITY 2 - STAGE 2
Native Ibex double-fault generation test

PURPOSE
-------
This is an additive simulation-only package. It does not modify the existing
Stage4F/Stage5 RTL, firmware, Arty wrapper, external Ibex repository, or Vivado
project.

It adds a dedicated FuseSoC target that executes a real nested synchronous
exception on each Ibex core, one core at a time. The other core is held in reset
by the testbench so the first event cannot reset the second core before it is
independently tested.

STIMULUS
--------
The test-only RISC-V image starts at 0x00100080. It writes mtvec to
0x00100100, executes ECALL (the first machine-mode synchronous exception),
then the trap handler at 0x00100100 immediately executes another ECALL before
MRET. Ibex defines a synchronous exception occurring while handling a previous
synchronous exception as a double fault. Its double_fault_seen_o output is a
one-cycle pulse.

The testbench observes the actual output pin from each Ibex wrapper. It does
not force or deposit that output. It then verifies the SoC sticky capture,
fault code 0x04, safe-state activation and external-reset clearing.

FILES ADDED
-----------
data/stage4f_native_double_fault.vmem
sw/stage4f_native_double_fault.S
sw/stage4f_native_double_fault.ld
rtl/bringup/safety_riscv_soc_stage4f_native_double_fault.core
tb/safety_riscv_soc_stage4f_native_double_fault_tb.sv
sim/safety_riscv_soc_stage4f_native_double_fault_main.cpp

INSTALLATION
------------
1. Download Stage5_Ibex_Native_DoubleFault_Stage2.zip to Windows Downloads.
2. Run the installer command supplied in the ChatGPT response from WSL.
3. Run git diff --check and git status --short.
4. Run the dedicated FuseSoC simulation target supplied in the response.

No existing source files are overwritten. The installer checks SHA-256
baselines for the current wrapper/top/fault-manager RTL before adding files.

LIMITATIONS
-----------
This is a directed digital simulation of the Ibex exception mechanism and the
SoC capture/containment path. It is not a fault-injection campaign, silicon
fault-coverage claim, or ISO 26262 certification result. The supplied VMEM is
checked at key word addresses by the testbench. The assembly and linker script
are included as the documented stimulus source.
