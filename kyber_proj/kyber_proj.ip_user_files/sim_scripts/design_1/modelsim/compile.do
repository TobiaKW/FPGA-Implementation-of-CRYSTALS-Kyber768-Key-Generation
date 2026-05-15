vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/axi_infrastructure_v1_1_0
vlib modelsim_lib/msim/axi_vip_v1_1_22
vlib modelsim_lib/msim/processing_system7_vip_v1_0_24
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/proc_sys_reset_v5_0_17
vlib modelsim_lib/msim/smartconnect_v1_0
vlib modelsim_lib/msim/axi_register_slice_v2_1_36
vlib modelsim_lib/msim/fifo_generator_v13_2_14

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap axi_infrastructure_v1_1_0 modelsim_lib/msim/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_22 modelsim_lib/msim/axi_vip_v1_1_22
vmap processing_system7_vip_v1_0_24 modelsim_lib/msim/processing_system7_vip_v1_0_24
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap proc_sys_reset_v5_0_17 modelsim_lib/msim/proc_sys_reset_v5_0_17
vmap smartconnect_v1_0 modelsim_lib/msim/smartconnect_v1_0
vmap axi_register_slice_v2_1_36 modelsim_lib/msim/axi_register_slice_v2_1_36
vmap fifo_generator_v13_2_14 modelsim_lib/msim/fifo_generator_v13_2_14

vlog -work xilinx_vip  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/axi_vip_if.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/clk_vip_if.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"C:/Xilinx/2025.2.1/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"C:/Xilinx/2025.2.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/Xilinx/2025.2.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axi_infrastructure_v1_1_0  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_22  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/b16a/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work processing_system7_vip_v1_0_24  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_processing_system7_0_0/sim/design_1_processing_system7_0_0.v" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/sim/bd_6f02.v" \

vcom -work proc_sys_reset_v5_0_17  -93  \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9438/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib  -93  \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_1/sim/bd_6f02_psr_aclk_0.vhd" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/sc_util_v1_0_vl_rfs.sv" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/3d9a/hdl/sc_mmu_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_2/sim/bd_6f02_s00mmu_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/7785/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_3/sim/bd_6f02_s00tr_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/3051/hdl/sc_si_converter_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_4/sim/bd_6f02_s00sic_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/852f/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_5/sim/bd_6f02_s00a2s_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/sc_node_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_6/sim/bd_6f02_sarn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_7/sim/bd_6f02_srn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_8/sim/bd_6f02_sawn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_9/sim/bd_6f02_swn_0.sv" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_10/sim/bd_6f02_sbn_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/fca9/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_11/sim/bd_6f02_m00s2a_0.sv" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/e44a/hdl/sc_exit_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/bd_0/ip/ip_12/sim/bd_6f02_m00e_0.sv" \

vcom -work smartconnect_v1_0  -93  \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.vhd" \

vlog -work smartconnect_v1_0  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/cb42/hdl/sc_ultralite_v1_0_rfs.sv" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/0848/hdl/sc_switchboard_v1_0_vl_rfs.sv" \

vlog -work axi_register_slice_v2_1_36  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/bc4b/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib  -incr -mfcu  -sv -L smartconnect_v1_0 -L axi_vip_v1_1_22 -L processing_system7_vip_v1_0_24 -L xilinx_vip "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_axi_smc_1/sim/design_1_axi_smc_1.sv" \

vcom -work xil_defaultlib  -93  \
"../../../bd/design_1/ip/design_1_rst_ps7_0_50M_1/sim/design_1_rst_ps7_0_50M_1.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_8/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_14  -93  \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_8/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../../kyber_proj.gen/sources_1/bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_8/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_8/sim/fifo_generator_8.v" \
"../../../bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_7/sim/fifo_generator_7.v" \
"../../../bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_1/sim/fifo_generator_1.v" \
"../../../bd/design_1/ip/design_1_topserver_axi_0_8/src/fifo_generator_0/sim/fifo_generator_0.v" \
"../../../bd/design_1/ipshared/970e/src/BRAM.v" \
"../../../bd/design_1/ipshared/970e/src/BROM.v" \
"../../../bd/design_1/ipshared/970e/src/FA.v" \
"../../../bd/design_1/ipshared/970e/src/HA.v" \
"../../../bd/design_1/ipshared/970e/src/KyberHPM1PE.v" \
"../../../bd/design_1/ipshared/970e/src/KyberHPM1PE_top.v" \
"../../../bd/design_1/ipshared/970e/src/a_gen.v" \
"../../../bd/design_1/ipshared/970e/src/addressgenerator.v" \
"../../../bd/design_1/ipshared/970e/src/bram_sdp_12x768.v" \
"../../../bd/design_1/ipshared/970e/src/butterfly.v" \
"../../../bd/design_1/ipshared/970e/src/decode_keccak.v" \
"../../../bd/design_1/ipshared/970e/src/div2.v" \
"../../../bd/design_1/ipshared/970e/src/dt0.v" \
"../../../bd/design_1/ipshared/970e/src/dt1.v" \
"../../../bd/design_1/ipshared/970e/src/dt2.v" \
"../../../bd/design_1/ipshared/970e/src/dt3.v" \
"../../../bd/design_1/ipshared/970e/src/hash_core_Server.v" \
"../../../bd/design_1/ipshared/970e/src/hash_unit.v" \
"../../../bd/design_1/ipshared/970e/src/intmul.v" \
"../../../bd/design_1/ipshared/970e/src/mat_vec_mul.v" \
"../../../bd/design_1/ipshared/970e/src/modadd.v" \
"../../../bd/design_1/ipshared/970e/src/modmul.v" \
"../../../bd/design_1/ipshared/970e/src/modred.v" \
"../../../bd/design_1/ipshared/970e/src/modsub.v" \
"../../../bd/design_1/ipshared/970e/src/se_gen.v" \
"../../../bd/design_1/ipshared/970e/src/shiftreg.v" \
"../../../bd/design_1/ipshared/970e/src/topserver.v" \

vcom -work xil_defaultlib  -93  \
"../../../bd/design_1/ipshared/970e/src/Keccak1600.vhd" \
"../../../bd/design_1/ipshared/970e/src/RegisterFDRE.vhd" \
"../../../bd/design_1/ipshared/970e/src/Round.vhd" \
"../../../bd/design_1/ipshared/970e/src/StateMachine.vhd" \
"../../../bd/design_1/ipshared/970e/src/chi.vhd" \
"../../../bd/design_1/ipshared/970e/src/iota.vhd" \
"../../../bd/design_1/ipshared/970e/src/neoTRNG.vhd" \
"../../../bd/design_1/ipshared/970e/src/pi.vhd" \
"../../../bd/design_1/ipshared/970e/src/rho.vhd" \
"../../../bd/design_1/ipshared/970e/src/theta.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/ec67/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/9a25/hdl" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/f0b6/hdl/verilog" "+incdir+../../../../kyber_proj.gen/sources_1/bd/design_1/ipshared/00fe/hdl/verilog" "+incdir+../../../../../../../../Xilinx/2025.2.1/Vivado/data/rsb/busdef" "+incdir+C:/Xilinx/2025.2.1/Vivado/data/xilinx_vip/include" \
"../../../bd/design_1/ipshared/970e/src/topserver_axi.v" \
"../../../bd/design_1/ip/design_1_topserver_axi_0_8/sim/design_1_topserver_axi_0_8.v" \
"../../../bd/design_1/sim/design_1.v" \

vlog -work xil_defaultlib \
"glbl.v"

