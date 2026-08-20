function txt = encodePreconfig(s)
%encodePreconfig Encode a SidelinkPreconfigNR-r16 struct (see preconfig.m) back to JSON.
%Spec:   TS 38.331 clause 6.3.5, IE SidelinkPreconfigNR-r16. Exact inverse of preconfig.m.
%Inputs: s  scalar struct as returned by cfg.preconfig()
%Outputs: txt  char, JSON object text (this is the value of the top-level "preconfig" key)
n = numel(s.sl_PreconfigFreqInfoList_r16);
elems = cell(1, n);
for i = 1:n, elems{i} = encodeFreqConfigCommon(s.sl_PreconfigFreqInfoList_r16(i)); end
pairs = {jsonPair('sl-PreconfigFreqInfoList-r16', jsonJoinArr(elems))};

if s.sl_PreconfigNR_AnchorCarrierFreqList_r16_Present
    pairs{end+1} = jsonPair('sl-PreconfigNR-AnchorCarrierFreqList-r16', jsonencode(s.sl_PreconfigNR_AnchorCarrierFreqList_r16));
end
if s.sl_PreconfigEUTRA_AnchorCarrierFreqList_r16_Present
    pairs{end+1} = jsonPair('sl-PreconfigEUTRA-AnchorCarrierFreqList-r16', jsonencode(s.sl_PreconfigEUTRA_AnchorCarrierFreqList_r16));
end
if s.sl_OffsetDFN_r16_Present, pairs{end+1} = jsonPair('sl-OffsetDFN-r16', jsonencode(s.sl_OffsetDFN_r16)); end
if s.t400_r16_Present, pairs{end+1} = jsonPair('t400-r16', jsonencode(unresolveEnum('t400-r16', s.t400_r16))); end
if s.sl_MaxNumConsecutiveDTX_r16_Present, pairs{end+1} = jsonPair('sl-MaxNumConsecutiveDTX-r16', jsonencode(unresolveEnum('sl-MaxNumConsecutiveDTX-r16', s.sl_MaxNumConsecutiveDTX_r16))); end
if s.sl_SSB_PriorityNR_r16_Present, pairs{end+1} = jsonPair('sl-SSB-PriorityNR-r16', jsonencode(s.sl_SSB_PriorityNR_r16)); end

if s.sl_PreconfigGeneral_r16_Present
    g = s.sl_PreconfigGeneral_r16;
    gPairs = {};
    if g.sl_TDD_Configuration_r16_Present, gPairs{end+1} = jsonPair('sl-TDD-Configuration-r16', encodeTddConfigCommon(g.sl_TDD_Configuration_r16)); end
    if g.reservedBits_r16_Present, gPairs{end+1} = jsonPair('reservedBits-r16', jsonencode(double(g.reservedBits_r16))); end
    pairs{end+1} = jsonPair('sl-PreconfigGeneral-r16', jsonJoinObj(gPairs));
end

if s.sl_UE_SelectedPreConfig_r16_Present
    pairs{end+1} = jsonPair('sl-UE-SelectedPreConfig-r16', encodeUeSelectedConfig(s.sl_UE_SelectedPreConfig_r16));
end

if s.sl_CSI_Acquisition_r16, pairs{end+1} = jsonPair('sl-CSI-Acquisition-r16', jsonencode('enabled')); end

if s.sl_RoHC_Profiles_r16_Present
    r = s.sl_RoHC_Profiles_r16;
    names = {'profile0x0001_r16', 'profile0x0002_r16', 'profile0x0003_r16', 'profile0x0004_r16', ...
             'profile0x0006_r16', 'profile0x0101_r16', 'profile0x0102_r16', 'profile0x0103_r16', 'profile0x0104_r16'};
    rPairs = cell(1, numel(names));
    for i = 1:numel(names)
        rPairs{i} = jsonPair(strrep(names{i}, '_', '-'), jsonencode(r.(names{i})));
    end
    pairs{end+1} = jsonPair('sl-RoHC-Profiles-r16', jsonJoinObj(rPairs));
end

pairs{end+1} = jsonPair('sl-MaxCID-r16', jsonencode(s.sl_MaxCID_r16));

txt = jsonJoinObj(pairs);
end

function txt = encodeFreqConfigCommon(f)
n = numel(f.sl_SCS_SpecificCarrierList_r16);
elems = cell(1, n);
for i = 1:n
    c = f.sl_SCS_SpecificCarrierList_r16(i);
    elems{i} = jsonJoinObj({jsonPair('offsetToCarrier', jsonencode(c.offsetToCarrier)), ...
        jsonPair('subcarrierSpacing', jsonencode(unresolveEnum('subcarrierSpacing', c.subcarrierSpacing))), ...
        jsonPair('carrierBandwidth', jsonencode(c.carrierBandwidth))});
end
pairs = {jsonPair('sl-SCS-SpecificCarrierList-r16', jsonJoinArr(elems)), ...
    jsonPair('sl-AbsoluteFrequencyPointA-r16', jsonencode(f.sl_AbsoluteFrequencyPointA_r16))};
if f.sl_AbsoluteFrequencySSB_r16_Present, pairs{end+1} = jsonPair('sl-AbsoluteFrequencySSB-r16', jsonencode(f.sl_AbsoluteFrequencySSB_r16)); end
if f.frequencyShift7p5khzSL_r16, pairs{end+1} = jsonPair('frequencyShift7p5khzSL-r16', jsonencode('true')); end
pairs{end+1} = jsonPair('valueN-r16', jsonencode(f.valueN_r16));
if f.sl_BWP_List_r16_Present
    m = numel(f.sl_BWP_List_r16);
    belems = cell(1, m);
    for i = 1:m, belems{i} = encodeBwpConfig(f.sl_BWP_List_r16(i)); end
    pairs{end+1} = jsonPair('sl-BWP-List-r16', jsonJoinArr(belems));
end
if f.sl_SyncPriority_r16_Present, pairs{end+1} = jsonPair('sl-SyncPriority-r16', jsonencode(unresolveEnum('sl-SyncPriority-r16', f.sl_SyncPriority_r16))); end
if f.sl_NbAsSync_r16_Present, pairs{end+1} = jsonPair('sl-NbAsSync-r16', jsonencode(f.sl_NbAsSync_r16)); end
if f.sl_SyncConfigList_r16_Present, pairs{end+1} = jsonPair('sl-SyncConfigList-r16', jsonencode(f.sl_SyncConfigList_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodeUeSelectedConfig(u)
pairs = {};
if u.sl_PSSCH_TxConfigList_r16_Present
    n = numel(u.sl_PSSCH_TxConfigList_r16);
    elems = cell(1, n);
    for i = 1:n, elems{i} = encodePsschTxConfig(u.sl_PSSCH_TxConfigList_r16(i)); end
    pairs{end+1} = jsonPair('sl-PSSCH-TxConfigList-r16', jsonJoinArr(elems));
end
if u.sl_ProbResourceKeep_r16_Present, pairs{end+1} = jsonPair('sl-ProbResourceKeep-r16', jsonencode(unresolveEnum('sl-ProbResourceKeep-r16', u.sl_ProbResourceKeep_r16))); end
if u.sl_ReselectAfter_r16_Present, pairs{end+1} = jsonPair('sl-ReselectAfter-r16', jsonencode(unresolveEnum('sl-ReselectAfter-r16', u.sl_ReselectAfter_r16))); end
if u.sl_CBR_CommonTxConfigList_r16_Present
    n = numel(u.sl_CBR_CommonTxConfigList_r16);
    elems = cell(1, n);
    for i = 1:n
        e = u.sl_CBR_CommonTxConfigList_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-Priority-r16', jsonencode(e.sl_Priority_r16)), jsonPair('sl-CBR-r16', jsonencode(e.sl_CBR_r16))});
    end
    pairs{end+1} = jsonPair('sl-CBR-CommonTxConfigList-r16', jsonJoinArr(elems));
end
if u.ul_PrioritizationThres_r16_Present, pairs{end+1} = jsonPair('ul-PrioritizationThres-r16', jsonencode(u.ul_PrioritizationThres_r16)); end
if u.sl_PrioritizationThres_r16_Present, pairs{end+1} = jsonPair('sl-PrioritizationThres-r16', jsonencode(u.sl_PrioritizationThres_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodePsschTxConfig(t)
pairs = {};
if t.sl_TypeTxSync_r16_Present, pairs{end+1} = jsonPair('sl-TypeTxSync-r16', jsonencode(unresolveEnum('sl-TypeTxSync-r16', t.sl_TypeTxSync_r16))); end
pairs{end+1} = jsonPair('sl-ThresUE-Speed-r16', jsonencode(unresolveEnum('sl-ThresUE-Speed-r16', t.sl_ThresUE_Speed_r16)));
pairs{end+1} = jsonPair('sl-ParametersAboveThres-r16', encodePsschTxParameters(t.sl_ParametersAboveThres_r16));
pairs{end+1} = jsonPair('sl-ParametersBelowThres-r16', encodePsschTxParameters(t.sl_ParametersBelowThres_r16));
txt = jsonJoinObj(pairs);
end

function txt = encodePsschTxParameters(p)
pairs = {jsonPair('sl-MinMCS-PSSCH-r16', jsonencode(p.sl_MinMCS_PSSCH_r16)), ...
    jsonPair('sl-MaxMCS-PSSCH-r16', jsonencode(p.sl_MaxMCS_PSSCH_r16)), ...
    jsonPair('sl-MinSubChannelNumPSSCH-r16', jsonencode(p.sl_MinSubChannelNumPSSCH_r16)), ...
    jsonPair('sl-MaxSubchannelNumPSSCH-r16', jsonencode(p.sl_MaxSubchannelNumPSSCH_r16)), ...
    jsonPair('sl-MaxTxTransNumPSSCH-r16', jsonencode(p.sl_MaxTxTransNumPSSCH_r16))};
if p.sl_MaxTxPower_r16_Present
    tp = p.sl_MaxTxPower_r16;
    tpPairs = {jsonPair('case', jsonencode(tp.case))};
    if strcmp(tp.case, 'txPower-r16'), tpPairs{end+1} = jsonPair('txPower-r16', jsonencode(tp.txPower_r16)); end
    pairs{end+1} = jsonPair('sl-MaxTxPower-r16', jsonJoinObj(tpPairs));
end
txt = jsonJoinObj(pairs);
end
