function ind = slPSBCHIndices(Nsymb)
%slPSBCHIndices PSBCH data resource element indices within one S-SS/PSBCH block.
%Spec:   TS 38.211 V16.10.0, clause 8.4.3.1.3, Table 8.4.3.1-1
%Inputs: Nsymb  integer, 13 (normal CP) or 11 (extended CP)
%Outputs: ind  (99*(Nsymb-4))-by-2 integer matrix, columns [k l], 0-based,
%              relative to the S-SS/PSBCH block's own origin. l in {0,5,6,...,
%              Nsymb-1}; k in 0..131 excluding the 33 DM-RS subcarriers
%              {0,4,8,...,128}. Order: l outer (increasing), k inner
%              (increasing), matching the spec's "first k, then l" mapping
%              rule and slPSBCHDMRSIndices()'s row ordering.
symbols = [0, 5:(Nsymb-1)];
allK = (0:131)';
dmrsK = (0:4:128)';
dataK = setdiff(allK, dmrsK);   % ascending, 99 values
nSym = numel(symbols);
nK = numel(dataK);
ind = zeros(nK*nSym, 2);
for si = 1:nSym
    rows = (si-1)*nK + (1:nK);
    ind(rows, :) = [dataK, repmat(symbols(si), nK, 1)];
end
end
