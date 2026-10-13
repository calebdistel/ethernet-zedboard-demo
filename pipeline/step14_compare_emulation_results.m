%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'emulation');
slDir = fullfile(here, '..', 'results', 'simulink');

ref = readtable(fullfile(slDir, 'reference_frame.csv'));
sl  = readtable(fullfile(slDir, 'simulink_frame.csv'));

% Consecutive IP core frames (step 11), one column per frame
ipStream = readtable(fullfile(here, '..', 'results', 'vivado', 'ip_stream.csv')).TDATA;
ipFrames = reshape(ipStream(1:floor(end/1024)*1024), 1024, []);

%% Every received frame should match the IP core frame with the same number
files = dir(fullfile(outDir, 'udp_frame_*.csv'));
assert(~isempty(files), 'No UDP frames in %s; run step 13 first', outDir);
for i = 1:numel(files)
    n = sscanf(files(i).name, 'udp_frame_%d.csv');
    udp = readtable(fullfile(outDir, files(i).name));
    fprintf('%s vs IP core frame %d: max |difference| = %g LSB\n', files(i).name, n, max(abs(udp.Magnitude - ipFrames(:, n))));
    if n > 1
        prev = readtable(fullfile(outDir, sprintf('udp_frame_%d.csv', n-1)));
        fprintf('    differs from frame %d in %d/1024 bins (consecutive frames, not repeats)\n', n-1, nnz(udp.Magnitude ~= prev.Magnitude));
    end
end

%% Plot frame 1 (HDL cosim is bit-exact to Simulink and the IP core, so it is left out)
udp = readtable(fullfile(outDir, 'udp_frame_1.csv'));
plotSpectrumComparison(ref.Bin, {ref.Magnitude, sl.Magnitude, ipFrames(:, 1), udp.Magnitude}, ...
    {'Reference', 'Simulink', 'IP core', 'Emulated board (UDP)'}, ...
    'Reference vs. Simulink vs. IP Core vs. Emulated Board', ...
    fullfile(outDir, 'reference_vs_simulink_vs_ip_vs_emulation.png'));
