set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]

open_checkpoint $dcp

puts "\n===== CURRENT DESIGN METHODOLOGY ====="
report_methodology \
    -file "reports/implementation/methodology_routed_detailed.rpt"

puts "\n===== TIMING CHECKS ====="
check_timing -verbose \
    -file "reports/timing/check_timing_routed_detailed.rpt"

close_design
puts "\nMETHODOLOGY INSPECTION COMPLETE"
exit
