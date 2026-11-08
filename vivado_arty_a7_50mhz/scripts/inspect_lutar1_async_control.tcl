open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

set lut [get_cells {u_safety_riscv_soc/core_b/i___95}]
set lut_o [get_pins {u_safety_riscv_soc/core_b/i___95/O}]
set reset_net [get_nets -of_objects $lut_o]

puts "\n========== LUT OUTPUT NET =========="
puts "LUT: $lut"
puts "OUTPUT PIN: $lut_o"
puts "OUTPUT NET: $reset_net"
report_property $reset_net

puts "\n========== ALL RESET NET CONNECTIONS =========="
foreach p [get_pins -of_objects $reset_net] {
    puts "\nPIN: $p"
    puts "DIRECTION: [get_property DIRECTION $p]"
    set c [get_cells -of_objects $p]
    puts "CELL: $c"
    if {[llength $c] > 0} {
        report_property $c
    }
}

puts "\n========== RESET SYNCHRONIZER CELLS =========="
foreach name {
    u_safety_riscv_soc/core_b/core_reset_sync_reg[0]
    u_safety_riscv_soc/core_b/core_reset_sync_reg[1]
} {
    set c [get_cells -quiet $name]
    puts "\nCELL: $c"
    if {[llength $c] > 0} {
        report_property $c
        puts "CLR PIN:"
        report_property [get_pins -of_objects $c -filter {REF_PIN_NAME == CLR}]
        puts "CLK PIN:"
        report_property [get_pins -of_objects $c -filter {REF_PIN_NAME == C}]
    }
}

puts "\n========== ASYNC RESET TIMING CHECK =========="
report_timing -to [get_pins -of_objects \
    [get_cells -quiet {u_safety_riscv_soc/core_b/core_reset_sync_reg[0]}] \
    -filter {REF_PIN_NAME == CLR}] \
    -delay_type min_max -max_paths 10 -path_type full

puts "\n========== END =========="
close_design
exit
