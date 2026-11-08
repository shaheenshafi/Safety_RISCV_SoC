set dcp [file normalize "checkpoints/implementation/arty_a7_50mhz_routed.dcp"]
open_checkpoint $dcp

set lut [get_cells -quiet {u_safety_riscv_soc/core_b/i___95}]

if {[llength $lut] != 1} {
    error "Expected exactly one LUT cell; found [llength $lut]"
}

puts "\n===== LUT IDENTITY ====="
puts "Cell: [get_property NAME $lut]"
puts "Type: [get_property REF_NAME $lut]"
puts "LOC:  [get_property LOC $lut]"
puts "INIT: [get_property INIT $lut]"

puts "\n===== LUT INPUT PINS ====="
foreach p [get_pins -of_objects $lut -filter {DIRECTION == IN}] {
    puts "PIN: [get_property NAME $p]"
    set nets [get_nets -quiet -of_objects $p]
    foreach n $nets {
        puts "  NET: [get_property NAME $n]"
        foreach dp [get_pins -of_objects $n -filter {DIRECTION == OUT}] {
            puts "  DRIVER: [get_property NAME $dp]"
        }
    }
}

puts "\n===== LUT OUTPUT PINS ====="
foreach p [get_pins -of_objects $lut -filter {DIRECTION == OUT}] {
    puts "PIN: [get_property NAME $p]"
    set nets [get_nets -quiet -of_objects $p]
    foreach n $nets {
        puts "  NET: [get_property NAME $n]"
        foreach load [get_pins -of_objects $n -filter {DIRECTION == IN}] {
            puts "  LOAD: [get_property NAME $load]"
        }
    }
}

close_design
puts "\nLUTAR-1 INSPECTION COMPLETE"
exit
