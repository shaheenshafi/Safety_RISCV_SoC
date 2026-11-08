set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

set target [get_pins -quiet {u_safety_riscv_soc/core_b/i___95/I1}]
set net [get_nets -quiet -of_objects $target]

puts "\n===== I1 NET ====="
puts "Net: [get_property NAME $net]"

puts "\n===== NET DRIVER PINS ====="
set drivers [get_pins -quiet -of_objects $net -filter {DIRECTION == OUT}]
puts "Driver count: [llength $drivers]"
foreach p $drivers {
    puts "Driver: [get_property NAME $p]"
    puts "Cell: [get_property NAME [get_cells -of_objects $p]]"
}

puts "\n===== NET CONNECTED CELL PINS ====="
foreach p [get_pins -quiet -of_objects $net] {
    puts "[get_property NAME $p] | [get_property DIRECTION $p]"
}

puts "\n===== FANIN STARTPOINTS OF I1 ====="
set starts [all_fanin -to $target -flat -startpoints_only]
puts "Startpoint count: [llength $starts]"
foreach p $starts {
    puts [get_property NAME $p]
}

puts "\n===== FANIN CELL TYPES ====="
set cells [all_fanin -to $target -flat -only_cells]
set counts [dict create]
foreach c $cells {
    set t [get_property REF_NAME $c]
    dict incr counts $t
}
foreach t [lsort [dict keys $counts]] {
    puts "$t : [dict get $counts $t]"
}

close_design
puts "\nHIERARCHY TRACE COMPLETE"
exit
