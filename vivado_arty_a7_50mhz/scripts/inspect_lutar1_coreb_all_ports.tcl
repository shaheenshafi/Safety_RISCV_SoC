open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

set coreb [get_cells -quiet {u_safety_riscv_soc/core_b}]

puts "\n========== COMPLETE CORE B BOUNDARY PORT MAP =========="

foreach p [lsort [get_pins -quiet -of_objects $coreb]] {
    set pname [get_property REF_PIN_NAME $p]
    set direction [get_property DIRECTION $p]
    set net [get_nets -quiet -of_objects $p]

    puts [format "%-12s | %-45s | %s" $direction $pname $net]
}

puts "\n========== SIGNALS CONNECTED TO LUT INPUTS =========="

foreach pin_name {
    u_safety_riscv_soc/core_b/i___95/I0
    u_safety_riscv_soc/core_b/i___95/I1
} {
    set pin [get_pins -quiet $pin_name]
    set net [get_nets -quiet -of_objects $pin]

    puts "\n$pin_name"
    puts "NET: $net"

    report_property -all $net
}

puts "\n========== END =========="
close_design
exit
