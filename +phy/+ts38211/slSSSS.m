function seq = slSSSS(NID1, NID2)
%slSSSS Sidelink Secondary Synchronization Signal (S-SSS) sequence.
%Spec:   TS 38.211 V16.10.0, clause 8.4.2.3.1
%Inputs: NID1  integer, 0..335 -- N_ID,1^SL
%        NID2  integer, 0 or 1 -- N_ID,2^SL
%Outputs: seq  127-by-1 double column vector, BPSK values in {+1,-1}
%             (d_S-SSS(0)..d_S-SSS(126))
%
%Product of two DIFFERENT m-sequences (x0: degree 7, taps {4,0}; x1: degree 7,
%taps {1,0}; both initial state [0 0 0 0 0 0 1]), each independently
%cyclically shifted (m0 from both NID1 and NID2; m1 from NID1 alone).
%Structurally the Uu-SSS construction (clause 7.4.2.3.1), not the clause-5.2.1
%Gold generator used for scrambling elsewhere in clause 8 -- "Gold-derived" in
%earlier project notes was imprecise; corrected here and in
%+phy/+ts38211/CLAUDE.md.
if ~isscalar(NID1) || NID1 < 0 || NID1 > 335 || mod(NID1, 1) ~= 0
    error('ts38211:slSSSS:badNID1', 'slSSSS: NID1 must be an integer in 0..335, got %s', mat2str(NID1));
end
if ~isscalar(NID2) || ~ismember(NID2, [0 1])
    error('ts38211:slSSSS:badNID2', 'slSSSS: NID2 must be 0 or 1, got %s', mat2str(NID2));
end
x0seq = phy.ts38211.slMSeq([4 0], [0 0 0 0 0 0 1], 127);
x1seq = phy.ts38211.slMSeq([1 0], [0 0 0 0 0 0 1], 127);
m0 = 15*floor(NID1/112) + 5*NID2;
m1 = mod(NID1, 112);
n = (0:126)';
idx0 = mod(n + m0, 127);
idx1 = mod(n + m1, 127);
seq = (1 - 2*double(x0seq(idx0+1).')) .* (1 - 2*double(x1seq(idx1+1).'));
seq = seq(:);
end
