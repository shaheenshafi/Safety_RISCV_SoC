set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

set parent_name {u_safety_riscv_soc/core_b}
set parent [get_cells -quiet $parent_name]

puts "\n===== CORE B PARENT CELL ====="
puts "Matches: [llength $parent]"

if {[llength $parent] == 1} {
    puts "Name: [get_property NAME $parent]"
    puts "Reference: [get_property REF_NAME $parent]"

    puts "\n===== ALL PARENT CELL PINS ====="
    foreach p [get_pins -of_objects $parent] {
        set net [get_nets -quiet -of_objects $p]
        set net_name "<unconnected>"
        if {[llength $net] > 0} {
            set net_name [get_property NAME $net]
        }

        puts "[get_property NAME $p] | \
[get_property DIRECTION $p] | $net_name"
    }

    puts "\n===== PINS MATCHING OUT ====="
    foreach p [get_pins -of_objects $parent -filter {NAME =~ *out*}] {
        puts "[get_property NAME $p] | \
[get_property DIRECTION $p] | \
[get_property REF_PIN_NAME $p]"

        foreach n [get_nets -quiet -of_objects $p] {
            puts "  NET: [get_property NAME $n]"
        }
    }
}

puts "\n===== LUT I1 NET DRIVER QUERY ====="
set i1 [get_pins -quiet {u_safety_riscv_soc/core_b/i___95/I1}]
set net [get_nets -quiet -of_objects $i1]

foreach n $net {
    puts "Net: [get_property NAME $n]"

    set drivers [get_pins -quiet -of_objects $n \
        -filter {DIRECTION == OUT}]

    puts "Output driver count: [llength $drivers]"

    foreach d $drivers {
        puts "Driver: [get_property NAME $d]"
    }
}

close_design
puts "\nCORE B BOUNDARY INSPECTION COMPLETE"
exit
