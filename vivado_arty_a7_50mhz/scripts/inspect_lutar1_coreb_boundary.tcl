open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

set coreb [get_cells -quiet {u_safety_riscv_soc/core_b}]
set lut   [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]

puts "\n========== CORE B INSTANCE PORTS =========="
foreach p [get_pins -quiet -of_objects $coreb] {
    set pname [get_property REF_PIN_NAME $p]
    set net [get_nets -quiet -of_objects $p]

    if {[regexp -nocase {progress_age|out|reset|safe_state|rst_ni} $pname]} {
        puts "PIN: $p"
        puts "REF_PIN_NAME: $pname"
        puts "DIRECTION: [get_property DIRECTION $p]"
        puts "NET: $net"
    }
}

puts "\n========== LUT INPUT BOUNDARY NETS =========="
foreach pin_name {
    u_safety_riscv_soc/core_b/i___95/I0
    u_safety_riscv_soc/core_b/i___95/I1
} {
    set pin [get_pins -quiet $pin_name]
    set net [get_nets -quiet -of_objects $pin]

    puts "\nLUT PIN: $pin_name"
    puts "NET: $net"

    foreach p [get_pins -quiet -of_objects $net] {
        puts "CONNECTED PIN: $p"
        puts "  DIRECTION: [get_property DIRECTION $p]"
        puts "  REF_PIN_NAME: [get_property REF_PIN_NAME $p]"
    }
}

puts "\n========== CORE B RESET-RELATED INSTANCE PINS =========="
foreach p [get_pins -quiet -of_objects $coreb] {
    set pname [get_property REF_PIN_NAME $p]
    if {[regexp -nocase {rst|reset|safe} $pname]} {
        puts "$p | [get_property DIRECTION $p] | [get_nets -quiet -of_objects $p]"
    }
}

puts "\n========== END =========="
close_design
exit
