## Digilent Arty A7-100T
## FPGA: xc7a100tcsg324-1
## Pin names follow the Digilent Arty A7 master constraints file.
## The clock is defined separately in clock.xdc.

## System clock, 100 MHz oscillator
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }]

## RESET button, active low (ck_rst)
set_property -dict { PACKAGE_PIN C2  IOSTANDARD LVCMOS33 } [get_ports { reset }]

## Slide switches SW0..SW3
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]

## Push buttons BTN0..BTN3
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
set_property -dict { PACKAGE_PIN B9  IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
set_property -dict { PACKAGE_PIN B8  IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

## User LEDs LD4..LD7
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## RGB LEDs LD0..LD3
set_property -dict { PACKAGE_PIN G6  IOSTANDARD LVCMOS33 } [get_ports { led_r[0] }]
set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports { led_g[0] }]
set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports { led_b[0] }]
set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports { led_r[1] }]
set_property -dict { PACKAGE_PIN J4  IOSTANDARD LVCMOS33 } [get_ports { led_g[1] }]
set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS33 } [get_ports { led_b[1] }]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { led_r[2] }]
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { led_g[2] }]
set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { led_b[2] }]
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { led_r[3] }]
set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports { led_g[3] }]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { led_b[3] }]

## USB-UART bridge: FPGA transmit (Digilent name uart_rxd_out)
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]

## FPGA configuration bank voltage
## Verified against Digilent Arty A7-100T Rev E.2 schematic
## CFGBVS_0 is pulled up to VCC3V3 through R178.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## Board inputs are asynchronous and are synchronized inside the design.
## Indicator and UART outputs have no timing relationship to the clock.
set_false_path -from [get_ports { reset sw[*] btn[*] }]
set_false_path -to   [get_ports { led[*] led_r[*] led_g[*] led_b[*] uart_tx }]
