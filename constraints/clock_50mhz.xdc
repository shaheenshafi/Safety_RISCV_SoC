# Digilent Arty A7-100T
# Physical oscillator: 100 MHz at E3.
# The 50 MHz SoC clock is generated internally by MMCME2_BASE.
# Vivado derives the generated clock through the MMCM and BUFG.

create_clock -name board_clk_100mhz -period 10.000 \
    -waveform {0 5} [get_ports {clk}]
