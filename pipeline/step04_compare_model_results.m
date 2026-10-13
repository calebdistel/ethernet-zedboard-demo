%% Compare the Simulink frame against the floating-point reference.
% Reads the CSVs written by step1 and step3, so it does not depend on the
% workspace.

%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink');
if ~isfolder(outDir), mkdir(outDir); end

ref = readtable(fullfile(outDir, 'reference_frame.csv'));
sl  = readtable(fullfile(outDir, 'simulink_frame.csv'));

%% Plot
plotSpectrumComparison(ref.Bin, {ref.Magnitude, sl.Magnitude}, {'Reference', 'Simulink'}, ...
    'Simulink Model vs. Floating-Point Reference', fullfile(outDir, 'simulink_vs_reference.png'));
