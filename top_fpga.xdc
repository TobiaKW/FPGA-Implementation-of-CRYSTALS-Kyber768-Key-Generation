# top_fpga wrapper constraints (ZedBoard / xc7z020clg484-1)

# 100 MHz board clock
set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]

# Control inputs (map to slide switches for simple bring-up)
set_property PACKAGE_PIN G22 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

set_property PACKAGE_PIN F22 [get_ports top_start]
set_property IOSTANDARD LVCMOS33 [get_ports top_start]

# Status output (map to LED0)
set_property PACKAGE_PIN T22 [get_ports top_done]
set_property IOSTANDARD LVCMOS33 [get_ports top_done]

