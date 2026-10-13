% Vivado must be set up for this MATLAB session (see step 6)
here = fileparts(mfilename('fullpath'));
simDir = fullfile(here, '..', 'results', 'vivado', 'ip_tb');

system(['vivado -mode batch -nojournal -nolog -tempDir "' simDir '" -source "' fullfile(here, 'step10_run_ip_tb.tcl') '"']);
