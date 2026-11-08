open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

set lut_i0 [get_pins {u_safety_riscv_soc/core_b/i___95/I0}]
set lut_o  [get_pins {u_safety_riscv_soc/core_b/i___95/O}]

puts "\n========== LUT INPUT TIMING =========="

foreach pattern {
    *u_mmio_config/profile_o_reg*
    *u_mmio_config/profile_complement_q_reg*
    *u_mmio_config/injection_authorize_o_reg*
    *u_mmio_config/injection_authorize_complement_q_reg*
    *u_fault_manager/fault_latched_o_reg*
} {
    set cells [get_cells -quiet -hier -filter "NAME =~ $pattern"]

    foreach c $cells {
        set q [get_pins -quiet -of_objects $c -filter {REF_PIN_NAME == Q}]
        if {[llength $q] > 0} {
            puts "\nSOURCE: $q"
            report_timing -from $q -to $lut_i0 \
                -delay_type min_max -max_paths 2 \
                -input_pins -nets
        }
    }
}

puts "\n========== LUT OUTPUT TO RESET CLEAR =========="

foreach pin_name {
    u_safety_riscv_soc/core_b/core_reset_sync_reg[0]/CLR
    u_safety_riscv_soc/core_b/core_reset_sync_reg[1]/CLR
} {
    set dst [get_pins -quiet $pin_name]
    puts "\nDESTINATION: $dst"

    report_timing -from $lut_o -to $dst \
        -delay_type min_max -max_paths 5 \
        -input_pins -nets
}

puts "\n========== END =========="
close_design
exit
