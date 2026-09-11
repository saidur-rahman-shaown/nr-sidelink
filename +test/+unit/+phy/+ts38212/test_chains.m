function test_chains()
%test_chains Unit tests for +phy/+ts38212/'s transport-channel processing chains: slBchEncode
%(clause 8.1), slSchEncode (clause 8.2), sci1aChainEncode (clause 8.3.2-8.3.4),
%sci2OutputLength/sci2ChainEncode (clause 8.4.2-8.4.4), sci12Multiplex (clause 8.2.1); plus the
%generic clause 7.3.2 primitive in +phy/+lib/+ts38212/ the SCI chains are built from:
%dciCrcEncode/dciCrcCheck. slSchEncode's toolbox body (nrULSCH) covers clause 6.2.1-6.2.2's CRC-
%polynomial-select and base-graph-select internally -- no separate primitives for those needed
%here (see slSchEncode.m's header for the bit-identical cross-check against the previous
%hand-composed chain that was done before making that switch).
%SPEC: TS 38.212 V16.15.0 clause 7.3.2 (dciCrcEncode/dciCrcCheck), clause 8.1 (slBchEncode),
%      clause 8.2/8.2.1 (slSchEncode/sci12Multiplex), clause 8.3.2-8.3.4 (sci1aChainEncode),
%      clause 8.4.2-8.4.4 (sci2OutputLength/sci2ChainEncode); TS 38.211 clause 8.3.1.2 Table
%      8.3.1.2-1 (slSchEncode's modulation restriction)
%
%Structural/shape assertions and round trips only at this stage -- per +test/CLAUDE.md level 2,
%an independent-verifier pass on the genuinely new hand-derived procedures (dciCrcEncode's
%prepend-ones CRC, sci12Multiplex's NL=1 algorithm, sci2OutputLength's sizing formula) is still
%required before this is considered done -- see +phy/+ts38212/CLAUDE.md.

%% dciCrcEncode worked examples (independent-verifier, hand-derived from clause 7.3.2, never
%% saw this code) -- locks in both the 24-ones-prepend behaviour and the RNTI mask 8/16 bit
%% split (top 8 parity bits unmasked, low 16 masked with the RNTI MSB-first).
blkWorked = [1;0;1;1;0;0;1;0];
gotNoMask = phy.lib.ts38212.dciCrcEncode(blkWorked, []);
expectedNoMask = [1;0;1;1;0;0;1;0; 0;0;1;0;0;1;0;1;1;1;0;0;1;1;1;1;1;0;0;0;1;1;1;0];
assert(isequal(double(gotNoMask), double(expectedNoMask)), 'dciCrcEncode: no-mask worked example mismatch');

gotMasked = phy.lib.ts38212.dciCrcEncode(blkWorked, 43981); % 0xABCD
expectedMasked = [1;0;1;1;0;0;1;0; 0;0;1;0;0;1;0;1;0;1;1;0;0;1;0;0;0;1;0;0;0;0;1;1];
assert(isequal(double(gotMasked), double(expectedMasked)), 'dciCrcEncode: masked (0xABCD) worked example mismatch');

%% dciCrcEncode / dciCrcCheck
a = randi([0 1], 100, 1);
withCrc = phy.lib.ts38212.dciCrcEncode(a, []);
assert(numel(withCrc) == 124, 'dciCrcEncode: expected A+24=124 bits, got %d (not A+24+24 -- the prepended ones must be dropped)', numel(withCrc));
assert(isequal(double(withCrc(1:100)), double(a)), 'dciCrcEncode: data bits altered');

[aBack, err] = phy.lib.ts38212.dciCrcCheck(withCrc, []);
assert(err == 0, 'dciCrcCheck: CRC did not verify on an unmodified block');
assert(isequal(double(aBack), double(a)), 'dciCrcCheck: recovered data does not match original');

withCrcBad = withCrc;
withCrcBad(1) = ~withCrcBad(1);
[~, errBad] = phy.lib.ts38212.dciCrcCheck(withCrcBad, []);
assert(errBad ~= 0, 'dciCrcCheck: corrupted block should not verify');

%% slBchEncode
mibBits = logical(randi([0 1], 32, 1));
% Clause 8.1 states the rule in terms of the RRC field: E = 1386 when cyclicPrefix is
% CONFIGURED, otherwise 1782. TS 38.331's BWP IE makes that field ENUMERATED {extended}
% OPTIONAL, "If not set, the UE uses the normal cyclic prefix" -- so configured means extended.
% Hence normal = 1782 and extended = 1386.
%
% This assertion pinned the INVERSE until 2026-09-11, which is why the defect survived: the
% code and its test agreed with each other. The lengths are now cross-checked against the
% resource allocation they must fill, which is the independent fact neither could fake.
outNormal = phy.ts38212.slBchEncode(mibBits, 'normal');
assert(numel(outNormal) == 1782, 'slBchEncode: normal CP expected 1782 bits, got %d', numel(outNormal));
outExtended = phy.ts38212.slBchEncode(mibBits, 'extended');
assert(numel(outExtended) == 1386, 'slBchEncode: extended CP expected 1386 bits, got %d', numel(outExtended));
% The cross-check: TS 38.211 clause 8.4.3.1 gives N_symb^S-SSB = 13 (normal) / 11 (extended),
% and Table 8.4.3.1-1 puts PSBCH on (N_symb - 4) symbols x 99 subcarriers. QPSK, so the coded
% length must be exactly twice the RE count. A future inversion fails HERE, against 38.211,
% rather than agreeing with itself.
assert(numel(outNormal) == 2 * size(phy.ts38211.slPSBCHIndices(13), 1), ...
    'the normal-CP codeword must exactly fill the 891 PSBCH REs of a 13-symbol S-SSB');
assert(numel(outExtended) == 2 * size(phy.ts38211.slPSBCHIndices(11), 1), ...
    'the extended-CP codeword must exactly fill the 693 PSBCH REs of an 11-symbol S-SSB');

try
    phy.ts38212.slBchEncode(mibBits, 'invalid');
    error('test_chains:shouldHaveErrored', 'slBchEncode should reject an illegal cyclicPrefix');
catch e
    assert(strcmp(e.identifier, 'ts38212:slBchEncode:badCyclicPrefix'), 'slBchEncode: wrong error for illegal cyclicPrefix');
end

%% slSchEncode
tbBits = randi([0 1], 1000, 1);
outlenSch = 6000;
gSlSch = phy.ts38212.slSchEncode(tbBits, 0.5, outlenSch, 0, 'QPSK', 1);
assert(numel(gSlSch) == outlenSch, 'slSchEncode: expected %d bits, got %d', outlenSch, numel(gSlSch));

% TS 38.211 Table 8.3.1.2-1: PSSCH data supports QPSK/16QAM/64QAM/256QAM only, no BPSK of
% either form -- confirmed against the rendered spec table. nrULSCH's own validation would
% catch 'BPSK' too but not 'pi/2-BPSK' (which it wrongly permits for sidelink use), so this
% function's own check is load-bearing, not redundant with the toolbox body's.
try
    phy.ts38212.slSchEncode(tbBits, 0.5, outlenSch, 0, 'BPSK', 1);
    error('test_chains:shouldHaveErrored', 'slSchEncode should reject BPSK (not in Table 8.3.1.2-1)');
catch e
    assert(strcmp(e.identifier, 'ts38212:slSchEncode:badModulation'), 'slSchEncode: wrong error for illegal modulation BPSK');
end
try
    phy.ts38212.slSchEncode(tbBits, 0.5, outlenSch, 0, 'pi/2-BPSK', 1);
    error('test_chains:shouldHaveErrored', 'slSchEncode should reject pi/2-BPSK (not in Table 8.3.1.2-1, even though nrULSCH alone would accept it)');
catch e
    assert(strcmp(e.identifier, 'ts38212:slSchEncode:badModulation'), 'slSchEncode: wrong error for illegal modulation pi/2-BPSK');
end

% Boundary cases (CRC-poly threshold A=3824/3825, base-graph thresholds) are now handled
% internally by nrULSCH (toolbox-verified) rather than by separate primitives in this
% package -- see slSchEncode.m's header for the bit-exact cross-check against the previous
% hand-composed chain across these exact boundaries, done before switching.

%% sci1aChainEncode
sci1aBits = randi([0 1], 42, 1);
Esci1a = 216;
gSci1a = phy.ts38212.sci1aChainEncode(sci1aBits, Esci1a);
assert(numel(gSci1a) == Esci1a, 'sci1aChainEncode: expected %d bits, got %d', Esci1a, numel(gSci1a));

%% sci2OutputLength / sci2ChainEncode
GSci2 = phy.ts38212.sci2OutputLength(35, 1.0, 0.5, 1.0, 2000, 0);
% Hand check: qBeta = ceil((35+24)*1.0/(2*0.5)) = ceil(59) = 59; qAlpha = ceil(1.0*2000) = 2000;
% Qprime = min(59,2000)+0 = 59; G = 59*2 = 118. Independent-verifier-confirmed.
assert(GSci2 == 118, 'sci2OutputLength: expected 118, got %d', GSci2);

% independent-verifier: the RE-bound (alpha*sumMscSci2) branch binds instead of the beta/R
% branch -- the nominal case above never exercises this side of the min().
GSci2ReBound = phy.ts38212.sci2OutputLength(35, 1.125, 0.05, 1.0, 40, 0);
assert(GSci2ReBound == 80, 'sci2OutputLength: RE-bound branch expected 80, got %d', GSci2ReBound);

% independent-verifier: gamma is additive OUTSIDE the min{} -- zero available REs
% (sumMscSci2=0) still yields a nonzero G when gamma>0. Confirms the min() isn't wrapping
% the whole expression.
GSci2GammaOutside = phy.ts38212.sci2OutputLength(35, 1.125, 0.5, 1.0, 0, 7);
assert(GSci2GammaOutside == 14, 'sci2OutputLength: gamma-outside-min case expected 14, got %d', GSci2GammaOutside);

sci2Bits = randi([0 1], 35, 1);
gSci2 = phy.ts38212.sci2ChainEncode(sci2Bits, GSci2);
assert(numel(gSci2) == GSci2, 'sci2ChainEncode: expected %d bits, got %d', GSci2, numel(gSci2));

%% sci12Multiplex
gMux = phy.ts38212.sci12Multiplex(gSci2, gSlSch, 1, 2);
assert(numel(gMux) == numel(gSci2) + numel(gSlSch), 'sci12Multiplex: wrong output length');
assert(isequal(double(gMux(1:numel(gSci2))), double(gSci2)), 'sci12Multiplex: SCI-2 portion mismatch');

% independent-verifier: QmSci2 is unreferenced on the NL=1 path -- the output must be
% bit-identical regardless of its value. A sharper test than any single interior point: it
% fails loudly if NL=2-style Qm-chunking ever leaks into the NL=1 branch.
gMuxQm1 = phy.ts38212.sci12Multiplex(gSci2, gSlSch, 1, 1);
gMuxQm6 = phy.ts38212.sci12Multiplex(gSci2, gSlSch, 1, 6);
assert(isequal(gMuxQm1, gMux) && isequal(gMuxQm6, gMux), 'sci12Multiplex: NL=1 output must be invariant to QmSci2');
assert(isequal(double(gMux(numel(gSci2) + 1:end)), double(gSlSch)), 'sci12Multiplex: SL-SCH portion mismatch');

try
    phy.ts38212.sci12Multiplex(gSci2, gSlSch, 2, 2);
    error('test_chains:shouldHaveErrored', 'sci12Multiplex should reject NL=2 as not yet supported');
catch e
    assert(strcmp(e.identifier, 'ts38212:sci12Multiplex:nl2NotSupported'), 'sci12Multiplex: wrong error for NL=2');
end

fprintf('test_chains: PASS\n');
end
