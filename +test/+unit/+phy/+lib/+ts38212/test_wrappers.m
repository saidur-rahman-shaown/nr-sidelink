function test_wrappers()
%test_wrappers Unit tests for the +phy/+lib/+ts38212/ toolbox wrappers:
%crcEncode/crcCheck, cbSegment, polarEncode/polarRateMatch/polarDeRateMatch,
%ldpcEncode/ldpcRateMatch/ldpcDeRateMatch.
%SPEC: TS 38.212 V16.15.0 clause 5.1 (crcEncode/crcCheck), clause 5.2.2
%      (cbSegment), clause 5.3.1/5.4.1 (polar*), clause 5.3.2/5.4.2/5.5
%      (ldpc*)
%
%   Structural/shape assertions and round trips only at this stage -- these
%   are generation-side wrappers per +phy/+lib/CLAUDE.md's Tests split, so a
%   hand-computed worked example via independent-verifier is still required
%   before vectors are frozen (see +test/CLAUDE.md level 2). The polar
%   rate-match round trip mirrors nrRateMatchPolar's own documented example
%   (bit-selection/interleaving invertibility, not full SCL decode -- the
%   decoder is not built yet). The LDPC rate-match round trip is similarly
%   out of reach without the LDPC decoder, so ldpcRateMatch/ldpcDeRateMatch
%   are shape/error-only for now. See +phy/+lib/+ts38212/ch5-toolbox-survey.md.

%% crcEncode / crcCheck
poly = '24A'; L = 24;
a = randi([0 1], 100, 1);
b = phy.lib.ts38212.crcEncode(a, poly);
assert(islogical(b) && iscolumn(b) && numel(b) == 100 + L, 'crcEncode: wrong shape/type');
assert(isequal(double(b(1:100)), double(a)), 'crcEncode: data bits altered');

[aBack, err] = phy.lib.ts38212.crcCheck(b, poly);
assert(err == 0, 'crcCheck: CRC did not verify on an unmodified block');
assert(isequal(double(aBack), double(a)), 'crcCheck: recovered data does not match original');

bBad = b;
bBad(1) = ~bBad(1);
[~, errBad] = phy.lib.ts38212.crcCheck(bBad, poly);
assert(errBad ~= 0, 'crcCheck: corrupted block should not verify');

try
    phy.lib.ts38212.crcEncode(a, '99');
    error('test_wrappers:shouldHaveErrored', 'crcEncode should reject an illegal polynomial name');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:crcEncode:badPoly'), 'crcEncode: wrong error for illegal poly');
end

%% cbSegment -- LDPC segmentation boundary at Kcb (3840 for bgn=2)
bgn = 2; Kcb = 3840;
cbsNoSeg = phy.lib.ts38212.cbSegment(ones(Kcb, 1), bgn);
assert(size(cbsNoSeg, 2) == 1, 'cbSegment: expected C=1 at exactly Kcb');

cbsSeg = phy.lib.ts38212.cbSegment(ones(Kcb + 1, 1), bgn);
assert(size(cbsSeg, 2) == 2, 'cbSegment: expected C=2 just above Kcb');

try
    phy.lib.ts38212.cbSegment(ones(10, 1), 3);
    error('test_wrappers:shouldHaveErrored', 'cbSegment should reject bgn not in {1,2}');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:cbSegment:badBgn'), 'cbSegment: wrong error for illegal bgn');
end

%% polarEncode / polarRateMatch / polarDeRateMatch
K = 56; E = 864; N = 512; nMax = 10; iIL = false;
msg = randi([0 1], K, 1);
enc = phy.lib.ts38212.polarEncode(msg, E, nMax, iIL);
assert(islogical(enc) && numel(enc) == N, 'polarEncode: wrong output length');

rm = phy.lib.ts38212.polarRateMatch(enc, K, E, iIL);
assert(numel(rm) == E, 'polarRateMatch: wrong output length');

llrLike = 1 - 2 * double(rm);
recovered = phy.lib.ts38212.polarDeRateMatch(llrLike, K, N, iIL);
assert(isequal(recovered < 1, enc), 'polarRateMatch/polarDeRateMatch: round trip failed');

try
    phy.lib.ts38212.polarEncode(msg, E, 7, iIL);
    error('test_wrappers:shouldHaveErrored', 'polarEncode should reject nMax not in {9,10}');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:polarEncode:badNMax'), 'polarEncode: wrong error for illegal nMax');
end

%% ldpcEncode / ldpcRateMatch / ldpcDeRateMatch -- shape and error checks
bgnL = 2; Kseg = 2560; F = 36; C = 2;
cbs = [ones(Kseg - F, C); -1 * ones(F, C)];
coded = phy.lib.ts38212.ldpcEncode(cbs, bgnL);
assert(isequal(size(coded), [12800, C]), 'ldpcEncode: wrong output shape for the toolbox-documented example');

outlen = 8000; rv = 0; modulation = 'QPSK'; nlayers = 1;
rmLdpc = phy.lib.ts38212.ldpcRateMatch(coded, outlen, rv, modulation, nlayers, []);
assert(islogical(rmLdpc) && numel(rmLdpc) == outlen, 'ldpcRateMatch: wrong output length');

try
    phy.lib.ts38212.ldpcEncode(cbs, 3);
    error('test_wrappers:shouldHaveErrored', 'ldpcEncode should reject bgn not in {1,2}');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:ldpcEncode:badBgn'), 'ldpcEncode: wrong error for illegal bgn');
end
try
    phy.lib.ts38212.ldpcRateMatch(coded, outlen, 5, modulation, nlayers, []);
    error('test_wrappers:shouldHaveErrored', 'ldpcRateMatch should reject rv not in 0..3');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:ldpcRateMatch:badRv'), 'ldpcRateMatch: wrong error for illegal rv');
end
try
    phy.lib.ts38212.ldpcRateMatch(coded, outlen, rv, '1024QAM', nlayers, []);
    error('test_wrappers:shouldHaveErrored', 'ldpcRateMatch should reject 1024QAM (out of Rel-16 sidelink scope)');
catch e
    assert(strcmp(e.identifier, 'lib:ts38212:ldpcRateMatch:badModulation'), 'ldpcRateMatch: wrong error for illegal modulation');
end

% Independent, toolbox-documented shape example (not chained from the ldpcEncode/
% ldpcRateMatch section above -- deriving a consistent trblklen/R for that specific
% Kseg/C/bgn combination is itself a TBS/segmentation computation this wrapper does
% not own; see +phy/+lib/+ts38212/CLAUDE.md's base-graph-selection trap).
recoveredLdpc = phy.lib.ts38212.ldpcDeRateMatch(ones(4500, 1), 4000, 0.5, 0, 'QPSK', 1, []);
assert(isequal(size(recoveredLdpc), [12672, 1]), 'ldpcDeRateMatch: wrong output shape');

fprintf('test_wrappers (ts38212): PASS\n');
end
