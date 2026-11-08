set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

set lut [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]

foreach pin_name {
    u_safety_riscv_soc/core_b/i___95/I0
    u_safety_riscv_soc/core_b/i___95/I1
    u_safety_riscv_soc/core_b/i___95/O
} {
    set pin [get_pins -quiet $pin_name]
    puts "\n===== $pin_name ====="

    if {[llength $pin] != 1} {
        puts "Pin not found"
        continue
    }

    set net [get_nets -quiet -of_objects $pin]
    foreach n $net {
        puts "NET: [get_property NAME $n]"
        puts "TYPE: [get_property TYPE $n]"

        puts "CONNECTED PINS:"
        foreach p [get_pins -quiet -of_objects $n] {
            puts "  [get_property NAME $p] | [get_property DIRECTION $p]"
        }

        puts "HIERARCHICAL PORTS:"
        foreach hp [get_pins -quiet -of_objects $n -filter {IS_PART_OF_CONSTRAINT == 0}] {
            puts "  [get_property NAME $hp]"
        }
    }
}

puts "\n===== LUT HIERARCHY ====="
puts "Parent: [get_property PARENT $lut]"

close_design
puts "\nINPUT TRACE COMPLETE"
exit
