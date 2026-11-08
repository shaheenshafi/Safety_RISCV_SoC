# Arty A7-100T - 50 MHz system clock
# Target period: 20 ns
# No physical placement constraints are defined here.

create_clock -name sys_clk_pin -period 20.000 \
    -waveform {0 10} [get_ports {clk}]
