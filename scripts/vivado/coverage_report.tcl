# ------------------------------------------------------------------------------
# Functional coverage report (text) of the UVM safety-manager test
#
#   source E:/Dissertation/Working_Model_RISCV/scripts/vivado/coverage_report.tcl
#
# Runs the UVM test and writes results/coverage_<stamp>/coverage_summary.txt
# ------------------------------------------------------------------------------
set cr_script_dir [file dirname [file normalize [info script]]]
set cr_root       [file normalize [file join $cr_script_dir .. ..]]
set cr_proj_dir   [get_property DIRECTORY [current_project]]
set cr_proj_name  [get_property NAME      [current_project]]

catch {close_sim -force -quiet}
current_fileset -simset [get_filesets uvm_safety_manager]
launch_simulation -simset uvm_safety_manager -mode behavioral
catch {close_sim -force -quiet}

set cr_sim_dir [file join $cr_proj_dir "${cr_proj_name}.sim" uvm_safety_manager behav xsim]
set cr_stamp   [clock format [clock seconds] -format "%Y%m%d_%H%M"]
set cr_out     [file join $cr_root results "coverage_${cr_stamp}"]
file mkdir $cr_out

# Vivado's HTML coverage report generator (xcrg) needs the PRO simulator
# licence tier, which is not available here. The coverage figures are
# therefore taken from the covergroups themselves, as printed by the UVM
# coverage collector, and written to a text report.
set cr_fh  [open [file join $cr_sim_dir simulate.log] r]
set cr_log [read $cr_fh]
close $cr_fh
set cr_fh [open [file join $cr_out coverage_summary.txt] w]
puts $cr_fh "Functional coverage and checking summary - UVM safety-manager test"
puts $cr_fh "Date: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $cr_fh ""
foreach cr_line [split $cr_log \n] {
    if {[regexp {\[(COV|SCB|TEST)\] (.*)$} $cr_line -> cr_id cr_text] ||
        [regexp {^(SVA .*)$} $cr_line -> cr_text]} {
        puts $cr_fh $cr_text
    }
}
close $cr_fh
catch {file copy -force [file join $cr_sim_dir simulate.log] [file join $cr_out uvm_simulate.log]}

puts ""
puts "=============================================================="
puts " Coverage report folder: $cr_out"
puts " Files: [glob -nocomplain -tails -directory $cr_out *]"
puts "=============================================================="
