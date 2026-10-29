function rules = sdapRules(rbList)
%sdapRules Build the QoS-flow-to-SLRB mapping rules from the configured sidelink radio bearers.
%Spec:   TS 38.331 V16.22.0, SL-SDAP-Config-r16 and its field descriptions:
%          sl-MappedQoS-FlowsList: "Indicates the list of QoS profiles of the NR sidelink
%            communication transmission destination mapped to this sidelink DRB."
%          sl-DefaultRB: "Indicates whether or not this is the default sidelink DRB for this NR
%            sidelink communication transmission destination. Among all configured instances of
%            SL-SDAP-Config for this destination, this field shall be set to true in at most one
%            instance of SL-SDAP-Config and to false in all other instances."
%          sl-SDAP-Header: "Indicates whether or not a SDAP header is present on this sidelink
%            DRB. ... This field is set to present if the field sl-DefaultRB is set to true."
%          sl-CastType-r16 ENUMERATED {broadcast, groupcast, unicast, spare1} OPTIONAL.
%        TS 37.324 V19.0.0 clauses 5.2.3 / 5.5 are where the rules are APPLIED -- see sdap.sdapTxMap.
%Inputs: rbList  1 x nRb struct array, +cfg/slrbPreconfig's sl_RadioBearerPreConfigList_r16
%Outputs: rules  scalar struct of flat arrays:
%            .pqi            1 x K integer -- standardized PQI of each mapped QoS profile
%            .rb             1 x K integer -- index into rbList of the SLRB it maps to
%            .cast           1 x K integer -- cast-type code of that SLRB: 0 = any (sl-CastType
%                            absent), 1 broadcast, 2 groupcast, 3 unicast
%            .defaultRb      1 x 3 integer -- per cast code 1..3, index of the default SLRB
%                            usable for that cast type, 0 if none
%            .headerPresent  1 x nRb logical -- sl-SDAP-Header per SLRB
%            .rbCast         1 x nRb integer -- cast code per SLRB
%            .rbIndex        1 x nRb integer -- slrb-Uu-ConfigIndex-r16 per SLRB
%
%A QoS profile identifies a flow by its PQI here because preconfiguration carries
%sl-MappedQoS-FlowsList (profiles), not the PFI list dedicated signalling uses. Matching on the
%PQI is the only key the profile offers when GFBR/MFBR/range are absent, as they are for the
%non-GBR V2X flows this tree carries. A non-standardized PQI is rejected by +cfg before here.

CAST_ANY = 0;
N_CAST = 3;
nRb = numel(rbList);
rules = struct('pqi', zeros(1, 0), 'rb', zeros(1, 0), 'cast', zeros(1, 0), ...
    'defaultRb', zeros(1, N_CAST), 'headerPresent', false(1, nRb), ...
    'rbCast', zeros(1, nRb), 'rbIndex', zeros(1, nRb));
for i = 1:nRb
    rb = rbList(i);
    rules.rbIndex(i) = rb.slrb_Uu_ConfigIndex_r16;
    if ~rb.sl_SDAP_Config_r16_Present
        continue;                      % an SLRB with no SDAP config carries no mapped flow
    end
    s = rb.sl_SDAP_Config_r16;
    rules.headerPresent(i) = strcmp(s.sl_SDAP_Header_r16, 'present');
    cast = CAST_ANY;
    if s.sl_CastType_r16_Present
        cast = sdap.castCode(s.sl_CastType_r16);
    end
    rules.rbCast(i) = cast;
    if s.sl_MappedQoS_Flows_r16_Present
        for q = 1:numel(s.sl_MappedQoS_FlowsList_r16)
            prof = s.sl_MappedQoS_FlowsList_r16(q);
            if prof.sl_PQI_r16_Present
                rules.pqi(end + 1) = prof.sl_PQI_r16;
                rules.rb(end + 1) = i;
                rules.cast(end + 1) = cast;
            end
        end
    end
    if s.sl_DefaultRB_r16
        if cast == CAST_ANY
            targets = 1:N_CAST;
        else
            targets = cast;
        end
        for c = targets
            if rules.defaultRb(c) ~= 0
                error('sdap:sdapRules:twoDefaults', ['sdapRules: more than one sl-DefaultRB for cast type %d ' ...
                    '(38.331: "set to true in at most one instance")'], c);
            end
            rules.defaultRb(c) = i;
        end
    end
end
end
