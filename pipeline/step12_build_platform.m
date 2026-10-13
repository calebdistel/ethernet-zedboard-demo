%% Vivado must be set up for this MATLAB session (see step 6)
%% For this step you have two options. Option 1 is mandatory for your first build
%% Option 1: create and integrate the Vivado platform manually
% Launch Vivado, create a project, and add the following blocks to a new block design:
% 1. SignalChain IP Core.
% 2. Zynq Processing System
% 3. AXI Direct Memory Access
% Set the Zynq processing system to the Zedboard preset, then set FCLK0 to
% 125MHz and enable AXI Slave HP0 Interface
% Configure the AXI DMA. Disable read Channel and disable SG Engine
% Finally, run Connection Automation to add interconnects and reset block
% Then, generate the HDL wrapper for the block design
% Generate Bitstream (Runs Synthesis and Implementation first)
% Export Hardware platform .xsa including bitstream
% Export using 'Write tcl' to reproduce using Option 2 next time
%% Option 2:The following script can be used to rebuild from tcl
% Must complete Option 1 first
% After building the block design, export to tcl and add it to this
% directory as 'step12_build_platform.tcl'
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'vivado', 'platform');
if ~isfolder(outDir), mkdir(outDir); end

system(['vivado -mode batch -nojournal -nolog -tempDir "' outDir '" -source "' fullfile(here, 'step12_build_platform.tcl') '"']);
