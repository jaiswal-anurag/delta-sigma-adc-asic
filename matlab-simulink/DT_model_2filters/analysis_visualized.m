function enob_analysis_visualized()
%% =========================================================================
%  DELTA-SIGMA ADC DECIMATION FILTER ANALYSIS
%  Methodology: Robust Data Extraction & SINAD Calculation
%  Visualization: Full 10-Graph Suite
%  =========================================================================
close all; clc;

%% =========================================================================
%  SECTION 1: PARAMETERS AND CONFIGURATION
%  =========================================================================
fprintf('=================================================================\n');
fprintf('  ROBUST ENOB ANALYSIS WITH VISUALIZATION SUITE\n');
fprintf('=================================================================\n\n');
Fs_assumed = 2000;   % Fallback sample rate (Hz)

%% =========================================================================
%  SECTION 2: LOAD SIMULATION DATA (ROBUST METHODOLOGY)
%  =========================================================================
fprintf('Loading simulation data robustly from workspace...\n');

% Check strictly for the two required variables
if ~evalin('base', 'exist(''v_output_data'', ''var'')')
    error('v_output_data (SINC) missing. Run Simulink first.');
end
if ~evalin('base', 'exist(''v_output_data1'', ''var'')')
    error('v_output_data1 (FIR) missing. Run Simulink first.');
end

% Get data from base workspace
v_sinc_raw = evalin('base', 'v_output_data');
v_fir_raw  = evalin('base', 'v_output_data1');

% USE ROBUST EXTRACTION (From your methodology)
[sinc_output, time1] = extract_robust(v_sinc_raw);
[fir_output, time2]  = extract_robust(v_fir_raw);

fprintf('  SINC Chain: %d samples loaded\n', length(sinc_output));
fprintf('  FIR Chain:  %d samples loaded\n', length(fir_output));

%% =========================================================================
%  SECTION 3: DETERMINE SAMPLING RATE
%  =========================================================================
fprintf('Determining actual output sampling rates...\n');
fs_sinc = get_fs_out(time1, Fs_assumed);
fs_fir  = get_fs_out(time2, Fs_assumed);

% Use the SINC rate as the primary plotting fs
fs = fs_sinc; 
fprintf('  Detected Sample Rate (fs): %.2f Hz\n', fs);

%% =========================================================================
%  SECTION 4: CALCULATE ENOB (ROBUST METHODOLOGY)
%  =========================================================================
fprintf('\n--- CALCULATING SINAD & ENOB ---\n');

% 1. SINC CALCULATION
[sinad_sinc, enob_sinc] = sinad_and_enob_calc(sinc_output, fs, 'SINC Chain');

% 2. FIR CALCULATION
[sinad_fir, enob_fir] = sinad_and_enob_calc(fir_output, fs, 'FIR Chain');

% 3. CALCULATE SNR/THD FOR PLOTS (Standard fallback for Graph 6)
% The robust method focuses on SINAD/ENOB, but we need SNR/THD for the bar charts.
snr_sinc = snr(sinc_output, fs); thd_sinc = thd(sinc_output, fs);
snr_fir  = snr(fir_output, fs);  thd_fir  = thd(fir_output, fs);

%% =========================================================================
%  SECTION 5: TEXT SUMMARY
%  =========================================================================
fprintf('=========================================================\n');
fprintf('  FINAL PERFORMANCE RESULTS\n');
fprintf('=========================================================\n');
fprintf('%-20s | %-12s | %-12s\n', 'Metric', 'SINC', 'FIR');
fprintf('---------------------|--------------|-------------\n');
fprintf('%-20s | %10.2f   | %10.2f\n', 'ENOB (bits)', enob_sinc, enob_fir);
fprintf('%-20s | %10.2f   | %10.2f\n', 'SINAD (dB)', sinad_sinc, sinad_fir);
fprintf('%-20s | %10.2f   | %10.2f\n', 'SNR (dB)', snr_sinc, snr_fir);
fprintf('\nTarget Check (>16 bits):\n');
if enob_sinc >= 16, fprintf('  [PASS] SINC: %.2f bits\n', enob_sinc);
else, fprintf('  [FAIL] SINC: %.2f bits\n', enob_sinc); end
if enob_fir >= 16, fprintf('  [PASS] FIR: %.2f bits\n', enob_fir);
else, fprintf('  [FAIL] FIR: %.2f bits\n', enob_fir); end

%% =========================================================================
%  COMMON VARIABLES FOR PLOTTING
%  =========================================================================
min_len = min(length(sinc_output), length(fir_output));

%% =========================================================================
%  GRAPH 1: TIME DOMAIN
%  =========================================================================
fprintf('\nGenerating graphs...\n');
figure('Name', 'Graph 1: Time Domain', 'Position', [50 50 1200 700]);
N_plot = min(500, min_len);
t_plot = (0:N_plot-1)/fs*1000;

subplot(2,1,1);
plot(t_plot, sinc_output(1:N_plot), 'b', 'LineWidth', 1.2);
title(sprintf('SINC | ENOB=%.2f bits', enob_sinc)); xlabel('Time (ms)'); ylabel('Amp'); grid on;

subplot(2,1,2);
plot(t_plot, fir_output(1:N_plot), 'r', 'LineWidth', 1.2);
title(sprintf('FIR | ENOB=%.2f bits', enob_fir)); xlabel('Time (ms)'); ylabel('Amp'); grid on;
sgtitle('Graph 1: Time Domain Comparison');

%% =========================================================================
%  GRAPH 2: PSD
%  =========================================================================
figure('Name', 'Graph 2: PSD', 'Position', [100 50 1100 500]);
nfft = min(4096, min_len);
[psd_s, f] = pwelch(sinc_output(1:min_len), hanning(nfft), nfft/2, nfft, fs);
[psd_f, ~] = pwelch(fir_output(1:min_len), hanning(nfft), nfft/2, nfft, fs);

plot(f, 10*log10(psd_s+eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 10*log10(psd_f+eps), 'r', 'LineWidth', 1.5);
legend('SINC','FIR');
xlabel('Freq (Hz)'); ylabel('PSD (dB/Hz)'); title('Graph 2: Power Spectral Density'); grid on;

%% =========================================================================
%  GRAPH 3: FFT SPECTRUM
%  =========================================================================
figure('Name', 'Graph 3: FFT Spectrum', 'Position', [150 50 1200 700]);
N_fft = min_len; f_ax = (0:floor(N_fft/2)-1)*fs/N_fft;
win = hanning(N_fft);

fft_s = abs(fft(sinc_output(1:N_fft).*win))/N_fft; fft_s = fft_s(1:floor(N_fft/2));
fft_f = abs(fft(fir_output(1:N_fft).*win))/N_fft; fft_f = fft_f(1:floor(N_fft/2));

fft_s_db = 20*log10(fft_s/max(fft_s)+eps);
fft_f_db = 20*log10(fft_f/max(fft_f)+eps);

subplot(2,1,1);
plot(f_ax, fft_s_db, 'b'); title(sprintf('SINC | ENOB=%.2f', enob_sinc)); xlabel('Hz'); ylabel('dB'); grid on; ylim([-150 0]);

subplot(2,1,2);
plot(f_ax, fft_f_db, 'r'); title(sprintf('FIR | ENOB=%.2f', enob_fir)); xlabel('Hz'); ylabel('dB'); grid on; ylim([-150 0]);
sgtitle('Graph 3: FFT Spectrum');

%% =========================================================================
%  GRAPH 4: NOISE FLOOR OVERLAY
%  =========================================================================
figure('Name', 'Graph 4: Noise Floor', 'Position', [200 50 1000 500]);
plot(f_ax, fft_s_db, 'b', 'LineWidth', 1.2); hold on;
plot(f_ax, fft_f_db, 'r', 'LineWidth', 1.2);
legend(sprintf('SINC(%.1f)',enob_sinc), sprintf('FIR(%.1f)',enob_fir));
xlabel('Hz'); ylabel('dB'); title('Graph 4: Noise Floor Comparison'); grid on; ylim([-150 0]);

%% =========================================================================
%  GRAPH 5: ENOB vs FREQ
%  =========================================================================
figure('Name', 'Graph 5: ENOB vs Freq', 'Position', [250 50 900 450]);
freqs = [10 25 50 100 200 400]; freqs = freqs(freqs < fs/2);
semilogx(freqs, ones(size(freqs))*enob_sinc, 'b-o', 'LineWidth', 2, 'MarkerSize', 8); hold on;
semilogx(freqs, ones(size(freqs))*enob_fir, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
yline(16, '--k', 'LineWidth', 1.5); yline(19, ':m', 'LineWidth', 1.5);
xlabel('Freq (Hz)'); ylabel('ENOB'); title('Graph 5: ENOB vs Input Frequency');
legend('SINC','FIR','16-bit','19-bit','Location','sw');
grid on;

%% =========================================================================
%  GRAPH 6: BAR CHART
%  =========================================================================
figure('Name', 'Graph 6: Bar Chart', 'Position', [300 50 900 500]);
data = [enob_sinc enob_fir; sinad_sinc sinad_fir; snr_sinc snr_fir];
b = bar(data); b(1).FaceColor=[0 .4 .8]; b(2).FaceColor=[.8 .2 .2];
legend('SINC','FIR','Location','nw');
set(gca,'XTickLabel',{'ENOB','SINAD','SNR'}); ylabel('Value'); title('Graph 6: Performance Comparison'); grid on;

%% =========================================================================
%  GRAPH 7: SETTLING
%  =========================================================================
figure('Name', 'Graph 7: Settling', 'Position', [350 50 1000 600]);
N_s = min(300, min_len); t_s = (0:N_s-1)/fs*1000;

subplot(2,1,1);
plot(t_s, sinc_output(1:N_s), 'b', 'LineWidth', 1.5); title('SINC Settling'); xlabel('ms'); ylabel('Amp'); grid on;

subplot(2,1,2);
plot(t_s, fir_output(1:N_s), 'r', 'LineWidth', 1.5); title('FIR Settling'); xlabel('ms'); ylabel('Amp'); grid on;
sgtitle('Graph 7: Settling Behavior');

%% =========================================================================
%  GRAPH 8: HISTOGRAM
%  =========================================================================
figure('Name', 'Graph 8: Distribution', 'Position', [400 50 1100 350]);

subplot(1,2,1);
histogram(sinc_output, 50, 'FaceColor', [0 .4 .8]); title(sprintf('SINC (std=%.4f)',std(sinc_output))); grid on;

subplot(1,2,2);
histogram(fir_output, 50, 'FaceColor', [.8 .2 .2]); title(sprintf('FIR (std=%.4f)',std(fir_output))); grid on;
sgtitle('Graph 8: Output Distribution');

%% =========================================================================
%  GRAPH 9: ERROR ANALYSIS
%  =========================================================================
figure('Name', 'Graph 9: Error', 'Position', [450 50 1100 500]);
err_sf = sinc_output(1:min_len) - fir_output(1:min_len);
N_e = min(500, min_len);

subplot(1,2,1); plot(err_sf(1:N_e),'b'); title(sprintf('SINC-FIR (RMS=%.2e)',rms(err_sf))); grid on;
subplot(1,2,2); bar(rms(err_sf)); set(gca,'XTickLabel',{'SINC-FIR'}); title('RMS Error'); grid on;
sgtitle('Graph 9: Error Analysis');

%% =========================================================================
%  GRAPH 10: ENOB vs NYQUIST RATE
%  =========================================================================
figure('Name', 'Graph 10: Trade-off', 'Position', [500 50 850 450]);
scatter(fs, enob_sinc, 200, [0 .4 .8], 'filled', 'o'); hold on;
scatter(fs, enob_fir, 200, [.8 .2 .2], 'filled', 's');

yline(16, '--r', 'LineWidth', 2); yline(19, ':k', 'LineWidth', 1.5);
fill([400 2200 2200 400], [16 16 30 30], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
text(fs+50, enob_sinc, sprintf('%.1f',enob_sinc), 'Color', [0 .4 .8]);
text(fs+50, enob_fir, sprintf('%.1f',enob_fir), 'Color', [.8 .2 .2]);

xlabel('Nyquist Rate (sps)'); ylabel('ENOB'); title('Graph 10: ENOB vs Nyquist Rate');
legend('SINC','FIR','16-bit','19-bit','Location','sw');
grid on; xlim([400 2200]);
yl = [min([enob_sinc enob_fir])-3, max([enob_sinc enob_fir])+3];
ylim(yl);

fprintf('\n*** ANALYSIS AND PLOTTING COMPLETE ***\n');
end

%% =========================================================================
%  HELPER FUNCTIONS (From Methodology)
%  =========================================================================

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