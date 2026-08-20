function ind = slPSCCHIndices(carrier, cfg)
%slPSCCHIndices PSCCH data resource element indices (DM-RS REs excluded).
%Spec:   TS 38.211 V16.10.0, clause 8.3.2.3
%Inputs: carrier  scalar struct, slCarrierConfig -- unused here, accepted for
%                 the uniform (carrier, config) call signature
%        cfg      scalar struct from slPSCCHConfig()
%Outputs: ind  N-by-2 integer matrix, columns [k l], k absolute
%              (common-resource-block-0-relative), in increasing k then l
%              order, over cfg.symbols x the assigned PRBs, excluding the
%              3*NRB DM-RS REs per symbol from slPSCCHDMRSIndices()
%#ok<*INUSD>
allK = (cfg.startPRB*12 : cfg.startPRB*12 + cfg.NRB*12 - 1)';
dmrsInd = phy.ts38211.slPSCCHDMRSIndices(cfg.startPRB, cfg.NRB, cfg.symbols);

nSym = numel(cfg.symbols);
nK = numel(allK);
ind = zeros(nK*nSym, 2);
row = 0;
for si = 1:nSym
    l = cfg.symbols(si);
    dmrsK = dmrsInd(dmrsInd(:,2) == l, 1);
    dataK = setdiff(allK, dmrsK, 'stable');
    dataK = sort(dataK);
    n = numel(dataK);
    ind(row+1:row+n, :) = [dataK, repmat(l, n, 1)];
    row = row + n;
end
ind = ind(1:row, :);
end
