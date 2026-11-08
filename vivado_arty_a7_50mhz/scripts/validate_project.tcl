# Controlled Vivado project creation and configuration validation.
set workspace_root [file normalize [file join [file dirname [info script]] ".."]]
cd $workspace_root

puts "\n========== CREATE PROJECT =========="
source [file join $workspace_root scripts create_project.tcl]

puts "\n========== VALIDATE PROJECT =========="

set expected_part "xc7a100tcsg324-1"
set actual_part [get_property PART [current_project]]
if {$actual_part ne $expected_part} {
    error "Incorrect FPGA part: expected $expected_part, got $actual_part"
}
puts "PASS: FPGA part = $actual_part"

set actual_top [get_property TOP [get_filesets sources_1]]
if {$actual_top ne "safety_riscv_soc_arty_a7"} {
    error "Incorrect top module: $actual_top"
}
puts "PASS: top module = $actual_top"

set rtl_files [get_files -of_objects [get_filesets sources_1]]
set rtl_count [llength $rtl_files]
puts "RTL source count: $rtl_count"
if {$rtl_count != 152} {
    error "Expected 152 RTL source files; found $rtl_count"
}

foreach f $rtl_files {
    set path [get_property NAME $f]
    if {![file exists $path]} {
        error "Missing RTL source: $path"
    }
}
puts "PASS: all RTL source paths resolve"

set xdc_files [get_files -of_objects [get_filesets constrs_1]]
set xdc_count [llength $xdc_files]
puts "Constraint file count: $xdc_count"
if {$xdc_count != 2} {
    error "Expected 2 XDC files; found $xdc_count"
}

foreach f $xdc_files {
    set path [get_property NAME $f]
    if {![file exists $path]} {
        error "Missing constraint file: $path"
    }
    puts "  $path"
}
puts "PASS: both constraint paths resolve"

set clock_obj [get_clocks -quiet sys_clk_pin]
if {[llength $clock_obj] != 1} {
    error "Expected exactly one sys_clk_pin clock"
}
set clock_period [get_property PERIOD $clock_obj]
puts "Clock period: $clock_period ns"
if {abs($clock_period - 20.0) > 0.001} {
    error "Expected 20.000 ns clock period; got $clock_period"
}
puts "PASS: 50 MHz clock constraint"

puts "\n========== SAVE PROJECT =========="
close_project -save
puts "PASS: project saved and closed"
puts "PROJECT VALIDATION COMPLETE"
exit 0
