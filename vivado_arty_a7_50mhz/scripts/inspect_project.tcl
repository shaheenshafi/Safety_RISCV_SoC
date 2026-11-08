set ws [file normalize [file join [file dirname [info script]] ".."]]
set xpr [file join $ws build project arty_a7_50mhz.xpr]

puts "\n========== OPEN EXISTING PROJECT =========="
open_project $xpr

puts "\n========== PROJECT CONFIGURATION =========="
puts "Project: [current_project]"
puts "Part: [get_property PART [current_project]]"
puts "Top: [get_property TOP [get_filesets sources_1]]"

set rtl [get_files -of_objects [get_filesets sources_1]]
puts "RTL files: [llength $rtl]"
if {[llength $rtl] != 152} {
    error "Unexpected RTL file count"
}
foreach f $rtl {
    if {![file exists [get_property NAME $f]]} {
        error "Missing RTL: [get_property NAME $f]"
    }
}
puts "PASS: all 152 RTL paths resolve"

set xdc [get_files -of_objects [get_filesets constrs_1]]
puts "XDC files: [llength $xdc]"
if {[llength $xdc] != 2} {
    error "Unexpected XDC file count"
}
foreach f $xdc {
    puts "  [get_property NAME $f]"
    if {![file exists [get_property NAME $f]]} {
        error "Missing XDC: [get_property NAME $f]"
    }
}
puts "PASS: both XDC paths resolve"

puts "\n========== STATIC CLOCK CONSTRAINT CHECK =========="
set clock_file [file join $ws constraints clock_50mhz.xdc]
set fh [open $clock_file r]
set clock_text [read $fh]
close $fh

if {![regexp -- {-period[[:space:]]+20\.000} $clock_text]} {
    error "20.000 ns period not found in clock_50mhz.xdc"
}
if {![regexp -- {get_ports[[:space:]]+\{clk\}} $clock_text]} {
    error "Clock constraint does not target port clk"
}
puts "PASS: clock_50mhz.xdc specifies a 20.000 ns clock on clk"

puts "\n========== PROJECT SAVE =========="
close_project
puts "PASS: existing project inspected and saved"
exit 0
