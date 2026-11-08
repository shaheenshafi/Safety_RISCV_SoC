# Arty A7-100T standalone Vivado project configuration

set PROJECT_NAME "arty_a7_50mhz"
set FPGA_PART "xc7a100tcsg324-1"
set TOP_MODULE "safety_riscv_soc_arty_a7"

set TARGET_CLOCK_MHZ 50
set TARGET_CLOCK_PERIOD_NS 20.000

set PROJECT_ROOT [file normalize [file join [file dirname [info script]]]]
set PROJECT_DIR [file join $PROJECT_ROOT "build" "project"]
set SOURCE_ROOT [file join $PROJECT_ROOT "src"]

# RTL snapshot provenance:
# Copied from the FuseSoC-resolved Vivado source tree.
# This is a frozen build snapshot, not an automatically synchronized source tree.
