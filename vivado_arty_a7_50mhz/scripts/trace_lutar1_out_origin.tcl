set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

puts "\n===== LUTAR-1 TARGET ====="
set lut [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]

if {[llength $lut] == 1} {
    puts "Cell: [get_property NAME $lut]"
    puts "Type: [get_property REF_NAME $lut]"
    puts "INIT: [get_property INIT $lut]"
    puts "Parent: [get_property PARENT $lut]"
} else {
    puts "ERROR: Expected one LUT cell, found [llength $lut]"
}

puts "\n===== CORE B OUT[0] HIERARCHICAL PORT ====="
set port [get_ports -quiet {u_safety_riscv_soc/core_b/out[0]}]

puts "Port matches: [llength $port]"

foreach p $port {
    puts "Port: [get_property NAME $p]"
    puts "Direction: [get_property DIRECTION $p]"
    puts "Parent: [get_property PARENT $p]"
    puts "Connected net: [get_property NAME [get_nets -quiet -of_objects $p]]"
}

puts "\n===== MATCHING CORE B OUT SIGNALS ====="
foreach n [get_nets -hier -quiet -filter {NAME =~ *core_b/out*}] {
    puts "NET: [get_property NAME $n]"
    foreach p [get_pins -quiet -of_objects $n] {
        puts "  PIN: [get_property NAME $p] | [get_property DIRECTION $p]"
    }
}

puts "\n===== LUT INPUT AND OUTPUT CONNECTIVITY ====="
foreach pin_name {
    u_safety_riscv_soc/core_b/i___95/I0
    u_safety_riscv_soc/core_b/i___95/I1
    u_safety_riscv_soc/core_b/i___95/O
} {
    set pin [get_pins -quiet $pin_name]
    puts "\nPIN: $pin_name"

    foreach n [get_nets -quiet -of_objects $pin] {
        puts "NET: [get_property NAME $n]"
        foreach cp [get_pins -quiet -of_objects $n] {
            puts "  [get_property NAME $cp] | [get_property DIRECTION $cp]"
        }
    }
}

puts "\n===== CORE B HIERARCHY MATCHES ====="
foreach c [get_cells -hier -quiet -filter {NAME =~ *core_b*}] {
    set ref [get_property REF_NAME $c]
    if {$ref ne ""} {
        puts "[get_property NAME $c] | $ref"
    }
}

close_design
puts "\nLUTAR-1 OUT ORIGIN TRACE COMPLETE"
exit
