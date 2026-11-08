set ws [file normalize [file join [file dirname [info script]] ".."]]
set xpr [file join $ws build project arty_a7_50mhz.xpr]

cd $ws
open_project $xpr

puts "\n========== SYNTHESIS RUN =========="
puts "Project: [current_project]"
puts "Part: [get_property PART [current_project]]"

set synth_run [get_runs synth_1]
if {[llength $synth_run] != 1} {
    error "Expected Vivado synthesis run synth_1"
}

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $status"

if {![string match "*Complete*" $status]} {
    error "Synthesis did not complete successfully: $status"
}

open_run synth_1

file mkdir reports/synthesis
report_utilization -file reports/synthesis/utilization_synth.rpt
report_timing_summary -file reports/synthesis/timing_summary_synth.rpt

puts "\n========== SYNTHESIS REPORTS =========="
puts "reports/synthesis/utilization_synth.rpt"
puts "reports/synthesis/timing_summary_synth.rpt"

close_project
puts "SYNTHESIS-ONLY STAGE COMPLETE"
exit 0
