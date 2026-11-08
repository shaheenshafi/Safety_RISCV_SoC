open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

set lut [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]

puts "\n========== LUT DETAILS =========="
report_property $lut

foreach input_pin {I0 I1} {
    set pin [get_pins -quiet "u_safety_riscv_soc/core_b/i___95/$input_pin"]
    set net [get_nets -quiet -of_objects $pin]

    puts "\n========== INPUT $input_pin =========="
    puts "PIN: $pin"
    puts "NET: $net"

    puts "\n--- Net properties ---"
    report_property $net

    puts "\n--- Connected pins and cells ---"
    foreach p [get_pins -quiet -of_objects $net] {
        set cell [get_cells -quiet -of_objects $p]
        puts "PIN: $p"
        puts "DIRECTION: [get_property DIRECTION $p]"
        puts "CELL: $cell"

        if {[llength $cell] > 0} {
            puts "CELL_TYPE: [get_property REF_NAME $cell]"
            puts "CELL_ORIG_TYPE: [get_property ORIG_REF_NAME $cell]"
        }
    }

    puts "\n--- Driver pins ---"
    set drivers [get_pins -quiet -of_objects $net \
        -filter {DIRECTION == OUT}]

    if {[llength $drivers] == 0} {
        puts "No direct output pin returned by this query."
    } else {
        foreach d $drivers {
            puts "DRIVER: $d"
            puts "DRIVER_CELL: [get_cells -quiet -of_objects $d]"
        }
    }

    puts "\n--- Sequential startpoints in fan-in ---"
    set starts [all_fanin -flat -to $pin -startpoints_only]
    foreach s $starts {
        puts "STARTPOINT: $s"
    }
}

puts "\n========== RELATED NET NAMES =========="
foreach pattern {
    *fault_latched*
    *profile_integrity_fault*
    *safe_state*
    *soc_reset_release_sync*
} {
    puts "\nPATTERN: $pattern"
    foreach n [get_nets -quiet -hier -filter "NAME =~ $pattern"] {
        puts "NET: $n"
    }
}

puts "\n========== END =========="
close_design
exit
