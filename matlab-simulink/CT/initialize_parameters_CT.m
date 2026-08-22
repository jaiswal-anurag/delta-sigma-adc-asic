[num, den] = butter(1, [80 120]/(2000/2), 'bandpass');
% Fs_mid = 256000 / 128 (New intermediate rate: 2000 Hz)
% Passband = 900 Hz
% Normalized Passband = 900 / (2000 / 2) = 0.9
% This is very wide, let's use a standard half-band.
N = 50; % Filter order
b_fir = firhalfband(N, 0.45); % 0.45 is a good default