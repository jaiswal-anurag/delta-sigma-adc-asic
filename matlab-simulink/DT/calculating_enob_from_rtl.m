%% --- FILTER CHAIN ANALYSIS SCRIPT ---
clear; clc; close all;

% --- 1. Parameters ---
filename = 'output_results.txt';
fs = 2000;  % Output Sample Rate (2 kHz)

% --- 2. Load Data ---
if ~isfile(filename)
    error('Error: "%s" not found. Run the Verilog simulation first.', filename);
end

fprintf('Loading simulation results from %s...\n', filename);
sim_data = load(filename); % Loads data into a column vector

% Convert to double for analysis
sim_output = double(sim_data);

% Remove initial transient response (optional but recommended)
% Filters take time to settle. We ignore the first 100 samples.
if length(sim_output) > 100
    sim_output = sim_output(100:end);
else
    warning('Data length is short. Transients might affect accuracy.');
end

% --- 3. Calculate SINAD & ENOB ---
fprintf('Analyzing spectrum...\n');

% Calculate SINAD (Signal to Noise and Distortion Ratio)
% This function automatically finds the fundamental frequency peak.
[sinad_dB, thd_dB] = sinad(sim_output, fs);

% Calculate ENOB
% Formula: ENOB = (SINAD - 1.76) / 6.02
enob = (sinad_dB - 1.76) / 6.02;

% --- 4. Display Results ---
fprintf('\n========================================\n');
fprintf('       RTL SIMULATION RESULTS           \n');
fprintf('========================================\n');
fprintf('Data Points:      %d\n', length(sim_output));
fprintf('SINAD:            %.2f dB\n', sinad_dB);
fprintf('THD:              %.2f dB\n', thd_dB);
fprintf('----------------------------------------\n');
fprintf('Calculated ENOB:  %.2f bits\n', enob);
fprintf('========================================\n');

% --- 5. Plot Spectrum (Visual Verification) ---
figure('Name', 'RTL Output Spectrum', 'Color', 'w');
periodogram(sim_output, rectwin(length(sim_output)), length(sim_output), fs);
title(['RTL Output Spectrum (ENOB = ' num2str(enob, '%.2f') ' bits)']);
grid on;