# Timing guard band for the 40 MHz system clock (implementation only).
#
# Vivado stops optimising as soon as timing is met, which left only 0.07 ns
# of slack on the longest path. This extra setup uncertainty makes the tool
# close timing with a real margin: the slack in the timing report is the
# margin that remains AFTER this guard band has been subtracted.
#
# The value is written by scripts/vivado/freeze_run.tcl (it uses the largest
# value of 1.500, 0.800, 0.000 ns for which timing closes).
set_clock_uncertainty -setup 1.500 \
    [get_clocks -of_objects [get_pins u_board_clock/u_system_mmcm/CLKOUT0]]
