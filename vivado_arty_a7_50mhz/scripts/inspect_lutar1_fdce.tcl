set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

set cell_name {u_safety_riscv_soc/soc_reset_release_sync_reg[1]}
set cell [get_cells -quiet $cell_name]

puts "\n===== RESET RELEASE REGISTER ====="
puts "Cell query: $cell_name"
puts "Match count: [llength $cell]"

if {[llength $cell] == 1} {
    puts "Cell: [get_property NAME $cell]"
    puts "Primitive: [get_property REF_NAME $cell]"
    puts "LOC: [get_property LOC $cell]"

    puts "\n===== ALL FDCE PINS AND CONNECTED NETS ====="
    foreach p [get_pins -of_objects $cell] {
        set net [get_nets -quiet -of_objects $p]
        set net_name "<unconnected>"
        if {[llength $net] > 0} {
            set net_name [get_property NAME $net]
        }
        puts "[get_property NAME $p] | [get_property DIRECTION $p] | $net_name"
    }
} else {
    puts "Exact cell query did not return one cell."
    puts "Searching for matching reset-release registers:"
    foreach c [get_cells -hier -quiet -filter {NAME =~ *soc_reset_release_sync_reg*}] {
        puts "[get_property NAME $c] | [get_property REF_NAME $c]"
    }
}

puts "\n===== LUT I1 CONNECTIVITY ====="
set lut_i1 [get_pins -quiet {u_safety_riscv_soc/core_b/i___95/I1}]
set i1_net [get_nets -quiet -of_objects $lut_i1]

foreach n $i1_net {
    puts "Net: [get_property NAME $n]"
    puts "Connected pins:"
    foreach p [get_pins -quiet -of_objects $n] {
        puts "  [get_property NAME $p] | [get_property DIRECTION $p]"
    }
}

puts "\n===== LUT I1 FANIN STARTPOINTS ====="
foreach p [all_fanin -to $lut_i1 -flat -startpoints_only] {
    puts [get_property NAME $p]
}

close_design
puts "\nFDCE INSPECTION COMPLETE"
exit
