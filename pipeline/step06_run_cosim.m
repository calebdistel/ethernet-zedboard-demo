% Signal Parameters must be in workspace before running this
% Vivado must be set up for this MATLAB session (adds bin and the xsim kernel libs to PATH):
hdlsetuptoolpath('ToolName', 'Xilinx Vivado', 'ToolPath', 'C:\Xilinx\Vivado\2024.1\bin\vivado.bat');
here = fileparts(mfilename('fullpath'));
model = 'SignalChainModelWithNCO';
cosimModel = ['gm_' model '_vs'];
srcDir = fullfile(here, '..', 'results', 'simulink', 'hdlsrc', model);

load_system(fullfile(srcDir, [cosimModel '.slx']));

% Compile HDL into the xsim DLL (same as double-clicking 'Start Simulator')
open_system([cosimModel '/Start Simulator']);

% Log the HDL outputs (the model outports carry the Simulink DUT outputs)
ph = get_param([cosimModel '/SignalChain_vs'], 'PortHandles');
set_param(ph.Outport(1), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'hdl_mag_data');
set_param(ph.Outport(2), 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'hdl_mag_valid');

% xsim loads xsim.dir/design/xsimk.dll relative to the current folder,
% so run the cosim from the HDL source folder
workingDir = pwd;
cd(srcDir);

% Compare block asserts HDL == Simulink on every sample
cosimOut = sim(cosimModel);

cd(workingDir);
