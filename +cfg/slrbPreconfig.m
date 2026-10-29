function [rbList, rbPresent, rlcList, rlcPresent] = slrbPreconfig(raw)
%slrbPreconfig Build sl-RadioBearerPreConfigList-r16 and sl-RLC-BearerPreConfigList-r16.
%Spec:   TS 38.331 V16.22.0, SidelinkPreconfigNR-r16 fields sl-RadioBearerPreConfigList-r16
%        (SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SL-RadioBearerConfig-r16) and
%        sl-RLC-BearerPreConfigList-r16 (SEQUENCE (SIZE (1..maxSL-LCID-r16)) OF
%        SL-RLC-BearerConfig-r16); the IEs SL-RadioBearerConfig-r16, SL-SDAP-Config-r16,
%        SL-QoS-Profile-r16, SL-PQI-r16, SL-PDCP-Config-r16, SL-RLC-BearerConfig-r16,
%        SL-RLC-Config-r16 and SL-LogicalChannelConfig-r16.
%Inputs: raw  the decoded "preconfig" JSON object (hyphens already underscores)
%Outputs: rbList      1 x nRb struct array -- SL-RadioBearerConfig-r16, leaf for leaf:
%            .slrb_Uu_ConfigIndex_r16          integer, 1..512
%            .sl_SDAP_Config_r16_Present / .sl_SDAP_Config_r16
%                .sl_SDAP_Header_r16           'present' | 'absent'
%                .sl_DefaultRB_r16             logical
%                .sl_MappedQoS_Flows_r16_Present
%                .sl_MappedQoS_FlowsList_r16   1 x q struct array of SL-QoS-Profile-r16:
%                    .sl_PQI_r16_Present, .sl_PQI_r16 (sl-StandardizedPQI-r16, 0..255),
%                    .sl_GFBR_r16(_Present), .sl_MFBR_r16(_Present), .sl_Range_r16(_Present)
%                .sl_CastType_r16_Present / .sl_CastType_r16   label
%            .sl_PDCP_Config_r16_Present / .sl_PDCP_Config_r16
%                .sl_DiscardTimer_r16_Present / .sl_DiscardTimer_r16   label
%                .sl_PDCP_SN_Size_r16_Present / .sl_PDCP_SN_Size_r16   label
%                .sl_OutOfOrderDelivery         logical (ENUMERATED {true} present)
%            .sl_TransRange_r16_Present / .sl_TransRange_r16   label
%          rbPresent   logical -- the list was in the JSON
%          rlcList     1 x nRlc struct array -- SL-RLC-BearerConfig-r16:
%            .sl_RLC_BearerConfigIndex_r16     integer, 1..512
%            .sl_ServedRadioBearer_r16_Present / .sl_ServedRadioBearer_r16   slrb-Uu-ConfigIndex
%            .sl_RLC_Config_r16_Present / .sl_RLC_Config_r16
%                .case            'sl-AM-RLC-r16' | 'sl-UM-RLC-r16'
%                .sl_AM_RLC_r16   leaf of labels (rlc.amConfig's input shape)
%                .sl_UM_RLC_r16   leaf of labels (rlc.umConfig's input shape)
%            .sl_MAC_LogicalChannelConfig_r16_Present / .sl_MAC_LogicalChannelConfig_r16
%                .sl_Priority_r16, .sl_PrioritisedBitRate_r16, .sl_BucketSizeDuration_r16,
%                .sl_HARQ_FeedbackEnabled_r16_Present, .sl_HARQ_FeedbackEnabled_r16
%          rlcPresent  logical
%
%ENUMERATED LEAVES ARE KEPT AS THEIR ASN.1 LABELS HERE, ON PURPOSE
%-----------------------------------------------------------------
%Every other +cfg builder resolves labels to numbers through resolveEnum. These do not, because
%each has exactly one consumer that already owns the resolution table for its own layer:
%rlc.umConfig / rlc.amConfig, pdcp.pdcpConfig, mac.slLchConfig. Resolving here as well would put
%a second copy of each table in the tree, and two tables drift. Labels are still validated --
%cfgValidate runs every leaf through its owner's resolver and reports the clause on failure.
%
%A non-standardized PQI (sl-Non-StandardizedPQI-r16) is rejected rather than half-parsed:
%nothing downstream could act on its fields, and silently ignoring one would lose a mapping.

MAX_SLRB = 512;        % maxNrofSLRB-r16
MAX_SL_LCID = 512;     % maxSL-LCID-r16

items = getOptList(raw, 'sl_RadioBearerPreConfigList_r16');
rbPresent = ~isempty(items);
if numel(items) > MAX_SLRB
    error('cfg:slrbPreconfig:badSize', 'sl-RadioBearerPreConfigList-r16: SIZE(1..%d), got %d', MAX_SLRB, numel(items));
end
rbList = repmat(buildRb(struct('slrb_Uu_ConfigIndex_r16', 1)), 1, numel(items));
for i = 1:numel(items)
    rbList(i) = buildRb(items{i});
end

items = getOptList(raw, 'sl_RLC_BearerPreConfigList_r16');
rlcPresent = ~isempty(items);
if numel(items) > MAX_SL_LCID
    error('cfg:slrbPreconfig:badSize', 'sl-RLC-BearerPreConfigList-r16: SIZE(1..%d), got %d', MAX_SL_LCID, numel(items));
end
rlcList = repmat(buildRlc(struct('sl_RLC_BearerConfigIndex_r16', 1)), 1, numel(items));
for i = 1:numel(items)
    rlcList(i) = buildRlc(items{i});
end
end

% ======================================================================
function rb = buildRb(raw)
rb.slrb_Uu_ConfigIndex_r16 = getMandatory(raw, 'slrb_Uu_ConfigIndex_r16');
[sRaw, rb.sl_SDAP_Config_r16_Present] = getOptional(raw, 'sl_SDAP_Config_r16', struct());
rb.sl_SDAP_Config_r16 = buildSdap(sRaw, rb.sl_SDAP_Config_r16_Present);
[pRaw, rb.sl_PDCP_Config_r16_Present] = getOptional(raw, 'sl_PDCP_Config_r16', struct());
rb.sl_PDCP_Config_r16 = buildPdcp(pRaw);
[rb.sl_TransRange_r16, rb.sl_TransRange_r16_Present] = getOptional(raw, 'sl_TransRange_r16', '');
end

function s = buildSdap(raw, present)
if present
    s.sl_SDAP_Header_r16 = getMandatory(raw, 'sl_SDAP_Header_r16');
    s.sl_DefaultRB_r16 = logical(getMandatory(raw, 'sl_DefaultRB_r16'));
else
    s.sl_SDAP_Header_r16 = 'absent';
    s.sl_DefaultRB_r16 = false;
end
if ~any(strcmp(s.sl_SDAP_Header_r16, {'present', 'absent'}))
    error('cfg:slrbPreconfig:badLabel', 'sl-SDAP-Header-r16: unknown label "%s"', s.sl_SDAP_Header_r16);
end
% sl-MappedQoS-Flows-r16 is a CHOICE; preconfiguration uses the sl-MappedQoS-FlowsList-r16 arm.
flows = getOptList(raw, 'sl_MappedQoS_FlowsList_r16');
s.sl_MappedQoS_Flows_r16_Present = ~isempty(flows);
s.sl_MappedQoS_FlowsList_r16 = repmat(buildProfile(struct()), 1, numel(flows));
for q = 1:numel(flows)
    s.sl_MappedQoS_FlowsList_r16(q) = buildProfile(flows{q});
end
[s.sl_CastType_r16, s.sl_CastType_r16_Present] = getOptional(raw, 'sl_CastType_r16', '');
if s.sl_CastType_r16_Present && ~any(strcmp(s.sl_CastType_r16, {'broadcast', 'groupcast', 'unicast'}))
    error('cfg:slrbPreconfig:badLabel', 'sl-CastType-r16: unknown label "%s"', s.sl_CastType_r16);
end
end

function p = buildProfile(raw)
p.sl_PQI_r16_Present = isfield(raw, 'sl_PQI_r16');
p.sl_PQI_r16 = 0;
if p.sl_PQI_r16_Present
    pqi = raw.sl_PQI_r16;
    if isfield(pqi, 'sl_StandardizedPQI_r16')
        p.sl_PQI_r16 = pqi.sl_StandardizedPQI_r16;      % INTEGER (0..255)
    else
        error('cfg:slrbPreconfig:nonStandardPqi', 'SL-PQI-r16: only sl-StandardizedPQI-r16 is supported');
    end
end
[p.sl_GFBR_r16, p.sl_GFBR_r16_Present] = getOptional(raw, 'sl_GFBR_r16', 0);
[p.sl_MFBR_r16, p.sl_MFBR_r16_Present] = getOptional(raw, 'sl_MFBR_r16', 0);
[p.sl_Range_r16, p.sl_Range_r16_Present] = getOptional(raw, 'sl_Range_r16', 0);
end

function p = buildPdcp(raw)
[p.sl_DiscardTimer_r16, p.sl_DiscardTimer_r16_Present] = getOptional(raw, 'sl_DiscardTimer_r16', '');
[p.sl_PDCP_SN_Size_r16, p.sl_PDCP_SN_Size_r16_Present] = getOptional(raw, 'sl_PDCP_SN_Size_r16', '');
p.sl_OutOfOrderDelivery = isfield(raw, 'sl_OutOfOrderDelivery');
end

function r = buildRlc(raw)
r.sl_RLC_BearerConfigIndex_r16 = getMandatory(raw, 'sl_RLC_BearerConfigIndex_r16');
[r.sl_ServedRadioBearer_r16, r.sl_ServedRadioBearer_r16_Present] = getOptional(raw, 'sl_ServedRadioBearer_r16', 0);
[cRaw, r.sl_RLC_Config_r16_Present] = getOptional(raw, 'sl_RLC_Config_r16', struct());
r.sl_RLC_Config_r16 = buildRlcConfig(cRaw, r.sl_RLC_Config_r16_Present);
[lRaw, r.sl_MAC_LogicalChannelConfig_r16_Present] = getOptional(raw, 'sl_MAC_LogicalChannelConfig_r16', struct());
r.sl_MAC_LogicalChannelConfig_r16 = buildLch(lRaw, r.sl_MAC_LogicalChannelConfig_r16_Present);
end

function c = buildRlcConfig(raw, present)
emptyAm = struct('sl_SN_FieldLengthAM_r16', '', 'sl_T_PollRetransmit_r16', '', ...
    'sl_PollPDU_r16', '', 'sl_PollByte_r16', '', 'sl_MaxRetxThreshold_r16', '');
emptyUm = struct('sl_SN_FieldLengthUM_r16', '');
c = struct('case', '', 'sl_AM_RLC_r16', emptyAm, 'sl_UM_RLC_r16', emptyUm);
if ~present
    return;
end
c.case = getMandatory(raw, 'case');
switch c.case
    case 'sl-AM-RLC-r16'
        a = getMandatory(raw, 'sl_AM_RLC_r16');
        f = fieldnames(emptyAm);
        for k = 1:numel(f)
            c.sl_AM_RLC_r16.(f{k}) = getOptional(a, f{k}, '');
        end
    case 'sl-UM-RLC-r16'
        u = getMandatory(raw, 'sl_UM_RLC_r16');
        c.sl_UM_RLC_r16.sl_SN_FieldLengthUM_r16 = getOptional(u, 'sl_SN_FieldLengthUM_r16', '');
    otherwise
        error('cfg:slrbPreconfig:badChoice', 'SL-RLC-Config-r16: unknown CHOICE "%s"', c.case);
end
end

function l = buildLch(raw, present)
l = struct('sl_Priority_r16', 0, 'sl_PrioritisedBitRate_r16', '', 'sl_BucketSizeDuration_r16', '', ...
    'sl_HARQ_FeedbackEnabled_r16_Present', false, 'sl_HARQ_FeedbackEnabled_r16', '');
if ~present
    return;
end
l.sl_Priority_r16 = getMandatory(raw, 'sl_Priority_r16');
l.sl_PrioritisedBitRate_r16 = getMandatory(raw, 'sl_PrioritisedBitRate_r16');
l.sl_BucketSizeDuration_r16 = getMandatory(raw, 'sl_BucketSizeDuration_r16');
[l.sl_HARQ_FeedbackEnabled_r16, l.sl_HARQ_FeedbackEnabled_r16_Present] = getOptional(raw, 'sl_HARQ_FeedbackEnabled_r16', '');
end
