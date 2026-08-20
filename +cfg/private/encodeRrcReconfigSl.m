function txt = encodeRrcReconfigSl(s)
%encodeRrcReconfigSl Encode a per-link reconfiguration struct (see rrcReconfigSl.m) to JSON.
%Spec:   TS 38.331 clause 6.3.5, IEs SL-BWP-PoolConfig-r16 / SL-ConfiguredGrantConfig-r16.
%        Exact inverse of rrcReconfigSl.m.
%Inputs: s  scalar struct as returned by cfg.rrcReconfigSl()
%Outputs: txt  char, JSON object text
pairs = {jsonPair('linkId', jsonencode(s.linkId))};

if s.sl_BWP_PoolConfig_r16_Present
    pairs{end+1} = jsonPair('sl-BWP-PoolConfig-r16', encodeBwpPoolConfig(s.sl_BWP_PoolConfig_r16));
end

if s.sl_ConfiguredGrantConfigList_r16_Present
    n = numel(s.sl_ConfiguredGrantConfigList_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodeConfiguredGrantConfig(s.sl_ConfiguredGrantConfigList_r16(i)); end
    pairs{end+1} = jsonPair('sl-ConfiguredGrantConfigList-r16', jsonJoinArr(elems));
end

txt = jsonJoinObj(pairs);
end

function txt = encodeBwpPoolConfig(p)
pairs = {};
if p.sl_RxPool_r16_Present
    n = numel(p.sl_RxPool_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodeResourcePool(p.sl_RxPool_r16(i)); end
    pairs{end+1} = jsonPair('sl-RxPool-r16', jsonJoinArr(elems));
end
if p.sl_TxPoolSelectedNormal_r16_Present, pairs{end+1} = jsonPair('sl-TxPoolSelectedNormal-r16', encodeTxPoolDedicated(p.sl_TxPoolSelectedNormal_r16)); end
if p.sl_TxPoolScheduling_r16_Present, pairs{end+1} = jsonPair('sl-TxPoolScheduling-r16', encodeTxPoolDedicated(p.sl_TxPoolScheduling_r16)); end
if p.sl_TxPoolExceptional_r16_Present, pairs{end+1} = jsonPair('sl-TxPoolExceptional-r16', encodeResourcePoolConfigEntry(p.sl_TxPoolExceptional_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodeTxPoolDedicated(d)
pairs = {};
if d.sl_PoolToReleaseList_r16_Present, pairs{end+1} = jsonPair('sl-PoolToReleaseList-r16', jsonencode(d.sl_PoolToReleaseList_r16)); end
if d.sl_PoolToAddModList_r16_Present
    n = numel(d.sl_PoolToAddModList_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodeResourcePoolConfigEntry(d.sl_PoolToAddModList_r16(i)); end
    pairs{end+1} = jsonPair('sl-PoolToAddModList-r16', jsonJoinArr(elems));
end
txt = jsonJoinObj(pairs);
end

function txt = encodeResourcePoolConfigEntry(c)
pairs = {jsonPair('sl-ResourcePoolID-r16', jsonencode(c.sl_ResourcePoolID_r16))};
if c.sl_ResourcePool_r16_Present, pairs{end+1} = jsonPair('sl-ResourcePool-r16', encodeResourcePool(c.sl_ResourcePool_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodeConfiguredGrantConfig(g)
pairs = {jsonPair('sl-ConfigIndexCG-r16', jsonencode(g.sl_ConfigIndexCG_r16))};

if g.sl_PeriodCG_r16_Present
    pc = g.sl_PeriodCG_r16;
    pcPairs = {jsonPair('case', jsonencode(pc.case))};
    switch pc.case
        case 'sl-PeriodCG1-r16'
            pcPairs{end+1} = jsonPair('sl-PeriodCG1-r16', jsonencode(unresolveEnum('sl-PeriodCG1-r16', pc.period_ms)));
        case 'sl-PeriodCG2-r16'
            pcPairs{end+1} = jsonPair('sl-PeriodCG2-r16', jsonencode(pc.period_ms));
    end
    pairs{end+1} = jsonPair('sl-PeriodCG-r16', jsonJoinObj(pcPairs));
end

if g.sl_NrOfHARQ_Processes_r16_Present, pairs{end+1} = jsonPair('sl-NrOfHARQ-Processes-r16', jsonencode(g.sl_NrOfHARQ_Processes_r16)); end
if g.sl_HARQ_ProcID_offset_r16_Present, pairs{end+1} = jsonPair('sl-HARQ-ProcID-offset-r16', jsonencode(g.sl_HARQ_ProcID_offset_r16)); end

if g.sl_CG_MaxTransNumList_r16_Present
    n = numel(g.sl_CG_MaxTransNumList_r16);
    elems = cell(1, n);
    for i = 1:n
        e = g.sl_CG_MaxTransNumList_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-Priority-r16', jsonencode(e.sl_Priority_r16)), jsonPair('sl-MaxTransNum-r16', jsonencode(e.sl_MaxTransNum_r16))});
    end
    pairs{end+1} = jsonPair('sl-CG-MaxTransNumList-r16', jsonJoinArr(elems));
end

r = g.rrc_ConfiguredSidelinkGrant_r16;
rPairs = {};
if r.sl_TimeResourceCG_Type1_r16_Present, rPairs{end+1} = jsonPair('sl-TimeResourceCG-Type1-r16', jsonencode(r.sl_TimeResourceCG_Type1_r16)); end
if r.sl_StartSubchannelCG_Type1_r16_Present, rPairs{end+1} = jsonPair('sl-StartSubchannelCG-Type1-r16', jsonencode(r.sl_StartSubchannelCG_Type1_r16)); end
if r.sl_FreqResourceCG_Type1_r16_Present, rPairs{end+1} = jsonPair('sl-FreqResourceCG-Type1-r16', jsonencode(r.sl_FreqResourceCG_Type1_r16)); end
if r.sl_TimeOffsetCG_Type1_r16_Present, rPairs{end+1} = jsonPair('sl-TimeOffsetCG-Type1-r16', jsonencode(r.sl_TimeOffsetCG_Type1_r16)); end
if r.sl_N1PUCCH_AN_r16_Present, rPairs{end+1} = jsonPair('sl-N1PUCCH-AN-r16', jsonencode(r.sl_N1PUCCH_AN_r16)); end
if r.sl_PSFCH_ToPUCCH_CG_Type1_r16_Present, rPairs{end+1} = jsonPair('sl-PSFCH-ToPUCCH-CG-Type1-r16', jsonencode(r.sl_PSFCH_ToPUCCH_CG_Type1_r16)); end
if r.sl_ResourcePoolID_r16_Present, rPairs{end+1} = jsonPair('sl-ResourcePoolID-r16', jsonencode(r.sl_ResourcePoolID_r16)); end
if r.sl_TimeReferenceSFN_Type1_r16, rPairs{end+1} = jsonPair('sl-TimeReferenceSFN-Type1-r16', jsonencode('sfn512')); end
pairs{end+1} = jsonPair('rrc-ConfiguredSidelinkGrant-r16', jsonJoinObj(rPairs));

txt = jsonJoinObj(pairs);
end
