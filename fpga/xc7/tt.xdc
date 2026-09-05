# Tiny Tapeout wrapper harness on the Arty A7-35 (see tt_top.v).
# Generated from the pin catalog in arty.xdc.

set_property PACKAGE_PIN E3 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]
set_property PACKAGE_PIN C2 [get_ports {ck_rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {ck_rst}]
set_property PACKAGE_PIN D9 [get_ports {btn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[0]}]
set_property PACKAGE_PIN C9 [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[1]}]
set_property PACKAGE_PIN H5 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN J5 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

create_clock -period 10.0 [get_ports {clk}]
