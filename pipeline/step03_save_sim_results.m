%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink');
if ~isfolder(outDir), mkdir(outDir); end

%% Load dataset
y = out.get('yout');
mag   = y.getElement(1).Values;                % outport 1 = MagData
valid = y.getElement(2).Values;                % outport 2 = MagValid
md = squeeze(mag.Data);

raw = double(storedInteger(md));           % sfix27_En14 raw integer

v = logical(squeeze(valid.Data));
stream = raw(v); % filter only valid frames
assert(numel(stream) >= 1024, 'Only %d valid samples; increase Stop Time', numel(stream));
stream = stream(1:1024);
fprintf('First MagValid at sample %d\n', find(v, 1));

k = (0:NFFT-1)';
natural = zeros(NFFT, 1);
natural(bins + 1) = stream;

% Save to csv files
writetable(table(k, stream, 'VariableNames', {'Index', 'Magnitude'}), fullfile(outDir, 'simulink_frame_stream.csv'));
writetable(table(k, natural, 'VariableNames', {'Bin', 'Magnitude'}), fullfile(outDir, 'simulink_frame.csv'));
% Verify correct bins
[~, o] = sort(natural, 'descend');
fprintf('Simulink: strongest bin %d (%d), next %d (%d)\n', o(1)-1, natural(o(1)), o(2)-1, natural(o(2)));


frequencies = (0:NFFT-1) * (Fs / NFFT);
figure;
plot(frequencies, natural);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Magnitude Spectrum of the Signal');
xlim([0 Fs]);
saveas(gcf, fullfile(outDir, 'simulink_spectrum.png'));


