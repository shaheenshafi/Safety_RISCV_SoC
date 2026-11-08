# ============================================================
# Arty A7-100T - 50 MHz implementation-only flow
# Stops after route_design. NO bitstream generation.
# ============================================================

set ws [file normalize [file join [file dirname [info script]] ".."]]
cd $ws

set xpr [file join $ws build project arty_a7_50mhz.xpr]

if {![file exists $xpr]} {
    error "Vivado project not found: $xpr"
}

foreach dir {
    reports/implementation
    reports/timing
    checkpoints/implementation
    build/logs
} {
    file mkdir $dir
}

puts "============================================================"
puts "IMPLEMENTATION-ONLY FLOW: START"
puts "Workspace: $ws"
puts "Project:   $xpr"
puts "Target:    50 MHz"
puts "Stop step: route_design"
puts "Bitstream: DISABLED"
puts "============================================================"

open_project $xpr

# Verify synthesis completed successfully.
set synth_run [get_runs synth_1]
set synth_status [get_property STATUS $synth_run]

puts "Synthesis status: $synth_status"

if {![string match "*Complete*" $synth_status]} {
    error "Synthesis is not complete. Implementation aborted."
}

# Verify the synthesis checkpoint exists.
set synth_dir [get_property DIRECTORY $synth_run]
set synth_dcp [file join $synth_dir safety_riscv_soc_arty_a7.dcp]

if {![file exists $synth_dcp]} {
    error "Synthesis checkpoint not found: $synth_dcp"
}

puts "Synthesis checkpoint verified: $synth_dcp"

# Launch implementation only through routing.
set impl_run [get_runs impl_1]

launch_runs $impl_run -to_step route_design -jobs 4
wait_on_run $impl_run

set impl_status [get_property STATUS $impl_run]
puts "Implementation status: $impl_status"

if {![string match "*Complete*" $impl_status]} {
    error "Implementation did not complete through route_design. Review the Vivado run log."
}

# Open routed implementation.
open_run $impl_run

# Generate implementation reports.
report_utilization \
    -file reports/implementation/utilization_routed.rpt

report_timing_summary \
    -delay_type min_max \
    -file reports/timing/timing_summary_routed.rpt

report_route_status \
    -file reports/implementation/route_status.rpt

report_clock_utilization \
    -file reports/implementation/clock_utilization.rpt

report_drc \
    -file reports/implementation/drc_routed.rpt

# Save routed checkpoint for later analysis.
write_checkpoint -force \
    checkpoints/implementation/arty_a7_50mhz_routed.dcp

puts "============================================================"
puts "IMPLEMENTATION-ONLY FLOW: COMPLETE"
puts "Implementation status: $impl_status"
puts "Routed checkpoint: checkpoints/implementation/arty_a7_50mhz_routed.dcp"
puts "Timing report: reports/timing/timing_summary_routed.rpt"
puts "Utilization report: reports/implementation/utilization_routed.rpt"
puts "Route report: reports/implementation/route_status.rpt"
puts "Clock report: reports/implementation/clock_utilization.rpt"
puts "DRC report: reports/implementation/drc_routed.rpt"
puts "BITSTREAM GENERATION: NOT RUN"
puts "============================================================"

close_project
exit 0
