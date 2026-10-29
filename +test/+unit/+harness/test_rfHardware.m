function test_rfHardware()
%test_rfHardware The TX/RX hardware models do what their headers claim, measured, not assumed.
%  1. PA output averages hw.tx.pOutDbm (compression included) on a fresh slot.
%  2. Transmit EVM is non-zero (the impairments act) and inside TS 38.101-1 Table 6.4.2.1-1's
%     64QAM limit of 8 % (a module that failed it could not be sold).
%  3. A one-sub-channel transmission leaks into the other sub-channels (in-band emission), below
%     -20 dBc and above -80 dBc: real, and of a plausible size.
%  4. The carrier-frequency error is the drawn value, recovered from the waveform.
%  5. The receiver preserves absolute power (the digital rescale undoes the AGC gain) and clips
%     nothing on a normal slot.
hw = rf.hwDefaults();
fs = 30.72e6; fc = 5.9e9;
st = rf.txHardwareInit(hw, fs, fc, 3);
rs = RandStream('mt19937ar', 'Seed', 9);
nSc = 600;
sym = (sign(randn(rs, nSc, 13)) + 1j * sign(randn(rs, nSc, 13))) / sqrt(2);
grid = [sym zeros(nSc, 1)];
x = phy.lib.ofdmMod(grid, 1, 0);
y = rf.txHardware(st, x, 0);
on = x ~= 0;
pDbm = 10 * log10(mean(abs(y(on)).^2)) + 30;
assert(abs(pDbm - hw.tx.pOutDbm) < 0.3, 'PA output %.2f dBm, expected %g', pDbm, hw.tx.pOutDbm);

% ---- EVM (frequency error removed so only the distortion is measured) ----------------------
st2 = rf.txHardwareInit(setfield(hw, 'lo', struct('ppm', 0)), fs, fc, 4); %#ok<SFLD>
y2 = rf.txHardware(st2, x, 0);
g2 = phy.lib.ofdmDemod(y2, nSc, 1, 0);
ref = grid(:, 1:13); got = g2(:, 1:13);
a = (ref(:)' * got(:)) / (ref(:)' * ref(:));     % best complex gain
evm = sqrt(mean(abs(got(:) / a - ref(:)).^2) / mean(abs(ref(:)).^2));
assert(evm > 0.002 && evm < 0.08, 'EVM %.2f %% outside (0.2 %%, 8 %%)', 100 * evm);

% ---- in-band emission: one 10-PRB sub-channel in use ----------------------------------------
g1 = zeros(nSc, 14); g1(1:120, 1:13) = sym(1:120, :);
x1 = phy.lib.ofdmMod(g1, 1, 0);
st3 = rf.txHardwareInit(setfield(hw, 'lo', struct('ppm', 0)), fs, fc, 5); %#ok<SFLD>
y1 = rf.txHardware(st3, x1, 0);
G = phy.lib.ofdmDemod(y1, nSc, 1, 0);
pIn = mean(abs(G(1:120, 1:13)).^2, 'all');
pOut = mean(abs(G(241:600, 1:13)).^2, 'all');      % sub-channels 2..4 (skip the adjacent one)
leakDbc = 10 * log10(pOut / pIn);
assert(leakDbc < -20 && leakDbc > -80, 'in-band emission %.1f dBc not in (-80, -20)', leakDbc);

% ---- carrier-frequency error ----------------------------------------------------------------
tone = exp(1j * 2 * pi * 1e5 * (0:15359)' / fs);
st4 = rf.txHardwareInit(hw, fs, fc, 6);
release(st4.pn); st4.pn = @(v) v;                % isolate the frequency error
yt = rf.txHardware(st4, tone, 0);
ph = unwrap(angle(yt .* conj(tone)));
fEst = (ph(end) - ph(1)) / (2 * pi * (numel(ph) - 1) / fs);
assert(abs(fEst - st4.foHz) < 5, 'frequency error %.1f Hz, drawn %.1f Hz', fEst, st4.foHz);

% ---- receiver: absolute scale and no clipping -----------------------------------------------
sr = rf.rxHardwareInit(hw, fs, fc, 8);
sr.noiseW = 0;                                    % isolate the AGC/ADC scale
release(sr.pfo); sr.pfo.FrequencyOffset = 0;
yIn = y * 10^(-60 / 20);
[yr, info] = rf.rxHardware(sr, yIn, 0, 1097);
dP = 10 * log10(mean(abs(yr(on)).^2) / mean(abs(yIn(on)).^2));
assert(abs(dP) < 0.2, 'receiver changed the absolute power by %.2f dB', dP);
assert(info.clipFrac < 1e-3, 'receiver clipped %.3f %% of samples on a normal slot', 100 * info.clipFrac);
fprintf('test_rfHardware: PA %.2f dBm, EVM %.2f %%, in-band emission %.1f dBc, CFO %.1f Hz (drawn %.1f), RX scale %.3f dB -- all assertions passed.\n', ...
    pDbm, 100 * evm, leakDbc, fEst, st4.foHz, dP);
end
