function test_measurements()
%test_measurements Unit tests for +phy/+ts38215/'s sidelink physical layer measurements.
%SPEC: TS 38.215 V16.7.0 clause 5.1 (slRsrp: 5.1.22 PSBCH-RSRP / 5.1.23 PSSCH-RSRP / 5.1.24
%      PSCCH-RSRP; slRssi: 5.1.25; cr: 5.1.26; cbr: 5.1.27; cbrWindowSlots/crWindowSlots:
%      the window-length sentences of 5.1.27 and 5.1.26 NOTE 1)
%
%Synthetic grids with known per-RE power, so every expected value is a hand computation rather
%than a regression capture. Per +test/CLAUDE.md level 2 an independent-verifier pass (spec-only,
%blind to this code) is required before these are trusted -- see +phy/+ts38215/CLAUDE.md for
%what it found.
tol = 1e-12;

%% slRsrp -- clause 5.1.23, the antenna-port summation
% PSSCH-RSRP is "the linear average [...] of the resource elements OF THE ANTENNA PORT(S) [...]
% SUMMED OVER THE ANTENNA PORTS", so two ports carrying 4 W and 1 W per RE give 4+1 = 5 W, NOT
% the 2.5 W a joint average over all 12 (port, RE) pairs would give. This is the single most
% consequential reading in the module.
K = 12; L = 4;
dmrsInd = [(0:5)', ones(6, 1)];            % 6 DM-RS REs, all in symbol l=1
grid2 = zeros(K, L, 2);
for i = 1:6
    grid2(dmrsInd(i, 1) + 1, 2, 1) = 2;    % |2|^2 = 4 W on port 1
    grid2(dmrsInd(i, 1) + 1, 2, 2) = 1;    % |1|^2 = 1 W on port 2
end
[rsrpW, rsrpDbm, nRe] = phy.ts38215.slRsrp(grid2, dmrsInd, 'pssch');
assert(abs(rsrpW - 5) < tol, 'slRsrp: two-port PSSCH-RSRP must SUM the per-port averages (4+1=5 W), got %g -- 2.5 W means the ports were averaged together instead', rsrpW);
assert(nRe == 6, 'slRsrp: nRe is the per-port RE count (6), got %d', nRe);
assert(abs(rsrpDbm - (10*log10(5) + 30)) < tol, 'slRsrp: rsrpDbm must be 10*log10(rsrpW)+30');

% Single port, uneven powers: linear average of |RE|^2, not of |RE|.
gridA = zeros(K, L);
gridA(1, 2) = sqrt(2); gridA(2, 2) = sqrt(8); gridA(3, 2) = sqrt(2);
indA = [(0:2)', ones(3, 1)];
[rsrpA, dbmA, nReA] = phy.ts38215.slRsrp(gridA, indA, 'pscch');
assert(abs(rsrpA - 4) < tol, 'slRsrp: expected mean(|RE|^2) = mean([2 8 2]) = 4 W, got %g', rsrpA);
assert(nReA == 3 && abs(dbmA - (10*log10(4) + 30)) < tol, 'slRsrp: single-port PSCCH-RSRP outputs mismatch');

% A measurement over an empty index set is ABSENT, not zero (package interface rule).
[rsrpE, dbmE, nReE] = phy.ts38215.slRsrp(gridA, zeros(0, 2), 'pscch');
assert(isnan(rsrpE) && isnan(dbmE) && nReE == 0, 'slRsrp: an empty DM-RS index set must report an absent measurement (NaN, nRe=0), not 0 W');

% Clauses 5.1.22/5.1.24 define no port summation, so a multi-port grid has no normative answer.
try
    phy.ts38215.slRsrp(grid2, dmrsInd, 'pscch');
    error('test_measurements:shouldHaveErrored', 'slRsrp should reject a 2-port grid for a variant with no defined port summation');
catch e
    assert(strcmp(e.identifier, 'ts38215:slRsrp:badPorts'), 'slRsrp: wrong error for a multi-port PSCCH grid');
end
try
    phy.ts38215.slRsrp(gridA, indA, 'pssch_rsrp');
    error('test_measurements:shouldHaveErrored', 'slRsrp should reject an unknown variant label');
catch e
    assert(strcmp(e.identifier, 'ts38215:slRsrp:badVariant'), 'slRsrp: wrong error for an unknown variant');
end
try
    phy.ts38215.slRsrp(gridA, [0 99], 'pscch');
    error('test_measurements:shouldHaveErrored', 'slRsrp should reject indices outside the grid');
catch e
    assert(strcmp(e.identifier, 'ts38215:slRsrp:indexOutOfGrid'), 'slRsrp: wrong error for out-of-grid indices');
end

%% slRssi -- clause 5.1.25, "starting from the 2nd OFDM symbol"
% Symbol 0 (the AGC symbol) is loaded with 100 W/RE and symbols 1..3 with 2 W/RE, so including
% it would give (12*100 + 36*2)/48 = 26.5 W instead of 2 W. A 13x-off answer, deliberately:
% this exclusion is easy to drop and easy to apply twice.
gridR = zeros(12, 4);
gridR(:, 1) = 10;             % |10|^2 = 100 W per RE, symbol l=0
gridR(:, 2:4) = sqrt(2);      % |sqrt(2)|^2 = 2 W per RE, symbols l=1,2,3
[rssiW, rssiDbm, nReR] = phy.ts38215.slRssi(gridR, 0, 1, [0 1 2 3]);
assert(abs(rssiW - 2) < tol, 'slRssi: clause 5.1.25 starts at the 2nd OFDM symbol, so the AGC symbol must be excluded -- expected 2 W, got %g (26.5 W means it was included)', rssiW);
assert(nReR == 36, 'slRssi: expected 3 measured symbols x 12 subcarriers = 36 REs, got %d', nReR);
assert(abs(rssiDbm - (10*log10(2) + 30)) < tol, 'slRssi: rssiDbm must be 10*log10(rssiW)+30');

% RSSI is TOTAL received power over every RE of the sub-channel, not just reference signals:
% an empty (zero) RE drags the average down rather than being skipped.
gridZ = zeros(12, 3);
gridZ(1:6, 2) = 2;            % lower half of the PRB at |2|^2 = 4 W, upper half left empty,
gridZ(1:6, 3) = 2;            % in both measured symbols l=1 and l=2
rssiZ = phy.ts38215.slRssi(gridZ, 0, 1, [0 1 2]);
assert(abs(rssiZ - 2) < tol, 'slRssi: expected the total-power average over all 24 measured REs (12 at 4 W + 12 at 0 W = 48/24) = 2 W, got %g -- skipping empty REs would give 4 W', rssiZ);

% Sub-channel offset: measuring PRB 2 must read subcarriers 24..35, not 0..11.
gridS = zeros(48, 3);
gridS(25:36, 2:3) = 3;        % |3|^2 = 9 W per RE, PRB 2 only
rssiS = phy.ts38215.slRssi(gridS, 2, 1, [0 1 2]);
assert(abs(rssiS - 9) < tol, 'slRssi: prbStart=2 must address subcarriers 24..35, expected 9 W, got %g', rssiS);
rssiS0 = phy.ts38215.slRssi(gridS, 0, 1, [0 1 2]);
assert(rssiS0 == 0, 'slRssi: PRB 0 is empty in this grid, expected 0 W, got %g', rssiS0);

% A slot whose PSCCH/PSSCH region is one symbol long has nothing left after the exclusion.
[rssiN, dbmN, nReN] = phy.ts38215.slRssi(gridR, 0, 1, 0);
assert(isnan(rssiN) && isnan(dbmN) && nReN == 0, 'slRssi: a single-symbol region must report an absent measurement once the 2nd-symbol rule removes it');
try
    phy.ts38215.slRssi(gridR, 0, 1, [3 1 2]);
    error('test_measurements:shouldHaveErrored', 'slRssi should reject non-ascending slotSymbols');
catch e
    assert(strcmp(e.identifier, 'ts38215:slRssi:badSymbols'), 'slRssi: wrong error for unsorted slotSymbols');
end
try
    phy.ts38215.slRssi(gridR, 5, 1, [0 1 2 3]);
    error('test_measurements:shouldHaveErrored', 'slRssi should reject a sub-channel past the end of the grid');
catch e
    assert(strcmp(e.identifier, 'ts38215:slRssi:subchannelOutOfGrid'), 'slRssi: wrong error for an out-of-grid sub-channel');
end

%% cbrWindowSlots / crWindowSlots -- the ms-vs-slot labels
% The two labels coincide only at mu=0, so mu=0 alone cannot tell them apart.
assert(phy.ts38215.cbrWindowSlots('slot100', 0) == 100 && phy.ts38215.cbrWindowSlots('ms100', 0) == 100, 'cbrWindowSlots: both labels give 100 slots at mu=0');
assert(phy.ts38215.cbrWindowSlots('slot100', 2) == 100, 'cbrWindowSlots: ''slot100'' is 100 slots at every numerology');
assert(phy.ts38215.cbrWindowSlots('ms100', 2) == 400, 'cbrWindowSlots: ''ms100'' at mu=2 is 100*2^2 = 400 slots');
assert(phy.ts38215.cbrWindowSlots('ms100', 3) == 800, 'cbrWindowSlots: ''ms100'' at mu=3 is 800 slots');
assert(phy.ts38215.crWindowSlots('slot1000', 3) == 1000, 'crWindowSlots: ''slot1000'' is 1000 slots at every numerology');
assert(phy.ts38215.crWindowSlots('ms1000', 1) == 2000, 'crWindowSlots: ''ms1000'' at mu=1 is 1000*2 = 2000 slots');
try
    phy.ts38215.cbrWindowSlots('ms1000', 0);
    error('test_measurements:shouldHaveErrored', 'cbrWindowSlots should reject the CR label');
catch e
    assert(strcmp(e.identifier, 'ts38215:cbrWindowSlots:badLabel'), 'cbrWindowSlots: wrong error for a CR-shaped label');
end

%% cbr -- clause 5.1.27
% Threshold -90 dBm. "Exceed" is strict, so the sub-channel measuring exactly -90 is NOT busy.
% The NaN (an own-transmission slot the UE could not sense) leaves both numerator and
% denominator, so the denominator is 7 measured samples, not 8.
rssiMat = [-85 -95 -90 -80; ...
           -88 -100 NaN -70];
[cbrRatio, nBusy, nSamples] = phy.ts38215.cbr(rssiMat, -90);
assert(nSamples == 7, 'cbr: the unmeasured (NaN) sample must leave the denominator, expected 7, got %d', nSamples);
assert(nBusy == 4, 'cbr: expected 4 busy samples (-85,-80,-88,-70; -90 does NOT exceed -90), got %d', nBusy);
assert(abs(cbrRatio - 4/7) < tol, 'cbr: expected 4/7, got %g', cbrRatio);

% Boundary, isolated: a single sample exactly at the threshold is idle, not busy.
[cbrEq, nBusyEq] = phy.ts38215.cbr(-90, -90);
assert(cbrEq == 0 && nBusyEq == 0, 'cbr: SL RSSI exactly equal to sl-ThreshS-RSSI-CBR must NOT count as busy ("exceed" is strict)');
[cbrAbove, nBusyAbove] = phy.ts38215.cbr(-89.999, -90);
assert(cbrAbove == 1 && nBusyAbove == 1, 'cbr: SL RSSI just above the threshold must count as busy');

assert(phy.ts38215.cbr([-50 -50; -50 -50], -90) == 1, 'cbr: an entirely busy window must give 1');
assert(phy.ts38215.cbr([-120 -120], -90) == 0, 'cbr: an entirely idle window must give 0');

% An all-NaN window is ABSENT, not idle -- the boot case, and the one that must never be read
% as "CBR = 0, channel free".
[cbrNan, nBusyNan, nSamplesNan] = phy.ts38215.cbr([NaN NaN; NaN NaN], -90);
assert(isnan(cbrNan) && nBusyNan == 0 && nSamplesNan == 0, 'cbr: a fully unmeasured window must report absent (NaN), never 0');

%% cr -- clause 5.1.26
% A CONFORMANT window first: 'slot1000' gives a+b+1 = 1000, split a=899/b=100 satisfying
% NOTE 1's b < (a+b+1)/2. Deliberately a real window size -- the independent-verifier pointed
% out that a suite built only on a scaled-down a=8,b=1 fixture would silently pass a cr() that
% never range-checked the window at all, which is what an earlier version of it did.
totalW = phy.ts38215.crWindowSlots('slot1000', 0);
assert(totalW == 1000, 'crWindowSlots: ''slot1000'' must give 1000 slots');
[crRatio, nUsed, nConfigured] = phy.ts38215.cr(10, 2, 5, 899, 100, totalW);
assert(nConfigured == 5000, 'cr: denominator must be numSubchannel*(a+b+1) = 5*1000 = 5000, got %d', nConfigured);
assert(nUsed == 12, 'cr: numerator must be used+granted = 10+2 = 12, got %d', nUsed);
assert(abs(crRatio - 12/5000) < tol, 'cr: expected 12/5000, got %g', crRatio);

% The a+b+1 vs a+b question, isolated on a small window so the two differ visibly (50 vs 45).
% [n-a, n+b] is INCLUSIVE at both ends, so it spans a+b+1 = 10 slots.
[crSmall, ~, nConfSmall] = phy.ts38215.cr(10, 2, 5, 8, 1, 10);
assert(nConfSmall == 50, 'cr: denominator must be numSubchannel*(a+b+1) = 5*10 = 50, got %d -- 45 means the window was treated as a+b slots', nConfSmall);
assert(abs(crSmall - 0.24) < tol, 'cr: expected 12/50 = 0.24, got %g', crSmall);

% b=0 is legal (NOTE 1: "b is 0 or a positive integer") and slot n still counts, on the GRANTED
% side -- so a 10-slot window with a=9 leaves exactly slot n for the grant.
[crB0, ~, nConfB0] = phy.ts38215.cr(0, 3, 2, 9, 0, 10);
assert(nConfB0 == 20, 'cr: with a=9,b=0 the window is still 10 slots, expected denominator 2*10=20, got %d', nConfB0);
assert(abs(crB0 - 3/20) < tol, 'cr: expected 3/20, got %g', crB0);

% An idle UE occupies nothing.
assert(phy.ts38215.cr(0, 0, 5, 8, 1, 10) == 0, 'cr: a UE that transmitted nothing and holds no grant must have CR 0');

% NOTE 1's constraints: b < (a+b+1)/2, a >= 1, and a+b+1 equal to the configured window total.
try
    phy.ts38215.cr(1, 1, 5, 2, 5, 8);
    error('test_measurements:shouldHaveErrored', 'cr should reject b >= (a+b+1)/2');
catch e
    assert(strcmp(e.identifier, 'ts38215:cr:badSplit'), 'cr: wrong error for a b violating NOTE 1');
end
try
    phy.ts38215.cr(1, 1, 5, 0, 1, 2);
    error('test_measurements:shouldHaveErrored', 'cr should reject a=0 (NOTE 1: a is a positive integer)');
catch e
    assert(strcmp(e.identifier, 'ts38215:cr:badA'), 'cr: wrong error for a=0');
end
try
    phy.ts38215.cr(10, 2, 5, 8, 1, 1000);
    error('test_measurements:shouldHaveErrored', 'cr should reject a split whose a+b+1 does not equal the configured window total');
catch e
    assert(strcmp(e.identifier, 'ts38215:cr:badWindowTotal'), 'cr: wrong error for a split not summing to sl-TimeWindowSizeCR''s total');
end

% Per-priority CR (NOTE 5) keeps the SAME denominator, which is what makes TS 38.214 clause
% 8.1.6's sum_{i>=k} CR(i) meaningful: the eight per-priority CRs sum to the UE's total CR.
crP3 = phy.ts38215.cr(6, 1, 5, 899, 100, totalW);
crP5 = phy.ts38215.cr(4, 1, 5, 899, 100, totalW);
assert(abs((crP3 + crP5) - crRatio) < tol, 'cr: per-priority CRs computed over the same window must sum to the total CR (6+4 used, 1+1 granted), got %g vs %g', crP3 + crP5, crRatio);

fprintf('test_measurements: PASS\n');
end
