function pairs = encodeSlrbPreconfig(s)
%encodeSlrbPreconfig Encode the two sidelink bearer lists back to JSON. Exact inverse of slrbPreconfig.
%Spec:   TS 38.331 V16.22.0, sl-RadioBearerPreConfigList-r16 / sl-RLC-BearerPreConfigList-r16
%        (see cfg.slrbPreconfig for every IE).
%Inputs: s  the preconfig struct from cfg.preconfig
%Outputs: pairs  1 x k cell of JSON "key": value texts, to append to the preconfig object (empty
%                when neither list is present). Cell arrays here are the jsonPair plumbing the
%                other private encoders use, not a function interface of the normative tree.

pairs = {};
if s.sl_RadioBearerPreConfigList_r16_Present
    rbs = s.sl_RadioBearerPreConfigList_r16;
    elems = cell(1, numel(rbs));
    for i = 1:numel(rbs)
        elems{i} = encodeRb(rbs(i));
    end
    pairs{end + 1} = jsonPair('sl-RadioBearerPreConfigList-r16', jsonJoinArr(elems));
end
if s.sl_RLC_BearerPreConfigList_r16_Present
    rl = s.sl_RLC_BearerPreConfigList_r16;
    elems = cell(1, numel(rl));
    for i = 1:numel(rl)
        elems{i} = encodeRlc(rl(i));
    end
    pairs{end + 1} = jsonPair('sl-RLC-BearerPreConfigList-r16', jsonJoinArr(elems));
end
end

function txt = encodeRb(rb)
p = {jsonPair('slrb-Uu-ConfigIndex-r16', jsonencode(rb.slrb_Uu_ConfigIndex_r16))};
if rb.sl_SDAP_Config_r16_Present
    sd = rb.sl_SDAP_Config_r16;
    q = {jsonPair('sl-SDAP-Header-r16', jsonencode(sd.sl_SDAP_Header_r16)), ...
         jsonPair('sl-DefaultRB-r16', jsonencode(logical(sd.sl_DefaultRB_r16)))};
    if sd.sl_MappedQoS_Flows_r16_Present
        prof = sd.sl_MappedQoS_FlowsList_r16;
        pe = cell(1, numel(prof));
        for k = 1:numel(prof)
            pe{k} = encodeProfile(prof(k));
        end
        q{end + 1} = jsonPair('sl-MappedQoS-FlowsList-r16', jsonJoinArr(pe));
    end
    if sd.sl_CastType_r16_Present
        q{end + 1} = jsonPair('sl-CastType-r16', jsonencode(sd.sl_CastType_r16));
    end
    p{end + 1} = jsonPair('sl-SDAP-Config-r16', jsonJoinObj(q));
end
if rb.sl_PDCP_Config_r16_Present
    pd = rb.sl_PDCP_Config_r16;
    q = {};
    if pd.sl_DiscardTimer_r16_Present, q{end + 1} = jsonPair('sl-DiscardTimer-r16', jsonencode(pd.sl_DiscardTimer_r16)); end
    if pd.sl_PDCP_SN_Size_r16_Present, q{end + 1} = jsonPair('sl-PDCP-SN-Size-r16', jsonencode(pd.sl_PDCP_SN_Size_r16)); end
    if pd.sl_OutOfOrderDelivery, q{end + 1} = jsonPair('sl-OutOfOrderDelivery', jsonencode('true')); end
    p{end + 1} = jsonPair('sl-PDCP-Config-r16', jsonJoinObj(q));
end
if rb.sl_TransRange_r16_Present
    p{end + 1} = jsonPair('sl-TransRange-r16', jsonencode(rb.sl_TransRange_r16));
end
txt = jsonJoinObj(p);
end

function txt = encodeProfile(pr)
q = {};
if pr.sl_PQI_r16_Present
    q{end + 1} = jsonPair('sl-PQI-r16', jsonJoinObj({jsonPair('sl-StandardizedPQI-r16', jsonencode(pr.sl_PQI_r16))}));
end
if pr.sl_GFBR_r16_Present, q{end + 1} = jsonPair('sl-GFBR-r16', jsonencode(pr.sl_GFBR_r16)); end
if pr.sl_MFBR_r16_Present, q{end + 1} = jsonPair('sl-MFBR-r16', jsonencode(pr.sl_MFBR_r16)); end
if pr.sl_Range_r16_Present, q{end + 1} = jsonPair('sl-Range-r16', jsonencode(pr.sl_Range_r16)); end
txt = jsonJoinObj(q);
end

function txt = encodeRlc(r)
p = {jsonPair('sl-RLC-BearerConfigIndex-r16', jsonencode(r.sl_RLC_BearerConfigIndex_r16))};
if r.sl_ServedRadioBearer_r16_Present
    p{end + 1} = jsonPair('sl-ServedRadioBearer-r16', jsonencode(r.sl_ServedRadioBearer_r16));
end
if r.sl_RLC_Config_r16_Present
    c = r.sl_RLC_Config_r16;
    switch c.case
        case 'sl-AM-RLC-r16'
            a = c.sl_AM_RLC_r16;
            f = fieldnames(a);
            q = {};
            for k = 1:numel(f)
                if ~isempty(a.(f{k}))
                    q{end + 1} = jsonPair(strrep(f{k}, '_', '-'), jsonencode(a.(f{k}))); %#ok<AGROW>
                end
            end
            arm = jsonPair('sl-AM-RLC-r16', jsonJoinObj(q));
        case 'sl-UM-RLC-r16'
            q = {};
            if ~isempty(c.sl_UM_RLC_r16.sl_SN_FieldLengthUM_r16)
                q{end + 1} = jsonPair('sl-SN-FieldLengthUM-r16', jsonencode(c.sl_UM_RLC_r16.sl_SN_FieldLengthUM_r16));
            end
            arm = jsonPair('sl-UM-RLC-r16', jsonJoinObj(q));
    end
    p{end + 1} = jsonPair('sl-RLC-Config-r16', jsonJoinObj({jsonPair('case', jsonencode(c.case)), arm}));
end
if r.sl_MAC_LogicalChannelConfig_r16_Present
    l = r.sl_MAC_LogicalChannelConfig_r16;
    q = {jsonPair('sl-Priority-r16', jsonencode(l.sl_Priority_r16)), ...
         jsonPair('sl-PrioritisedBitRate-r16', jsonencode(l.sl_PrioritisedBitRate_r16)), ...
         jsonPair('sl-BucketSizeDuration-r16', jsonencode(l.sl_BucketSizeDuration_r16))};
    if l.sl_HARQ_FeedbackEnabled_r16_Present
        q{end + 1} = jsonPair('sl-HARQ-FeedbackEnabled-r16', jsonencode(l.sl_HARQ_FeedbackEnabled_r16));
    end
    p{end + 1} = jsonPair('sl-MAC-LogicalChannelConfig-r16', jsonJoinObj(q));
end
txt = jsonJoinObj(p);
end
