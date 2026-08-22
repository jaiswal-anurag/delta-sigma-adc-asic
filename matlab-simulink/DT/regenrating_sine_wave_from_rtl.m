%% --- RAW ADC DATA VISUALIZATION ---
clear; clc; close all;

% --- 1. Parameters ---
filename = 'output_results.txt';
fs = 2000;  % Sample Rate (2 kHz)

% --- 2. Load Data ---
if ~isfile(filename)
    error('File %s not found.', filename);
end

sim_data = load(filename);
sim_output = double(sim_data);

% Create Time Vector
N = length(sim_output);
t = (0:N-1) / fs;

% --- 3. Plot Raw Discrete Steps ---
figure('Color', 'w');

% 'stairs' draws a horizontal line for the duration of the sample, 
% then a vertical line to the next value. This is how a DAC sees data.
stairs(t, sim_output, 'b', 'LineWidth', 1.2); 

grid on;
title('Raw Discrete ADC Output (Step Plot)');
xlabel('Time (seconds)');
ylabel('Digital Code Value');

% Set axis limits to focus on the data range
xlim([0 max(t)]);