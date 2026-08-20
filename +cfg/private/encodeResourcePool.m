function txt = encodeResourcePool(s)
%encodeResourcePool Encode an SL-ResourcePool-r16 struct (see resourcePool.m) back to JSON.
%Spec:   TS 38.331 clause 6.3.5, IE SL-ResourcePool-r16. Exact inverse of resourcePool.m --
%        every field there has its mirror assembled here; keep the two in lockstep.
%Inputs: s  scalar struct as returned by cfg.resourcePool()
%Outputs: txt  char, JSON object text with ASN.1-verbatim hyphenated keys, OPTIONAL fields
%              omitted when their "<field>_Present" flag is false
pairs = {};

if s.sl_PSCCH_Config_r16_Present
    pairs{end+1} = jsonPair('sl-PSCCH-Config-r16', jsonJoinObj({jsonPair('case', jsonencode('setup')), ...
        jsonPair('setup', encodePscchConfig(s.sl_PSCCH_Config_r16))}));
end
if s.sl_PSSCH_Config_r16_Present
    pairs{end+1} = jsonPair('sl-PSSCH-Config-r16', jsonJoinObj({jsonPair('case', jsonencode('setup')), ...
        jsonPair('setup', encodePsschConfig(s.sl_PSSCH_Config_r16))}));
end
if s.sl_PSFCH_Config_r16_Present
    pairs{end+1} = jsonPair('sl-PSFCH-Config-r16', jsonJoinObj({jsonPair('case', jsonencode('setup')), ...
        jsonPair('setup', encodePsfchConfig(s.sl_PSFCH_Config_r16))}));
end
if s.sl_SyncAllowed_r16_Present
    pairs{end+1} = jsonPair('sl-SyncAllowed-r16', encodeSyncAllowed(s.sl_SyncAllowed_r16));
end
if s.sl_SubchannelSize_r16_Present
    pairs{end+1} = jsonPair('sl-SubchannelSize-r16', jsonencode(unresolveEnum('sl-SubchannelSize-r16', s.sl_SubchannelSize_r16)));
end
if s.dummy_Present
    pairs{end+1} = jsonPair('dummy', jsonencode(s.dummy));
end
if s.sl_StartRB_Subchannel_r16_Present
    pairs{end+1} = jsonPair('sl-StartRB-Subchannel-r16', jsonencode(s.sl_StartRB_Subchannel_r16));
end
if s.sl_NumSubchannel_r16_Present
    pairs{end+1} = jsonPair('sl-NumSubchannel-r16', jsonencode(s.sl_NumSubchannel_r16));
end
if s.sl_Additional_MCS_Table_r16_Present
    pairs{end+1} = jsonPair('sl-Additional-MCS-Table-r16', jsonencode(unresolveEnum('sl-Additional-MCS-Table-r16', s.sl_Additional_MCS_Table_r16)));
end
if s.sl_ThreshS_RSSI_CBR_r16_Present
    pairs{end+1} = jsonPair('sl-ThreshS-RSSI-CBR-r16', jsonencode(s.sl_ThreshS_RSSI_CBR_r16));
end
if s.sl_TimeWindowSizeCBR_r16_Present
    pairs{end+1} = jsonPair('sl-TimeWindowSizeCBR-r16', jsonencode(unresolveEnum('sl-TimeWindowSizeCBR-r16', s.sl_TimeWindowSizeCBR_r16)));
end
if s.sl_TimeWindowSizeCR_r16_Present
    pairs{end+1} = jsonPair('sl-TimeWindowSizeCR-r16', jsonencode(unresolveEnum('sl-TimeWindowSizeCR-r16', s.sl_TimeWindowSizeCR_r16)));
end
if s.sl_PTRS_Config_r16_Present
    pairs{end+1} = jsonPair('sl-PTRS-Config-r16', encodePtrsConfig(s.sl_PTRS_Config_r16));
end
if s.sl_UE_SelectedConfigRP_r16_Present
    pairs{end+1} = jsonPair('sl-UE-SelectedConfigRP-r16', encodeUeSelectedConfigRp(s.sl_UE_SelectedConfigRP_r16));
end
if s.sl_RxParametersNcell_r16_Present
    nc = s.sl_RxParametersNcell_r16;
    ncPairs = {};
    if nc.sl_TDD_Configuration_r16_Present
        ncPairs{end+1} = jsonPair('sl-TDD-Configuration-r16', encodeTddConfigCommon(nc.sl_TDD_Configuration_r16));
    end
    ncPairs{end+1} = jsonPair('sl-SyncConfigIndex-r16', jsonencode(nc.sl_SyncConfigIndex_r16));
    pairs{end+1} = jsonPair('sl-RxParametersNcell-r16', jsonJoinObj(ncPairs));
end
if s.sl_ZoneConfigMCR_List_r16_Present
    elems = cell(1, 16);
    for i = 1:16
        elems{i} = encodeZoneConfigMcr(s.sl_ZoneConfigMCR_List_r16(i));
    end
    pairs{end+1} = jsonPair('sl-ZoneConfigMCR-List-r16', jsonJoinArr(elems));
end
if s.sl_FilterCoefficient_r16_Present
    pairs{end+1} = jsonPair('sl-FilterCoefficient-r16', jsonencode(unresolveEnum('FilterCoefficient', s.sl_FilterCoefficient_r16)));
end
if s.sl_RB_Number_r16_Present
    pairs{end+1} = jsonPair('sl-RB-Number-r16', jsonencode(s.sl_RB_Number_r16));
end
if s.sl_PreemptionEnable_r16_Present
    pairs{end+1} = jsonPair('sl-PreemptionEnable-r16', jsonencode(unresolveEnum('sl-PreemptionEnable-r16', s.sl_PreemptionEnable_r16)));
end
if s.sl_PriorityThreshold_UL_URLLC_r16_Present
    pairs{end+1} = jsonPair('sl-PriorityThreshold-UL-URLLC-r16', jsonencode(s.sl_PriorityThreshold_UL_URLLC_r16));
end
if s.sl_PriorityThreshold_r16_Present
    pairs{end+1} = jsonPair('sl-PriorityThreshold-r16', jsonencode(s.sl_PriorityThreshold_r16));
end
if s.sl_X_Overhead_r16_Present
    pairs{end+1} = jsonPair('sl-X-Overhead-r16', jsonencode(unresolveEnum('sl-X-Overhead-r16', s.sl_X_Overhead_r16)));
end
if s.sl_PowerControl_r16_Present
    pairs{end+1} = jsonPair('sl-PowerControl-r16', encodePowerControl(s.sl_PowerControl_r16));
end
if s.sl_TxPercentageList_r16_Present
    elems = cell(1, 8);
    for i = 1:8
        e = s.sl_TxPercentageList_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-Priority-r16', jsonencode(e.sl_Priority_r16)), ...
            jsonPair('sl-TxPercentage-r16', jsonencode(unresolveEnum('sl-TxPercentage-r16', e.sl_TxPercentage_r16)))});
    end
    pairs{end+1} = jsonPair('sl-TxPercentageList-r16', jsonJoinArr(elems));
end
if s.sl_MinMaxMCS_List_r16_Present
    n = numel(s.sl_MinMaxMCS_List_r16);
    elems = cell(1, n);
    for i = 1:n
        e = s.sl_MinMaxMCS_List_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-MCS-Table-r16', jsonencode(unresolveEnum('sl-MCS-Table-r16', e.sl_MCS_Table_r16))), ...
            jsonPair('sl-MinMCS-PSSCH-r16', jsonencode(e.sl_MinMCS_PSSCH_r16)), ...
            jsonPair('sl-MaxMCS-PSSCH-r16', jsonencode(e.sl_MaxMCS_PSSCH_r16))});
    end
    pairs{end+1} = jsonPair('sl-MinMaxMCS-List-r16', jsonJoinArr(elems));
end
if s.sl_TimeResource_r16_Present
    pairs{end+1} = jsonPair('sl-TimeResource-r16', jsonencode(double(s.sl_TimeResource_r16)));
end

txt = jsonJoinObj(pairs);
end

% ======================================================================
% Local encoders, mirroring resourcePool.m's local decoders one for one.
% ======================================================================

function txt = encodePscchConfig(c)
pairs = {};
if c.sl_TimeResourcePSCCH_r16_Present, pairs{end+1} = jsonPair('sl-TimeResourcePSCCH-r16', jsonencode(unresolveEnum('sl-TimeResourcePSCCH-r16', c.sl_TimeResourcePSCCH_r16))); end
if c.sl_FreqResourcePSCCH_r16_Present, pairs{end+1} = jsonPair('sl-FreqResourcePSCCH-r16', jsonencode(unresolveEnum('sl-FreqResourcePSCCH-r16', c.sl_FreqResourcePSCCH_r16))); end
if c.sl_DMRS_ScrambleID_r16_Present, pairs{end+1} = jsonPair('sl-DMRS-ScrambleID-r16', jsonencode(c.sl_DMRS_ScrambleID_r16)); end
if c.sl_NumReservedBits_r16_Present, pairs{end+1} = jsonPair('sl-NumReservedBits-r16', jsonencode(c.sl_NumReservedBits_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodePsschConfig(c)
pairs = {};
if c.sl_PSSCH_DMRS_TimePatternList_r16_Present, pairs{end+1} = jsonPair('sl-PSSCH-DMRS-TimePatternList-r16', jsonencode(c.sl_PSSCH_DMRS_TimePatternList_r16)); end
if c.sl_BetaOffsets2ndSCI_r16_Present, pairs{end+1} = jsonPair('sl-BetaOffsets2ndSCI-r16', jsonencode(c.sl_BetaOffsets2ndSCI_r16)); end
if c.sl_Scaling_r16_Present, pairs{end+1} = jsonPair('sl-Scaling-r16', jsonencode(unresolveEnum('sl-Scaling-r16', c.sl_Scaling_r16))); end
txt = jsonJoinObj(pairs);
end

function txt = encodePsfchConfig(c)
pairs = {};
if c.sl_PSFCH_Period_r16_Present, pairs{end+1} = jsonPair('sl-PSFCH-Period-r16', jsonencode(unresolveEnum('sl-PSFCH-Period-r16', c.sl_PSFCH_Period_r16))); end
if c.sl_PSFCH_RB_Set_r16_Present, pairs{end+1} = jsonPair('sl-PSFCH-RB-Set-r16', jsonencode(double(c.sl_PSFCH_RB_Set_r16))); end
if c.sl_NumMuxCS_Pair_r16_Present, pairs{end+1} = jsonPair('sl-NumMuxCS-Pair-r16', jsonencode(unresolveEnum('sl-NumMuxCS-Pair-r16', c.sl_NumMuxCS_Pair_r16))); end
if c.sl_MinTimeGapPSFCH_r16_Present, pairs{end+1} = jsonPair('sl-MinTimeGapPSFCH-r16', jsonencode(unresolveEnum('sl-MinTimeGapPSFCH-r16', c.sl_MinTimeGapPSFCH_r16))); end
if c.sl_PSFCH_HopID_r16_Present, pairs{end+1} = jsonPair('sl-PSFCH-HopID-r16', jsonencode(c.sl_PSFCH_HopID_r16)); end
if c.sl_PSFCH_CandidateResourceType_r16_Present, pairs{end+1} = jsonPair('sl-PSFCH-CandidateResourceType-r16', jsonencode(unresolveEnum('sl-PSFCH-CandidateResourceType-r16', c.sl_PSFCH_CandidateResourceType_r16))); end
txt = jsonJoinObj(pairs);
end

function txt = encodeSyncAllowed(c)
pairs = {};
if c.gnss_Sync_r16, pairs{end+1} = jsonPair('gnss-Sync-r16', jsonencode('true')); end
if c.gnbEnb_Sync_r16, pairs{end+1} = jsonPair('gnbEnb-Sync-r16', jsonencode('true')); end
if c.ue_Sync_r16, pairs{end+1} = jsonPair('ue-Sync-r16', jsonencode('true')); end
txt = jsonJoinObj(pairs);
end

function txt = encodePtrsConfig(c)
pairs = {};
if c.sl_PTRS_FreqDensity_r16_Present, pairs{end+1} = jsonPair('sl-PTRS-FreqDensity-r16', jsonencode(c.sl_PTRS_FreqDensity_r16)); end
if c.sl_PTRS_TimeDensity_r16_Present, pairs{end+1} = jsonPair('sl-PTRS-TimeDensity-r16', jsonencode(c.sl_PTRS_TimeDensity_r16)); end
if c.sl_PTRS_RE_Offset_r16_Present, pairs{end+1} = jsonPair('sl-PTRS-RE-Offset-r16', jsonencode(unresolveEnum('sl-PTRS-RE-Offset-r16', c.sl_PTRS_RE_Offset_r16))); end
txt = jsonJoinObj(pairs);
end

function txt = encodeZoneConfigMcr(c)
pairs = {jsonPair('sl-ZoneConfigMCR-Index-r16', jsonencode(c.sl_ZoneConfigMCR_Index_r16))};
if c.sl_TransRange_r16_Present, pairs{end+1} = jsonPair('sl-TransRange-r16', jsonencode(unresolveEnum('sl-TransRange-r16', c.sl_TransRange_r16))); end
if c.sl_ZoneConfig_r16_Present
    pairs{end+1} = jsonPair('sl-ZoneConfig-r16', jsonJoinObj({jsonPair('sl-ZoneLength-r16', ...
        jsonencode(unresolveEnum('sl-ZoneLength-r16', c.sl_ZoneConfig_r16.sl_ZoneLength_r16)))}));
end
txt = jsonJoinObj(pairs);
end

function txt = encodeUeSelectedConfigRp(c)
pairs = {};
if c.sl_CBR_PriorityTxConfigList_r16_Present
    n = numel(c.sl_CBR_PriorityTxConfigList_r16);
    elems = cell(1, n);
    for i = 1:n
        e = c.sl_CBR_PriorityTxConfigList_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-Priority-r16', jsonencode(e.sl_Priority_r16)), jsonPair('sl-CBR-r16', jsonencode(e.sl_CBR_r16))});
    end
    pairs{end+1} = jsonPair('sl-CBR-PriorityTxConfigList-r16', jsonJoinArr(elems));
end
if c.sl_Thres_RSRP_List_r16_Present, pairs{end+1} = jsonPair('sl-Thres-RSRP-List-r16', jsonencode(c.sl_Thres_RSRP_List_r16)); end
if c.sl_MultiReserveResource_r16, pairs{end+1} = jsonPair('sl-MultiReserveResource-r16', jsonencode('enabled')); end
if c.sl_MaxNumPerReserve_r16_Present, pairs{end+1} = jsonPair('sl-MaxNumPerReserve-r16', jsonencode(unresolveEnum('sl-MaxNumPerReserve-r16', c.sl_MaxNumPerReserve_r16))); end
if c.sl_SensingWindow_r16_Present, pairs{end+1} = jsonPair('sl-SensingWindow-r16', jsonencode(unresolveEnum('sl-SensingWindow-r16', c.sl_SensingWindow_r16))); end
if c.sl_SelectionWindowList_r16_Present
    elems = cell(1, 8);
    for i = 1:8
        e = c.sl_SelectionWindowList_r16(i);
        elems{i} = jsonJoinObj({jsonPair('sl-Priority-r16', jsonencode(e.sl_Priority_r16)), ...
            jsonPair('sl-SelectionWindow-r16', jsonencode(unresolveEnum('sl-SelectionWindow-r16', e.sl_SelectionWindow_r16)))});
    end
    pairs{end+1} = jsonPair('sl-SelectionWindowList-r16', jsonJoinArr(elems));
end
if c.sl_ResourceReservePeriodList_r16_Present
    n = numel(c.sl_ResourceReservePeriodList_r16);
    elems = cell(1, n);
    for i = 1:n
        elems{i} = encodeResourceReservePeriod(c.sl_ResourceReservePeriodList_r16(i));
    end
    pairs{end+1} = jsonPair('sl-ResourceReservePeriodList-r16', jsonJoinArr(elems));
end
pairs{end+1} = jsonPair('sl-RS-ForSensing-r16', jsonencode(unresolveEnum('sl-RS-ForSensing-r16', c.sl_RS_ForSensing_r16)));
txt = jsonJoinObj(pairs);
end

function txt = encodeResourceReservePeriod(r)
switch r.case
    case 'sl-ResourceReservePeriod1-r16'
        pairs = {jsonPair('case', jsonencode(r.case)), jsonPair('sl-ResourceReservePeriod1-r16', ...
            jsonencode(unresolveEnum('sl-ResourceReservePeriod1-r16', r.sl_ResourceReservePeriod_ms)))};
    case 'sl-ResourceReservePeriod2-r16'
        pairs = {jsonPair('case', jsonencode(r.case)), jsonPair('sl-ResourceReservePeriod2-r16', jsonencode(r.sl_ResourceReservePeriod_ms))};
    otherwise
        error('cfg:encodeResourcePool:badChoice', 'sl-ResourceReservePeriod-r16: unknown case "%s"', r.case);
end
txt = jsonJoinObj(pairs);
end

function txt = encodePowerControl(c)
pairs = {jsonPair('sl-MaxTransPower-r16', jsonencode(c.sl_MaxTransPower_r16))};
if c.sl_Alpha_PSSCH_PSCCH_r16_Present, pairs{end+1} = jsonPair('sl-Alpha-PSSCH-PSCCH-r16', jsonencode(unresolveEnum('sl-Alpha-r16', c.sl_Alpha_PSSCH_PSCCH_r16))); end
if c.dl_Alpha_PSSCH_PSCCH_r16_Present, pairs{end+1} = jsonPair('dl-Alpha-PSSCH-PSCCH-r16', jsonencode(unresolveEnum('sl-Alpha-r16', c.dl_Alpha_PSSCH_PSCCH_r16))); end
if c.sl_P0_PSSCH_PSCCH_r16_Present, pairs{end+1} = jsonPair('sl-P0-PSSCH-PSCCH-r16', jsonencode(c.sl_P0_PSSCH_PSCCH_r16)); end
if c.dl_P0_PSSCH_PSCCH_r16_Present, pairs{end+1} = jsonPair('dl-P0-PSSCH-PSCCH-r16', jsonencode(c.dl_P0_PSSCH_PSCCH_r16)); end
if c.dl_Alpha_PSFCH_r16_Present, pairs{end+1} = jsonPair('dl-Alpha-PSFCH-r16', jsonencode(unresolveEnum('sl-Alpha-r16', c.dl_Alpha_PSFCH_r16))); end
if c.dl_P0_PSFCH_r16_Present, pairs{end+1} = jsonPair('dl-P0-PSFCH-r16', jsonencode(c.dl_P0_PSFCH_r16)); end
txt = jsonJoinObj(pairs);
end

function txt = encodeTddConfigCommon(c)
pairs = {jsonPair('referenceSubcarrierSpacing', jsonencode(unresolveEnum('subcarrierSpacing', c.referenceSubcarrierSpacing))), ...
    jsonPair('pattern1', encodeTddPattern(c.pattern1))};
if c.pattern2_Present, pairs{end+1} = jsonPair('pattern2', encodeTddPattern(c.pattern2)); end
txt = jsonJoinObj(pairs);
end

function txt = encodeTddPattern(p)
txt = jsonJoinObj({jsonPair('dl-UL-TransmissionPeriodicity', jsonencode(unresolveEnum('dl-UL-TransmissionPeriodicity', p.dl_UL_TransmissionPeriodicity))), ...
    jsonPair('nrofDownlinkSlots', jsonencode(p.nrofDownlinkSlots)), jsonPair('nrofDownlinkSymbols', jsonencode(p.nrofDownlinkSymbols)), ...
    jsonPair('nrofUplinkSlots', jsonencode(p.nrofUplinkSlots)), jsonPair('nrofUplinkSymbols', jsonencode(p.nrofUplinkSymbols))});
end
