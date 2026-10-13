%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'vivado', 'hdl_prj');
if ~isfolder(outDir), mkdir(outDir); end

model = 'SignalChainModelWithNCO';
dut = [model '/SignalChain'];
load_system(model);

%% Target: IP core only, for our own Vivado block design
hdlset_param(model, 'Workflow', 'IP Core Generation');
hdlset_param(model, 'TargetPlatform', 'Generic Xilinx Platform');
hdlset_param(model, 'TargetLanguage', 'VHDL');
hdlset_param(model, 'SynthesisTool', 'Xilinx Vivado');
hdlset_param(model, 'SynthesisToolChipFamily', 'Zynq');   % xc7z020clg484-1
hdlset_param(model, 'SynthesisToolDeviceName', 'xc7z020');
hdlset_param(model, 'SynthesisToolPackageName', 'clg484');
hdlset_param(model, 'SynthesisToolSpeedValue', '-1');
hdlset_param(model, 'TargetFrequency', 125);   % FCLK0

%% Port to interface mapping
% enable    -> AXI4-Lite register (replaces the AXI GPIO start control)
% mag_data  -> AXI4-Stream master data (padded to 32 bits, TLAST generated)
% mag_valid -> AXI4-Stream master valid
hdlset_param([dut '/enable'],    'IOInterface', 'AXI4-Lite',          'IOInterfaceMapping', 'x"100"');
hdlset_param([dut '/mag_data'],  'IOInterface', 'AXI4-Stream Master', 'IOInterfaceMapping', 'Data');
hdlset_param([dut '/mag_valid'], 'IOInterface', 'AXI4-Stream Master', 'IOInterfaceMapping', 'Valid');

%% Run only the RTL + IP core task
hWC = hdlcoder.WorkflowConfig('SynthesisTool', 'Xilinx Vivado', 'TargetWorkflow', 'IP Core Generation');
hWC.ProjectFolder = outDir;
hWC.RunTaskGenerateRTLCodeAndIPCore = true;
hWC.RunTaskCreateProject = false;
hWC.RunTaskGenerateSoftwareInterface = false;
hWC.RunTaskBuildFPGABitstream = false;
hWC.RunTaskProgramTargetDevice = false;

hdlcoder.runWorkflow(dut, hWC);
