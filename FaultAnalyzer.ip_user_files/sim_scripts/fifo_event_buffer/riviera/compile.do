transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xpm
vlib riviera/fifo_generator_v13_2_14
vlib riviera/xil_defaultlib

vmap xpm riviera/xpm
vmap fifo_generator_v13_2_14 riviera/fifo_generator_v13_2_14
vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xpm  -incr "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93  -incr \
"/opt/Xilinx/2025.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -v2k5 "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../ipstatic/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_14 -93  -incr \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_14  -incr -v2k5 "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../ipstatic/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work xil_defaultlib  -incr -v2k5 "+incdir+../../../../../../../../../opt/Xilinx/2025.2/data/rsb/busdef" -l xpm -l fifo_generator_v13_2_14 -l xil_defaultlib \
"../../../../FaultAnalyzer.gen/sources_1/ip/fifo_event_buffer/sim/fifo_event_buffer.v" \

vlog -work xil_defaultlib \
"glbl.v"

