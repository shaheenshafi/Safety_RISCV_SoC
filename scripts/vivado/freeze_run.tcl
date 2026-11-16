# ------------------------------------------------------------------------------
# Safety-Oriented RISC-V SoC - unattended complete run
#
#   source E:/Dissertation/Working_Model_RISCV/scripts/vivado/freeze_run.tcl
#
# 1. Regenerates the Vivado project.
# 2. Runs the complete behavioural regression (all simulation sets).
# 3. Synthesises and implements the design and writes the bitstream, using
#    the largest timing guard band (1.5, 0.8, 0.0 ns) for which timing closes.
# 4. Collects the implementation evidence into results/fpga_build_<stamp>/.
# 5. Prints and saves a short summary (results/freeze_run_<stamp>.txt).
#
# Nothing is committed and the board is not programmed.
# ------------------------------------------------------------------------------
set fr_script_dir [file dirname [file normalize [info script]]]
set fr_root       [file normalize [file join $fr_script_dir .. ..]]
set fr_stamp      [clock format [clock seconds] -format "%Y%m%d_%H%M"]
set fr_lines      [list]

proc fr_note {text} {
    global fr_lines
    lappend fr_lines $text
    puts "FREEZE RUN: $text"
}

fr_note "started [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"

# --- 1. Project ---------------------------------------------------------------
source [file join $fr_script_dir create_project.tcl]

# --- 2. Regression ------------------------------------------------------------
set REGRESSION_PATTERN *
source [file join $fr_script_dir run_regression.tcl]
set fr_reg_pass $n_pass
set fr_reg_fail $n_fail
set fr_reg_dir  $out_dir
fr_note "regression: $fr_reg_pass passed, $fr_reg_fail failed ($fr_reg_dir)"

# --- 3. Implementation with timing guard band ----------------------------------
set fr_xdc [file join $fr_root constraints timing_guard_band.xdc]
set fr_guard_used ""
set fr_wns ""
set fr_whs ""

foreach fr_guard {1.500 0.800 0.000} {
    # Write the guard-band value into the constraint file.
    set fh [open $fr_xdc r]
    set text [read $fh]
    close $fh
    regsub {set_clock_uncertainty -setup [0-9.]+} $text \
        "set_clock_uncertainty -setup $fr_guard" text
    set fh [open $fr_xdc w]
    # Keep Unix line endings so the file does not show as changed in git.
    fconfigure $fh -translation lf
    puts -nonewline $fh $text
    close $fh

    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        launch_runs synth_1 -jobs 4
        wait_on_run synth_1
    }
    reset_run impl_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1

    set fr_wns [get_property STATS.WNS [get_runs impl_1]]
    set fr_whs [get_property STATS.WHS [get_runs impl_1]]
    set fr_progress [get_property PROGRESS [get_runs impl_1]]
    fr_note "guard band $fr_guard ns: progress $fr_progress, WNS $fr_wns ns, WHS $fr_whs ns"

    if {$fr_progress eq "100%" && $fr_wns ne "" && $fr_wns >= 0 && $fr_whs >= 0} {
        set fr_guard_used $fr_guard
        break
    }
}

# --- 4. Evidence ---------------------------------------------------------------
if {$fr_guard_used ne ""} {
    source [file join $fr_script_dir report_implementation.tcl]
    fr_note "timing met with guard band $fr_guard_used ns: reported WNS $fr_wns ns, real setup margin [format %.3f [expr {$fr_wns + $fr_guard_used}]] ns"
    fr_note "implementation evidence: $out_dir"
} else {
    fr_note "TIMING NOT MET with any guard band - do not use this bitstream"
}

# --- 5. Summary ----------------------------------------------------------------
fr_note "finished [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
set fh [open [file join $fr_root results "freeze_run_${fr_stamp}.txt"] w]
foreach l $fr_lines { puts $fh $l }
close $fh

puts ""
puts "=============================================================="
foreach l $fr_lines { puts " $l" }
puts "=============================================================="
