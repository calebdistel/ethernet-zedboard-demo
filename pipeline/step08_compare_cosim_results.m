%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink');

ref = readtable(fullfile(outDir, 'reference_frame.csv'));
sl  = readtable(fullfile(outDir, 'simulink_frame.csv'));
hdl = readtable(fullfile(outDir, 'cosim_frame.csv'));

fprintf('HDL cosim vs Simulink: max |difference| = %g LSB\n', max(abs(sl.Magnitude - hdl.Magnitude)));

%% Plot
plotSpectrumComparison(ref.Bin, {ref.Magnitude, sl.Magnitude, hdl.Magnitude}, ...
    {'Reference', 'Simulink', 'HDL cosim'}, ...
    'Reference vs. Simulink vs. HDL Cosimulation', ...
    fullfile(outDir, 'reference_vs_simulink_vs_cosim.png'));
