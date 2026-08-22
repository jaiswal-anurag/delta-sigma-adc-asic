Fs=512e3; % set sampling frequency
Ts=1/Fs;
[num, den] = butter(2, [80 120]/(2000/2), 'bandpass');

