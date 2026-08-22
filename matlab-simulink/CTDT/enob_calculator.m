% --- 1. Define Simulation Parameters ---
fs = 2000;  % Nyquist Sample Rate (2000 Hz)
fprintf('--- ------------------------------------ ---\n');
fprintf('--- STARTING ADC PERFORMANCE ANALYSIS ---');
fprintf('\n---------------------------------------- ---\n');
fprintf('Analysis Sample Rate (fs): %.0f Hz\n', fs);

% --- 2. Get Data from Simulink ---
% Changing variable check to 'probe_final'
if ~exist('probe_final', 'var')
    error('Output variable "probe_final" not found in workspace. Please run your simulation first.');
end

% Check if the data is in a Timeseries object
if isa(probe_final, 'timeseries')
    sim_output = probe_final.Data;
else
    sim_output = probe_final; % Assumes it's an array
end

% --- !!! KEY CHANGE HERE !!! ---
% This line "unrolls" the matrix (e.g., 1024xN) into one
% long column vector, which is what sinad expects.
sim_output = sim_output(:);
% --- !!! END OF CHANGE !!! ---

% Convert to double, just in case it's fixed-point
fprintf('Converting data to double...\n');
sim_output = double(sim_output);

% --- 3. Calculate SINAD (SNR) ---
fprintf('Analyzing filtered output spectrum...\n');
[sinad_dB, thd_dB] = sinad(sim_output, fs);

% --- 4. Final Calculation ---
SNR_dB = sinad_dB; 
ENOB = (SNR_dB - 1.76) / 6.02;

% --- 5. Display the Results ---
fprintf('\n--- ------------------------------------ ---\n');
fprintf('--- SIMULATION ANALYSIS RESULTS ---');
fprintf('\n---------------------------------------- ---\n');
fprintf('Calculated SINAD (SNR): %.2f dB\n', SNR_dB);
fprintf('Calculated ENOB:        %.2f bits\n', ENOB);
fprintf('--- ------------------------------------ ---\n');