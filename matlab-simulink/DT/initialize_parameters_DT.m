%% --- FILTER COEFFICIENT GENERATOR (V2) ---
clear; clc;

% --- 1. System Parameters ---
fs_mod = 256000;      % Modulator Input Rate
R_cic  = 64;          % CIC Decimation Factor
fs_cic = fs_mod / R_cic; % Intermediate Rate (4000 Hz)
R_fir  = 2;           % FIR Decimation Factor
fs_out = fs_cic / R_fir; % Final Rate (2000 Hz)

fprintf('System Rates:\n');
fprintf('  Modulator: %d Hz\n', fs_mod);
fprintf('  CIC Out:   %d Hz\n', fs_cic);
fprintf('  Final:     %d Hz\n', fs_out);

% --- 2. FIR Filter Design (Stage 2) ---
% Goal: Lowpass with cutoff near 1000Hz (Nyquist of final stage)
% Input Rate: 4000 Hz.
% We use a standard Equiripple FIR (fir1 is robust and standard).
N_fir = 64;    % Filter Order (Higher = sharper cutoff)
F_cutoff = 800; % Cutoff freq (Hz) - well below Nyquist to stop aliasing
W_n = F_cutoff / (fs_cic/2); % Normalized frequency (0 to 1)

% Design the coefficients
b_fir = fir1(N_fir, W_n, 'low');

fprintf('\n--- [BLOCK 2] FIR Decimation Settings ---\n');
fprintf('  Coefficients:      b_fir\n');
fprintf('  Decimation factor: %d\n', R_fir);

% --- 3. IIR Highpass Design (Stage 3 - DC Blocker) ---
% Goal: Remove DC offset, pass 300 Hz.
% Input Rate: 2000 Hz.
% Cutoff: 20 Hz.
N_iir = 1; % 1st order is sufficient
W_high = 20 / (fs_out/2);
[b_iir, a_iir] = butter(N_iir, W_high, 'high');

fprintf('\n--- [BLOCK 3] Discrete Filter (IIR) Settings ---\n');
fprintf('  Numerator (b):     b_iir\n');
fprintf('  Denominator (a):   a_iir\n');

fprintf('\n>> Coefficients "b_fir", "b_iir", and "a_iir" are now in your Workspace.\n');