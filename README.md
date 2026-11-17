# Safety-Oriented RISC-V SoC

A configurable safety-oriented RISC-V system-on-chip, prototyped on a Digilent
Arty A7-100T FPGA. Two unmodified Ibex cores run the same battery-monitoring
firmware in lockstep. Safety logic outside the cores compares their bus
activity every clock cycle, supervises program progress, latches the first
fault and forces a safe state. Faults can be injected from the board buttons
to show the detection working on hardware.

M.Tech dissertation project, 2026. Tool: Vivado 2026.1 (XSim for simulation).
Device: `xc7a100tcsg324-1`. System clock: 40 MHz.

## Architecture

```
            +-----------+     +---------+
 firmware ->| Ibex A    |<--->| RAM A   |      MMIO configuration (two replicas)
 (.vmem)    +-----------+     +---------+      profile, injection authorisation,
                  | bus signals                heartbeat, fault status
                  v
            +---------------------+     +---------------------+
            | lockstep comparator |---->| fault manager       |--> safe state
            | response monitor    |     | (first fault, code) |--> diagnostic log
            +---------------------+     +---------------------+
                  ^                               ^
                  | bus signals                   |
            +-----------+     +---------+   +----------------------+
 firmware ->| Ibex B    |<--->| RAM B   |   | execution supervisor |
 (.vmem)    +-----------+     +---------+   | (watchdog, timeout)  |
                                            +----------------------+
```

Each core has its own 16 KiB RAM at `0x0010_0000`, initialised from the same
memory image. The comparator sees only what the cores drive on their
instruction and data buses: requests, addresses, write enable, write data and
error responses. Ibex itself is not changed.

## Safety mechanisms

| Mechanism | Module | Fault code |
| --- | --- | --- |
| Instruction-channel lockstep comparison | `dcls_comparator` | `01` |
| Data-channel lockstep comparison | `dcls_comparator`, `dcls_paired_data_capture_stage` | `02` |
| Windowed watchdog and progress timeout on the firmware heartbeat | `safety_execution_supervisor` | `03` |
| Ibex double-fault indication of either core | Ibex output, taken by the fault manager | `04` |
| Configuration integrity (value against stored complement) | `safety_mmio_config_stage4f` | `05` |
| Configuration replica comparison | two instances of `safety_mmio_config_stage4f` | `06` |

The fault manager (`safety_fault_manager_stage4f`) latches the first fault and
its code until reset and requests the safe state, in which RAM and MMIO writes
are blocked. The diagnostic logger keeps the last four fault records through a
system reset.

## Runtime profiles

Selected by the firmware through `PROFILE_CTRL`; on the board the firmware
follows switches SW1:SW0.

| Profile | Lockstep comparison | Watchdog, logging, safe state | Fault injection |
| --- | --- | --- | --- |
| Basic (`00`) | off | on | not permitted |
| Safety (`01`) | on | on | not permitted |
| Diagnostic (`10`) | on | on | permitted |

## Register map (base `0x0020_0000`)

| Offset | Register | Access |
| --- | --- | --- |
| `0x00` | `PROFILE_CTRL` | read/write |
| `0x04` | `INJECTION_AUTH` | read/write |
| `0x08` | `PROFILE_STATUS` | read |
| `0x0C` | `FAULT_STATUS` | read |
| `0x10` | `HEARTBEAT` | read/write |
| `0x14` | `BOARD_CTRL` (SW1:SW0) | read |

## Firmware

`fw/src/stage5/apps/battery_monitor` checks fourteen battery samples (pack
voltage, current, temperature) against under/over-voltage, charge/discharge
over-current and temperature limits, writes a result record per sample and a
checksum, and updates the heartbeat. The samples are a fixed data set compiled
into the image; there is no sensor interface. Smaller images (`hal_test`,
`smoke_test`, two assembly tests) are used by individual simulations.

The firmware is built with `riscv32-unknown-elf-gcc` (`-march=rv32im`) and
converted to a `.vmem` image that initialises both RAMs. Prebuilt images are
in `fw/images/`, so the toolchain is needed only to change the firmware:

    bash fw/build_demo.sh

## Results of the baselined run (17 Nov 2026)

| Item | Result |
| --- | --- |
| Behavioural regression | 32 of 32 simulation sets pass |
| Timing at 40 MHz | met; setup slack 1.513 ns, hold slack 0.077 ns |
| Utilization | 8,350 LUT, 4,823 flip-flops, 8 block RAM |
| One Ibex core | about 3,670 LUT, 2,010 flip-flops |
| Safety logic outside the cores | 336 LUT, 376 flip-flops |
| Power (vectorless estimate) | 0.244 W total, 0.146 W dynamic |
| Run time of the battery workload | Basic 1,284 cycles, Safety 1,522 (+18.5 %), Diagnostic 1,523 |
| Board demonstration | six injected faults, all detected and reported |

Reports, logs, screenshots and the serial capture are under `results/`; see
`results/README.md`.

## Repository layout

| Path | Content | Language |
| --- | --- | --- |
| `rtl/soc/` | SoC top and the per-core channel (Ibex, RAM, guards) | Verilog |
| `rtl/safety/` | Comparator, capture stage, monitors, injectors, fault manager, supervisor, logger, MMIO configuration | Verilog |
| `rtl/board/` | Arty A7 wrapper, clock and reset, debounce, injection control, UART status reporter | Verilog |
| `ip/ibex/` | Ibex processor and lowRISC primitives, third-party, unchanged | SystemVerilog |
| `constraints/` | Pins, clock, timing guard band | XDC |
| `fw/` | Firmware sources, build scripts and memory images | C, assembly |
| `tb/unit/`, `tb/soc/`, `tb/board/` | Self-checking testbenches | SystemVerilog |
| `tb/sva/` | 42 assertions, attached with `bind` | SystemVerilog |
| `tb/uvm/` | UVM environment for the fault manager, supervisor and logger | SystemVerilog |
| `scripts/vivado/` | Project generator, regression runner, implementation and report scripts | Tcl |
| `results/` | Evidence of the baselined run; earlier runs in `results/archive/` | |
| `docs/` | Known limitations and open warnings | |

`build/` is generated and is not tracked.

## Reproducing the results

In the Vivado 2026.1 Tcl Console, with `<repo>` as the path of this folder:

    source <repo>/scripts/vivado/create_project.tcl
    source <repo>/scripts/vivado/run_regression.tcl

`create_project.tcl` generates the project under `build/` with one simulation
set per test. `run_regression.tcl` runs all of them and writes a summary to
`results/`. `freeze_run.tcl` does the complete flow in one step: project,
regression, synthesis, implementation, bitstream and reports.

To run one test in the GUI: Sources > Simulation Sources, right-click a
simulation set, Make Active, then Flow Navigator > Run Simulation > Run
Behavioral Simulation. The set `board_demo` shows the whole board sequence.

## Board demonstration

Program the bitstream from `results/fpga_build_20261117_1802/` and open a
serial terminal on the USB-UART port at 115200 baud, 8N1.

| Control | Function |
| --- | --- |
| SW1:SW0 | Profile: `00` Basic, `01` Safety, `10` Diagnostic |
| SW3 | Arm the injection buttons (effective in Diagnostic only) |
| BTN0 | Flip one bit of an instruction word entering core B (code `01`) |
| BTN1 | Flip one bit of read data entering core B (code `02`) |
| BTN2 | Flip one comparator input: SW2 down instruction address (`01`), SW2 up data address (`02`) |
| BTN3 | Stall execution so the watchdog expires (code `03`) |
| Reset button | Leave the safe state and restart |

| Indicator | Meaning |
| --- | --- |
| LD4 | Heartbeat |
| LD5 | Lockstep comparison enabled |
| LD6 | Fault latched |
| LD7 | Safe state |
| LD0 | Health: green running, red fault |
| LD1 | Injection: off not permitted, blue armed, red injected |
| LD2 | Fault code bits (red bit 0, green bit 1, blue bit 2) |
| LD3 | Profile: blue Basic, green Safety, red Diagnostic |

The serial output prints the boot banner and diagnostic log (`[BOOT]`,
`[LOG ]`), a status line every 1.7 s (`[STAT]`), each injection (`[INJ ]`)
and each detected fault with its code and detection latency in clock cycles
(`[FLT ]`).

## Verification

- 7 unit tests of the safety modules.
- 20 SoC tests with both cores running firmware: normal operation, each fault
  path, address guards, write blocking in the safe state, profile policy.
- 1 board-level test that drives the switches and buttons and decodes the
  UART output.
- 1 UVM test of the fault manager, supervisor and logger against a
  cycle-accurate reference model: 476,910 comparisons without a mismatch,
  100 % of the defined functional coverage.
- 3 mutation runs in which a deliberate error is forced into the design; the
  scoreboard reports thousands of mismatches in each, which shows that the
  environment can fail.
- 42 SystemVerilog assertions active in the SoC, board and UVM simulations.

## Design notes

- **40 MHz system clock.** The longest path (decode, ALU, branch, cross-core
  comparison, data grant) is about 23 ns over 31 logic levels. At 50 MHz
  timing closed only marginally and not on every build, so the clock was
  reduced to 40 MHz. The safety logic counts in clock cycles and did not
  change.
- **Replicated configuration blocks carry `DONT_TOUCH`.** Without it synthesis
  recognised the two replicas as identical and kept one, which would have made
  the replica comparison compare a block with itself on the FPGA.
- **Memory images are padded with zeros to the full RAM size.** Block RAM
  powers up as zero, but unspecified words are unknown in simulation, and the
  Ibex prefetcher reads one word past the last instruction.
- **The board layer only uses existing SoC ports.** Switches, buttons, LEDs
  and UART drive the injection inputs and observe the status outputs; they do
  not add paths into the safety logic.

## Limitations

See `docs/KNOWN_LIMITATIONS.md`. In short: comparison is at bus level, not of
internal core state; the RAMs have no ECC; common-cause faults are not
covered; the battery data is a fixed data set; the design is a prototype and
makes no claim of ISO 26262 compliance.

## Third-party code

`ip/ibex/` contains the Ibex RISC-V core and lowRISC primitives
(https://github.com/lowRISC/ibex), licensed under Apache-2.0 and used without
modification.
