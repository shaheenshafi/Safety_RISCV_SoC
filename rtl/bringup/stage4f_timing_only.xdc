# Temporary timing-analysis constraint.
# Assumes a 100 MHz clock at the top-level clk_i port.
create_clock -name sys_clk -period 10.000 [get_ports {clk_i}]
