%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink');
if ~isfolder(outDir), mkdir(outDir); end

%% Load dataset
mag   = cosimOut.logsout.get('hdl_mag_data').Values;
valid = cosimOut.logsout.get('hdl_mag_valid').Values;

raw = double(storedInteger(squeeze(mag.Data)));  % sfix27_En14 raw integer
v = logical(squeeze(valid.Data));

% Raw cosim output, every sample
writetable(table(mag.Time, v, raw, 'VariableNames', {'Time', 'MagValid', 'MagData'}), fullfile(outDir, 'cosim_raw.csv'));

hdlStream = raw(v); % filter only valid frames
assert(numel(hdlStream) >= 1024, 'Only %d valid samples; increase Stop Time', numel(hdlStream));
hdlStream = hdlStream(1:1024);
fprintf('First MagValid at sample %d\n', find(v, 1));

k = (0:NFFT-1)';
hdlNatural = zeros(NFFT, 1);
hdlNatural(bins + 1) = hdlStream;

% Save to csv files
writetable(table(k, hdlStream, 'VariableNames', {'Index', 'Magnitude'}), fullfile(outDir, 'cosim_frame_stream.csv'));
writetable(table(k, hdlNatural, 'VariableNames', {'Bin', 'Magnitude'}), fullfile(outDir, 'cosim_frame.csv'));
% Verify correct bins
[~, o] = sort(hdlNatural, 'descend');
fprintf('HDL cosim: strongest bin %d (%d), next %d (%d)\n', o(1)-1, hdlNatural(o(1)), o(2)-1, hdlNatural(o(2)));

frequencies = (0:NFFT-1) * (Fs / NFFT);
figure;
plot(frequencies, hdlNatural);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('HDL Cosimulation Magnitude Spectrum');
xlim([0 Fs]);
saveas(gcf, fullfile(outDir, 'cosim_spectrum.png'));
