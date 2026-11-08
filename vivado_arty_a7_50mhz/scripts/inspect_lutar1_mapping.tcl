set dcp "checkpoints/implementation/arty_a7_50mhz_routed.dcp"

puts "========== OPEN ROUTED CHECKPOINT =========="
open_checkpoint $dcp

set lut [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]
set coreb [get_cells -quiet {u_safety_riscv_soc/core_b}]

puts "\n========== LUT CELL PROPERTIES =========="
if {[llength $lut] == 1} {
    report_property $lut
    puts "REF_NAME: [get_property REF_NAME $lut]"
    puts "ORIG_REF_NAME: [get_property ORIG_REF_NAME $lut]"
    puts "PARENT: [get_property PARENT $lut]"
} else {
    puts "LUT cell not found or not unique"
}

puts "\n========== CORE B CELL PROPERTIES =========="
if {[llength $coreb] == 1} {
    report_property $coreb
} else {
    puts "Core B cell not found or not unique"
}

puts "\n========== LUT INPUT AND OUTPUT CONNECTIVITY =========="
foreach pin_name {
    u_safety_riscv_soc/core_b/i___95/I0
    u_safety_riscv_soc/core_b/i___95/I1
    u_safety_riscv_soc/core_b/i___95/O
} {
    set pin [get_pins -quiet $pin_name]
    puts "\nPIN: $pin_name"

    if {[llength $pin] == 1} {
        puts "DIRECTION: [get_property DIRECTION $pin]"
        set nets [get_nets -quiet -of_objects $pin]
        foreach net $nets {
            puts "NET: $net"
            puts "NET HIERARCHY: [get_property NAME $net]"
            puts "NET DRIVER PINS:"
            foreach p [get_pins -quiet -of_objects $net \
                -filter {DIRECTION == OUT}] {
                puts "  $p"
            }
            puts "NET LOAD PINS:"
            foreach p [get_pins -quiet -of_objects $net \
                -filter {DIRECTION == IN}] {
                puts "  $p"
            }
        }
    } else {
        puts "Pin not found or not unique"
    }
}

puts "\n========== PROGRESS COUNTER REGISTER =========="
set progress_regs [get_cells -quiet -hier \
    -filter {NAME =~ *progress_age_q_reg*}]

puts "Matching register cells: [llength $progress_regs]"
foreach c $progress_regs {
    puts "\nCELL: $c"
    puts "REF_NAME: [get_property REF_NAME $c]"
    puts "ORIG_REF_NAME: [get_property ORIG_REF_NAME $c]"
    report_property $c

    foreach p [get_pins -quiet -of_objects $c] {
        puts "PIN: $p | DIR: [get_property DIRECTION $p] | NET: [get_nets -quiet -of_objects $p]"
    }
}

puts "\n========== RESET RELEASE REGISTER =========="
set reset_regs [get_cells -quiet -hier \
    -filter {NAME =~ *soc_reset_release_sync_reg*}]

puts "Matching register cells: [llength $reset_regs]"
foreach c $reset_regs {
    puts "\nCELL: $c"
    puts "REF_NAME: [get_property REF_NAME $c]"
    report_property $c

    foreach p [get_pins -quiet -of_objects $c] {
        puts "PIN: $p | DIR: [get_property DIRECTION $p] | NET: [get_nets -quiet -of_objects $p]"
    }
}

puts "\n========== END INSPECTION =========="
close_design
exit
