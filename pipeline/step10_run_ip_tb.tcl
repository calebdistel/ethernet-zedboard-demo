# IP-level simulation of the HDL Coder IP core (run by step10_run_ip_tb.m).
# Builds a throwaway Vivado project with the IP core HDL + tb/tb_signalchain_ip.sv
# (Vivado sorts the compile order) and runs it in xsim until $finish.
# Output: results/vivado/ip_tb/ip_stream.txt (one "TDATA TLAST" line per beat)

set here    [file normalize [file dirname [info script]]]
set root    [file normalize $here/..]
set ip_dir  $root/results/vivado/hdl_prj/ipcore/SignalCha_ip_v1_0
set sim_dir $root/results/vivado/ip_tb

create_project ip_tb $sim_dir/prj -part xc7z020clg484-1 -force
add_files [glob $ip_dir/hdl/*.vhd]
add_files -fileset sim_1 $here/tb/tb_signalchain_ip.sv
set_property top tb_signalchain_ip [get_filesets sim_1]

set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg out=$sim_dir/ip_stream.txt" -objects [get_filesets sim_1]

launch_simulation
close_project
