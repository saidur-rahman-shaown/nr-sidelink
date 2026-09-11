function test_psbchPsfch()
%test_psbchPsfch PSBCH (S-SS/PSBCH block) and PSFCH chains.
%SPEC: TS 38.212 V16.15.0 clause 8.1 (SL-BCH), TS 38.211 V16.10.0 clause 8.4 (S-PSS, S-SSS,
%      PSBCH and its DM-RS) and clause 8.3.4 (PSFCH format 0), with the cyclic shift chosen by
%      TS 38.213 clause 16.3.

carrier = struct();

%% ---- PSBCH: the S-SS/PSBCH block assembles and round-trips -------------
NID1 = 200; NID2 = 1; NIDSL = NID1 + 336 * NID2; Nsymb = 13;
cfg = phy.ts38211.slPSBCHConfig(NIDSL, Nsymb);
blockGrid = complex(zeros(132, Nsymb));
mib = randi([0 1], 32, 1);
[blockGrid, info] = phy.chan.psbchTx(blockGrid, carrier, cfg, mib, NID1, NID2);

rx = blockGrid(sub2ind(size(blockGrid), info.dataInd(:, 1) + 1, info.dataInd(:, 2) + 1));
[mibRx, crcOk] = phy.chan.psbchRx(rx, carrier, cfg, 1e-9, 8);
assert(crcOk, 'PSBCH loopback CRC must pass');
assert(isequal(logical(mibRx(:)), logical(mib(:))), 'PSBCH loopback must be bit-exact');

%% ---- the codeword length must match the allocation, which is the defect guard
% TS 38.212 clause 8.1: "E = 1386 when higher layer parameter cyclicPrefix is configured,
% otherwise, E = 1782" -- cyclicPrefix is present only for EXTENDED CP, so extended is 1386 and
% normal is 1782. The resource grid says the same independently: normal CP has 13 S-SSB symbols,
% PSBCH occupies 99 subcarriers in Nsymb-4 of them, giving 891 REs = 1782 QPSK bits.
assert(info.nDataRE == 891, 'normal CP must give 891 PSBCH data REs, got %d', info.nDataRE);
assert(info.E == 1782, 'and therefore E = 1782, got %d', info.E);
assert(size(phy.ts38211.slPSBCHIndices(11), 1) == 693, 'extended CP must give 693 REs');
% slBchEncode was inverted on these two labels until 2026-09-11 and psbchTx compensated at its
% call site; both are corrected now, so the label and the allocation must agree directly.
assert(numel(phy.ts38212.slBchEncode(mib, 'normal')) == 1782 && ...
       numel(phy.ts38212.slBchEncode(mib, 'extended')) == 1386, ...
       'slBchEncode must give normal CP 1782 bits and extended 1386, per clause 8.1 and TS 38.331''s cyclicPrefix field');

%% ---- RE accounting across the whole block ------------------------------
% Every RE is attributable, nothing is claimed twice, and the unwritten ones are exactly the
% sync guard subcarriers: S-PSS and S-SSS carry 127 values in a 132-subcarrier block, so 5
% subcarriers x 2 symbols x 2 signals = 20 REs stay empty.
allInd = [info.dataInd; info.dmrsInd; info.spssInd; info.sssInd];
lin = sub2ind(size(blockGrid), allInd(:, 1) + 1, allInd(:, 2) + 1);
assert(numel(unique(lin)) == numel(lin), 'no RE in the S-SSB block may be claimed twice');
assert(nnz(blockGrid) == numel(lin), 'every claimed RE must be written: %d written, %d claimed', nnz(blockGrid), numel(lin));
assert(numel(blockGrid) - numel(lin) == 20, 'the unclaimed REs must be the 20 sync guard subcarriers, got %d', numel(blockGrid) - numel(lin));

% S-PSS is the SAME 127-value sequence in each of two symbols, not one 254-long sequence.
spss = phy.ts38211.slSPSS(NID2);
sym1 = blockGrid(sub2ind(size(blockGrid), info.spssInd(1:127, 1) + 1, info.spssInd(1:127, 2) + 1));
sym2 = blockGrid(sub2ind(size(blockGrid), info.spssInd(128:254, 1) + 1, info.spssInd(128:254, 2) + 1));
assert(isequal(sym1, complex(spss)) && isequal(sym2, complex(spss)), 'S-PSS must be the same sequence repeated in both symbols');

%% ---- PSBCH is very robust, which is what a sync channel must be -------
% 32 information bits over 1782 coded bits, so it decodes far below where any data channel
% could. That is the property acquisition depends on.
st = RandStream('mt19937ar', 'Seed', 3);
nv = 10^(12 / 10);                                  % SNR = -12 dB
fails = 0; nTrial = 40;
for t = 1:nTrial
    r = rx + sqrt(nv / 2) * (randn(st, size(rx)) + 1j * randn(st, size(rx)));
    [m, ok] = phy.chan.psbchRx(r, carrier, cfg, nv, 8);
    fails = fails + (~ok || ~isequal(logical(m(:)), logical(mib(:))));
end
assert(fails / nTrial < 0.25, 'PSBCH must still decode at -12 dB, got BLER %.2f', fails / nTrial);

%% ---- PSFCH: one PRB over two symbols, the first a duplicate ------------
pool = struct('sl_PSFCH_HopID_r16_Present', true, 'sl_PSFCH_HopID_r16', 123);
base = struct('m0', 3, 'lp', 12, 'nsf', 0, 'NsymbSlot', 14, 'startPRB', 5, 'symbol', 12);

for bit = [0 1]
    dp = base; dp.mcs = phy.ts38213.psfchCyclicShiftMcs(bit, false);
    pcfg = phy.ts38211.slPSFCHConfig(pool, dp);
    grid = complex(zeros(120, 14));
    [grid, pinfo] = phy.chan.psfchTx(grid, carrier, pcfg);

    content = grid(sub2ind(size(grid), pinfo.ind(:, 1) + 1, pinfo.ind(:, 2) + 1));
    agc     = grid(sub2ind(size(grid), pinfo.agcInd(:, 1) + 1, pinfo.agcInd(:, 2) + 1));
    % +phy/+chan/CLAUDE.md's trap: 1 PRB over 2 symbols, first serving as AGC. Not 2 PRBs, not
    % one symbol. Writing only the content symbol leaves the AGC transient unabsorbed.
    assert(numel(content) == 12, 'PSFCH format 0 occupies exactly one PRB');
    assert(isequal(agc, content), 'the first PSFCH symbol must duplicate the second');
    assert(pinfo.agcInd(1, 2) == pinfo.ind(1, 2) - 1, 'the AGC symbol must immediately precede the content symbol');

    [b, det, m] = phy.chan.psfchRx(content, carrier, pool, base, false, 0.5);
    assert(det && b == bit, 'PSFCH must detect the transmitted bit %d, got %d (det=%d)', bit, b, det);
    % The two shifts are orthogonal, so the wrong hypothesis must score ~0.
    assert(m(bit + 1) > 0.99 && m(2 - bit) < 0.01, 'the two cyclic shifts must be orthogonal, got metrics [%.3f %.3f]', m(1), m(2));
end

% NACK-only mode: Table 16.3-3 gives ACK the literal entry "N/A", so there is no ACK hypothesis
% to test. Silence is the positive acknowledgement.
dp = base; dp.mcs = phy.ts38213.psfchCyclicShiftMcs(0, true);
pcfg = phy.ts38211.slPSFCHConfig(pool, dp);
g2 = complex(zeros(120, 14));
[g2, i2] = phy.chan.psfchTx(g2, carrier, pcfg);
r2 = g2(sub2ind(size(g2), i2.ind(:, 1) + 1, i2.ind(:, 2) + 1));
[b2, d2, m2] = phy.chan.psfchRx(r2, carrier, pool, base, true, 0.5);
assert(d2 && b2 == 0, 'a NACK must be detected in NACK-only mode');
assert(m2(2) == 0, 'the ACK hypothesis must not be scored in NACK-only mode, got %.3f', m2(2));

% Nothing transmitted is a DTX, not a NACK. Clause 5.22.1.3.3 counts consecutive DTX toward
% radio link failure while a NACK only triggers a retransmission, so collapsing the two makes a
% UE that walked out of range look lossy-but-alive and never declare RLF.
st = RandStream('mt19937ar', 'Seed', 11);
[b3, d3] = phy.chan.psfchRx(0.01 * complex(randn(st, 12, 1), randn(st, 12, 1)), carrier, pool, base, false, 0.5);
assert(~d3 && b3 == -1, 'noise alone must yield a DTX (-1, undetected), got bit %d det %d', b3, d3);

fprintf('test_psbchPsfch: all assertions passed.\n');
end
