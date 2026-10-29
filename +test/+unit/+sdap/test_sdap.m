function test_sdap()
%test_sdap SDAP: QoS-flow-to-SLRB mapping rules and the SDAP header.
%SPEC: TS 38.331 V16.22.0 SL-SDAP-Config-r16; TS 37.324 V19.0.0 clauses 5.2.3, 5.2.4, 6.2.1,
%      6.2.2.4 (Figure 6.2.2.4-1), 6.3.3, 6.3.8 -- both local.
%Level 1 only. The cross-package priority check (PQI -> SLRB -> logical channel -> SCI-1A) is in
%test_stack, because it needs every layer.

prof = @(pqi) struct('sl_PQI_r16_Present', true, 'sl_PQI_r16', pqi, 'sl_GFBR_r16_Present', false, ...
    'sl_GFBR_r16', 0, 'sl_MFBR_r16_Present', false, 'sl_MFBR_r16', 0, 'sl_Range_r16_Present', false, 'sl_Range_r16', 0);
rbOf = @(idx, hdr, dflt, pqis, cast) struct('slrb_Uu_ConfigIndex_r16', idx, 'sl_SDAP_Config_r16_Present', true, ...
    'sl_SDAP_Config_r16', struct('sl_SDAP_Header_r16', hdr, 'sl_DefaultRB_r16', dflt, ...
        'sl_MappedQoS_Flows_r16_Present', ~isempty(pqis), 'sl_MappedQoS_FlowsList_r16', arrayfun(prof, pqis), ...
        'sl_CastType_r16_Present', ~isempty(cast), 'sl_CastType_r16', cast), ...
    'sl_PDCP_Config_r16_Present', false, 'sl_PDCP_Config_r16', struct(), ...
    'sl_TransRange_r16_Present', false, 'sl_TransRange_r16', '');
% Broadcast SLRBs carry no SDAP header (37.324 6.2.1) and so cannot be default (38.331 ties the
% default to a header); the unicast SLRB is the default with a header.
rbs = [rbOf(1, 'absent', false, [58 59], 'broadcast'), ...
       rbOf(2, 'absent', false, [55 56], 'broadcast'), ...
       rbOf(3, 'present', true, 59, 'unicast')];
r = sdap.sdapRules(rbs);
assert(isequal(r.defaultRb, [0 0 3]) && isequal(r.headerPresent, [false false true]), 'defaults and headers per cast type');
assert(sdap.sdapTxMap(r, 56, 'broadcast') == 2, 'PQI 56 broadcast -> SLRB 2');
assert(sdap.castCode('broadcast') == 1 && sdap.castCode('groupcast') == 2 && sdap.castCode('unicast') == 3, 'castCode');
assert(sdap.sdapTxMap(r, 59, 'broadcast') == 1, 'PQI 59 broadcast -> SLRB 1 (rule, not default)');
assert(sdap.sdapTxMap(r, 59, 'unicast') == 3, 'the SAME PQI on unicast maps to the unicast bearer');
[rb, viaDefault] = sdap.sdapTxMap(r, 57, 'unicast');
assert(rb == 3 && viaDefault, 'an unmapped unicast PQI falls to the default SLRB (37.324 5.2.3)');
assert(sdap.sdapTxMap(r, 57, 'broadcast') == 0, 'an unmapped broadcast PQI has no default to fall to');
assert(sdap.sdapTxMap(r, 57, 'groupcast') == 0, 'no rule and no default: no bearer, not an invented one');
twoDefaults = rbs; twoDefaults(3).sl_SDAP_Config_r16.sl_CastType_r16 = 'broadcast';
twoDefaults(1).sl_SDAP_Config_r16.sl_DefaultRB_r16 = true;
try
    sdap.sdapRules(twoDefaults); error('test:noError', 'two defaults accepted');
catch e
    assert(strcmp(e.identifier, 'sdap:sdapRules:twoDefaults'), 'at most one sl-DefaultRB per destination');
end

% Header: D/C=1, R=0, PQFI (Figure 6.2.2.4-1).
assert(isequal(sdap.sdapPduPack(true, 5, [7 8]), [hex2dec('85') 7 8]), 'D/C|R|PQFI = 1|0|000101');
assert(isequal(sdap.sdapPduPack(true, 63, 1), [hex2dec('BF') 1]), 'PQFI 63 fills the field with R still 0');
assert(isequal(sdap.sdapPduPack(false, 5, [7 8]), [7 8]), 'no header: the SDU unchanged');
for q = 0:63
    [v, q2, s2] = sdap.sdapPduParse(sdap.sdapPduPack(true, q, 1:3), true);
    assert(v && q2 == q && isequal(s2, 1:3), 'QFI round trip %d', q);
end
assert(~sdap.sdapPduParse(hex2dec('05'), true), 'D/C = 0 is not a data PDU');
end
