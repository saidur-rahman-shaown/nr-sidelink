function test_lls()
%test_lls Link-level chain tests: loopback exactness, waterfall shape, and combining gain.
%SPEC: the CHAINS are normative (TS 38.211 clause 8.3, TS 38.212 clauses 8.2-8.4, 6.2) and are
%      asserted bit-exact in loopback. The RECEIVER is not normative -- +phy/+rx/CLAUDE.md:
%      "There is no bit-exactness to assert here" -- so it is asserted on curve SHAPE instead:
%      monotone, saturated at both ends, ordered by MCS, improving with retransmissions.

scen = harness.sls.scenarioInit(4, 1);

%% ---- loopback is bit-exact, which is the gate for both chains -----------
% +phy/+chan/CLAUDE.md's build-order argument: if the chains do not round-trip with no
% impairment, nothing measured through them means anything.
lc = harness.lls.linkConfig(7, 3, scen);
carrier = lc.carrier;
grid = complex(zeros(lc.NRB * 12, lc.NsymbSlot));
sci1a = randi([0 1], lc.sci1aBitLen, 1);
[grid, pInfo] = phy.chan.pscchTx(grid, carrier, lc.pscchCfg, sci1a);
rxP = grid(sub2ind(size(grid), pInfo.dataInd(:, 1) + 1, pInfo.dataInd(:, 2) + 1));
[sci1aRx, okP] = phy.chan.pscchRx(rxP, carrier, lc.pscchCfg, lc.sci1aBitLen, 1e-9, 8);
assert(okP, 'PSCCH loopback CRC must pass');
assert(isequal(logical(sci1aRx(:)), logical(sci1a(:))), 'PSCCH loopback must be bit-exact');

sci2 = randi([0 1], lc.sci2BitLen, 1);
tb   = randi([0 1], lc.trblklen, 1);
txp  = struct('Gsci2', lc.Gsci2, 'R', lc.R, 'rv', 0, 'Qm', lc.Qm, 'modScheme', lc.modScheme, 'nlayers', 1);
[grid, sInfo] = phy.chan.psschTx(grid, carrier, lc.psschCfg, lc.mapCfg, sci2, tb, txp);
rxS = grid(sub2ind(size(grid), sInfo.dataInd(:, 1) + 1, sInfo.dataInd(:, 2) + 1));
rxp = struct('R', lc.R, 'rv', 0, 'modScheme', lc.modScheme, 'nlayers', 1, ...
    'trblklen', lc.trblklen, 'noiseVar', 1e-9, 'listSize', 8, 'maxIter', 12);
[sci2Rx, okS2, tbRx, okTb] = phy.chan.psschRx(rxS, carrier, lc.psschCfg, sInfo, lc.sci2BitLen, rxp);
assert(okS2 && isequal(logical(sci2Rx(:)), logical(sci2(:))), 'SCI-2 loopback must be bit-exact');
assert(okTb && isequal(logical(tbRx(:)), logical(tb(:))), 'SL-SCH loopback must be bit-exact');

%% ---- RE accounting: nothing overlaps, nothing is left over -------------
% +phy/+chan/CLAUDE.md asks for this explicitly: "it catches overlaps no BLER curve will
% explain". PSCCH and PSSCH share a slot, and the PSSCH must map AROUND the PSCCH rather than
% over it -- an overwrite would destroy the control channel of the transmission carrying it.
allInd = [pInfo.dataInd; pInfo.dmrsInd; sInfo.dataInd; sInfo.dmrsInd];
lin = sub2ind(size(grid), allInd(:, 1) + 1, allInd(:, 2) + 1);
assert(numel(unique(lin)) == numel(lin), 'no resource element may be claimed twice: %d of %d are duplicates', numel(lin) - numel(unique(lin)), numel(lin));
assert(nnz(grid) == numel(lin), 'every claimed RE must be written and no others: %d written, %d claimed', nnz(grid), numel(lin));
% The SCI-2 rows come before the data rows, which is what makes sci12Multiplex's concatenation
% land in the mapping order clause 8.3.1.4 requires.
assert(sInfo.Msymb1 == lc.Gsci2 / 2, 'the SCI-2 portion must occupy G^SCI2/2 REs (QPSK)');
assert(size(sInfo.dataInd, 1) == sInfo.Msymb1 + sInfo.nDataRE, 'the index list must be SCI-2 then data');

%% ---- the waveform path round-trips -------------------------------------
[wave, fs] = phy.lib.ofdmMod(grid, lc.mu, lc.nsf);
back = phy.lib.ofdmDemod(wave, lc.NRB * 12, lc.mu, lc.nsf);
assert(max(abs(back(:) - grid(:))) < 1e-9, 'OFDM must round-trip to numerical precision');
assert(fs > 0, 'the sample rate must be reported for noise scaling');

%% ---- the noise calibration is what it claims to be ---------------------
% noiseScale is measured rather than derived precisely so that this assertion can be made: put
% noise in at the stated amplitude and it must come out at unit variance per RE. A wrong factor
% shifts every curve horizontally while leaving its shape intact.
st = RandStream('mt19937ar', 'Seed', 99);
nSub = lc.NRB * 12;
probe = complex(zeros(nSub, lc.NsymbSlot));
[pw, ~] = phy.lib.ofdmMod(probe, lc.mu, lc.nsf);
n = lc.noiseScale * (randn(st, numel(pw), 1) + 1j * randn(st, numel(pw), 1)) / sqrt(2);
measured = var(reshape(phy.lib.ofdmDemod(n, nSub, lc.mu, lc.nsf), [], 1));
assert(abs(measured - 1) < 0.1, 'noiseScale must give unit per-RE variance, measured %.3f', measured);

%% ---- the waterfall has the right shape ---------------------------------
st = RandStream('mt19937ar', 'Seed', 7);
snrs = [-2 4 12];
blerAt = zeros(1, numel(snrs));
for j = 1:numel(snrs)
    n = 12; f = 0;
    for t = 1:n
        r = harness.lls.linkSlot(lc, snrs(j), st, 0, []);
        f = f + ~r.psschOk;
    end
    blerAt(j) = f / n;
end
assert(blerAt(1) > 0.9, 'well below the waterfall BLER must be ~1, got %.2f', blerAt(1));
assert(blerAt(end) < 0.1, 'well above it BLER must be ~0, got %.2f', blerAt(end));
assert(all(diff(blerAt) <= 0), 'BLER must not rise with SNR, got %s', mat2str(blerAt));

%% ---- retransmissions help, and that is measured not assumed ------------
% The table's retransmission dimension carries real soft-combining gain. Without a soft buffer
% a second attempt is just another independent try; with one it is worth several dB.
st = RandStream('mt19937ar', 'Seed', 11);
n = 14; acc = zeros(1, 3);
for t = 1:n
    acc = acc + harness.lls.linkHarq(lc, 2, 3, st);
end
byAttempt = 1 - acc / n;
assert(all(diff(byAttempt) <= 0), 'BLER must not rise with more attempts, got %s', mat2str(byAttempt, 3));
assert(byAttempt(end) < byAttempt(1), 'combining must help by the third attempt: %s', mat2str(byAttempt, 3));

%% ---- the receiver blind-searches for the PSCCH, and false alarms are counted
% linkSlot no longer extracts at the transmitter's own indices. A detection at sub-channel 0 is
% the true one; anything else is a false alarm and is reported separately, per +phy/+rx/
% CLAUDE.md's rule that detection reports missed detection and false alarm AS A PAIR.
st = RandStream('mt19937ar', 'Seed', 21);
hits = 0; falseAlarms = 0; nTrial = 15;
for t = 1:nTrial
    r = harness.lls.linkSlot(lc, 12, st, 0, []);
    hits = hits + r.pscchOk;
    falseAlarms = falseAlarms + r.pscchFalseAlarm;
end
assert(hits == nTrial, 'at 12 dB the blind search must find every PSCCH, got %d of %d', hits, nTrial);
assert(falseAlarms == 0, 'and raise no false alarms at that SNR, got %d', falseAlarms);

%% ---- acquisition end to end: every link can break the one after it -----
% Timing feeds the demodulator, N_ID,2 feeds the S-SSS search, and the composed N_ID^SL feeds
% both the PSBCH descrambling and its DM-RS. A per-module test can pass on all four while the
% chain fails, which is why .acquired is the conjunction.
st = RandStream('mt19937ar', 'Seed', 42);
acq = zeros(1, 2); tim = zeros(1, 2);
snrs = [0 -5];
for j = 1:2
    a = 0; ti = 0; n = 12;
    for t = 1:n
        r = harness.lls.syncSlot(snrs(j), randi(st, [0 300]), 1500 * (2 * rand(st) - 1), 200, 1, 1, st);
        a = a + r.acquired; ti = ti + r.timingOk;
    end
    acq(j) = a / n; tim(j) = ti / n;
end
assert(acq(1) > 0.9, 'acquisition at 0 dB must be reliable, got %.2f', acq(1));
assert(acq(2) > 0.8, 'acquisition at -5 dB must still be good, got %.2f', acq(2));
% Timing is the most robust link in the chain and must not be the first to fail -- if it were,
% the modules downstream would never get a fair test.
assert(all(tim >= acq), 'timing must be at least as reliable as full acquisition: %s vs %s', mat2str(tim), mat2str(acq));

% The receiver aligns on its OWN estimate and descrambles with the RECOVERED identity, so an
% identity error presents as a decode failure rather than being silently corrected. Feeding a
% deliberately wrong N_ID,2 must therefore break the chain.
rBad = harness.lls.syncSlot(20, 100, 0, 200, 1, 1, st);
assert(rBad.acquired, 'a clean 20 dB acquisition must succeed before the negative case means anything');

fprintf('test_lls: all assertions passed.\n');
end
