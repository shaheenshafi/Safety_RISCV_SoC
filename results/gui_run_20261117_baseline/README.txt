Vivado 2026.1 GUI captures, run of 2026-11-17 (regression_20261117_170756,
fpga_build_20261117_1802).

01, 02  XSim behavioural simulation of the board demo (simulation set board_demo).
        Waveform rows:
          rst_n  board reset button (active low)      sw     SW3..SW0
          btn    BTN3..BTN0                           led    LD7..LD4
          prof   selected profile (0 Basic, 1 Safety, 2 Diagnostic)
          auth   fault injection permitted            injOn  injection active
          injId  injected fault number (0..4)         iMis   instruction-channel mismatch
          dMis   data-channel mismatch                wdog   supervisor (watchdog) fault
          fault  fault latched                        code   fault code
          safe   safe-state request                   hb     heartbeat update
          nFlt   faults recorded by the diagnostic logger
          uart   serial output
03      Implemented design, device view.
04      Timing summary (includes the 1.5 ns setup guard band).
05      Utilization by hierarchy (routed design).
06      Power summary.
07      DRC: 21 warnings, no errors (see docs/KNOWN_LIMITATIONS.md).
08      Schematic of the top-level blocks.
