%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'simulink');
if ~isfolder(outDir), mkdir(outDir); end
%% setup NCO parameters

F    = 50e6;     % 50 MHz signal frequency  (F/Fs = 0.4, same bins as the original 100 MHz / 250 MHz plan)
Fs   = 125e6;    % 125 MHz sampling frequency = FPGA fabric clock (FCLK0)
NFFT = 1024;     % FFT length

expected_FFT_bin       = round((F / Fs) * NFFT)          % 410 (409.6 rounded)
expected_conjugate_bin = NFFT - expected_FFT_bin         % 614

%% Floating-point reference spectrum
t = 0:1/Fs:(NFFT-1)/Fs;                  % NFFT samples
signal = sin(2*pi*F*t);
magnitude_spectrum = abs(fft(signal, NFFT));
frequencies = (0:NFFT-1) * (Fs / NFFT);
figure; plot(frequencies, magnitude_spectrum);
xlabel('Frequency (Hz)'); ylabel('Magnitude');
title('Magnitude Spectrum of the Signal'); xlim([0 Fs]);
saveas(gcf, fullfile(outDir, 'reference_spectrum.png'));

bins = 0:(NFFT-1);

writetable(table(bins', magnitude_spectrum(:), 'VariableNames', {'Bin', 'Magnitude'}), fullfile(outDir, 'reference_frame.csv'));

%% NCO parameters for HDL generation
PHASE_BITS = 32;
phase_increment = round((F / Fs) * 2^PHASE_BITS)        % 1717986918 (0x66666666)
% The NCO block's accumulator is 16 bits, so this acts as
% mod(phase_increment, 2^16) = 26214 (0x6666) per sample.
nco_amplitude = 1.0;
phase_offset  = 0;
dither_bits   = 4;
