function [NID1, NIDSL, peak, margin] = sssDetect(blockGrid, NID2)
%sssDetect Recover N_ID,1^SL from the S-SSS, completing the sidelink sync identity.
%Spec:   none -- detection is not specified. TS 38.211 clause 8.4.2.2 defines the S-SSS this
%        correlates against, and clause 8.4.2 composes N_ID^SL = N_ID,1^SL + 336 * N_ID,2^SL.
%Inputs: blockGrid  132-by-Nsymb complex -- the demodulated S-SS/PSBCH block, time-aligned
%        NID2       integer, 0 or 1 -- from phy.rx.sync.pssSearch. The S-SSS sequence depends
%                   on BOTH halves of the identity, so the S-PSS half must be known first
%Outputs: NID1    integer, 0..335 -- the winning hypothesis
%         NIDSL   integer, 0..671 -- N_ID,1 + 336 * N_ID,2, composed here because every
%                 downstream consumer (PSBCH scrambling, PSBCH DM-RS) wants the combined value
%         peak    real -- the winning normalised correlation
%         margin  real -- peak minus the best losing hypothesis. A detection that wins by a
%                 hair is not a detection, and a caller that only reads NID1 cannot tell
%
%336 HYPOTHESES, TESTED EXHAUSTIVELY
%-------------------------------------
%There is no cleverness here and none is needed: 336 correlations of length 127 is trivial, and
%the S-SSS is a product of two m-sequences whose structure could in principle be exploited to
%search in two stages. Doing so would be an optimisation of something that is not a bottleneck,
%and it would couple this function to the sequence's internal construction -- which is
%+phy/+ts38211/slSSSS's business, not the detector's.
%
%The identity is only complete once BOTH halves are known. Returning NID1 alone would invite a
%caller to use it where N_ID^SL is wanted -- and for NID2 = 0 the two are numerically equal, so
%that mistake works perfectly on half the cells and fails on the other half.

if ~any(NID2 == [0 1])
    error('rx:sync:sssDetect:badNID2', 'sssDetect: NID2 must be 0 or 1, got %s', num2str(NID2));
end

ind = phy.ts38211.slSSSSIndices();
% The S-SSS, like the S-PSS, is the same 127-value sequence placed once in each of two symbols.
% Averaging the two before correlating gives a 3 dB noise advantage over using either alone.
n = size(ind, 1) / 2;
rxA = blockGrid(sub2ind(size(blockGrid), ind(1:n, 1) + 1, ind(1:n, 2) + 1));
rxB = blockGrid(sub2ind(size(blockGrid), ind(n + 1:end, 1) + 1, ind(n + 1:end, 2) + 1));
rx  = (rxA(:) + rxB(:)) / 2;
rx  = rx / max(norm(rx), eps);

nHyp = 336;
corr = zeros(1, nHyp);
for h = 0:nHyp - 1
    ref = phy.ts38211.slSSSS(h, NID2);
    ref = ref(:) / max(norm(ref), eps);
    corr(h + 1) = abs(ref' * rx);
end

[sorted, order] = sort(corr, 'descend');
NID1   = order(1) - 1;
peak   = sorted(1);
margin = sorted(1) - sorted(2);
NIDSL  = NID1 + 336 * NID2;
end
