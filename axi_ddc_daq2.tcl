# FFT quad
set ip_name "axi_ddc_daq2"
create_project $ip_name "." -force
source ./util.tcl

# file
set proj_fileset [get_filesets sources_1]
add_files -norecurse -scan_for_includes -fileset $proj_fileset [list \
"axi_ddc_daq2.v" \
"axi_ddc_daq2_core.v" \
]

set_property "top" "axi_ddc_daq2" $proj_fileset

ipx::package_project -root_dir "." -vendor kuhep -library user -taxonomy /kuhep
set_property name $ip_name [ipx::current_core]
set_property vendor_display_name {kuhep} [ipx::current_core]

################################################ IP generation
# Block memory for the first frequency selector
create_ip -vlnv [latest_ip blk_mem_gen] -module_name bram_ring
set_property CONFIG.Memory_Type "Simple_Dual_Port_RAM" [get_ips bram_ring]
set_property CONFIG.Assume_Synchronous_Clk "true" [get_ips bram_ring]
set_property CONFIG.Write_Width_A 14 [get_ips bram_ring]
set_property CONFIG.Write_Depth_A 128 [get_ips bram_ring]
set_property CONFIG.Read_Width_A 14 [get_ips bram_ring]
set_property CONFIG.Operating_Mode_A "READ_FIRST" [get_ips bram_ring]

# Block memory for the second frequency selector
create_ip -vlnv [latest_ip blk_mem_gen] -module_name bram_ring_second
set_property CONFIG.Memory_Type "Simple_Dual_Port_RAM" [get_ips bram_ring_second]
set_property CONFIG.Assume_Synchronous_Clk "true" [get_ips bram_ring_second]
set_property CONFIG.Write_Width_A 4 [get_ips bram_ring_second]
set_property CONFIG.Write_Depth_A 128 [get_ips bram_ring_second]
set_property CONFIG.Read_Width_A 4 [get_ips bram_ring_second]
set_property CONFIG.Operating_Mode_A "READ_FIRST" [get_ips bram_ring_second]

# Block memory for the temporal data storage
create_ip -vlnv [latest_ip blk_mem_gen] -module_name blk_mem_data
set_property CONFIG.Memory_Type "Simple_Dual_Port_RAM" [get_ips blk_mem_data]
set_property CONFIG.Assume_Synchronous_Clk "true" [get_ips blk_mem_data]
set_property CONFIG.Write_Width_A 64 [get_ips blk_mem_data]
set_property CONFIG.Write_Depth_A 4096 [get_ips blk_mem_data]
set_property CONFIG.Read_Width_A 64 [get_ips blk_mem_data]
set_property CONFIG.Operating_Mode_A "READ_FIRST" [get_ips blk_mem_data]

# Block memory for the counter
create_ip -vlnv [latest_ip blk_mem_gen] -module_name blk_mem_counter
set_property CONFIG.Memory_Type "Simple_Dual_Port_RAM" [get_ips blk_mem_counter]
set_property CONFIG.Assume_Synchronous_Clk "true" [get_ips blk_mem_counter]
set_property CONFIG.Write_Width_A 5 [get_ips blk_mem_counter]
set_property CONFIG.Write_Depth_A 128 [get_ips blk_mem_counter]
set_property CONFIG.Read_Width_A 5 [get_ips blk_mem_counter]
set_property CONFIG.Operating_Mode_A "READ_FIRST" [get_ips blk_mem_counter]

# FIFO for the assert logic
create_ip -vlnv [latest_ip fifo_generator] -module_name fifo_assert
set_property CONFIG.Performance_Options "First_Word_Fall_Through" [get_ips fifo_assert]
set_property CONFIG.Input_Data_Width 8 [get_ips fifo_assert]
set_property CONFIG.Input_Depth 512 [get_ips fifo_assert]
set_property CONFIG.Output_Data_Width 8 [get_ips fifo_assert]
set_property CONFIG.Output_Depth 512 [get_ips fifo_assert]

# FFT for fft_second
create_ip -vlnv [latest_ip xfft] -module_name xfft_second
set_property CONFIG.transform_length 16 [get_ips xfft_second]
set_property CONFIG.input_width 29 [get_ips xfft_second]
set_property CONFIG.phase_factor_width 16 [get_ips xfft_second]
set_property CONFIG.scaling_options "unscaled" [get_ips xfft_second]
set_property CONFIG.rounding_modes "convergent_rounding" [get_ips xfft_second]
set_property CONFIG.target_clock_frequency 300 [get_ips xfft_second]
set_property CONFIG.target_data_throughput 300 [get_ips xfft_second]
set_property CONFIG.xk_index true [get_ips xfft_second]

# FIFO for fft_second
create_ip -vlnv [latest_ip fifo_generator] -module_name fifo_second_index
set_property CONFIG.Performance_Options {First_Word_Fall_Through} [get_ips fifo_second_index]
set_property CONFIG.Input_Data_Width 7 [get_ips fifo_second_index]
set_property CONFIG.Input_Depth 512 [get_ips fifo_second_index]
set_property CONFIG.Output_Data_Width 7 [get_ips fifo_second_index]
set_property CONFIG.Output_Depth 512 [get_ips fifo_second_index]

################################################ Register XCI files
# file groups
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/bram_ring/bram_ring.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/bram_ring_second/bram_ring_second.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/blk_mem_data/blk_mem_data.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/blk_mem_counter/blk_mem_counter.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/fifo_assert/fifo_assert.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/fifo_second_index/fifo_second_index.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file ./axi_freq_selector.srcs/sources_1/ip/xfft_second/xfft_second.xci \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]

ipx::reorder_files -after ./axi_freq_selector.srcs/sources_1/ip/xfft_second/xfft_second.xci \
../axi_freq_selector.v \
[ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -before ../axi_freq_selector.v ../second_fft.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -before ../second_fft.v ../ring_rand_second.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -after ./axi_freq_selector.srcs/sources_1/ip/xfft_second/xfft_second.xci ../ring_rand.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -before ../ring_rand.v ../data_transfer.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -after ./axi_freq_selector.srcs/sources_1/ip/xfft_second/xfft_second.xci ../data_store.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::reorder_files -before ../axi_freq_selector.v ../axi_freq_selector_core.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]

# Interface
ipx::infer_bus_interface dev_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::save_core [ipx::current_core]
