function seq = slSPSS(NID2)
%slSPSS Sidelink Primary Synchronization Signal (S-PSS) sequence.
%Spec:   TS 38.211 V16.10.0, clause 8.4.2.2.1
%Inputs: NID2  integer, 0 or 1 -- N_ID,2^SL (see clause 8.4.2.1 for its role in
%              the 672-value sidelink synchronization identity)
%Outputs: seq  127-by-1 double column vector, BPSK values in {+1,-1}
%             (d_S-PSS(0)..d_S-PSS(126))
%
%This is ONE m-sequence (degree 7, taps {4,0}, initial state [1 1 1 0 1 1 0]),
%read out at cyclic shift 22 + 43*NID2 -- shift 22 for NID2=0, shift 65 for
%NID2=1. It is NOT two different base sequences; see the "Known traps" entry
%in +phy/+ts38211/CLAUDE.md this corrects. Values cross-checked against an
%independent derivation from the same clause text: NID2=0 first 20 values
%[1,-1,-1,1,1,1,1,1,-1,-1,1,-1,-1,1,-1,1,-1,-1,-1,1], NID2=1 first 20
%[1,1,-1,-1,1,-1,1,1,-1,-1,-1,-1,1,-1,-1,-1,1,1,1,1].
if ~isscalar(NID2) || ~ismember(NID2, [0 1])
    error('ts38211:slSPSS:badNID2', 'slSPSS: NID2 must be 0 or 1, got %s', mat2str(NID2));
end
xseq = phy.ts38211.slMSeq([4 0], [1 1 1 0 1 1 0], 127);
n = (0:126)';
m = mod(n + 22 + 43*NID2, 127);
seq = 1 - 2*double(xseq(m+1).');
seq = seq(:);
end
