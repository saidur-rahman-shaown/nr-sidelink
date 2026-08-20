function s = preconfig(raw)
%preconfig Build SidelinkPreconfigNR-r16 from its JSON-decoded raw struct.
%Spec:   TS 38.331 clause 6.3.5, IE SidelinkPreconfigNR-r16 (the real content of
%        SL-PreconfigurationNR-r16.sidelinkPreconfigNR-r16; the JSON schema skips that
%        one-field wrapper and starts directly at this level -- see +cfg/CLAUDE.md).
%        Release-16 baseline (see +cfg/CLAUDE.md scope decision).
%Inputs: raw  scalar struct from jsondecode(), the top-level "preconfig" JSON object
%Outputs: s  scalar struct, full Rel-16 SidelinkPreconfigNR-r16 tree. Every OPTIONAL field
%            carries a "<field>_Present" logical alongside its value.
%
%Deliberately not built here (deferred to B9, where +pdcp/+rlc/+sdap own this content):
%sl-RadioBearerPreConfigList-r16, sl-RLC-BearerPreConfigList-r16, sl-MeasPreConfig-r16.

freqItems = getOptList(raw, 'sl_PreconfigFreqInfoList_r16');
if isempty(freqItems)
    error('cfg:preconfig:missingField', 'sl-PreconfigFreqInfoList-r16 is required (at least one carrier)');
end
if numel(freqItems) > 8   % maxNrofFreqSL-r16 == 8
    error('cfg:preconfig:badSize', 'sl-PreconfigFreqInfoList-r16: SIZE(1..8), got %d entries', numel(freqItems));
end
f = repmat(defaultFreqConfigCommon(), 1, numel(freqItems));
for i = 1:numel(freqItems)
    f(i) = buildFreqConfigCommon(freqItems{i});
end
s.sl_PreconfigFreqInfoList_r16 = f;

[nrList, s.sl_PreconfigNR_AnchorCarrierFreqList_r16_Present] = getOptional(raw, 'sl_PreconfigNR_AnchorCarrierFreqList_r16', zeros(1, 0));
s.sl_PreconfigNR_AnchorCarrierFreqList_r16 = nrList(:)';

[eutraList, s.sl_PreconfigEUTRA_AnchorCarrierFreqList_r16_Present] = getOptional(raw, 'sl_PreconfigEUTRA_AnchorCarrierFreqList_r16', zeros(1, 0));
s.sl_PreconfigEUTRA_AnchorCarrierFreqList_r16 = eutraList(:)';

[s.sl_OffsetDFN_r16, s.sl_OffsetDFN_r16_Present] = getOptional(raw, 'sl_OffsetDFN_r16', 0);   % INTEGER (1..1000)

[lbl, s.t400_r16_Present] = getOptional(raw, 't400_r16', '');
if s.t400_r16_Present, s.t400_r16 = resolveEnum('t400-r16', lbl); else, s.t400_r16 = 0; end

[lbl, s.sl_MaxNumConsecutiveDTX_r16_Present] = getOptional(raw, 'sl_MaxNumConsecutiveDTX_r16', '');
if s.sl_MaxNumConsecutiveDTX_r16_Present, s.sl_MaxNumConsecutiveDTX_r16 = resolveEnum('sl-MaxNumConsecutiveDTX-r16', lbl); else, s.sl_MaxNumConsecutiveDTX_r16 = 0; end

[s.sl_SSB_PriorityNR_r16, s.sl_SSB_PriorityNR_r16_Present] = getOptional(raw, 'sl_SSB_PriorityNR_r16', 0);   % INTEGER (1..8)

[genRaw, s.sl_PreconfigGeneral_r16_Present] = getOptional(raw, 'sl_PreconfigGeneral_r16', struct());
if s.sl_PreconfigGeneral_r16_Present
    s.sl_PreconfigGeneral_r16 = buildPreconfigGeneral(genRaw);
else
    s.sl_PreconfigGeneral_r16 = defaultPreconfigGeneral();
end

[selRaw, s.sl_UE_SelectedPreConfig_r16_Present] = getOptional(raw, 'sl_UE_SelectedPreConfig_r16', struct());
if s.sl_UE_SelectedPreConfig_r16_Present
    s.sl_UE_SelectedPreConfig_r16 = buildUeSelectedConfig(selRaw);
else
    s.sl_UE_SelectedPreConfig_r16 = defaultUeSelectedConfig();
end

s.sl_CSI_Acquisition_r16 = getFlag(raw, 'sl_CSI_Acquisition_r16', 'enabled');

[rohcRaw, s.sl_RoHC_Profiles_r16_Present] = getOptional(raw, 'sl_RoHC_Profiles_r16', struct());
if s.sl_RoHC_Profiles_r16_Present
    s.sl_RoHC_Profiles_r16 = buildRohcProfiles(rohcRaw);
else
    s.sl_RoHC_Profiles_r16 = defaultRohcProfiles();
end

s.sl_MaxCID_r16 = getOptional(raw, 'sl_MaxCID_r16', 15);   % INTEGER (1..16383), DEFAULT 15
end

% ======================================================================
% Local builders. Not callable outside this file.
% ======================================================================

function f = buildFreqConfigCommon(raw)
% SPEC: TS 38.331, SL-FreqConfigCommon-r16
carrierItems = getOptList(raw, 'sl_SCS_SpecificCarrierList_r16');
if isempty(carrierItems)
    error('cfg:preconfig:missingField', 'sl-SCS-SpecificCarrierList-r16 is required (at least one carrier)');
end
if numel(carrierItems) > 5   % maxSCSs == 5
    error('cfg:preconfig:badSize', 'sl-SCS-SpecificCarrierList-r16: SIZE(1..5), got %d entries', numel(carrierItems));
end
c = repmat(defaultScsSpecificCarrier(), 1, numel(carrierItems));
for i = 1:numel(carrierItems)
    c(i) = buildScsSpecificCarrier(carrierItems{i});
end
f.sl_SCS_SpecificCarrierList_r16 = c;

f.sl_AbsoluteFrequencyPointA_r16 = getMandatory(raw, 'sl_AbsoluteFrequencyPointA_r16');   % ARFCN-ValueNR, INTEGER (0..3279165)
[f.sl_AbsoluteFrequencySSB_r16, f.sl_AbsoluteFrequencySSB_r16_Present] = getOptional(raw, 'sl_AbsoluteFrequencySSB_r16', 0);
f.frequencyShift7p5khzSL_r16 = getFlag(raw, 'frequencyShift7p5khzSL_r16', 'true');
f.valueN_r16 = getMandatory(raw, 'valueN_r16');   % INTEGER (-1..1)

bwpItems = getOptList(raw, 'sl_BWP_List_r16');
f.sl_BWP_List_r16_Present = ~isempty(bwpItems);
if f.sl_BWP_List_r16_Present
    if numel(bwpItems) > 4   % maxNrofSL-BWPs-r16 == 4
        error('cfg:preconfig:badSize', 'sl-BWP-List-r16: SIZE(1..4), got %d entries', numel(bwpItems));
    end
    b = repmat(cfg.bwpConfig(struct()), 1, numel(bwpItems));
    for i = 1:numel(bwpItems)
        b(i) = cfg.bwpConfig(bwpItems{i});
    end
    f.sl_BWP_List_r16 = b;
else
    f.sl_BWP_List_r16 = repmat(cfg.bwpConfig(struct()), 1, 0);
end

[lbl, f.sl_SyncPriority_r16_Present] = getOptional(raw, 'sl_SyncPriority_r16', '');
if f.sl_SyncPriority_r16_Present, f.sl_SyncPriority_r16 = resolveEnum('sl-SyncPriority-r16', lbl); else, f.sl_SyncPriority_r16 = ''; end

[f.sl_NbAsSync_r16, f.sl_NbAsSync_r16_Present] = getOptional(raw, 'sl_NbAsSync_r16', false);   % BOOLEAN

[scList, f.sl_SyncConfigList_r16_Present] = getOptional(raw, 'sl_SyncConfigList_r16', zeros(1, 0));   % SIZE(1..16), INTEGER(0..15)
f.sl_SyncConfigList_r16 = scList(:)';
end
function f = defaultFreqConfigCommon()
f = buildFreqConfigCommon(struct('sl_SCS_SpecificCarrierList_r16', struct( ...
    'offsetToCarrier', 0, 'subcarrierSpacing', 'kHz30', 'carrierBandwidth', 1), ...
    'sl_AbsoluteFrequencyPointA_r16', 0, 'valueN_r16', 0));
end

function c = buildScsSpecificCarrier(raw)
% SPEC: TS 38.331, generic IE SCS-SpecificCarrier
c.offsetToCarrier   = getMandatory(raw, 'offsetToCarrier');   % INTEGER (0..2199)
c.subcarrierSpacing = resolveEnum('subcarrierSpacing', getMandatory(raw, 'subcarrierSpacing'));
c.carrierBandwidth  = getMandatory(raw, 'carrierBandwidth');   % INTEGER (1..275)
end
function c = defaultScsSpecificCarrier()
c = buildScsSpecificCarrier(struct('offsetToCarrier', 0, 'subcarrierSpacing', 'kHz30', 'carrierBandwidth', 1));
end

function g = buildPreconfigGeneral(raw)
% SPEC: TS 38.331, SL-PreconfigGeneral-r16
[tddRaw, g.sl_TDD_Configuration_r16_Present] = getOptional(raw, 'sl_TDD_Configuration_r16', struct());
% TDD-UL-DL-ConfigCommon builder lives as a local function inside resourcePool.m (it is also
% needed there, for sl-RxParametersNcell-r16); duplicated here rather than exposed publicly,
% since it is a small generic IE and +cfg/CLAUDE.md's interface rule wants convenience
% accessors as functions, not a second copy of the tree -- this is a builder function, not a
% flattened copy of config data, so a second small local copy is the pragmatic choice over
% inventing a shared non-local file for one four-field IE used in two places.
if g.sl_TDD_Configuration_r16_Present
    g.sl_TDD_Configuration_r16 = buildTddConfigCommonLocal(tddRaw);
else
    g.sl_TDD_Configuration_r16 = buildTddConfigCommonLocal(struct('referenceSubcarrierSpacing', 'kHz30', ...
        'pattern1', struct('dl_UL_TransmissionPeriodicity', 'ms10', 'nrofDownlinkSlots', 0, ...
        'nrofDownlinkSymbols', 0, 'nrofUplinkSlots', 0, 'nrofUplinkSymbols', 0)));
end

[bits, g.reservedBits_r16_Present] = getOptional(raw, 'reservedBits_r16', [0 0]);   % BIT STRING (SIZE(2))
g.reservedBits_r16 = logical(bits(:))';
end
function g = defaultPreconfigGeneral()
g = buildPreconfigGeneral(struct());
end

function c = buildTddConfigCommonLocal(raw)
c.referenceSubcarrierSpacing = resolveEnum('subcarrierSpacing', getMandatory(raw, 'referenceSubcarrierSpacing'));
c.pattern1 = buildTddPatternLocal(getMandatory(raw, 'pattern1'));
[p2Raw, c.pattern2_Present] = getOptional(raw, 'pattern2', struct());
if c.pattern2_Present
    c.pattern2 = buildTddPatternLocal(p2Raw);
else
    c.pattern2 = buildTddPatternLocal(struct('dl_UL_TransmissionPeriodicity', 'ms10', ...
        'nrofDownlinkSlots', 0, 'nrofDownlinkSymbols', 0, 'nrofUplinkSlots', 0, 'nrofUplinkSymbols', 0));
end
end
function p = buildTddPatternLocal(raw)
p.dl_UL_TransmissionPeriodicity = resolveEnum('dl-UL-TransmissionPeriodicity', getMandatory(raw, 'dl_UL_TransmissionPeriodicity'));
p.nrofDownlinkSlots   = getMandatory(raw, 'nrofDownlinkSlots');
p.nrofDownlinkSymbols = getMandatory(raw, 'nrofDownlinkSymbols');
p.nrofUplinkSlots     = getMandatory(raw, 'nrofUplinkSlots');
p.nrofUplinkSymbols   = getMandatory(raw, 'nrofUplinkSymbols');
end

function u = buildUeSelectedConfig(raw)
% SPEC: TS 38.331, SL-UE-SelectedConfig-r16
txItems = getOptList(raw, 'sl_PSSCH_TxConfigList_r16');
u.sl_PSSCH_TxConfigList_r16_Present = ~isempty(txItems);
if u.sl_PSSCH_TxConfigList_r16_Present
    if numel(txItems) > 8   % maxPSSCH-TxConfig-r16 == 8
        error('cfg:preconfig:badSize', 'sl-PSSCH-TxConfigList-r16: SIZE(1..8), got %d entries', numel(txItems));
    end
    t = repmat(defaultPsschTxConfig(), 1, numel(txItems));
    for i = 1:numel(txItems)
        t(i) = buildPsschTxConfig(txItems{i});
    end
    u.sl_PSSCH_TxConfigList_r16 = t;
else
    u.sl_PSSCH_TxConfigList_r16 = repmat(defaultPsschTxConfig(), 1, 0);
end

[lbl, u.sl_ProbResourceKeep_r16_Present] = getOptional(raw, 'sl_ProbResourceKeep_r16', '');
if u.sl_ProbResourceKeep_r16_Present, u.sl_ProbResourceKeep_r16 = resolveEnum('sl-ProbResourceKeep-r16', lbl); else, u.sl_ProbResourceKeep_r16 = 0; end

[lbl, u.sl_ReselectAfter_r16_Present] = getOptional(raw, 'sl_ReselectAfter_r16', '');
if u.sl_ReselectAfter_r16_Present, u.sl_ReselectAfter_r16 = resolveEnum('sl-ReselectAfter-r16', lbl); else, u.sl_ReselectAfter_r16 = 0; end

cbrItems = getOptList(raw, 'sl_CBR_CommonTxConfigList_r16');
u.sl_CBR_CommonTxConfigList_r16_Present = ~isempty(cbrItems);
if u.sl_CBR_CommonTxConfigList_r16_Present
    if numel(cbrItems) > 8
        error('cfg:preconfig:badSize', 'sl-CBR-CommonTxConfigList-r16: SIZE(1..8), got %d entries', numel(cbrItems));
    end
    cb = repmat(struct('sl_Priority_r16', 0, 'sl_CBR_r16', 0), 1, numel(cbrItems));
    for i = 1:numel(cbrItems)
        cb(i).sl_Priority_r16 = getMandatory(cbrItems{i}, 'sl_Priority_r16');
        cb(i).sl_CBR_r16      = getMandatory(cbrItems{i}, 'sl_CBR_r16');
    end
    u.sl_CBR_CommonTxConfigList_r16 = cb;
else
    u.sl_CBR_CommonTxConfigList_r16 = repmat(struct('sl_Priority_r16', 0, 'sl_CBR_r16', 0), 1, 0);
end

[u.ul_PrioritizationThres_r16, u.ul_PrioritizationThres_r16_Present] = getOptional(raw, 'ul_PrioritizationThres_r16', 0);   % INTEGER (1..16)
[u.sl_PrioritizationThres_r16, u.sl_PrioritizationThres_r16_Present] = getOptional(raw, 'sl_PrioritizationThres_r16', 0);   % INTEGER (1..8)
end
function u = defaultUeSelectedConfig()
u = buildUeSelectedConfig(struct());
end

function t = buildPsschTxConfig(raw)
% SPEC: TS 38.331, SL-PSSCH-TxConfig-r16
[lbl, t.sl_TypeTxSync_r16_Present] = getOptional(raw, 'sl_TypeTxSync_r16', '');
if t.sl_TypeTxSync_r16_Present, t.sl_TypeTxSync_r16 = resolveEnum('sl-TypeTxSync-r16', lbl); else, t.sl_TypeTxSync_r16 = ''; end
t.sl_ThresUE_Speed_r16        = resolveEnum('sl-ThresUE-Speed-r16', getMandatory(raw, 'sl_ThresUE_Speed_r16'));
t.sl_ParametersAboveThres_r16 = buildPsschTxParameters(getMandatory(raw, 'sl_ParametersAboveThres_r16'));
t.sl_ParametersBelowThres_r16 = buildPsschTxParameters(getMandatory(raw, 'sl_ParametersBelowThres_r16'));
end
function t = defaultPsschTxConfig()
t = buildPsschTxConfig(struct('sl_ThresUE_Speed_r16', 'kmph60', ...
    'sl_ParametersAboveThres_r16', defaultPsschTxParamsRaw(), 'sl_ParametersBelowThres_r16', defaultPsschTxParamsRaw()));
end
function r = defaultPsschTxParamsRaw()
r = struct('sl_MinMCS_PSSCH_r16', 0, 'sl_MaxMCS_PSSCH_r16', 0, 'sl_MinSubChannelNumPSSCH_r16', 1, ...
    'sl_MaxSubchannelNumPSSCH_r16', 1, 'sl_MaxTxTransNumPSSCH_r16', 1);
end

function p = buildPsschTxParameters(raw)
% SPEC: TS 38.331, SL-PSSCH-TxParameters-r16
p.sl_MinMCS_PSSCH_r16          = getMandatory(raw, 'sl_MinMCS_PSSCH_r16');            % INTEGER (0..27)
p.sl_MaxMCS_PSSCH_r16          = getMandatory(raw, 'sl_MaxMCS_PSSCH_r16');            % INTEGER (0..31)
p.sl_MinSubChannelNumPSSCH_r16 = getMandatory(raw, 'sl_MinSubChannelNumPSSCH_r16');   % INTEGER (1..27)
p.sl_MaxSubchannelNumPSSCH_r16 = getMandatory(raw, 'sl_MaxSubchannelNumPSSCH_r16');   % INTEGER (1..27)
p.sl_MaxTxTransNumPSSCH_r16    = getMandatory(raw, 'sl_MaxTxTransNumPSSCH_r16');      % INTEGER (1..32)
if isfield(raw, 'sl_MaxTxPower_r16')
    node = raw.sl_MaxTxPower_r16;
    caseTag = getMandatory(node, 'case');
    p.sl_MaxTxPower_r16_Present = true;
    p.sl_MaxTxPower_r16.case = caseTag;
    switch caseTag
        case 'minusinfinity-r16'
            p.sl_MaxTxPower_r16.txPower_r16 = 0;
        case 'txPower-r16'
            p.sl_MaxTxPower_r16.txPower_r16 = getMandatory(node, 'txPower_r16');   % INTEGER (-30..33)
        otherwise
            error('cfg:preconfig:badChoice', 'sl-MaxTxPower-r16: unknown case "%s"', caseTag);
    end
else
    p.sl_MaxTxPower_r16_Present = false;
    p.sl_MaxTxPower_r16 = struct('case', 'minusinfinity-r16', 'txPower_r16', 0);
end
end

function r = buildRohcProfiles(raw)
% SPEC: TS 38.331, SL-RoHC-Profiles-r16 (closed SEQUENCE, all 9 fields mandatory within it)
names = {'profile0x0001_r16', 'profile0x0002_r16', 'profile0x0003_r16', 'profile0x0004_r16', ...
         'profile0x0006_r16', 'profile0x0101_r16', 'profile0x0102_r16', 'profile0x0103_r16', 'profile0x0104_r16'};
for i = 1:numel(names)
    r.(names{i}) = getMandatoryOrFalse(raw, names{i});
end
end
function v = getMandatoryOrFalse(raw, key)
% SL-RoHC-Profiles-r16 fields are BOOLEAN mandatory-within-an-optional-container: when the
% container itself is present every one of the 9 must be given explicitly.
if isfield(raw, key)
    v = raw.(key);
else
    v = false;
end
end
function r = defaultRohcProfiles()
r = buildRohcProfiles(struct());
end
