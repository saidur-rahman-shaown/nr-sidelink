function ind = slPSBCHDMRSIndices(Nsymb)
%slPSBCHDMRSIndices PSBCH DM-RS resource element indices within one S-SS/PSBCH block.
%Spec:   TS 38.211 V16.10.0, clause 8.4.3.1.3, Table 8.4.3.1-1
%Inputs: Nsymb  integer, 13 (normal CP) or 11 (extended CP)
%Outputs: ind  (33*(Nsymb-4))-by-2 integer matrix, columns [k l], 0-based and
%              relative to the S-SS/PSBCH block's own origin. l in {0, 5, 6,
%              ..., Nsymb-1}; k in {0,4,8,...,128} (33 values) at every such
%              l. Order: l outer (increasing), k inner (increasing) -- matches
%              the "increasing order of first k, then l" mapping rule (fixed
%              l, sweep k, then advance l: k is the faster-varying index), so
%              row i corresponds directly to slPSBCHDMRS()'s r(i-1).
symbols = [0, 5:(Nsymb-1)];
k = (0:4:128)';
nSym = numel(symbols);
nK = numel(k);
ind = zeros(nK*nSym, 2);
for si = 1:nSym
    rows = (si-1)*nK + (1:nK);
    ind(rows, :) = [k, repmat(symbols(si), nK, 1)];
end
end
