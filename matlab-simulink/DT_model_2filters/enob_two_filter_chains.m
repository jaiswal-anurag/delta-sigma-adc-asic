function enob_two_chains()
% enob_two_chains.m
% Robust SINAD / ENOB comparison for TWO ADC/filter chains exported from Simulink.
% Supports numeric arrays, timeseries, timetable, and common struct-with-signals.
%
% Expects workspace variables: v_output_data, v_output_data1
% Usage: run after Simulink finishes and exported the two signals.

clc; close all;

%% =========================================================================
%  SECTION 1: PARAMETERS AND CONFIGURATION
%% =========================================================================
fprintf('=================================================================\n');
fprintf('  FINAL ENOB CALCULATION AND COMPARISON FOR TWO ADC CHAINS\n');
fprintf('=================================================================\n\n');

Fs_assumed_out = 8000;   % fallback sample rate (Hz)
fprintf('Assumed Nominal Output Sample Rate (Fs\\_out): %.0f Hz\n\n', Fs_assumed_out);

%% =========================================================================
%  SECTION 2: LOAD SIMULATION DATA (ROBUSTLY)
%% =========================================================================
fprintf('Loading simulation data robustly from workspace...\n');

required_vars = {'v_output_data', 'v_output_data1'};
missing_vars = {};
for i = 1:length(required_vars)
    if ~evalin('base', ['exist(''' required_vars{i} ''', ''var'')'])
        missing_vars{end+1} = required_vars{i};
    end
end
if ~isempty(missing_vars)
    error('ERROR: Missing required Simulink variables: %s. Please run your simulation first.', strjoin(missing_vars, ', '));
end

v_output_data_local  = evalin('base', 'v_output_data');
v_output_data1_local = evalin('base', 'v_output_data1');

[data1, time1] = extract_robust(v_output_data_local);
[data2, time2] = extract_robust(v_output_data1_local);

if isempty(data1) || isempty(data2)
    error('Data extraction failed or resulted in empty arrays after robust conversion. Check your Simulink output signals.');
end

fprintf('  Chain 1: %d samples loaded\n', length(data1));
fprintf('  Chain 2: %d samples loaded\n', length(data2));
fprintf('-------------------------------------------------\n\n');

%% =========================================================================
%  SECTION 3: DETERMINE ACTUAL SAMPLING RATES (Fs_out)
%% =========================================================================
fprintf('Determining actual output sampling rates (Fs\\_out)...\n');

Fs_out1 = get_fs_out(time1, Fs_assumed_out);
Fs_out2 = get_fs_out(time2, Fs_assumed_out);

if Fs_out1 == Fs_assumed_out
    warning('Chain 1 time vector invalid/missing. Using assumed Fs: %.0f Hz.', Fs_assumed_out);
end
if Fs_out2 == Fs_assumed_out
    warning('Chain 2 time vector invalid/missing. Using assumed Fs: %.0f Hz.', Fs_assumed_out);
end

fprintf('  Chain 1 Actual Fs\\_out: %.2f Hz\n', Fs_out1);
fprintf('  Chain 2 Actual Fs\\_out: %.2f Hz\n\n', Fs_out2);

%% =========================================================================
%  SECTION 4: CALCULATE SINAD AND ENOB
%% =========================================================================
fprintf('--- ------------------------------------ ---\n');
fprintf('--- CALCULATING SINAD & ENOB ---\n');
fprintf('---------------------------------------- ---\n');

% compute SINAD/ENOB for each chain
[SNR1_dB, ENOB1] = sinad_and_enob_calc(data1, Fs_out1, 'Chain 1');
[SNR2_dB, ENOB2] = sinad_and_enob_calc(data2, Fs_out2, 'Chain 2');

%% =========================================================================
%  SECTION 5: DISPLAY RESULTS
%% =========================================================================
fprintf('=================================================================\n');
fprintf('                    FINAL RESULTS SUMMARY\n');
fprintf('=================================================================\n\n');

fprintf('%-10s | %-15s | %-12s | %-10s\n', 'Chain', 'Fs\\_out (Hz)', 'SINAD (dB)', 'ENOB (bits)');
fprintf('----------------------------------------------------------\n');
fprintf('%-10s | %-15.2f | %-12.2f | %-10.2f\n', 'Chain 1', Fs_out1, SNR1_dB, ENOB1);
fprintf('%-10s | %-15.2f | %-12.2f | %-10.2f\n', 'Chain 2', Fs_out2, SNR2_dB, ENOB2);
fprintf('----------------------------------------------------------\n');

[best_enob, best_chain_idx] = max([ENOB1, ENOB2]);
chain_names = {'Chain 1', 'Chain 2'};
fprintf('\nBest ENOB Performance: %s (%.2f bits)\n', chain_names{best_chain_idx}, best_enob);

%% =========================================================================
%  SECTION 6: VISUALIZATION
%% =========================================================================
fprintf('\nGenerating visualization plots...\n\n');

figure('Name', 'ADC Filter Chain ENOB Comparison', ...
       'Position', [100 100 800 600], 'Color', 'w');

subplot(2,1,1);
sinad_data = [SNR1_dB, SNR2_dB];
bar(sinad_data);
set(gca, 'XTickLabel', {'Chain 1', 'Chain 2'});
ylabel('SINAD (dB)');
title('Signal-to-Noise and Distortion Ratio (SINAD) Comparison');
grid on;

subplot(2,1,2);
enob_data = [ENOB1, ENOB2];
bar(enob_data);
set(gca, 'XTickLabel', {'Chain 1', 'Chain 2'});
ylabel('ENOB (bits)');
title('Effective Number of Bits (ENOB) Comparison');
grid on;

annotation('textbox', [0.1 0.01 0.8 0.05], 'String', ...
           sprintf('ENOB calculated using: ENOB = (SINAD - 1.76) / 6.02'), ...
           'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontSize', 10);

saveas(gcf, 'enob_comparison_sinad_two_chains.png');
fprintf('Figure saved to: enob_comparison_sinad_two_chains.png\n');
fprintf('\n=================================================================\n');
fprintf('  Analysis complete!\n');
fprintf('=================================================================\n');

end % end main function


%% =========================================================================
%  Helper functions
%% =========================================================================

% Robust extraction (supports timetable, timeseries, struct, table, numeric)
function [data_col, time_col] = extract_robust(v_in)
    while iscell(v_in) && ~isempty(v_in)
        v_in = v_in{1};
    end
    if iscell(v_in) || isempty(v_in)
        data_col = []; time_col = []; return;
    end

    if isa(v_in, 'timetable')
        extracted_data = v_in{:, 1};
        if iscell(extracted_data)
            data_col = cell2mat(extracted_data);
        else
            data_col = double(extracted_data);
        end
        % convert RowTimes -> seconds relative to start
        try
            rt = v_in.Properties.RowTimes;
            dt = seconds(rt - rt(1));
            time_col = double(dt(:));
        catch
            % fallback using datenum
            dn = datenum(v_in.Properties.RowTimes);
            time_col = double((dn - dn(1)) * 86400);
        end

    elseif isa(v_in, 'timeseries')
        data_col = double(v_in.Data(:));
        time_col = double(v_in.Time(:));

    elseif isstruct(v_in) && isfield(v_in, 'signals') && isfield(v_in.signals, 'values')
        vals = v_in.signals.values;
        if iscell(vals), vals = cell2mat(vals); end
        data_col = double(vals(:));
        if isfield(v_in,'time'), time_col = double(v_in.time(:)); else time_col = []; end

    elseif isa(v_in, 'table')
        dat = v_in{:, end};
        if iscell(dat), dat = cell2mat(dat); end
        data_col = double(dat(:));
        firstcol = v_in{:,1};
        if isdatetime(firstcol)
            dt = seconds(firstcol - firstcol(1));
            time_col = double(dt(:));
        else
            time_col = double(v_in{:,1});
        end

    elseif isnumeric(v_in)
        data_col = double(v_in(:));
        time_col = [];

    else
        warning('Unsupported data type: %s', class(v_in));
        data_col = []; time_col = [];
    end

    data_col = data_col(:);
    if ~isempty(time_col), time_col = time_col(:); end
end


% SINAD & ENOB calculation wrapper (uses MATLAB sinad if available)
function [SNR_dB, ENOB] = sinad_and_enob_calc(data, fs_out, chain_name)
    fprintf('Analyzing %s (Fs = %.2f Hz)...\n', chain_name, fs_out);

    % prepare data vector
    if isempty(data)
        SNR_dB = NaN; ENOB = NaN; fprintf('  Empty data.\n'); return;
    end
    x = double(data(:));
    x = x - mean(x);  % remove DC

    % Prefer using MATLAB's sinad if present; otherwise use periodogram fallback
    if exist('sinad','file') == 2
        try
            % MATLAB's sinad expects vector and sample rate as second arg in newer releases
            SNR_dB = sinad(x, fs_out);
        catch
            % old syntax fallback: compute via periodogram routine below
            SNR_dB = sinad_periodogram(x, fs_out);
        end
    else
        SNR_dB = sinad_periodogram(x, fs_out);
    end

    if isnan(SNR_dB)
        ENOB = NaN;
        fprintf('  SINAD undefined (no clear tone). Returning NaN.\n\n');
    else
        ENOB = (SNR_dB - 1.76) / 6.02;
        fprintf('  Calculated SINAD: %.2f dB\n', SNR_dB);
        fprintf('  Calculated ENOB:  %.2f bits\n\n', ENOB);
    end
end


% Periodogram-based SINAD (fallback if 'sinad' not available)
function SNR_dB = sinad_periodogram(x, Fs)
    SNR_dB = NaN;

    N = length(x);
    if N < 256
        return;
    end

    % choose nfft and window:
    nfft = 2^nextpow2(max(4096, N));
    w = hann(min(N,4096));
    % compute PSD using pwelch if available
    try
        [Pxx,f] = pwelch(x, w, floor(length(w)/2), nfft, Fs, 'onesided');
    catch
        % fallback: simple periodogram
        X = fft(x .* hann(N), nfft);
        Pxx = (abs(X).^2)/N;
        Pxx = Pxx(1:nfft/2+1);
        f = (0:(nfft/2))*(Fs/nfft);
    end

    % find fundamental peak (exclude DC)
    [~, idxMax] = max(Pxx(2:end));
    idxMax = idxMax + 1;

    % noise floor check
    peak_db = 10*log10(Pxx(idxMax));
    noise_db = median(10*log10(Pxx(2:end)));
    if (peak_db - noise_db) < 6
        % no clear tone
        SNR_dB = NaN;
        return;
    end

    % integrate signal power around peak (±1 Hz)
    binHz = f(2) - f(1);
    R = max(1, round(1/binHz));
    bins_sig = max(1, idxMax-R):min(length(Pxx), idxMax+R);
    P_signal = sum(Pxx(bins_sig));

    % total in-band (exclude DC index 1)
    P_total = sum(Pxx(2:end));
    P_others = P_total - P_signal;
    if P_others <= 0
        SNR_dB = Inf;
        return;
    end

    SNR_dB = 10*log10(P_signal / P_others);
end


% compute Fs from time vector (seconds) or fallback
function fs_out = get_fs_out(t, fs_assumed)
    if isempty(t) || numel(t) < 2
        fs_out = fs_assumed;
        return;
    end
    t = double(t(:));
    dt = diff(t);
    % handle datenum-like times (large values)
    if mean(t) > 1e4 && mean(dt) < 1
        dt = dt * 86400; % convert days->s
    end
    med = median(dt(dt>0));
    if isempty(med) || med <= 0
        fs_out = fs_assumed;
    else
        fs_out = 1/med;
    end
end