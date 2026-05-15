
#clk, name: SYSCLK, port: H4
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
set_property PACKAGE_PIN H4 [get_ports clk]         
set_property IOSTANDARD LVCMOS33 [get_ports clk]

#rst, name: FPGA_RST, port: D14
set_property PACKAGE_PIN D14 [get_ports rst_n]          
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

#Led green, Name: FPGA_LED1, port: J1
set_property PACKAGE_PIN J1 [get_ports led_green]       
set_property IOSTANDARD LVCMOS33 [get_ports led_green]

#led red, Name: FPGA_LED2, port: A13
set_property PACKAGE_PIN A13 [get_ports led_red]       
set_property IOSTANDARD LVCMOS33 [get_ports led_red]

#button 1, Name:FPGA_IO10, port: C3
set_property PACKAGE_PIN C3 [get_ports button_1]        
set_property IOSTANDARD LVCMOS33 [get_ports button_1]

#button 2, Name:FPGA_IO11, port: M4
set_property PACKAGE_PIN M4 [get_ports button_2]        
set_property IOSTANDARD LVCMOS33 [get_ports button_2]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]