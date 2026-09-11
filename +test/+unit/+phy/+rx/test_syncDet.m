function test_syncDet()
%test_syncDet Acquisition (+sync/) and blind detection (+det/).
%SPEC: none of this is normative -- +phy/+rx/CLAUDE.md: "Not specified anywhere. This is where
%      our performance comes from." So the assertions are on ACQUISITION PROBABILITY, TIMING
%      ERROR and the false-alarm/missed-detection PAIR, which is what that file asks for, not
%      on bit-exactness against a clause.

carrier = struct();
mu = 1; nSub = 132; Nsymb = 13;
NID1 = 200; NID2 = 1; NIDSL = NID1 + 336 * NID2;

cfg = phy.ts38211.slPSBCHConfig(NIDSL, Nsymb);
blockGrid = complex(zeros(132, Nsymb));
blockGrid = phy.chan.psbchTx(blockGrid, carrier, cfg, randi([0 1], 32, 1), NID1, NID2);
[wave, fs] = phy.lib.ofdmMod(blockGrid, mu, 0);
sigPow = mean(abs(wave).^2);

%% ---- pssSearch finds timing AND N_ID,2 together ------------------------
% The S-PSS sequence depends on N_ID,2, so the two are acquired jointly: there is no "find the
% timing, then read the identity". Correlating against one hypothesis only would find half the
% cells and lock onto a sidelobe for the other half.
delay = 137;
rxw = [complex(zeros(delay, 1)); wave; complex(zeros(500, 1))];
[off, n2, peak, prof] = phy.rx.sync.pssSearch(rxw, mu, nSub, 400);
assert(off == delay, 'timing must be exact with no impairment: got %d, want %d', off, delay);
assert(n2 == NID2, 'the S-PSS hypothesis must be recovered: got %d, want %d', n2, NID2);
assert(peak > 0.9, 'the correlation peak must be near unity with no noise, got %.3f', peak);
% The margin over the wrong hypothesis is what makes this a detection rather than a coin flip.
assert(max(prof(:, n2 + 1)) > 3 * max(prof(:, 2 - n2)), ...
    'the correct hypothesis must dominate: %.3f vs %.3f', max(prof(:, n2 + 1)), max(prof(:, 2 - n2)));

%% ---- acquisition probability vs SNR, which is the real metric ----------
st = RandStream('mt19937ar', 'Seed', 7);
rates = zeros(1, 3);
snrs = [-5 -10 -15];
for j = 1:3
    nv = sigPow / 10^(snrs(j) / 10);
    ok = 0; nTrial = 15;
    for t = 1:nTrial
        r = rxw + sqrt(nv / 2) * (randn(st, size(rxw)) + 1j * randn(st, size(rxw)));
        [o, n] = phy.rx.sync.pssSearch(r, mu, nSub, 400);
        ok = ok + (abs(o - delay) <= 2 && n == NID2);
    end
    rates(j) = ok / nTrial;
end
assert(rates(1) > 0.9, 'acquisition at -5 dB must be reliable, got %.2f', rates(1));
assert(rates(2) > 0.8, 'acquisition at -10 dB must still be good, got %.2f', rates(2));
assert(all(diff(rates) <= 0.1), 'acquisition must not improve as SNR falls: %s', mat2str(rates));

%% ---- sssDetect completes the identity ----------------------------------
[n1, nsl, pk, margin] = phy.rx.sync.sssDetect(blockGrid, NID2);
assert(n1 == NID1, 'N_ID,1 must be recovered: got %d, want %d', n1, NID1);
assert(nsl == NIDSL, 'N_ID^SL must be composed as NID1 + 336*NID2: got %d, want %d', nsl, NIDSL);
assert(pk > 0.99, 'the S-SSS correlation must be near unity on a clean grid, got %.3f', pk);
% 336 hypotheses, and the winner must be clear of the runner-up. A thin margin would mean the
% sequence family is not doing its job, not that the detector is weak.
assert(margin > 0.5, 'the winning S-SSS hypothesis must be well clear of the next, margin %.3f', margin);
% The identity is only complete with BOTH halves. For NID2 = 0 the two are numerically equal,
% so a caller that used NID1 where N_ID^SL was wanted would work on half the cells and fail on
% the other half -- which is why sssDetect returns the composed value.
[~, nslZero] = phy.rx.sync.sssDetect(blockGrid, 0);
assert(nslZero < 336, 'with NID2 = 0 the composed identity is just NID1, which is the trap');
mustError(@() phy.rx.sync.sssDetect(blockGrid, 2), 'rx:sync:sssDetect:badNID2', 'an N_ID,2 outside 0..1');

%% ---- cfoEstimate: flat error across its range --------------------------
% The estimator has a small constant bias (~63 Hz at mu=1, 0.2% of the subcarrier spacing) that
% is documented in its header rather than corrected. What matters is that the error is FLAT --
% a bias that varied with offset would mean the conversion itself is wrong.
errs = zeros(1, 5);
offsets = [-4000 -1500 0 1500 4000];
for j = 1:5
    t = (0:numel(wave) - 1)' / fs;
    w = wave .* exp(1j * 2 * pi * offsets(j) * t);
    errs(j) = phy.rx.sync.cfoEstimate(w, mu, nSub) - offsets(j);
end
assert(max(abs(errs)) < 200, 'CFO error must stay small across the range, got %s Hz', mat2str(round(errs)));
assert(max(errs) - min(errs) < 10, 'the CFO error must be FLAT across offsets (a constant bias), spread %.1f Hz', max(errs) - min(errs));

%% ---- pscchSearch sweeps positions, not transmissions -------------------
pool = struct('sl_DMRS_ScrambleID_r16_Present', false, 'sl_DMRS_ScrambleID_r16', 0);
numSubchannel = 10; subchSizeRb = 10; A = 32;
tmpl = phy.ts38211.slPSCCHConfig(pool, struct('startPRB', 0, 'NRB', subchSizeRb, ...
    'symbols', 1:2, 'nsf', 0, 'NsymbSlot', 14));
slotGrid = complex(zeros(numSubchannel * subchSizeRb * 12, 14));
planted = 6;
pcfg = tmpl; pcfg.startPRB = planted * subchSizeRb;
bits = randi([0 1], A, 1);
slotGrid = phy.chan.pscchTx(slotGrid, carrier, pcfg, bits);

[found, sci, starts] = phy.rx.det.pscchSearch(slotGrid, carrier, tmpl, numSubchannel, subchSizeRb, A, 1e-9, 8);
assert(isequal(starts(found), planted), 'the search must find the PSCCH at sub-channel %d, found %s', planted, mat2str(starts(found)));
assert(isequal(sci(:, planted + 1), logical(bits(:))), 'and recover its payload');

% Missed detection and false alarm are reported as a PAIR, per +phy/+rx/CLAUDE.md -- either
% alone is meaningless. An empty grid must produce no detections: the CRC is the detector, and
% with 24 bits a false alarm on noise is rare but not impossible, so this pins the clean case.
emptyFound = phy.rx.det.pscchSearch(complex(zeros(size(slotGrid))), carrier, tmpl, numSubchannel, subchSizeRb, A, 1e-9, 8);
assert(nnz(emptyFound) == 0, 'an empty grid must yield no detections, got %d', nnz(emptyFound));

%% ---- psfchDetect judges each monitored resource independently ----------
% A UE can have several TBs outstanding, each with its own PRB and cyclic-shift pair. Judging
% them jointly -- say by taking the strongest correlation in the slot -- would let a loud ACK
% from one peer mask another peer's silence, turning a radio link failure into a healthy link.
fpool = struct('sl_PSFCH_HopID_r16_Present', true, 'sl_PSFCH_HopID_r16', 123);
mk = @(m0, prb) struct('m0', m0, 'lp', 12, 'nsf', 0, 'NsymbSlot', 14, 'startPRB', prb, 'symbol', 12);
fgrid = complex(zeros(120, 14));
dps = [mk(3, 5), mk(4, 7), mk(5, 9)];
for r = [1 3]
    bit = double(r == 1);
    dp = dps(r); dp.mcs = phy.ts38213.psfchCyclicShiftMcs(bit, false);
    fcfg = phy.ts38211.slPSFCHConfig(fpool, dp);
    fgrid = phy.chan.psfchTx(fgrid, carrier, fcfg);
end
[ab, det] = phy.rx.det.psfchDetect(fgrid, carrier, fpool, dps, [false false false], 0.5);
assert(isequal(ab, [1 -1 0]), 'ACK, DTX and NACK must be distinguished per resource, got %s', mat2str(ab));
assert(isequal(det, [true false true]), 'the silent resource must read as undetected, got %s', mat2str(det));
mustError(@() phy.rx.det.psfchDetect(fgrid, carrier, fpool, dps, [false false], 0.5), ...
    'rx:det:psfchDetect:sizeMismatch', 'a per-slot ackNackOnly flag instead of a per-resource one');

fprintf('test_syncDet: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_syncDet:noError', 'expected an error for %s, none raised', what);
end
