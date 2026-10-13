%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink', 'hdlsrc');
if ~isfolder(outDir), mkdir(outDir); end

model = 'SignalChainModelWithNCO';
dut = [model '/SignalChain'];
cosimModel = ['gm_' model '_vs'];
srcDir = fullfile(outDir, model);
load_system(model);

%% Generate HDL
hdlset_param(model, 'TargetLanguage', 'VHDL');
hdlset_param(model, 'TargetDirectory', outDir);
hdlset_param(model, 'TargetPlatform', 'ZedBoard');
hdlset_param(model, 'SynthesisTool', 'Xilinx Vivado');
hdlset_param(model, 'SynthesisToolChipFamily', 'Zynq-7000');
hdlset_param(model, 'SynthesisToolDeviceName', 'xc7z020clg484-1');
hdlset_param(model, 'ClockHighTime', 4);   % 8 ns clock = 125 MHz
hdlset_param(model, 'ClockLowTime', 4);
makehdl(dut);

%% Generate Vivado Simulator cosimulation model
hdlset_param(model, 'GenerateHDLTestBench', 'off');
hdlset_param(model, 'GenerateCoSimModel', 'Vivado Simulator');
makehdltb(dut);
save_system(cosimModel, fullfile(srcDir, [cosimModel '.slx']));
