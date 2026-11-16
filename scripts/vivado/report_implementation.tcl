# ------------------------------------------------------------------------------
# Safety-Oriented RISC-V SoC - implementation evidence
#
# Run after "Generate Bitstream" has finished:
#   source E:/Dissertation/Working_Model_RISCV/scripts/vivado/report_implementation.tcl
#
# Copies the standard reports and the bitstream to results/fpga_build_<stamp>/
# and adds a hierarchical utilization report (resources per module), which is
# the basis of the baseline-versus-safety area comparison.
# ------------------------------------------------------------------------------
set script_dir [file dirname [file normalize [info script]]]
set root       [file normalize [file join $script_dir .. ..]]

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 is not complete. Run Generate Bitstream first."
}

set stamp   [clock format [clock seconds] -format "%Y%m%d_%H%M"]
set out_dir [file join $root results "fpga_build_${stamp}"]
file mkdir $out_dir

set impl_dir  [get_property DIRECTORY [get_runs impl_1]]
set synth_dir [get_property DIRECTORY [get_runs synth_1]]

foreach pattern {*_timing_summary_routed.rpt *_utilization_placed.rpt
                 *_power_routed.rpt *_drc_routed.rpt
                 *_methodology_drc_routed.rpt *_route_status.rpt *.bit} {
    foreach f [glob -nocomplain [file join $impl_dir $pattern]] {
        file copy -force $f $out_dir
    }
}
foreach f [glob -nocomplain [file join $synth_dir *_utilization_synth.rpt]] {
    file copy -force $f $out_dir
}
catch {file copy -force [file join $impl_dir runme.log]  [file join $out_dir impl_runme.log]}
catch {file copy -force [file join $synth_dir runme.log] [file join $out_dir synth_runme.log]}

open_run impl_1
report_utilization -hierarchical -hierarchical_depth 4 \
    -file [file join $out_dir utilization_hierarchical.rpt]
report_timing_summary -max_paths 5 \
    -file [file join $out_dir timing_summary_5_paths.rpt]
report_drc -file [file join $out_dir drc_full.rpt]
close_design

set commit "unknown"
catch {set commit [string trim [exec git -C $root rev-parse HEAD]]}
set dirty ""
catch {
    if {[string trim [exec git -C $root status --porcelain --untracked-files=no]] ne ""} {
        set dirty " (working tree has uncommitted changes)"
    }
}
set fh [open [file join $out_dir BUILD_INFO.txt] w]
puts $fh "Safety-Oriented RISC-V SoC - FPGA build evidence"
puts $fh "Date   : [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $fh "Vivado : [version -short]"
puts $fh "Commit : ${commit}${dirty}"
puts $fh "Part   : [get_property PART [current_project]]"
puts $fh "Impl strategy : [get_property STRATEGY [get_runs impl_1]]"
close $fh

puts ""
puts "=============================================================="
puts " Implementation evidence written to:"
puts "   $out_dir"
puts "=============================================================="
