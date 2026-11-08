set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]

if {![file exists $dcp]} {
    error "Routed checkpoint not found: $dcp"
}

open_checkpoint $dcp

puts "\n===== DESIGN IDENTITY ====="
puts "Part: [get_property PART [current_design]]"
puts "Top:  [get_property TOP [current_fileset]]"

puts "\n===== TOP-LEVEL PORTS ====="
foreach p [get_ports] {
    puts "[get_property NAME $p] | [get_property DIRECTION $p] | [get_property PACKAGE_PIN $p] | [get_property IOSTANDARD $p]"
}

puts "\n===== CLOCKS ====="
report_clocks

puts "\n===== UNCONSTRAINED PORTS ====="
set unconstrained_ports [get_ports -filter {PACKAGE_PIN == ""}]
puts "Ports without PACKAGE_PIN: [llength $unconstrained_ports]"
foreach p $unconstrained_ports {
    puts "UNASSIGNED: [get_property NAME $p]"
}

puts "\n===== UNCONSTRAINED PATHS ====="
report_timing_summary -report_unconstrained -check_timing_verbose \
    -file "reports/timing/pre_bitstream_timing_audit.rpt"

puts "\n===== CONFIGURATION PROPERTIES ====="
foreach prop {CFGBVS CONFIG_VOLTAGE} {
    if {[catch {set value [get_property $prop [current_design]]}]} {
        set value "UNAVAILABLE"
    }
    puts "$prop = $value"
}

puts "\n===== DRC SUMMARY ====="
report_drc -file "reports/implementation/pre_bitstream_drc_audit.rpt"

close_design
puts "\nPRE-BITSTREAM READ-ONLY AUDIT COMPLETE"
exit
