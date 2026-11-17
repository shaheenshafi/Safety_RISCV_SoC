# Results

Evidence for the baselined design. Everything here was produced by the
scripts in `scripts/vivado/`.

| Path | Content |
| --- | --- |
| `freeze_run_20261117_1707.txt` | Summary of the complete run: project, regression, implementation |
| `regression_20261117_170756/` | Behavioural regression, 32 simulation logs and `summary.txt` |
| `fpga_build_20261117_1802/` | Bitstream with timing, utilization, power, DRC and route-status reports |
| `gui_run_20261117_baseline/` | Vivado screenshots: waveforms, device view, timing, utilization, power, DRC, schematic |
| `coverage_20261117_1234/` | UVM functional coverage summary and simulation log |
| `board_demo_20261117/` | Serial captures from the Arty A7-100T (taken with the bitstream in `archive/fpga_build_20261117_0055`, same design) |
| `archive/` | Results of earlier runs, kept for history |
