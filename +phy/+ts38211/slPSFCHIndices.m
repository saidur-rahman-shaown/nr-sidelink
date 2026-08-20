function ind = slPSFCHIndices(carrier, cfg)
%slPSFCHIndices PSFCH resource element indices (second/content symbol only).
%Spec:   TS 38.211 V16.10.0, clause 8.3.4.2.2
%Inputs: carrier  scalar struct, slCarrierConfig -- unused here, accepted for
%                 call-signature uniformity with the other channels
%        cfg      scalar struct from slPSFCHConfig()
%Outputs: ind  12-by-2 integer matrix, columns [k l], k absolute
%              (common-resource-block-0-relative), ascending, at cfg.symbol
%
%The first (AGC-role) PSFCH symbol is a duplicate of this one -- populated by
%slAgcSymbol on the assembled grid, not returned here (same split as PSCCH).
%#ok<*INUSD>
k = (cfg.startPRB*12 : cfg.startPRB*12 + 11)';
ind = [k, repmat(cfg.symbol, 12, 1)];
end
