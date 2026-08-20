function test_RFModule()
%test_RFModule Analog-equivalent transmitter: 23 dBm, oversampling, PA.

rs = RandStream('mt19937ar', 'Seed', 5);
[bb, prm] = ofdmBaseband(rs);
% one 0.5 ms slot of samples at the toolbox-reported rate (per-symbol CP
% lengths come from nrOFDMInfo, so check duration, not a uniform formula)
assert(abs(numel(bb) - prm.SampleRate * prm.SlotDur_s) < 2, ...
    'waveform must span one slot: %d samples at %.3g Hz', numel(bb), prm.SampleRate);
if prm.Toolbox
    assert(sum(prm.CyclicPrefixLengths(1:prm.SymbolsPerSlot)) + ...
        prm.SymbolsPerSlot * prm.Nfft == numel(bb), 'CP accounting (nrOFDMInfo)');
end

%% ideal chain: exact 23 dBm average power, 4x oversampling
rf = RFModule('SampleRate', prm.SampleRate, 'OversampleFactor', 4);
[y, info] = rf.transmit(bb);
assert(abs(info.AvgPower_dBm - 23) < 1e-9, ...
    'average power must be exactly 23 dBm, got %.6f', info.AvgPower_dBm);
assert(abs(mean(abs(y).^2) - 0.199526) < 1e-3, '23 dBm = 199.5 mW');
assert(numel(y) == 4 * numel(bb), 'oversampling factor 4');
assert(info.SampleRate == 4 * prm.SampleRate);
assert(info.PAPR_dB > 4, 'OFDM PAPR should exceed 4 dB, got %.2f', info.PAPR_dB);
assert(info.EVM_pct == 0, 'ideal PA: zero EVM');

%% Rapp PA: power still 23 dBm, PAPR compressed, EVM nonzero
rfPA = RFModule('SampleRate', prm.SampleRate, 'OversampleFactor', 4, ...
    'PAModel', 'rapp', 'PABackoff_dB', 3);
[~, infoPA] = rfPA.transmit(bb);
assert(abs(infoPA.AvgPower_dBm - 23) < 1e-9, 'PA must not change average power');
assert(infoPA.PAPR_dB < info.PAPR_dB, 'PA compression must reduce PAPR');
assert(infoPA.EVM_pct > 0, 'nonlinear PA must report EVM');

%% passband demo: real signal, power preserved by the sqrt(2) convention
fc = 5e6;                                  % demo carrier (fs/2 = 61.44 MHz)
s = rf.toPassband(y, fc);
assert(isreal(s), 'passband signal must be real');
Pbb = mean(abs(y).^2);
Ppb = mean(s.^2);
assert(abs(10*log10(Ppb/Pbb)) < 0.1, ...
    'passband power must match envelope power, ratio %.2f dB', 10*log10(Ppb/Pbb));

%% guards
gotErr = false;
try
    rf.toPassband(y, 100e6);               % 100 MHz > fs/2: must refuse
catch
    gotErr = true;
end
assert(gotErr, 'carrier above fs/2 must raise');

gotErr = false;
try
    rf.transmit(zeros(100, 1));
catch
    gotErr = true;
end
assert(gotErr, 'zero-energy input must raise');

fprintf('test_RFModule: PASS\n');
end
