function s = resourcePool(raw)
%resourcePool Build SL-ResourcePool-r16 from its JSON-decoded raw struct.
%Spec:   TS 38.331 clause 6.3.5, IE SL-ResourcePool-r16 (Release-16 baseline; see
%        +cfg/CLAUDE.md scope decision -- Rel-17/18 extension-group fields are out of scope).
%        Clause number is the +cfg/CLAUDE.md/BUILD.md best-effort citation for where sidelink
%        IEs live in 38.331; cross-check against the pinned version in specVersions.json
%        before treating it as authoritative.
%Inputs: raw  scalar struct from jsondecode(), one SL-ResourcePool-r16 JSON object (keys are
%             the ASN.1 field names with hyphens auto-transliterated to underscores)
%Outputs: s  scalar struct, every SL-ResourcePool-r16 Rel-16 field. Every OPTIONAL field is
%            represented as a value (a defined default when absent) plus a matching
%            "<field>_Present" logical -- see jsonDecode.m design note 2. Dynamic range for
%            every numeric leaf is the ASN.1 constraint given inline below.
%
%Note on sl-TimeResource-r16: this field sits inside the first "[[ ]]" extension-marker block
%in the aggregated ASN.1 source, which technically makes it a post-freeze addition rather than
%base-sequence content -- but it is genuine Release-16 material (not a Rel-17/18 feature), and
%+cfg/CLAUDE.md's own validator checklist requires it ("sl-TimeResource bitmap length
%permitted..."), so it is included here as an in-scope Rel-16 field despite its ASN.1
%position. See the plan's design-decision notes for the full reasoning.

s = struct();

[s.sl_PSCCH_Config_r16, s.sl_PSCCH_Config_r16_Present] = decodeSetupRelease(raw, 'sl_PSCCH_Config_r16', @buildPscchConfig, defaultPscchConfig());
[s.sl_PSSCH_Config_r16, s.sl_PSSCH_Config_r16_Present] = decodeSetupRelease(raw, 'sl_PSSCH_Config_r16', @buildPsschConfig, defaultPsschConfig());
[s.sl_PSFCH_Config_r16, s.sl_PSFCH_Config_r16_Present] = decodeSetupRelease(raw, 'sl_PSFCH_Config_r16', @buildPsfchConfig, defaultPsfchConfig());

[syncRaw, s.sl_SyncAllowed_r16_Present] = getOptional(raw, 'sl_SyncAllowed_r16', struct());
if s.sl_SyncAllowed_r16_Present
    s.sl_SyncAllowed_r16 = buildSyncAllowed(syncRaw);
else
    s.sl_SyncAllowed_r16 = defaultSyncAllowed();
end

[lbl, s.sl_SubchannelSize_r16_Present] = getOptional(raw, 'sl_SubchannelSize_r16', '');
if s.sl_SubchannelSize_r16_Present, s.sl_SubchannelSize_r16 = resolveEnum('sl-SubchannelSize-r16', lbl); else, s.sl_SubchannelSize_r16 = 0; end

[s.dummy, s.dummy_Present] = getOptional(raw, 'dummy', 0);   % SPEC: legacy renamed field, INTEGER (10..160), unused
[s.sl_StartRB_Subchannel_r16, s.sl_StartRB_Subchannel_r16_Present] = getOptional(raw, 'sl_StartRB_Subchannel_r16', 0);   % INTEGER (0..265)
[s.sl_NumSubchannel_r16, s.sl_NumSubchannel_r16_Present]           = getOptional(raw, 'sl_NumSubchannel_r16', 0);        % INTEGER (1..27)

[lbl, s.sl_Additional_MCS_Table_r16_Present] = getOptional(raw, 'sl_Additional_MCS_Table_r16', '');
if s.sl_Additional_MCS_Table_r16_Present, s.sl_Additional_MCS_Table_r16 = resolveEnum('sl-Additional-MCS-Table-r16', lbl); else, s.sl_Additional_MCS_Table_r16 = ''; end

[s.sl_ThreshS_RSSI_CBR_r16, s.sl_ThreshS_RSSI_CBR_r16_Present] = getOptional(raw, 'sl_ThreshS_RSSI_CBR_r16', 0);   % INTEGER (0..45)

[lbl, s.sl_TimeWindowSizeCBR_r16_Present] = getOptional(raw, 'sl_TimeWindowSizeCBR_r16', '');
if s.sl_TimeWindowSizeCBR_r16_Present, s.sl_TimeWindowSizeCBR_r16 = resolveEnum('sl-TimeWindowSizeCBR-r16', lbl); else, s.sl_TimeWindowSizeCBR_r16 = ''; end

[lbl, s.sl_TimeWindowSizeCR_r16_Present] = getOptional(raw, 'sl_TimeWindowSizeCR_r16', '');
if s.sl_TimeWindowSizeCR_r16_Present, s.sl_TimeWindowSizeCR_r16 = resolveEnum('sl-TimeWindowSizeCR-r16', lbl); else, s.sl_TimeWindowSizeCR_r16 = ''; end

[ptrsRaw, s.sl_PTRS_Config_r16_Present] = getOptional(raw, 'sl_PTRS_Config_r16', struct());
if s.sl_PTRS_Config_r16_Present, s.sl_PTRS_Config_r16 = buildPtrsConfig(ptrsRaw); else, s.sl_PTRS_Config_r16 = defaultPtrsConfig(); end

[rpRaw, s.sl_UE_SelectedConfigRP_r16_Present] = getOptional(raw, 'sl_UE_SelectedConfigRP_r16', struct());
if s.sl_UE_SelectedConfigRP_r16_Present, s.sl_UE_SelectedConfigRP_r16 = buildUeSelectedConfigRp(rpRaw); else, s.sl_UE_SelectedConfigRP_r16 = defaultUeSelectedConfigRp(); end

[ncellRaw, s.sl_RxParametersNcell_r16_Present] = getOptional(raw, 'sl_RxParametersNcell_r16', struct());
if s.sl_RxParametersNcell_r16_Present
    tddRaw = struct(); tddPresent = false;
    if isfield(ncellRaw, 'sl_TDD_Configuration_r16')
        tddRaw = ncellRaw.sl_TDD_Configuration_r16; tddPresent = true;
    end
    nc.sl_TDD_Configuration_r16_Present = tddPresent;
    if tddPresent, nc.sl_TDD_Configuration_r16 = buildTddConfigCommon(tddRaw); else, nc.sl_TDD_Configuration_r16 = defaultTddConfigCommon(); end
    nc.sl_SyncConfigIndex_r16 = getMandatory(ncellRaw, 'sl_SyncConfigIndex_r16');   % INTEGER (0..15)
    s.sl_RxParametersNcell_r16 = nc;
else
    s.sl_RxParametersNcell_r16 = struct('sl_TDD_Configuration_r16_Present', false, ...
        'sl_TDD_Configuration_r16', defaultTddConfigCommon(), 'sl_SyncConfigIndex_r16', 0);
end

zoneItems = getOptList(raw, 'sl_ZoneConfigMCR_List_r16');
s.sl_ZoneConfigMCR_List_r16_Present = ~isempty(zoneItems);
if s.sl_ZoneConfigMCR_List_r16_Present
    if numel(zoneItems) ~= 16
        error('cfg:resourcePool:badSize', 'sl-ZoneConfigMCR-List-r16: SIZE(16) fixed, got %d entries', numel(zoneItems));
    end
    z = repmat(defaultZoneConfigMcr(), 1, 16);
    for i = 1:16
        z(i) = buildZoneConfigMcr(zoneItems{i});
    end
    s.sl_ZoneConfigMCR_List_r16 = z;
else
    s.sl_ZoneConfigMCR_List_r16 = repmat(defaultZoneConfigMcr(), 1, 16);
end

[lbl, s.sl_FilterCoefficient_r16_Present] = getOptional(raw, 'sl_FilterCoefficient_r16', '');
if s.sl_FilterCoefficient_r16_Present, s.sl_FilterCoefficient_r16 = resolveEnum('FilterCoefficient', lbl); else, s.sl_FilterCoefficient_r16 = 0; end

[s.sl_RB_Number_r16, s.sl_RB_Number_r16_Present] = getOptional(raw, 'sl_RB_Number_r16', 0);   % INTEGER (10..275)

[lbl, s.sl_PreemptionEnable_r16_Present] = getOptional(raw, 'sl_PreemptionEnable_r16', '');
if s.sl_PreemptionEnable_r16_Present, s.sl_PreemptionEnable_r16 = resolveEnum('sl-PreemptionEnable-r16', lbl); else, s.sl_PreemptionEnable_r16 = ''; end

[s.sl_PriorityThreshold_UL_URLLC_r16, s.sl_PriorityThreshold_UL_URLLC_r16_Present] = getOptional(raw, 'sl_PriorityThreshold_UL_URLLC_r16', 0);   % INTEGER (1..9)
[s.sl_PriorityThreshold_r16, s.sl_PriorityThreshold_r16_Present]                   = getOptional(raw, 'sl_PriorityThreshold_r16', 0);            % INTEGER (1..9)

[lbl, s.sl_X_Overhead_r16_Present] = getOptional(raw, 'sl_X_Overhead_r16', '');
if s.sl_X_Overhead_r16_Present, s.sl_X_Overhead_r16 = resolveEnum('sl-X-Overhead-r16', lbl); else, s.sl_X_Overhead_r16 = 0; end

[pcRaw, s.sl_PowerControl_r16_Present] = getOptional(raw, 'sl_PowerControl_r16', struct());
if s.sl_PowerControl_r16_Present, s.sl_PowerControl_r16 = buildPowerControl(pcRaw); else, s.sl_PowerControl_r16 = defaultPowerControl(); end

txPctItems = getOptList(raw, 'sl_TxPercentageList_r16');
s.sl_TxPercentageList_r16_Present = ~isempty(txPctItems);
if s.sl_TxPercentageList_r16_Present
    if numel(txPctItems) ~= 8
        error('cfg:resourcePool:badSize', 'sl-TxPercentageList-r16: SIZE(8) fixed, got %d entries', numel(txPctItems));
    end
    p = repmat(struct('sl_Priority_r16', 0, 'sl_TxPercentage_r16', 0), 1, 8);
    for i = 1:8
        p(i).sl_Priority_r16     = getMandatory(txPctItems{i}, 'sl_Priority_r16');           % INTEGER (1..8)
        p(i).sl_TxPercentage_r16 = resolveEnum('sl-TxPercentage-r16', getMandatory(txPctItems{i}, 'sl_TxPercentage_r16'));
    end
    s.sl_TxPercentageList_r16 = p;
else
    s.sl_TxPercentageList_r16 = repmat(struct('sl_Priority_r16', 0, 'sl_TxPercentage_r16', 0), 1, 8);
end

mcsItems = getOptList(raw, 'sl_MinMaxMCS_List_r16');
s.sl_MinMaxMCS_List_r16_Present = ~isempty(mcsItems);
if s.sl_MinMaxMCS_List_r16_Present
    if numel(mcsItems) < 1 || numel(mcsItems) > 3
        error('cfg:resourcePool:badSize', 'sl-MinMaxMCS-List-r16: SIZE(1..3), got %d entries', numel(mcsItems));
    end
    m = repmat(struct('sl_MCS_Table_r16', '', 'sl_MinMCS_PSSCH_r16', 0, 'sl_MaxMCS_PSSCH_r16', 0), 1, numel(mcsItems));
    for i = 1:numel(mcsItems)
        m(i).sl_MCS_Table_r16    = resolveEnum('sl-MCS-Table-r16', getMandatory(mcsItems{i}, 'sl_MCS_Table_r16'));
        m(i).sl_MinMCS_PSSCH_r16 = getMandatory(mcsItems{i}, 'sl_MinMCS_PSSCH_r16');   % INTEGER (0..27)
        m(i).sl_MaxMCS_PSSCH_r16 = getMandatory(mcsItems{i}, 'sl_MaxMCS_PSSCH_r16');   % INTEGER (0..31)
    end
    s.sl_MinMaxMCS_List_r16 = m;
else
    s.sl_MinMaxMCS_List_r16 = repmat(struct('sl_MCS_Table_r16', '', 'sl_MinMCS_PSSCH_r16', 0, 'sl_MaxMCS_PSSCH_r16', 0), 1, 0);
end

[bits, s.sl_TimeResource_r16_Present] = getOptional(raw, 'sl_TimeResource_r16', []);
if s.sl_TimeResource_r16_Present
    s.sl_TimeResource_r16 = logical(bits(:))';   % BIT STRING (SIZE (10..160))
else
    s.sl_TimeResource_r16 = false(1, 0);
end
end

% ======================================================================
% Local builders -- SL-ResourcePool-r16 sub-IEs. Not callable outside this file.
% ======================================================================

function [value, present] = decodeSetupRelease(raw, key, buildFn, defaultValue)
%decodeSetupRelease Decode a 38.331 SetupRelease{T} CHOICE (release NULL | setup T).
if ~isfield(raw, key)
    value = defaultValue; present = false; return;
end
node = raw.(key);
switch node.case
    case 'release'
        value = defaultValue; present = false;
    case 'setup'
        value = buildFn(node.setup); present = true;
    otherwise
        error('cfg:resourcePool:badChoice', '%s: case must be "release" or "setup", got "%s"', key, node.case);
end
end

function c = buildPscchConfig(raw)
% SPEC: TS 38.331, SL-PSCCH-Config-r16
[lbl, c.sl_TimeResourcePSCCH_r16_Present] = getOptional(raw, 'sl_TimeResourcePSCCH_r16', '');
if c.sl_TimeResourcePSCCH_r16_Present, c.sl_TimeResourcePSCCH_r16 = resolveEnum('sl-TimeResourcePSCCH-r16', lbl); else, c.sl_TimeResourcePSCCH_r16 = 0; end
[lbl, c.sl_FreqResourcePSCCH_r16_Present] = getOptional(raw, 'sl_FreqResourcePSCCH_r16', '');
if c.sl_FreqResourcePSCCH_r16_Present, c.sl_FreqResourcePSCCH_r16 = resolveEnum('sl-FreqResourcePSCCH-r16', lbl); else, c.sl_FreqResourcePSCCH_r16 = 0; end
[c.sl_DMRS_ScrambleID_r16, c.sl_DMRS_ScrambleID_r16_Present] = getOptional(raw, 'sl_DMRS_ScrambleID_r16', 0);   % INTEGER (0..65535)
[c.sl_NumReservedBits_r16, c.sl_NumReservedBits_r16_Present] = getOptional(raw, 'sl_NumReservedBits_r16', 2);   % INTEGER (2..4)
end
function c = defaultPscchConfig()
c = buildPscchConfig(struct());
end

function c = buildPsschConfig(raw)
% SPEC: TS 38.331, SL-PSSCH-Config-r16
[c.sl_PSSCH_DMRS_TimePatternList_r16, c.sl_PSSCH_DMRS_TimePatternList_r16_Present] = getOptional(raw, 'sl_PSSCH_DMRS_TimePatternList_r16', zeros(1, 0));   % SEQUENCE (SIZE(1..3)) OF INTEGER (2..4)
c.sl_PSSCH_DMRS_TimePatternList_r16 = c.sl_PSSCH_DMRS_TimePatternList_r16(:)';
[c.sl_BetaOffsets2ndSCI_r16, c.sl_BetaOffsets2ndSCI_r16_Present] = getOptional(raw, 'sl_BetaOffsets2ndSCI_r16', zeros(1, 4));   % SEQUENCE (SIZE(4)) OF INTEGER (0..31)
c.sl_BetaOffsets2ndSCI_r16 = c.sl_BetaOffsets2ndSCI_r16(:)';
[lbl, c.sl_Scaling_r16_Present] = getOptional(raw, 'sl_Scaling_r16', '');
if c.sl_Scaling_r16_Present, c.sl_Scaling_r16 = resolveEnum('sl-Scaling-r16', lbl); else, c.sl_Scaling_r16 = 1; end
end
function c = defaultPsschConfig()
c = buildPsschConfig(struct());
end

function c = buildPsfchConfig(raw)
% SPEC: TS 38.331, SL-PSFCH-Config-r16
[lbl, c.sl_PSFCH_Period_r16_Present] = getOptional(raw, 'sl_PSFCH_Period_r16', '');
if c.sl_PSFCH_Period_r16_Present, c.sl_PSFCH_Period_r16 = resolveEnum('sl-PSFCH-Period-r16', lbl); else, c.sl_PSFCH_Period_r16 = 0; end
[bits, c.sl_PSFCH_RB_Set_r16_Present] = getOptional(raw, 'sl_PSFCH_RB_Set_r16', []);   % BIT STRING (SIZE(10..275))
c.sl_PSFCH_RB_Set_r16 = logical(bits(:))';
[lbl, c.sl_NumMuxCS_Pair_r16_Present] = getOptional(raw, 'sl_NumMuxCS_Pair_r16', '');
if c.sl_NumMuxCS_Pair_r16_Present, c.sl_NumMuxCS_Pair_r16 = resolveEnum('sl-NumMuxCS-Pair-r16', lbl); else, c.sl_NumMuxCS_Pair_r16 = 1; end
[lbl, c.sl_MinTimeGapPSFCH_r16_Present] = getOptional(raw, 'sl_MinTimeGapPSFCH_r16', '');
if c.sl_MinTimeGapPSFCH_r16_Present, c.sl_MinTimeGapPSFCH_r16 = resolveEnum('sl-MinTimeGapPSFCH-r16', lbl); else, c.sl_MinTimeGapPSFCH_r16 = 2; end
[c.sl_PSFCH_HopID_r16, c.sl_PSFCH_HopID_r16_Present] = getOptional(raw, 'sl_PSFCH_HopID_r16', 0);   % INTEGER (0..1023)
[lbl, c.sl_PSFCH_CandidateResourceType_r16_Present] = getOptional(raw, 'sl_PSFCH_CandidateResourceType_r16', '');
if c.sl_PSFCH_CandidateResourceType_r16_Present, c.sl_PSFCH_CandidateResourceType_r16 = resolveEnum('sl-PSFCH-CandidateResourceType-r16', lbl); else, c.sl_PSFCH_CandidateResourceType_r16 = ''; end
end
function c = defaultPsfchConfig()
c = buildPsfchConfig(struct());
end

function c = buildSyncAllowed(raw)
% SPEC: TS 38.331, SL-SyncAllowed-r16 -- each field is presence-as-boolean (ENUMERATED{true})
c.gnss_Sync_r16   = getFlag(raw, 'gnss_Sync_r16', 'true');
c.gnbEnb_Sync_r16 = getFlag(raw, 'gnbEnb_Sync_r16', 'true');
c.ue_Sync_r16     = getFlag(raw, 'ue_Sync_r16', 'true');
end
function c = defaultSyncAllowed()
c = buildSyncAllowed(struct());
end

function c = buildPtrsConfig(raw)
% SPEC: TS 38.331, SL-PTRS-Config-r16
[c.sl_PTRS_FreqDensity_r16, c.sl_PTRS_FreqDensity_r16_Present] = getOptional(raw, 'sl_PTRS_FreqDensity_r16', zeros(1, 2));   % SIZE(2), INTEGER(1..276)
c.sl_PTRS_FreqDensity_r16 = c.sl_PTRS_FreqDensity_r16(:)';
[c.sl_PTRS_TimeDensity_r16, c.sl_PTRS_TimeDensity_r16_Present] = getOptional(raw, 'sl_PTRS_TimeDensity_r16', zeros(1, 3));   % SIZE(3), INTEGER(0..29)
c.sl_PTRS_TimeDensity_r16 = c.sl_PTRS_TimeDensity_r16(:)';
[lbl, c.sl_PTRS_RE_Offset_r16_Present] = getOptional(raw, 'sl_PTRS_RE_Offset_r16', '');
if c.sl_PTRS_RE_Offset_r16_Present, c.sl_PTRS_RE_Offset_r16 = resolveEnum('sl-PTRS-RE-Offset-r16', lbl); else, c.sl_PTRS_RE_Offset_r16 = ''; end
end
function c = defaultPtrsConfig()
c = buildPtrsConfig(struct());
end

function c = buildZoneConfigMcr(raw)
% SPEC: TS 38.331, SL-ZoneConfigMCR-r16
c.sl_ZoneConfigMCR_Index_r16 = getMandatory(raw, 'sl_ZoneConfigMCR_Index_r16');   % INTEGER (0..15)
[lbl, c.sl_TransRange_r16_Present] = getOptional(raw, 'sl_TransRange_r16', '');
if c.sl_TransRange_r16_Present, c.sl_TransRange_r16 = resolveEnum('sl-TransRange-r16', lbl); else, c.sl_TransRange_r16 = 0; end
[zcRaw, c.sl_ZoneConfig_r16_Present] = getOptional(raw, 'sl_ZoneConfig_r16', struct());
if c.sl_ZoneConfig_r16_Present
    c.sl_ZoneConfig_r16 = struct('sl_ZoneLength_r16', resolveEnum('sl-ZoneLength-r16', getMandatory(zcRaw, 'sl_ZoneLength_r16')));
else
    c.sl_ZoneConfig_r16 = struct('sl_ZoneLength_r16', 0);
end
end
function c = defaultZoneConfigMcr()
c = buildZoneConfigMcr(struct('sl_ZoneConfigMCR_Index_r16', 0));
end

function c = buildUeSelectedConfigRp(raw)
% SPEC: TS 38.331, SL-UE-SelectedConfigRP-r16
cbrItems = getOptList(raw, 'sl_CBR_PriorityTxConfigList_r16');
c.sl_CBR_PriorityTxConfigList_r16_Present = ~isempty(cbrItems);
if c.sl_CBR_PriorityTxConfigList_r16_Present
    if numel(cbrItems) < 1 || numel(cbrItems) > 8
        error('cfg:resourcePool:badSize', 'sl-CBR-PriorityTxConfigList-r16: SIZE(1..8), got %d entries', numel(cbrItems));
    end
    cb = repmat(struct('sl_Priority_r16', 0, 'sl_CBR_r16', 0), 1, numel(cbrItems));
    for i = 1:numel(cbrItems)
        cb(i).sl_Priority_r16 = getMandatory(cbrItems{i}, 'sl_Priority_r16');   % INTEGER (1..8)
        cb(i).sl_CBR_r16      = getMandatory(cbrItems{i}, 'sl_CBR_r16');        % INTEGER (0..100)
    end
    c.sl_CBR_PriorityTxConfigList_r16 = cb;
else
    c.sl_CBR_PriorityTxConfigList_r16 = repmat(struct('sl_Priority_r16', 0, 'sl_CBR_r16', 0), 1, 0);
end

[c.sl_Thres_RSRP_List_r16, c.sl_Thres_RSRP_List_r16_Present] = getOptional(raw, 'sl_Thres_RSRP_List_r16', zeros(1, 64));   % SIZE(64), INTEGER(0..66)
c.sl_Thres_RSRP_List_r16 = c.sl_Thres_RSRP_List_r16(:)';

c.sl_MultiReserveResource_r16 = getFlag(raw, 'sl_MultiReserveResource_r16', 'enabled');

[lbl, c.sl_MaxNumPerReserve_r16_Present] = getOptional(raw, 'sl_MaxNumPerReserve_r16', '');
if c.sl_MaxNumPerReserve_r16_Present, c.sl_MaxNumPerReserve_r16 = resolveEnum('sl-MaxNumPerReserve-r16', lbl); else, c.sl_MaxNumPerReserve_r16 = 2; end

[lbl, c.sl_SensingWindow_r16_Present] = getOptional(raw, 'sl_SensingWindow_r16', '');
if c.sl_SensingWindow_r16_Present, c.sl_SensingWindow_r16 = resolveEnum('sl-SensingWindow-r16', lbl); else, c.sl_SensingWindow_r16 = 0; end

swItems = getOptList(raw, 'sl_SelectionWindowList_r16');
c.sl_SelectionWindowList_r16_Present = ~isempty(swItems);
if c.sl_SelectionWindowList_r16_Present
    if numel(swItems) ~= 8
        error('cfg:resourcePool:badSize', 'sl-SelectionWindowList-r16: SIZE(8) fixed, got %d entries', numel(swItems));
    end
    sw = repmat(struct('sl_Priority_r16', 0, 'sl_SelectionWindow_r16', 0), 1, 8);
    for i = 1:8
        sw(i).sl_Priority_r16        = getMandatory(swItems{i}, 'sl_Priority_r16');   % INTEGER (1..8)
        sw(i).sl_SelectionWindow_r16 = resolveEnum('sl-SelectionWindow-r16', getMandatory(swItems{i}, 'sl_SelectionWindow_r16'));
    end
    c.sl_SelectionWindowList_r16 = sw;
else
    c.sl_SelectionWindowList_r16 = repmat(struct('sl_Priority_r16', 0, 'sl_SelectionWindow_r16', 0), 1, 8);
end

rrpItems = getOptList(raw, 'sl_ResourceReservePeriodList_r16');
c.sl_ResourceReservePeriodList_r16_Present = ~isempty(rrpItems);
if c.sl_ResourceReservePeriodList_r16_Present
    if numel(rrpItems) < 1 || numel(rrpItems) > 16
        error('cfg:resourcePool:badSize', 'sl-ResourceReservePeriodList-r16: SIZE(1..16), got %d entries', numel(rrpItems));
    end
    rp = repmat(struct('case', '', 'sl_ResourceReservePeriod_ms', 0), 1, numel(rrpItems));
    for i = 1:numel(rrpItems)
        rp(i) = buildResourceReservePeriod(rrpItems{i});
    end
    c.sl_ResourceReservePeriodList_r16 = rp;
else
    c.sl_ResourceReservePeriodList_r16 = repmat(struct('case', '', 'sl_ResourceReservePeriod_ms', 0), 1, 0);
end

[lbl] = getMandatory(raw, 'sl_RS_ForSensing_r16');
c.sl_RS_ForSensing_r16 = resolveEnum('sl-RS-ForSensing-r16', lbl);
end
function c = defaultUeSelectedConfigRp()
c = buildUeSelectedConfigRp(struct('sl_RS_ForSensing_r16', 'pssch'));
end

function r = buildResourceReservePeriod(raw)
% SPEC: TS 38.331, SL-ResourceReservePeriod-r16 CHOICE. sl-ResourceReservePeriod2-r16
% INTEGER(1..99) is read directly as milliseconds (fine-grained periods below the
% period-1 100ms granularity) -- this specific unit reading is a best-effort inference,
% cross-check clause 6.3.5 before relying on it for a sub-100ms reservation period.
caseTag = getMandatory(raw, 'case');
r.case = caseTag;
switch caseTag
    case 'sl-ResourceReservePeriod1-r16'
        r.sl_ResourceReservePeriod_ms = resolveEnum('sl-ResourceReservePeriod1-r16', getMandatory(raw, 'sl_ResourceReservePeriod1_r16'));
    case 'sl-ResourceReservePeriod2-r16'
        r.sl_ResourceReservePeriod_ms = getMandatory(raw, 'sl_ResourceReservePeriod2_r16');   % INTEGER (1..99)
    otherwise
        error('cfg:resourcePool:badChoice', 'sl-ResourceReservePeriod-r16: unknown case "%s"', caseTag);
end
end

function c = buildPowerControl(raw)
% SPEC: TS 38.331, SL-PowerControl-r16
c.sl_MaxTransPower_r16 = getMandatory(raw, 'sl_MaxTransPower_r16');   % INTEGER (-30..33)
[lbl, c.sl_Alpha_PSSCH_PSCCH_r16_Present] = getOptional(raw, 'sl_Alpha_PSSCH_PSCCH_r16', '');
if c.sl_Alpha_PSSCH_PSCCH_r16_Present, c.sl_Alpha_PSSCH_PSCCH_r16 = resolveEnum('sl-Alpha-r16', lbl); else, c.sl_Alpha_PSSCH_PSCCH_r16 = 1; end
[lbl, c.dl_Alpha_PSSCH_PSCCH_r16_Present] = getOptional(raw, 'dl_Alpha_PSSCH_PSCCH_r16', '');
if c.dl_Alpha_PSSCH_PSCCH_r16_Present, c.dl_Alpha_PSSCH_PSCCH_r16 = resolveEnum('sl-Alpha-r16', lbl); else, c.dl_Alpha_PSSCH_PSCCH_r16 = 1; end
[c.sl_P0_PSSCH_PSCCH_r16, c.sl_P0_PSSCH_PSCCH_r16_Present] = getOptional(raw, 'sl_P0_PSSCH_PSCCH_r16', 0);   % INTEGER (-16..15)
[c.dl_P0_PSSCH_PSCCH_r16, c.dl_P0_PSSCH_PSCCH_r16_Present] = getOptional(raw, 'dl_P0_PSSCH_PSCCH_r16', 0);   % INTEGER (-16..15)
[lbl, c.dl_Alpha_PSFCH_r16_Present] = getOptional(raw, 'dl_Alpha_PSFCH_r16', '');
if c.dl_Alpha_PSFCH_r16_Present, c.dl_Alpha_PSFCH_r16 = resolveEnum('sl-Alpha-r16', lbl); else, c.dl_Alpha_PSFCH_r16 = 1; end
[c.dl_P0_PSFCH_r16, c.dl_P0_PSFCH_r16_Present] = getOptional(raw, 'dl_P0_PSFCH_r16', 0);   % INTEGER (-16..15)
end
function c = defaultPowerControl()
c = buildPowerControl(struct('sl_MaxTransPower_r16', 0));
end

function c = buildTddConfigCommon(raw)
% SPEC: TS 38.331, TDD-UL-DL-ConfigCommon (generic IE, cross-referenced by sidelink pool config)
c.referenceSubcarrierSpacing = resolveEnum('subcarrierSpacing', getMandatory(raw, 'referenceSubcarrierSpacing'));
c.pattern1 = buildTddPattern(getMandatory(raw, 'pattern1'));
[p2Raw, c.pattern2_Present] = getOptional(raw, 'pattern2', struct());
if c.pattern2_Present, c.pattern2 = buildTddPattern(p2Raw); else, c.pattern2 = defaultTddPattern(); end
end
function c = defaultTddConfigCommon()
c = buildTddConfigCommon(struct('referenceSubcarrierSpacing', 'kHz30', 'pattern1', struct( ...
    'dl_UL_TransmissionPeriodicity', 'ms10', 'nrofDownlinkSlots', 0, 'nrofDownlinkSymbols', 0, ...
    'nrofUplinkSlots', 0, 'nrofUplinkSymbols', 0)));
end

function p = buildTddPattern(raw)
% SPEC: TS 38.331, TDD-UL-DL-Pattern
p.dl_UL_TransmissionPeriodicity = resolveEnum('dl-UL-TransmissionPeriodicity', getMandatory(raw, 'dl_UL_TransmissionPeriodicity'));
p.nrofDownlinkSlots   = getMandatory(raw, 'nrofDownlinkSlots');     % INTEGER (0..320)
p.nrofDownlinkSymbols = getMandatory(raw, 'nrofDownlinkSymbols');   % INTEGER (0..13)
p.nrofUplinkSlots     = getMandatory(raw, 'nrofUplinkSlots');       % INTEGER (0..320)
p.nrofUplinkSymbols   = getMandatory(raw, 'nrofUplinkSymbols');     % INTEGER (0..13)
end
function p = defaultTddPattern()
p = buildTddPattern(struct('dl_UL_TransmissionPeriodicity', 'ms10', 'nrofDownlinkSlots', 0, ...
    'nrofDownlinkSymbols', 0, 'nrofUplinkSlots', 0, 'nrofUplinkSymbols', 0));
end
