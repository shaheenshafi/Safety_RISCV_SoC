# Known limitations and open warnings

Assessment of the design-rule warnings that remain in the FPGA build
(`results/fpga_build_20261117_0055`, commit 95beab1). None is an error; all
three were present in every earlier build. No design change was made for
them. Each entry states the risk honestly and what a fix would be.

## REQP-1839: block RAM address driven by registers with asynchronous reset (20 reported, report limit)

What it is: the address inputs of the eight program/data block RAMs are
driven, through logic, by Ibex registers that have an asynchronous reset
(for example the register file). Ibex is used unmodified and uses
asynchronous resets throughout.

Risk: if the asynchronous reset arrives close to a clock edge while a RAM
access is in progress, the RAM can see an unstable address. For a write this
could, in principle, corrupt a memory word. Program and data share the same
RAM, so a corrupted word would persist until the FPGA is reconfigured.

Mitigations present: on safe-state entry the RAM requests are blocked by the
memory side-effect inhibit in the same cycle; the diagnostic log is kept in
separate registers, not in this RAM.

Observation: more than fifty reset and fault-recovery cycles on the board
without any wrong behaviour after restart. This is evidence of low
likelihood, not proof of absence.

Proper fix (not done): gate the RAM enable with a reset-request signal that
is asserted synchronously one cycle before the core reset, or use a
synchronous-reset core configuration.

## LUTAR-1: LUT drives asynchronous reset (2)

1. `u_board_clock`: the reset synchroniser is cleared by
   `reset_button AND mmcm_locked`. The two inputs never change in opposite
   directions at the same time (pressing reset forces `locked` low only
   afterwards; on release `locked` rises last), so the LUT output cannot
   glitch into a false reset. Benign.

2. Core reset synchronisers: cleared by `soc_reset AND NOT safe_state`.
   `safe_state` includes the combinational configuration-integrity check
   (stored value against stored complement). When a profile is written,
   both copies change on the same clock edge, so a short glitch on this
   LUT is theoretically possible and would restart the cores.
   Observation: no such restart in any board run, including many run-time
   profile changes (the heartbeat counter continued across every change).
   Proper fix (not done): register the safe-state signal before it is used
   as an asynchronous core reset; this delays the core reset by one cycle
   and requires re-verification of the reset-timing checks in
   `safety_riscv_soc_stage4f_tb`.

## SYNTH-6: block RAM output register not used (8)

Information about performance only: the RAM read data is not registered a
second time, which the design relies on for single-cycle memory responses.
No functional effect.

## Other limitations of the work

- The lockstep comparison is at bus-transaction level (addresses, data,
  control, responses), not at the level of every internal core signal.
- Each core has its own RAM copy; the RAMs are not protected by ECC or
  parity.
- Common-cause faults (clock, power, a fault that hits both cores in the
  same way) are not detected by lockstep comparison.
- Faults are injected at bus and comparison level and as an execution
  stall; there is no radiation or gate-level fault injection.
- The power figure is Vivado's vectorless estimate, not a measurement.
- The single-core area baseline is the `core_a` instance of the safety SoC,
  not a separately implemented single-core design.
- The UVM environment covers the central safety manager (fault manager,
  execution supervisor, diagnostic logger); the full SoC is verified with
  directed tests and assertions.
- A fault latched in the same clock cycle in which reset is asserted is not
  recorded by the diagnostic logger.
