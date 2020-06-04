# FFT quad
set ip_name "axi_ddc_daq2"
create_project $ip_name "./test_ip" -force
source ./util.tcl

# file
set proj_fileset [get_filesets sources_1]
add_files -norecurse -scan_for_includes -fileset $proj_fileset [list \
"axi_ddc_daq2.v" \
"axi_ddc_daq2_core.v" \
"accumulator.v" \
"ddc_core.v" \
"ddc_quad.v" \
]

set_property "top" "axi_ddc_daq2" $proj_fileset

ipx::package_project -root_dir "./test_ip" -vendor kuhep -library user -taxonomy /kuhep
set_property name $ip_name [ipx::current_core]
set_property vendor_display_name {kuhep} [ipx::current_core]

################################################ IP generation
############### DDC QUAD
### DDS
create_ip -vlnv [latest_ip dds_compiler] -module_name dds
set_property CONFIG.Parameter_Entry "Hardware_Parameters" [get_ips dds]
set_property CONFIG.PINC1 0 [get_ips dds]
set_property CONFIG.DDS_Clock_Rate 250 [get_ips dds]
set_property CONFIG.Mode_of_Operation "Standard" [get_ips dds]
set_property CONFIG.Phase_Increment "Streaming" [get_ips dds]
set_property CONFIG.Phase_offset "Streaming" [get_ips dds]
set_property CONFIG.Phase_Width 20 [get_ips dds]
set_property CONFIG.Output_Width 14 [get_ips dds]
set_property CONFIG.Noise_Shaping "None" [get_ips dds]
set_property CONFIG.Resync {true} [get_ips dds]

### DDC core
#### Multiplier
create_ip -vlnv [latest_ip mult_gen] -module_name multiplier
set_property CONFIG.PortAWidth 14 [get_ips multiplier]
set_property CONFIG.PortBWidth 14 [get_ips multiplier]
set_property CONFIG.Multiplier_Construction "Use_Mults" [get_ips multiplier]
set_property CONFIG.OptGoal "Area" [get_ips multiplier]
set_property CONFIG.OutputWidthHigh 29 [get_ips multiplier]
set_property CONFIG.PipeStages 3 [get_ips multiplier]
set_property generate_synth_checkpoint 0 [get_files multiplier.xci]

#### Adder
create_ip -vlnv [latest_ip c_addsub] -module_name adder
set_property CONFIG.A_Width 28 [get_ips adder]
set_property CONFIG.B_Width 28 [get_ips adder]
set_property CONFIG.Out_Width 29 [get_ips adder]
set_property CONFIG.CE "false" [get_ips adder]
set_property CONFIG.Latency 3 [get_ips adder]
set_property generate_synth_checkpoint 0 [get_files adder.xci]

#### Subtracter
create_ip -vlnv [latest_ip c_addsub] -module_name subtracter
set_property CONFIG.Add_Mode "Subtract" [get_ips subtracter]
set_property CONFIG.A_Width 28 [get_ips subtracter]
set_property CONFIG.B_Width 28 [get_ips subtracter]
set_property CONFIG.Out_Width 29 [get_ips subtracter]
set_property CONFIG.CE "false" [get_ips subtracter]
set_property CONFIG.Latency 3 [get_ips subtracter]
set_property generate_synth_checkpoint 0 [get_files subtracter.xci]

#### Adder for phase
create_ip -vlnv [latest_ip c_addsub] -module_name adder_phase
set_property CONFIG.A_Width 20 [get_ips adder_phase]
set_property CONFIG.B_Width 20 [get_ips adder_phase]
set_property CONFIG.Out_Width 20 [get_ips adder_phase]
set_property CONFIG.CE "false" [get_ips adder_phase]
set_property CONFIG.Latency 3 [get_ips adder_phase]
set_property generate_synth_checkpoint 0 [get_files adder_phase.xci]

#### 1st stage adder
create_ip -vlnv [latest_ip c_addsub] -module_name adder_1st
set_property CONFIG.A_Width 29 [get_ips adder_1st]
set_property CONFIG.B_Width 29 [get_ips adder_1st]
set_property CONFIG.Out_Width 30 [get_ips adder_1st]
set_property CONFIG.CE "false" [get_ips adder_1st]
set_property CONFIG.Latency 3 [get_ips adder_1st]
set_property generate_synth_checkpoint 0 [get_files adder_1st.xci]

#### 2nd stage adder
create_ip -vlnv [latest_ip c_addsub] -module_name adder_2nd
set_property CONFIG.A_Width 30 [get_ips adder_2nd]
set_property CONFIG.B_Width 30 [get_ips adder_2nd]
set_property CONFIG.Out_Width 31 [get_ips adder_2nd]
set_property CONFIG.CE "false" [get_ips adder_2nd]
set_property CONFIG.Latency 3 [get_ips adder_2nd]
set_property generate_synth_checkpoint 0 [get_files adder_2nd.xci]

############### Accumulator
### Accumulator
create_ip -vlnv [latest_ip c_accum] -module_name c_accum
set_property CONFIG.Implementation {DSP48} [get_ips c_accum]
set_property CONFIG.Input_Width {31} [get_ips c_accum]
set_property CONFIG.Output_Width {48} [get_ips c_accum]
set_property CONFIG.Latency_Configuration {Manual} [get_ips c_accum]
set_property CONFIG.Latency {2} [get_ips c_accum]
set_property CONFIG.SCLR {false} [get_ips c_accum]
set_property CONFIG.Bypass {true} [get_ips c_accum]


################################################ Register XCI files
# file groups
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/dds/dds.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/multiplier/multiplier.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/adder/adder.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/subtracter/subtracter.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/adder_phase/adder_phase.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/adder_1st/adder_1st.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/adder_2nd/adder_2nd.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_ddc_daq2.srcs/sources_1/ip/c_accum/c_accum.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]

# Reordering
ipx::reorder_files -after ./axi_ddc_daq2.srcs/sources_1/ip/c_accum/c_accum.xci ../axi_ddc_daq2.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -after ../ddc_quad.v ../axi_ddc_daq2_core.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]

# Interface
ipx::infer_bus_interface dev_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::save_core [ipx::current_core]
