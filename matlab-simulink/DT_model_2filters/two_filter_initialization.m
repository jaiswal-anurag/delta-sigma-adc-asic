% compare_decim_filters_isro_ready.m
% Full script: designs comp & half-band filters, enforces row-vector coeffs,
% compares Chain A (single CIC) vs Chain B (IZ two-stage CIC) analytically.
clear; clc; close all;

%% -------------------------
% USER / SYSTEM PARAMETERS (ISRO baseline values)
Fs_in = 256000;       % Input Rate (Modulator Clock) (Hz)
F_pass = 900;         % Passband (Hz)
F_stop = 1000;        % Stopband (Hz)
Rp = 0.005;           % Passband Ripple (dB) target (very tight)
Ast_target = 120;     % Target stopband attenuation (dB) - goal (practical filters may be lower)
Lcomp = 128;          % desired compensation FIR length (tunable)

%% -------------------------
% Design: Compensation FIR (firls fallback method)
fprintf('Designing compensation FIR (firls fallback method)...\n');
try
    % Build dense normalized freq grid 0..1 (1 = Fs/2 for firls)
    nGrid = 2000;
    f_grid = linspace(0,1,nGrid);  % normalized 0..1 corresponds to 0..Fs/2
    % Analytical single-stage CIC used as baseline (R=32,K=4)
    R = 32; Kc = 4;
    w_grid = 2*pi*f_grid;
    Hcic_grid = ((1/R) .* (sin(w_grid*R/2) ./ (sin(w_grid/2) + eps))).^Kc;
    Hcic_grid(1) = 1; % avoid NaN at 0
    % Desired magnitude: inverse of CIC within passband; taper to zero by stop
    fp_norm = F_pass / (Fs_in/2);     % normalized passband edge (0..1)
    fst_norm = F_stop / (Fs_in/2);    % normalized stop edge (0..1)
    des = zeros(size(f_grid));
    pass_idx = f_grid <= fp_norm;
    trans_idx = (f_grid > fp_norm) & (f_grid < fst_norm);
    des(pass_idx) = 1 ./ Hcic_grid(pass_idx);            % inverse to compensate droop
    % linear taper in transition band
    if any(trans_idx)
        des(trans_idx) = linspace(des(find(pass_idx,1,'last')), 0, sum(trans_idx));
    end
    % Select sample points for firls design (reduce to manageable number)
    nPts = 400;
    sel = round(linspace(1, nGrid, nPts));
    freq_firls = f_grid(sel);
    mag_firls  = des(sel);
    % Ensure start at zero and end at zero (for firls)
    if freq_firls(1) ~= 0
        freq_firls = [0, freq_firls];
        mag_firls  = [mag_firls(1), mag_firls];
    end
    if freq_firls(end) ~= 1
        freq_firls = [freq_firls, 1];
        mag_firls  = [mag_firls, 0];
    end
    % firls expects frequency vector in 0..1 and desired magnitude vector
    b_comp = firls(Lcomp-1, freq_firls, mag_firls);
    fprintf('Compensation FIR: designed via firls, length = %d\n', length(b_comp));
catch ME
    warning('firls path failed (%s). Falling back to windowed IFFT approach.', ME.message);
    % fallback: crude IFFT-based design
    Nfft_fb = 32768;
    D = zeros(1,Nfft_fb);
    idxN = 1:round(length(f_grid)/2);
    D(idxN) = des(1:length(idxN));
    htmp = real(ifft([D, fliplr(D(2:end-1))]));
    b_comp = htmp(1:Lcomp) .* hamming(Lcomp)';
    fprintf('Compensation FIR fallback length = %d\n', length(b_comp));
end

%% -------------------------
% Design: Half-band FIR (use firhalfband if available)
fprintf('Designing half-band FIR (firhalfband / fir1 fallback)...\n');
HB_order = 60;  % try this order; increase if you need steeper transition
try
    b_hb = firhalfband(HB_order, 0.45).'; % returns symmetric halfband taps, transpose to row
    fprintf('Half-band FIR designed via firhalfband, length = %d\n', length(b_hb));
catch
    % fallback using fir1 (less optimal but reliable)
    warning('firhalfband not available, using fir1 fallback');
    b_hb = fir1(HB_order, 0.45).';
    fprintf('Half-band FIR fallback length = %d\n', length(b_hb));
end

%% -------------------------
% Chain parameters (CIC and IZ settings)
A.R = 32; A.K = 4;
B.M1 = 8; B.K1 = 4;
B.M2 = 4; B.K2 = 3;
B1 = 3/2; B2 = 1/2;
I2 = [1, B1, B2, 1];
I1 = [1, zeros(1,B.M2-2), -2];
I_total = conv(I1, I2);

%% -------------------------
% --- ENFORCE ROW-VECTOR SHAPES for Simulink ---
% ensures 'Columns as channels (frame based)' won't reject coefficients
b_comp = b_comp(:).';   % 1 x N
b_hb   = b_hb(:).';     % 1 x N
I_total = I_total(:).'; % 1 x N

fprintf('Enforced row-vector shapes (suitable for Simulink):\n');
fprintf('  b_comp  => %d x %d\n', size(b_comp,1), size(b_comp,2));
fprintf('  b_hb    => %d x %d\n', size(b_hb,1), size(b_hb,2));
fprintf('  I_total => %d x %d\n', size(I_total,1), size(I_total,2));

%% -------------------------
% Frequency-domain analysis (analytic CIC approximations + FIR freqz)
Nfft = 16384;                            % reduced-size FFT grid for memory safety
freqHz = linspace(0, Fs_in/2, Nfft);    % row vector
w = 2*pi*(0:(Nfft-1))/Nfft;

% Chain A CIC response
M_A = A.R; K_A = A.K;
Hcic_A = ((1/M_A) .* (sin(w*M_A/2)./ (sin(w/2) + eps))).^K_A;
Hcic_A(1) = 1;

% Chain B: stage responses and IZ
H1 = ((1/B.M1) .* (sin(w*B.M1/2)./(sin(w/2)+eps))).^B.K1; H1(1)=1;
H2 = ((1/B.M2) .* (sin(w*B.M2/2)./(sin(w/2)+eps))).^B.K2; H2(1)=1;
H_iz = freqz(I_total,1,Nfft).';
H_cic_B = H1 .* H2 .* H_iz;

% FIR stage responses
Hcomp = freqz(b_comp,1,Nfft).';
Hhb   = freqz(b_hb,1,Nfft).';

% Overall responses
H_overall_A = Hcic_A .* Hcomp .* Hhb;
H_overall_B = H_cic_B .* Hcomp .* Hhb;

% dB versions
Hdb_A = 20*log10(abs(H_overall_A) + eps);
Hdb_B = 20*log10(abs(H_overall_B) + eps);

%% -------------------------
% METRICS (computational-efficiency, ripple, group delay, stopband attenuation)

% 1) Computational-efficiency estimate (crude)
mult_A = (length(b_comp)-1) + (length(b_hb)-1); % multipliers in FIR stages per output sample
adds_cic_A = (A.K + A.K); % integrators + combs per input sample (crude)
adds_cic_A_perOut = adds_cic_A * A.R;
ops_A = mult_A + adds_cic_A_perOut;

mult_B = (length(I_total)-1) + (length(b_comp)-1) + (length(b_hb)-1);
adds_stage1 = (B.K1 + B.K1);
adds_stage2 = (B.K2 + B.K2);
adds_B_perOut = adds_stage1 * (B.M1 * B.M2) + adds_stage2 * (B.M2);
ops_B = mult_B + adds_B_perOut;

% 2) Passband ripple (peak-to-peak in passband)
idx_pass = find(freqHz <= F_pass);
pass_ripple_A = max(Hdb_A(idx_pass)) - min(Hdb_A(idx_pass));
pass_ripple_B = max(Hdb_B(idx_pass)) - min(Hdb_B(idx_pass));

% 3) Group delay (approx via numerical derivative of phase)
phase_A = unwrap(angle(H_overall_A));   % 1 x Nfft
phase_B = unwrap(angle(H_overall_B));   % 1 x Nfft
dphase_A = diff(phase_A);               % 1 x (Nfft-1)
dphase_B = diff(phase_B);
dfreq = diff(2*pi*freqHz);              % 1 x (Nfft-1)
gd_A_seconds = - dphase_A ./ dfreq;     % 1 x (Nfft-1) seconds
gd_B_seconds = - dphase_B ./ dfreq;
% mean group delay in passband (converted to samples @ Fs_in)
gd_A_samples_mean = mean(gd_A_seconds(idx_pass(1:end-1))) * Fs_in;
gd_B_samples_mean = mean(gd_B_seconds(idx_pass(1:end-1))) * Fs_in;

% 4) Stopband attenuation (worst-case in [F_stop .. Fs/2])
idx_stop = find(freqHz >= F_stop & freqHz <= Fs_in/2);
stop_att_A = -max(Hdb_A(idx_stop)); % positive number
stop_att_B = -max(Hdb_B(idx_stop));

%% -------------------------
% PLOT results
figure('Units','normalized','Position',[0.05 0.05 0.9 0.85]);

subplot(2,2,1);
plot(freqHz/1e3, Hdb_A, 'b','LineWidth',1.1); hold on;
plot(freqHz/1e3, Hdb_B, 'r','LineWidth',1.1);
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title('Overall Magnitude Response (Chain A vs Chain B)');
legend('Chain A (single CIC)','Chain B (IZ two-stage)','Location','best');
grid on; xlim([0 Fs_in/2/1e3]);

subplot(2,2,2);
plot(freqHz(idx_pass)/1e3, Hdb_A(idx_pass),'b'); hold on;
plot(freqHz(idx_pass)/1e3, Hdb_B(idx_pass),'r');
xlabel('Frequency (kHz)'); ylabel('Magnitude (dB)');
title(sprintf('Passband zoom 0-%d Hz | ripple A=%.6f dB, B=%.6f dB', F_pass, pass_ripple_A, pass_ripple_B));
grid on;

subplot(2,2,3);
plot(freqHz(1:end-1)/1e3, gd_A_seconds*Fs_in, 'b'); hold on;
plot(freqHz(1:end-1)/1e3, gd_B_seconds*Fs_in, 'r');
xlabel('Frequency (kHz)'); ylabel('Group delay (samples)');
title(sprintf('Group delay (approx). Mean in passband: A=%.2f, B=%.2f samples', gd_A_samples_mean, gd_B_samples_mean));
grid on; xlim([0 Fs_in/2/1e3]);

subplot(2,2,4);
bar_data = [ops_A, ops_B; stop_att_A, stop_att_B]';
bar(bar_data);
set(gca,'XTickLabel',{'Chain A','Chain B'});
legend('Estimated ops (mixed units)','Stopband attenuation (dB)','Location','northwest');
title('Computational cost vs Stopband attenuation');
grid on;

%% -------------------------
% Print numeric summary
fprintf('\n--- Comparison Summary ---\n');
fprintf('Estimated ops per output sample: Chain A = %.1f, Chain B = %.1f\n', ops_A, ops_B);
fprintf('Passband ripple (dB): Chain A = %.6f, Chain B = %.6f\n', pass_ripple_A, pass_ripple_B);
fprintf('Mean group delay in passband (samples): Chain A = %.3f, Chain B = %.3f\n', gd_A_samples_mean, gd_B_samples_mean);
fprintf('Stopband attenuation (dB, worst in stop region): Chain A = %.2f, Chain B = %.2f\n', stop_att_A, stop_att_B);

%% -------------------------
% Save coefficients for Simulink
save('coeffs_ISRO_chainA.mat','b_comp','b_hb');
save('coeffs_ISRO_chainB.mat','b_comp','b_hb','I_total');
fprintf('Saved coefficient files: coeffs_ISRO_chainA.mat, coeffs_ISRO_chainB.mat\n');

% End of script
[num, den] = butter(2, [80 120]/(2000/2), 'bandpass');
% Fs_mid = 256000 / 128 (New intermediate rate: 2000 Hz)
% Passband = 900 Hz
% Normalized Passband = 900 / (2000 / 2) = 0.9
% This is very wide, let's use a standard half-band.
N = 50; % Filter order
b_halfband = firhalfband(N, 0.45); % 0.45 is a good default