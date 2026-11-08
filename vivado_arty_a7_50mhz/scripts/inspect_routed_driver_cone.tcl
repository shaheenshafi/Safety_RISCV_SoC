set dcp "checkpoints/implementation/arty_a7_50mhz_routed.dcp"
open_checkpoint $dcp

set ram_pin [get_pins -of_objects \
    [get_cells -hier -filter {NAME =~ *core_b/u_ram/u_ram/mem_reg_0}] \
    -filter {REF_PIN_NAME == ADDRARDADDR[14]}]

if {[llength $ram_pin] != 1} {
    error "Expected one RAM address pin; found [llength $ram_pin]"
}

set net [get_nets -of_objects $ram_pin]

puts "\n========== NET DRIVER =========="
puts "RAM PIN: $ram_pin"
puts "NET: $net"

set driver_pins [get_pins -of_objects $net -filter {DIRECTION == OUT}]

puts "DRIVER PIN COUNT: [llength $driver_pins]"

foreach driver $driver_pins {
    puts "\nDRIVER PIN: $driver"
    puts "REF PIN: [get_property REF_PIN_NAME $driver]"

    set driver_cells [get_cells -of_objects $driver]

    foreach cell $driver_cells {
        puts "DRIVER CELL: $cell"
        puts "REF_NAME: [get_property REF_NAME $cell]"
        puts "IS_SEQUENTIAL: [get_property IS_SEQUENTIAL $cell]"
        report_property $cell
    }
}

puts "\n========== FAN-IN STARTPOINTS =========="
set startpoints [all_fanin -to $ram_pin -flat -startpoints_only]

foreach point $startpoints {
    puts "STARTPOINT: $point"
}

puts "\n========== FAN-IN CELL SUMMARY =========="
set fanin_cells [all_fanin -to $ram_pin -flat -only_cells]

foreach cell $fanin_cells {
    puts "CELL: $cell | REF: [get_property REF_NAME $cell]"
}

puts "\n========== DRIVER CONE INSPECTION COMPLETE =========="
close_design
exit
