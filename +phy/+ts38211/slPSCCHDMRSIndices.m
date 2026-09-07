function ind = slPSCCHDMRSIndices(startPRB, NRB, symbols)
%slPSCCHDMRSIndices PSCCH DM-RS resource element indices (locations only).
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.3.2
%Inputs: startPRB  integer, >=0 -- first common resource block (k reference is
%                  subcarrier 0 of common resource block 0, not PSCCH-relative)
%        NRB       integer, >0 -- number of PRBs assigned to PSCCH
%        symbols   row vector of OFDM symbol indices l assigned to PSCCH
%                  (the caller's responsibility -- includes any duplicated
%                  first/AGC symbol per clause 8.3.2.3, this function only maps)
%Outputs: ind  (3*NRB*numel(symbols))-by-2 integer matrix, columns [k l],
%              k absolute (common-resource-block-0-relative)
%
%k = n*N_scRB + 4k' + 1, k' in {0,1,2}, n = 0..NRB-1: three DM-RS REs per PRB,
%at subcarrier offsets 1, 5, 9 within each 12-subcarrier PRB. The
%amplitude/phase factor w_{f,i}(k') (Table 8.4.1.3.2-1, i UE-selected) is a
%value to apply when assembling the grid, not a location -- not computed here,
%matching the toolbox Indices-vs-value split (nrPDSCHIndices returns
%locations; a separate step supplies values).
kOffsets = 4*(0:2) + 1;                       % 1, 5, 9
k = repmat((0:NRB-1)'*12, 1, 3) + kOffsets;   % NRB-by-3
k = sort(k(:)) + startPRB*12;                 % (3*NRB)-by-1, absolute, ascending

nSym = numel(symbols);
nK = numel(k);
ind = zeros(nK*nSym, 2);
for si = 1:nSym
    rows = (si-1)*nK + (1:nK);
    ind(rows, :) = [k, repmat(symbols(si), nK, 1)];
end
end
