function test_syncSignals()
%test_syncSignals Unit tests for slMSeq, slSPSS/slSPSSIndices, slSSSS/slSSSSIndices.
%SPEC: TS 38.211 V16.10.0 clause 8.4.2.2.1 (S-PSS), 8.4.2.3.1 (S-SSS), 8.4.3.1
%      (Table 8.4.3.1-1, RE mapping)
%
%   S-PSS/S-SSS values are cross-checked against an independent derivation
%   (independent-verifier subagent, no access to this implementation) pulled
%   directly from Documentations/38211-ga0.pdf clause text -- see the git
%   history / session notes for the derivation. Covers the boundary NID1
%   values (0, 335) and both NID2 values, plus an interior point.

%% slMSeq
x = phy.ts38211.slMSeq([4 0], [1 1 1 0 1 1 0], 127);
assert(numel(x) == 127 && islogical(x), 'slMSeq: wrong shape/type');

%% slSPSS
expected_NID2_0 = [1,-1,-1,1,1,1,1,1,-1,-1,1,-1,-1,1,-1,1,-1,-1,-1,1];
expected_NID2_1 = [1,1,-1,-1,1,-1,1,1,-1,-1,-1,-1,1,-1,-1,-1,1,1,1,1];

s0 = phy.ts38211.slSPSS(0);
s1 = phy.ts38211.slSPSS(1);
assert(numel(s0) == 127 && iscolumn(s0), 'slSPSS: wrong shape');
assert(isequal(s0(1:20)', expected_NID2_0), 'slSPSS: NID2=0 mismatch vs independent verification');
assert(isequal(s1(1:20)', expected_NID2_1), 'slSPSS: NID2=1 mismatch vs independent verification');
assert(all(abs(s0) == 1) && all(abs(s1) == 1), 'slSPSS: not +-1 valued');

try
    phy.ts38211.slSPSS(2);
    error('test_syncSignals:shouldHaveErrored', 'slSPSS should reject NID2=2');
catch e
    assert(strcmp(e.identifier, 'ts38211:slSPSS:badNID2'), 'slSPSS: wrong error for illegal NID2');
end

ind = phy.ts38211.slSPSSIndices();
assert(isequal(size(ind), [254 2]), 'slSPSSIndices: wrong size');
assert(all(ind(:,1) >= 2 & ind(:,1) <= 128), 'slSPSSIndices: k out of Table 8.4.3.1-1 range');
assert(isequal(unique(ind(:,2))', [1 2]), 'slSPSSIndices: l not {1,2}');

%% slSSSS
cases = { ...
    0,   0, [1,1,1,1,1,1,1,1,1,1,-1,1,1,1,1,1,-1,1,1,1]; ...
    1,   0, [-1,1,1,1,1,1,-1,-1,1,1,-1,1,-1,1,-1,1,-1,1,-1,-1]; ...
    0,   1, [-1,1,-1,1,1,-1,1,-1,-1,-1,1,-1,1,-1,1,-1,-1,-1,1,1]; ...
    112, 0, [-1,-1,1,1,-1,-1,-1,1,1,-1,-1,-1,1,-1,-1,1,-1,-1,-1,1]; ...
    335, 0, [-1,1,-1,-1,1,-1,1,-1,-1,1,-1,1,1,1,-1,1,1,1,1,1]; ...
    335, 1, [1,1,-1,1,-1,1,1,-1,1,1,1,1,-1,-1,-1,1,-1,-1,1,1]; ...
    167, 1, [-1,1,-1,1,-1,-1,1,-1,-1,1,1,-1,1,-1,-1,1,-1,-1,-1,-1] ...
};
for i = 1:size(cases, 1)
    n1 = cases{i,1}; n2 = cases{i,2}; expected = cases{i,3};
    s = phy.ts38211.slSSSS(n1, n2);
    assert(numel(s) == 127 && iscolumn(s) && all(abs(s) == 1), 'slSSSS: wrong shape/modulus at NID1=%d NID2=%d', n1, n2);
    assert(isequal(s(1:20)', expected), 'slSSSS: mismatch vs independent verification at NID1=%d NID2=%d', n1, n2);
end

indS = phy.ts38211.slSSSSIndices();
assert(isequal(size(indS), [254 2]), 'slSSSSIndices: wrong size');
assert(isequal(unique(indS(:,2))', [3 4]), 'slSSSSIndices: l not {3,4}');

fprintf('test_syncSignals: PASS\n');
end
