% automation_strict_enob_modulator.m
% 1. Designs filters (mapped to b_fir, b_iir, a_iir).
% 2. Clears old data -> Runs 'Modulator_DT' -> Reads 'probe_final'.
% 3. Calculates ENOB using YOUR logic.
% 4. Displays a summary table in the terminal and plots the graph.

clear; clc; close all;

%% ========================================================================
%  PART 1: FILTER DESIGN 
%  (Ideally, ensure these Fs/Pass specs match your Modulator_DT requirements)
%  ========================================================================

Fs_in = 256000;       
F_pass = 900;          
F_stop = 1000;        
Lcomp = 128;          

% --- FIR Filter Design (Mapped to b_fir) ---
% Using the CIC Compensation logic from your previous script
nGrid = 2000; f_grid = linspace(0,1,nGrid);
R = 32; Kc = 4; w_grid = 2*pi*f_grid;
Hcic_grid = ((1/R) .* (sin(w_grid*R/2) ./ (sin(w_grid/2) + eps))).^Kc; Hcic_grid(1) = 1;
fp_norm = F_pass / (Fs_in/2); fst_norm = F_stop / (Fs_in/2);
des = zeros(size(f_grid)); pass_idx = f_grid <= fp_norm; trans_idx = (f_grid > fp_norm) & (f_grid < fst_norm);
des(pass_idx) = 1 ./ Hcic_grid(pass_idx);
if any(trans_idx), des(trans_idx) = linspace(des(find(pass_idx,1,'last')), 0, sum(trans_idx)); end
nPts = 400; sel = round(linspace(1, nGrid, nPts));
freq_firls = f_grid(sel); mag_firls  = des(sel);
if freq_firls(1) ~= 0, freq_firls = [0, freq_firls]; mag_firls = [mag_firls(1), mag_firls]; end
if freq_firls(end) ~= 1, freq_firls = [freq_firls, 1]; mag_firls = [mag_firls, 0]; end

b_fir_ideal = firls(Lcomp-1, freq_firls, mag_firls); 
b_fir_ideal = b_fir_ideal(:).'; 

% --- IIR Filter Design (Mapped to b_iir, a_iir) ---
% Using Butterworth Bandpass logic
[b_iir_ideal, a_iir_ideal] = butter(2, [80 120]/(2000/2), 'bandpass');

%% ========================================================================
%  PART 2: SIMULATION LOOP (Targeting probe_final)
%  ========================================================================

bits_to_test = [4, 6, 8, 10, 12, 14, 16, 24]; 
enob_results = zeros(size(bits_to_test));
Fs_assumed_out = 8000; 

% --- CHANGED: Model Name ---
model_name = 'Modulator_DT';

if ~bdIsLoaded(model_name), load_system(model_name); end

fprintf('\nStarting Quantization Sweep on %s...\n', model_name);

for i = 1:length(bits_to_test)
    n_bits = bits_to_test(i);
    
    % 1. Quantize & Assign (Using new variable names)
    b_fir = quantize_coeffs(b_fir_ideal, n_bits);
    b_iir = quantize_coeffs(b_iir_ideal, n_bits);
    a_iir = quantize_coeffs(a_iir_ideal, n_bits);
    
    assignin('base', 'b_fir', b_fir);
    assignin('base', 'b_iir', b_iir);
    assignin('base', 'a_iir', a_iir);
    
    % 2. SAFETY: Clear variable before run to ensure we get fresh data
    % --- CHANGED: Variable Name to probe_final ---
    if evalin('base', 'exist(''probe_final'', ''var'')')
        evalin('base', 'clear probe_final');
    end
    
    try
        fprintf('Running %d-bit simulation... ', n_bits);
        simOut = sim(model_name);
        
        % 3. LOCATE probe_final (CRITICAL STEP)
        found_data = false;
        
        % Case A: Saved to Base Workspace (Format: Array/Structure)
        if evalin('base', 'exist(''probe_final'', ''var'')')
            raw_input = evalin('base', 'probe_final');
            found_data = true;
            
        % Case B: Saved inside simOut (Format: Dataset)
        elseif isfield(simOut, 'probe_final')
            raw_input = simOut.probe_final;
            found_data = true;
        elseif isfield(simOut, 'logsout') && ~isempty(simOut.logsout.find('probe_final'))
            raw_input = simOut.logsout.getElement('probe_final');
            found_data = true;
        end
        
        if ~found_data
            error('CRITICAL: probe_final NOT FOUND after simulation.');
        end
        
        % 4. EXTRACT & CALCULATE (Using your specific logic)
        [data_col, time_col] = extract_robust(raw_input);
        Fs_out = get_fs_out(time_col, Fs_assumed_out);
        [SNR_dB, ENOB] = sinad_and_enob_calc(data_col, Fs_out, sprintf('%d-bit', n_bits));
        
        if isnan(ENOB), ENOB = 0; end
        
    catch ME
        warning('Run failed: %s', ME.message);
        ENOB = 0;
    end
    
    enob_results(i) = ENOB;
end

%% ========================================================================
%  PART 3: RESULTS SUMMARY (TABLE & GRAPH)
%  ========================================================================

% --- TABULAR OUTPUT ---
fprintf('\n\n==============================================\n');
fprintf('       QUANTIZATION VS. ENOB RESULTS       \n');
fprintf('==============================================\n');
fprintf('  |  %10s  |  %12s  |\n', 'Coeff Bits', 'ENOB (bits)');
fprintf('  |--------------|----------------|\n');
for i = 1:length(bits_to_test)
    fprintf('  |  %10d  |  %12.4f  |\n', bits_to_test(i), enob_results(i));
end
fprintf('==============================================\n');

% --- GRAPH OUTPUT ---
figure('Color','w');
plot(bits_to_test, enob_results, '-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on;
title(['ADC ENOB vs. Quantization (' model_name ')']);
xlabel('Coefficient Bits'); ylabel('ENOB');
ylim([0 max(enob_results)+2]);
xticks(bits_to_test);

%% ========================================================================
%  HELPER FUNCTIONS (STRICTLY FROM YOUR CODE)
%  ========================================================================

function q_coeffs = quantize_coeffs(coeffs, n_bits)
    if n_bits >= 32, q_coeffs = coeffs; return; end
    scale_factor = 2^(n_bits - 1) - 1;
    max_val = max(abs(coeffs));
    if max_val > 0, norm_coeffs = coeffs / max_val; else, norm_coeffs = coeffs; end
    int_coeffs = round(norm_coeffs * scale_factor);
    q_coeffs_norm = int_coeffs / scale_factor;
    if max_val > 0, q_coeffs = q_coeffs_norm * max_val; else, q_coeffs = q_coeffs_norm; end
end

function [data_col, time_col] = extract_robust(v_in)
    while iscell(v_in) && ~isempty(v_in), v_in = v_in{1}; end
    if iscell(v_in) || isempty(v_in), data_col = []; time_col = []; return; end
    if isa(v_in, 'timetable')
        extracted_data = v_in{:, 1};
        if iscell(extracted_data), data_col = cell2mat(extracted_data); else, data_col = double(extracted_data); end
        try rt = v_in.Properties.RowTimes; dt = seconds(rt - rt(1)); time_col = double(dt(:));
        catch, dn = datenum(v_in.Properties.RowTimes); time_col = double((dn - dn(1)) * 86400); end
    elseif isa(v_in, 'timeseries')
        data_col = double(v_in.Data(:)); time_col = double(v_in.Time(:));
    elseif isstruct(v_in) && isfield(v_in, 'signals') && isfield(v_in.signals, 'values')
        vals = v_in.signals.values; if iscell(vals), vals = cell2mat(vals); end
        data_col = double(vals(:)); if isfield(v_in,'time'), time_col = double(v_in.time(:)); else time_col = []; end
    elseif isa(v_in, 'table')
        dat = v_in{:, end}; if iscell(dat), dat = cell2mat(dat); end
        data_col = double(dat(:)); firstcol = v_in{:,1};
        if isdatetime(firstcol), dt = seconds(firstcol - firstcol(1)); time_col = double(dt(:)); else, time_col = double(v_in{:,1}); end
    elseif isnumeric(v_in)
        data_col = double(v_in(:)); time_col = [];
    else
        warning('Unsupported data type: %s', class(v_in)); data_col = []; time_col = [];
    end
    data_col = data_col(:); if ~isempty(time_col), time_col = time_col(:); end
end

function [SNR_dB, ENOB] = sinad_and_enob_calc(data, fs_out, chain_name)
    fprintf('Analyzing %s (Fs = %.2f Hz)...\n', chain_name, fs_out);
    if isempty(data), SNR_dB = NaN; ENOB = NaN; fprintf(' Empty data.\n'); return; end
    x = double(data(:)); x = x - mean(x); 
    if exist('sinad','file') == 2
        try SNR_dB = sinad(x, fs_out); catch, SNR_dB = sinad_periodogram(x, fs_out); end
    else, SNR_dB = sinad_periodogram(x, fs_out); end
    if isnan(SNR_dB), ENOB = NaN; fprintf(' SINAD undefined.\n');
    else, ENOB = (SNR_dB - 1.76) / 6.02; fprintf(' Calculated ENOB: %.2f bits\n', ENOB); end
end

function SNR_dB = sinad_periodogram(x, Fs)
    SNR_dB = NaN; N = length(x); if N < 256, return; end
    nfft = 2^nextpow2(max(4096, N)); w = hann(min(N,4096));
    try [Pxx,f] = pwelch(x, w, floor(length(w)/2), nfft, Fs, 'onesided');
    catch, X = fft(x .* hann(N), nfft); Pxx = (abs(X).^2)/N; Pxx = Pxx(1:nfft/2+1); f = (0:(nfft/2))*(Fs/nfft); end
    [~, idxMax] = max(Pxx(2:end)); idxMax = idxMax + 1;
    peak_db = 10*log10(Pxx(idxMax)); noise_db = median(10*log10(Pxx(2:end)));
    if (peak_db - noise_db) < 6, SNR_dB = NaN; return; end
    binHz = f(2) - f(1); R = max(1, round(1/binHz));
    bins_sig = max(1, idxMax-R):min(length(Pxx), idxMax+R);
    P_signal = sum(Pxx(bins_sig)); P_total = sum(Pxx(2:end)); P_others = P_total - P_signal;
    if P_others <= 0, SNR_dB = Inf; return; end
    SNR_dB = 10*log10(P_signal / P_others);
end

function fs_out = get_fs_out(t, fs_assumed)
    if isempty(t) || numel(t) < 2, fs_out = fs_assumed; return; end
    t = double(t(:)); dt = diff(t);
    if mean(t) > 1e4 && mean(dt) < 1, dt = dt * 86400; end
    med = median(dt(dt>0));
    if isempty(med) || med <= 0, fs_out = fs_assumed; else, fs_out = 1/med; end
end