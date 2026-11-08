set dcp "checkpoints/implementation/arty_a7_50mhz_routed.dcp"

puts "\n========== OPEN ROUTED CHECKPOINT =========="
if {![file exists $dcp]} {
    error "Routed checkpoint not found: $dcp"
}
open_checkpoint $dcp

puts "\n========== TARGET RAMB36E1 =========="
set ram [get_cells -hier -filter {NAME =~ *core_b/u_ram/u_ram/mem_reg_0}]

if {[llength $ram] == 0} {
    error "Target RAMB36E1 instance not found"
}

foreach cell $ram {
    puts "RAM CELL: $cell"
    report_property $cell
}

puts "\n========== ADDRESS INPUT PIN =========="
set addr_pin [get_pins -hier -filter {NAME =~ *mem_reg_0/ADDRARDADDR\[14\]}]

if {[llength $addr_pin] == 0} {
    error "ADDRARDADDR[14] pin not found"
}

foreach pin $addr_pin {
    puts "RAM PIN: $pin"
    report_property $pin

    set nets [get_nets -of_objects $pin]

    foreach net $nets {
        puts "\nCONNECTED NET: $net"
        report_property $net

        puts "\n========== ALL PINS ON NET =========="
        set pins [get_pins -of_objects $net]

        foreach connected_pin $pins {
            puts "PIN: $connected_pin"
            puts "  DIRECTION: [get_property DIRECTION $connected_pin]"

            set cells [get_cells -of_objects $connected_pin]
            foreach connected_cell $cells {
                puts "  CELL: $connected_cell"
                puts "  REF_NAME: [get_property REF_NAME $connected_cell]"
                puts "  IS_SEQUENTIAL: [get_property IS_SEQUENTIAL $connected_cell]"
            }
        }
    }
}

puts "\n========== CHECKPOINT INSPECTION COMPLETE =========="
close_design
exit
