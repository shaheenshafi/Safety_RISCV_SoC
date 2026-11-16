# ------------------------------------------------------------------------------
# Safety-Oriented RISC-V SoC - behavioural regression in XSim
#
# Usage (Vivado Tcl Console, with the generated project open):
#   source E:/Dissertation/Working_Model_RISCV/scripts/vivado/run_regression.tcl
#
# Optional: run a subset by setting a glob pattern first, for example
#   set REGRESSION_PATTERN unit_*
#
# Runs every simulation set, copies each simulate.log to
#   results/regression_<date>_<time>/
# and writes summary.txt there. A test passes when its log ends with $finish
# and contains no "Fatal:" or "Error:" line.
# ------------------------------------------------------------------------------

set script_dir [file dirname [file normalize [info script]]]
set root       [file normalize [file join $script_dir .. ..]]
set proj_dir   [get_property DIRECTORY [current_project]]
set proj_name  [get_property NAME      [current_project]]

if {![info exists REGRESSION_PATTERN]} { set REGRESSION_PATTERN * }

set stamp   [clock format [clock seconds] -format {%Y%m%d_%H%M%S}]
set out_dir [file join $root results "regression_$stamp"]
file mkdir $out_dir

set commit "unknown"
catch {set commit [string trim [exec git -C $root rev-parse HEAD]]}

set rows   [list]
set n_pass 0
set n_fail 0

foreach name [lsort [get_property NAME [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]]] {
    if {![string match $REGRESSION_PATTERN $name]} { continue }
    puts "REGRESSION: running $name"
    catch {close_sim -force -quiet}
    current_fileset -simset [get_filesets $name]

    set result "PASS"
    set detail ""
    if {[catch {launch_simulation -simset $name -mode behavioral} msg]} {
        set result "FAIL"
        set detail "compile/elaborate/launch error: [lindex [split $msg \n] 0]"
    }
    catch {close_sim -force -quiet}

    set log [file join $proj_dir "${proj_name}.sim" $name behav xsim simulate.log]
    if {[file exists $log]} {
        file copy -force $log [file join $out_dir "${name}.log"]
        set fh [open $log r]
        set text [read $fh]
        close $fh
        if {[regexp -line {^(Fatal|FATAL|Error|ERROR):.*$} $text bad] ||
            [regexp -line {^UVM_(ERROR|FATAL) [^:].*$} $text bad]} {
            set result "FAIL"
            set detail [string range $bad 0 160]
        } elseif {$result eq "PASS" && ![regexp {\$finish called} $text]} {
            set result "FAIL"
            set detail "simulation did not reach \$finish"
        }
    } elseif {$result eq "PASS"} {
        set result "FAIL"
        set detail "simulate.log not found"
    }

    if {$result eq "PASS"} { incr n_pass } else { incr n_fail }
    lappend rows [format "%-40s %-5s %s" $name $result $detail]
}

set fh [open [file join $out_dir summary.txt] w]
puts $fh "Safety-Oriented RISC-V SoC - XSim behavioural regression"
puts $fh "Date    : [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
puts $fh "Vivado  : [version -short]"
puts $fh "Commit  : $commit"
puts $fh "Pattern : $REGRESSION_PATTERN"
puts $fh "Result  : $n_pass passed, $n_fail failed"
puts $fh ""
foreach r $rows { puts $fh $r }
close $fh

puts ""
puts "=============================================================="
puts " Regression: $n_pass passed, $n_fail failed"
foreach r $rows { puts " $r" }
puts " Logs: $out_dir"
puts "=============================================================="
