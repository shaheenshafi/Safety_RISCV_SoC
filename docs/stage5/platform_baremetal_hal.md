# Stage 5B — Bare-Metal Platform and Hardware Abstraction Layer

**Version:** 0.1
**Status:** Initial implementation and simulation verification

## 1. Objective

Define the bare-metal software foundation for Stage 5 of the
configurable safety-oriented RISC-V SoC.

This stage establishes the firmware startup sequence, linker-controlled
memory layout, reproducible firmware build process and a lightweight
Hardware Abstraction Layer (HAL) for the existing Stage 4F-compatible
MMIO safety interface.

The platform is intended to support the subsequent battery-monitoring
application without coupling its diagnostic logic to the underlying
hardware register implementation.

## 2. Software Architecture

The Stage 5 software is organized into the following components:

| Component | Location | Responsibility |
|---|---|---|
| Startup | `sw/stage5/startup/` | Stack initialization, BSS clearing and entry to `main()` |
| Linker | `sw/stage5/linker/` | Application, stack and result memory placement |
| Platform HAL | `sw/stage5/platform/` | MMIO register access and platform services |
| Smoke test | `sw/stage5/apps/smoke_test/` | Startup and memory initialization verification |
| HAL test | `sw/stage5/apps/hal_test/` | Profile selection and heartbeat integration |
| Build scripts | `sw/stage5/` | Reproducible firmware compilation and VMEM generation |

The firmware is bare-metal C and assembly targeting RV32IM with
the ILP32 ABI. Synthesizable hardware remains implemented in Verilog.
SystemVerilog is used for simulation and verification.

Both processor cores execute the same firmware image using their
independent instruction and data memories.

## 3. Memory Layout

The firmware uses the existing 16 KiB RAM address space of each core.

| Region | Start address | Length | Purpose |
|---|---:|---:|---|
| Application RAM | `0x00100000` | `0x3000` | Code, read-only data, initialized data and BSS |
| Stack RAM | `0x00103000` | `0x0FC0` | Runtime stack |
| Result RAM | `0x00103FC0` | `0x0040` | Firmware/test result markers |

The exclusive upper boundary of the complete RAM address range is
`0x00104000`.

The firmware entry point is placed at `0x00100080`, consistent with
the Ibex boot-vector convention used by this SoC.

The stack top is `0x00103FC0`, aligned to 16 bytes. The stack grows
downward within the stack region. The result region begins at the
stack-top boundary and is reserved for application/test results.

## 4. Startup Sequence

The startup routine is implemented in:

`sw/stage5/startup/start.S`

The `_start` routine performs the following operations:

1. Initializes the stack pointer using `__stack_top`.
2. Obtains the beginning and end addresses of the BSS section.
3. Clears the BSS region to zero using word stores.
4. Calls the application entry point `main()`.
5. Enters an infinite loop if `main()` returns.

The startup routine does not copy initialized data from a separate
load address. The initialized `.data` contents are included in the
memory initialization image and loaded into RAM by the simulation
memory initialization mechanism.

The BSS section is marked `NOLOAD` in the linker script and is
initialized by the startup routine.

## 5. Linker Configuration

The linker script is implemented in:

`sw/stage5/linker/stage5.ld`

It defines three memory regions:

- `RAM_APP`: application code and data.
- `RAM_STACK`: runtime stack.
- `RAM_RESULT`: result markers and test observations.

The `.text` output section begins at `ORIGIN(RAM_APP) + 0x80`.
The startup routine is retained at the beginning of this section using
`KEEP(*(.text.init))`.

The linker script exports the following symbols:

| Symbol | Purpose |
|---|---|
| `__stack_bottom` | Start of stack region |
| `__stack_top` | Initial stack pointer |
| `__result_start` | Start of result region |
| `__result_end` | Exclusive end of result region |
| `__bss_start` | Start of BSS |
| `__bss_end` | Exclusive end of BSS |
| `__image_end` | End of application image |

Linker assertions check that:

1. The application image does not exceed application RAM.
2. The stack top is 16-byte aligned.
3. BSS does not extend beyond the application image.
4. The firmware entry section begins at the boot address plus `0x80`.

## 6. Firmware Build and Memory Image Generation

The firmware build uses the RISC-V GCC toolchain with the following
target configuration:

| Option | Purpose |
|---|---|
| `-march=rv32im` | RV32IM instruction-set architecture |
| `-mabi=ilp32` | 32-bit integer calling convention |
| `-mcmodel=medany` | Medium-any code model |
| `-msmall-data-limit=0` | Disable small-data section optimization |
| `-ffreestanding` | Freestanding firmware environment |
| `-fno-builtin` | Disable compiler assumptions about library built-ins |
| `-nostdlib -nostartfiles` | Use the project startup and no hosted runtime |

The linker uses `sw/stage5/linker/stage5.ld`.
The firmware is converted from ELF to a binary image using
`riscv32-unknown-elf-objcopy`.

The binary is converted to a 32-bit VMEM image using `srec_cat` with
a byte offset of `0x80` and four-byte word swapping.

The offset is essential: the VMEM image must place the first firmware
instruction at word index `0x20`, corresponding to CPU address
`0x00100080`.

Two reproducible build scripts are provided:

| Script | Output |
|---|---|
| `sw/stage5/build_smoke_test.sh` | Smoke-test ELF, BIN, MAP and VMEM |
| `sw/stage5/build_hal_test.sh` | HAL-test ELF, BIN, MAP and VMEM |

Generated build artifacts are stored under `sw/stage5/build/`,
which is excluded from version control.

Each build script checks the ELF entry point and compares its generated
VMEM against the corresponding reference image under `data/`.
The reference images are not overwritten by these scripts.

## 7. Platform MMIO Register Map

The HAL provides access to the existing Stage 4F-compatible MMIO
interface. The register base address is `0x00200000`.

| Register | Address | Access | Description |
|---|---:|---|---|
| Profile control | `0x00200000` | Read/write | Selects the operating profile |
| Injection authorization | `0x00200004` | Read/write | Controls diagnostic fault-injection authorization |
| Profile status | `0x00200008` | Read-only | Reports profile and policy status |
| Fault status | `0x0020000C` | Read-only | Reports sticky fault status and fault code |
| Heartbeat sequence | `0x00200010` | Read/write | Stores the latest heartbeat sequence |

The implemented profile encodings are:

| Encoding | Profile |
|---|---|
| `0b00` | Basic |
| `0b01` | Safety |
| `0b10` | Diagnostic |
| `0b11` | Reserved |

The profile-status register has the following fields:

| Bit(s) | Meaning |
|---|---|
| `[1:0]` | Selected profile |
| `2` | Profile valid |
| `3` | DCLS enabled |
| `4` | Fault injection enabled |

The fault-status register has the following fields:

| Bit(s) | Meaning |
|---|---|
| `0` | Fault latched |
| `1` | Instruction fault observed |
| `2` | Data fault observed |
| `3` | Supervisor fault observed |
| `[15:8]` | Fault code |

All other documented status bits are reserved or zero in the
current implementation.

## 8. Heartbeat and Execution Supervision Protocol

The heartbeat register is located at `0x00200010`.

A heartbeat update is accepted only when all of the following conditions
are satisfied:

1. The MMIO request is accepted by the peripheral.
2. The transaction is a write.
3. All four byte enables are asserted (`be = 4'b1111`).
4. Safe state is not active.
5. The supplied 32-bit sequence value differs from the previously
   stored heartbeat value.

The redundant-core MMIO interlock requires both processor cores to
request the same valid MMIO transaction. For writes, the address,
write direction, byte enables and write data must match. Only a matched
transaction reaches the shared MMIO peripheral.

Consequently, both cores must execute the same heartbeat operations
in the same order. The heartbeat service must not be implemented as
an independent Core A-only operation.

The accepted heartbeat update drives both the watchdog kick and the
execution-progress event inputs of the supervisor.

The Stage 4F supervisor configuration used by Stage 5 has these
parameters:

| Parameter | Configured value |
|---|---:|
| `MIN_KICK_CYCLES` | 4 |
| `MAX_KICK_CYCLES` | 256 |
| `PROGRESS_TIMEOUT_CYCLES` | 256 |

The watchdog detects early service and missing or late service.
Progress supervision independently detects the absence of a valid
progress event. Supervisor faults are sticky until reset.

The supervisor is enabled whenever the selected profile is valid and
safe state is inactive. Basic is a valid profile after reset; therefore,
supervision is active before firmware explicitly selects Safety.

Firmware must generate its first valid heartbeat within the initial
supervision window and continue servicing it within the configured
window. Selecting Safety does not restart the supervisor timer.

The HAL initializes its local sequence from the current heartbeat
register value and then writes an incremented value. Subsequent service
calls increment the sequence before performing a full-word MMIO write.

The HAL does not enforce heartbeat scheduling automatically. The
application is responsible for calling the heartbeat service at a
frequency compatible with the hardware supervision window.

## 9. Platform HAL API

The HAL is implemented in:

- `sw/stage5/platform/platform.h`
- `sw/stage5/platform/platform.c`

The interface currently provides:

| API | Function |
|---|---|
| `platform_profile_select()` | Writes a requested profile and checks profile readback and policy status |
| `platform_profile_status_read()` | Reads the profile-status register |
| `platform_fault_status_read()` | Reads the fault-status register |
| `platform_heartbeat_value_read()` | Reads the stored heartbeat sequence |
| `platform_heartbeat_start()` | Initializes the software sequence and generates the first heartbeat |
| `platform_heartbeat_kick()` | Increments the sequence and writes the new value |

`platform_profile_select()` rejects unsupported profile values. It
checks the selected-profile readback and profile-valid status. For
Safety and Diagnostic profiles, it also checks that DCLS is enabled.

The header defines the injection-authorization register address and
the relevant status masks. A separate public fault-injection
authorization API is not implemented in this initial HAL.

The implementation uses volatile 32-bit MMIO accesses. It does not
provide an operating system, interrupt framework, dynamic memory
allocator or peripheral-driver framework.

## 10. Implementation and Simulation Verification

The following verification activities were completed.

### 10.1 Startup and Smoke-Test Firmware

The smoke-test application uses initialized data and zero-initialized
BSS variables. It checks their startup values, performs a simple
integer calculation and writes the result to the reserved result
address in each core's RAM.

Observed result:

| Check | Result |
|---|---|
| ELF entry point | `0x00100080` |
| Core A result | `0x0000000C` |
| Core B result | `0x0000000C` |
| Simulation cycles observed | 56 |
| Selected profile | Basic |
| DCLS enabled | No |
| Illegal decode/exception observations | None |
| Safety fault | None |

Simulation result: `STAGE 5 C FIRMWARE SMOKE TEST: PASS`.

### 10.2 HAL Compilation

The HAL was compiled independently for RV32IM/ILP32 with
`-Wall -Wextra -Werror`.

The generated object was inspected to verify the expected 32-bit
load and store operations for the MMIO registers.

The HAL integration firmware was linked with the Stage 5 startup
and linker configuration.

Observed HAL firmware properties:

| Property | Result |
|---|---:|
| ELF entry point | `0x00100080` |
| Text size | 720 bytes |
| Data size | 0 bytes |
| BSS size | 4 bytes |
| Total ELF section size | 724 bytes |

### 10.3 Dual-Core HAL Integration

A separate HAL integration firmware image and simulation target were
created:

- Firmware: `sw/stage5/apps/hal_test/main.c`
- Testbench: `tb/safety_riscv_soc_stage5_hal_tb.sv`
- Simulation runner: `sim/safety_riscv_soc_stage5_hal_main.cpp`
- FuseSoC target: `hal_sim`

The testbench checks the profile readback markers, matching heartbeat
transactions from both cores, sequence progression, heartbeat timing
and the absence of safety events.

Observed result:

| Check | Result |
|---|---:|
| Core A Safety profile | Confirmed |
| Core B Safety profile | Confirmed |
| Profile status | `0x0000000D` |
| Accepted heartbeat updates | 6 |
| Final heartbeat sequence | `0x00000006` |
| Simulation cycles observed | 1,200 |
| DCLS enabled | Yes |
| Injection enabled | No |
| Watchdog early-service fault | None |
| Watchdog timeout fault | None |
| Progress timeout fault | None |
| MMIO interlock fault | None |
| DCLS mismatch | None |

Simulation result: `STAGE5 HAL DUAL-CORE INTEGRATION: PASS`.

The testbench verifies that the first heartbeat arrives within the
initial 256-cycle limit and subsequent accepted heartbeat intervals
fall within the configured 4-to-256-cycle service window.

### 10.4 Regression Verification

After adding the HAL integration target, the original smoke-test
target was executed again without modification.

Both independent simulations passed:

- `sim`: original C firmware smoke test.
- `hal_sim`: dual-core HAL and heartbeat integration.

## 11. Current Implementation Limitations

The following limitations apply to the present Stage 5B implementation:

1. Verification is based on RTL simulation using Verilator. It is not
   evidence of complete FPGA hardware validation.
2. The current HAL integration test exercises profile selection,
   status readback and heartbeat service. It does not validate the
   complete battery-monitoring application.
3. The heartbeat is an application-level progress checkpoint.
   It is not an instruction-retirement monitor or a complete
   execution-equivalence mechanism.
4. The current DCLS implementation compares observable processor
   transactions and responses; it does not compare all internal
   processor state.
5. The software must maintain the heartbeat service schedule. The
   HAL does not independently guarantee that calls occur within
   the hardware supervision window.
6. No physical sensor acquisition, ADC interface, contactor control,
   actuator safe-state output, or battery-management hardware is
   implemented by this HAL.
7. Simulation results do not establish ISO 26262 compliance,
   certification, or an Automotive Safety Integrity Level (ASIL).

## 12. Completion Criteria

The initial Stage 5B implementation is considered complete when:

- The startup and linker configuration are reproducible.
- The smoke-test firmware builds and passes simulation.
- The platform HAL compiles for RV32IM/ILP32.
- The HAL integration firmware builds reproducibly.
- Both cores select and verify the Safety profile.
- Both cores generate matching, changing heartbeat transactions.
- The configured watchdog and progress supervision remain fault-free
  during the demonstrated simulation interval.
- The original smoke-test regression remains passing.

All listed implementation and simulation criteria have been
demonstrated in the current Stage 5B worktree.
