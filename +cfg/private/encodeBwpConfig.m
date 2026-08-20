function txt = encodeBwpConfig(s)
%encodeBwpConfig Encode an SL-BWP-ConfigCommon-r16 struct (see bwpConfig.m) back to JSON.
%Spec:   TS 38.331 clause 6.3.5, IE SL-BWP-ConfigCommon-r16. Exact inverse of bwpConfig.m.
%Inputs: s  scalar struct as returned by cfg.bwpConfig()
%Outputs: txt  char, JSON object text
pairs = {};
if s.sl_BWP_Generic_r16_Present
    pairs{end+1} = jsonPair('sl-BWP-Generic-r16', encodeBwpGeneric(s.sl_BWP_Generic_r16));
end
if s.sl_BWP_PoolConfigCommon_r16_Present
    pairs{end+1} = jsonPair('sl-BWP-PoolConfigCommon-r16', encodePoolConfigCommon(s.sl_BWP_PoolConfigCommon_r16));
end
txt = jsonJoinObj(pairs);
end

function txt = encodeBwpGeneric(g)
pairs = {};
if g.sl_BWP_r16_Present
    b = g.sl_BWP_r16;
    bPairs = {jsonPair('locationAndBandwidth', jsonencode(b.locationAndBandwidth)), ...
        jsonPair('subcarrierSpacing', jsonencode(unresolveEnum('subcarrierSpacing', b.subcarrierSpacing)))};
    if b.cyclicPrefix_Present, bPairs{end+1} = jsonPair('cyclicPrefix', jsonencode(unresolveEnum('cyclicPrefix', b.cyclicPrefix))); end
    pairs{end+1} = jsonPair('sl-BWP-r16', jsonJoinObj(bPairs));
end
if g.sl_LengthSymbols_r16_Present, pairs{end+1} = jsonPair('sl-LengthSymbols-r16', jsonencode(unresolveEnum('sl-LengthSymbols-r16', g.sl_LengthSymbols_r16))); end
if g.sl_StartSymbol_r16_Present, pairs{end+1} = jsonPair('sl-StartSymbol-r16', jsonencode(unresolveEnum('sl-StartSymbol-r16', g.sl_StartSymbol_r16))); end
if g.sl_PSBCH_Config_r16_Present
    c = g.sl_PSBCH_Config_r16;
    cPairs = {};
    if c.dl_P0_PSBCH_r16_Present, cPairs{end+1} = jsonPair('dl-P0-PSBCH-r16', jsonencode(c.dl_P0_PSBCH_r16)); end
    if c.dl_Alpha_PSBCH_r16_Present, cPairs{end+1} = jsonPair('dl-Alpha-PSBCH-r16', jsonencode(unresolveEnum('sl-Alpha-r16', c.dl_Alpha_PSBCH_r16))); end
    pairs{end+1} = jsonPair('sl-PSBCH-Config-r16', jsonJoinObj({jsonPair('case', jsonencode('setup')), jsonPair('setup', jsonJoinObj(cPairs))}));
end
if g.sl_TxDirectCurrentLocation_r16_Present, pairs{end+1} = jsonPair('sl-TxDirectCurrentLocation-r16', jsonencode(g.sl_TxDirectCurrentLocation_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodePoolConfigCommon(p)
pairs = {};
if p.sl_RxPool_r16_Present
    n = numel(p.sl_RxPool_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodeResourcePool(p.sl_RxPool_r16(i)); end
    pairs{end+1} = jsonPair('sl-RxPool-r16', jsonJoinArr(elems));
end
if p.sl_TxPoolSelectedNormal_r16_Present
    n = numel(p.sl_TxPoolSelectedNormal_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodeResourcePoolConfig(p.sl_TxPoolSelectedNormal_r16(i)); end
    pairs{end+1} = jsonPair('sl-TxPoolSelectedNormal-r16', jsonJoinArr(elems));
end
if p.sl_TxPoolExceptional_r16_Present
    pairs{end+1} = jsonPair('sl-TxPoolExceptional-r16', encodeResourcePoolConfig(p.sl_TxPoolExceptional_r16));
end
txt = jsonJoinObj(pairs);
end

function txt = encodeResourcePoolConfig(c)
pairs = {jsonPair('sl-ResourcePoolID-r16', jsonencode(c.sl_ResourcePoolID_r16))};
if c.sl_ResourcePool_r16_Present, pairs{end+1} = jsonPair('sl-ResourcePool-r16', encodeResourcePool(c.sl_ResourcePool_r16)); end
txt = jsonJoinObj(pairs);
end
