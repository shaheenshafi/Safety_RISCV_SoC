set dcp "checkpoints/implementation/arty_a7_50mhz_routed.dcp"

puts "\n========== OPEN ROUTED CHECKPOINT =========="
open_checkpoint $dcp

set ram [get_cells -hier -filter {NAME =~ *core_b/u_ram/u_ram/mem_reg_0}]

if {[llength $ram] != 1} {
    error "Expected exactly one target RAMB36E1; found [llength $ram]"
}

puts "\n========== ENUMERATE RAM ADDRESS PINS =========="

set addr_pins {}

foreach pin [get_pins -of_objects $ram] {
    set ref_pin [get_property REF_PIN_NAME $pin]

    if {[string match "ADDRARDADDR*" $ref_pin]} {
        lappend addr_pins $pin
        puts "PIN: $pin"
        puts "REF_PIN_NAME: $ref_pin"
        puts "DIRECTION: [get_property DIRECTION $pin]"
    }
}

if {[llength $addr_pins] == 0} {
    error "No ADDRARDADDR pins found on target RAM"
}

puts "\n========== TRACE ADDRESS BIT 14 =========="

set target_pin {}

foreach pin $addr_pins {
    if {[get_property REF_PIN_NAME $pin] eq "ADDRARDADDR[14]"} {
        set target_pin $pin
        break
    }
}

if {$target_pin eq ""} {
    puts "Exact bit 14 not matched. Available address pins are listed above."
} else {
    puts "TARGET PIN: $target_pin"

    set nets [get_nets -of_objects $target_pin]

    foreach net $nets {
        puts "\nCONNECTED NET: $net"
        report_property $net

        puts "\n========== CONNECTED PINS =========="

        foreach connected_pin [get_pins -of_objects $net] {
            set cell [get_cells -of_objects $connected_pin]

            puts "PIN: $connected_pin"
            puts "  REF_PIN_NAME: [get_property REF_PIN_NAME $connected_pin]"
            puts "  DIRECTION: [get_property DIRECTION $connected_pin]"

            foreach c $cell {
                puts "  CELL: $c"
                puts "  REF_NAME: [get_property REF_NAME $c]"
                puts "  IS_SEQUENTIAL: [get_property IS_SEQUENTIAL $c]"
            }
        }
    }
}

puts "\n========== INSPECTION COMPLETE =========="
close_design
exit
