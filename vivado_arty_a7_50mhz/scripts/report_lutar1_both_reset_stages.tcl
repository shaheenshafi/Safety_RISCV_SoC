open_checkpoint checkpoints/implementation/arty_a7_50mhz_routed.dcp

foreach index {0 1} {
    set cell_name "u_safety_riscv_soc/core_b/core_reset_sync_reg\[$index\]"
    set cell [get_cells -quiet $cell_name]

    puts "\n========== CORE B RESET STAGE $index =========="
    puts "CELL: $cell"

    if {[llength $cell] == 0} {
        puts "ERROR: Reset synchronizer cell not found."
        continue
    }

    set clr [get_pins -quiet -of_objects $cell \
        -filter {REF_PIN_NAME == CLR}]

    puts "CLR: $clr"

    if {[llength $clr] == 0} {
        puts "ERROR: CLR pin not found."
        continue
    }

    report_timing -to $clr \
        -delay_type min_max \
        -max_paths 20 \
        -path_type full
}

puts "\n========== END =========="
close_design
exit
