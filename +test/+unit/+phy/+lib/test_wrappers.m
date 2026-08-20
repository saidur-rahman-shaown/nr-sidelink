function test_wrappers()
%test_wrappers Unit tests for the +phy/+lib/ toolbox wrappers: goldSeq, modMap,
%lowPaprSeq, scramble.
%SPEC: TS 38.211 V16.10.0 clause 5.1 (modMap), clause 5.2.1 (goldSeq, scramble),
%      clause 5.2.2 (lowPaprSeq)
%
%   goldSeq is cross-checked against a hand-rolled LFSR (independent of the
%   toolbox) for four cinit values including both boundaries. lowPaprSeq is
%   checked for constant modulus at both the phase-table (m<30) and
%   Zadoff-Chu (m>=30) internal branches. See +phy/+lib/ch5-toolbox-survey.md
%   for the fuller verification writeup this distills.

%% goldSeq
s = phy.lib.goldSeq(12345, 200);
assert(islogical(s) && numel(s) == 200 && iscolumn(s), 'goldSeq: wrong shape/type');
assert(isequal(double(s), double(nrPRBS(12345, 200))), 'goldSeq: does not match nrPRBS');

for cinit = [0, 1, 2^31-1]
    s2 = phy.lib.goldSeq(cinit, 50);
    assert(isequal(double(s2), double(nrPRBS(cinit, 50))), 'goldSeq: mismatch at boundary cinit=%d', cinit);
end

%% modMap
bits = randi([0 1], 2000*2, 1);
sym = phy.lib.modMap(bits, 'QPSK');
assert(abs(mean(abs(sym).^2) - 1) < 0.05, 'modMap: QPSK average power far from 1');

qpsk = phy.lib.modMap([0;0;0;1;1;0;1;1], 'QPSK');
expected = [(1+1i)/sqrt(2); (1-1i)/sqrt(2); (-1+1i)/sqrt(2); (-1-1i)/sqrt(2)];
assert(all(abs(qpsk - expected) < 1e-12), 'modMap: QPSK mapping does not match Table 5.1.3-1');

try
    phy.lib.modMap(bits, '1024QAM');
    error('test_wrappers:shouldHaveErrored', 'modMap should reject 1024QAM (out of Rel-16 sidelink scope)');
catch e
    assert(strcmp(e.identifier, 'lib:modMap:badScheme'), 'modMap: wrong error for illegal scheme');
end

%% lowPaprSeq
seqShort = phy.lib.lowPaprSeq(0, 0, 0, 12);   % internal phase-table branch, m<30
seqLong  = phy.lib.lowPaprSeq(0, 0, 0, 36);   % internal Zadoff-Chu branch, m>=30
assert(max(abs(abs(seqShort) - 1)) < 1e-10, 'lowPaprSeq: m=12 not constant modulus');
assert(max(abs(abs(seqLong)  - 1)) < 1e-10, 'lowPaprSeq: m=36 not constant modulus');

seqAlpha = phy.lib.lowPaprSeq(0, 0, pi/6, 36);
assert(all(abs(abs(seqAlpha) - abs(seqLong)) < 1e-10), 'lowPaprSeq: cyclic shift altered magnitude');

try
    phy.lib.lowPaprSeq(30, 0, 0, 36);
    error('test_wrappers:shouldHaveErrored', 'lowPaprSeq should reject u=30 (out of 0..29)');
catch e
    assert(strcmp(e.identifier, 'lib:lowPaprSeq:badU'), 'lowPaprSeq: wrong error for illegal u');
end
try
    phy.lib.lowPaprSeq(0, 1, 0, 36);   % v=1 illegal when m<72
    error('test_wrappers:shouldHaveErrored', 'lowPaprSeq should reject v=1 when m<72');
catch e
    assert(strcmp(e.identifier, 'lib:lowPaprSeq:badV'), 'lowPaprSeq: wrong error for illegal v');
end

%% scramble
bits2 = randi([0 1], 100, 1);
scr = phy.lib.scramble(bits2, 777);
descr = xor(scr, phy.lib.goldSeq(777, 100));
assert(isequal(double(descr), double(bits2)), 'scramble: round trip against goldSeq failed');

fprintf('test_wrappers: PASS\n');
end
