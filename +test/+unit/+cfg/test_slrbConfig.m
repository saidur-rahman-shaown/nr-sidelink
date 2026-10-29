function test_slrbConfig()
%test_slrbConfig The sidelink radio-bearer part of the stored configuration.
%SPEC: TS 38.331 V16.22.0 sl-RadioBearerPreConfigList-r16, sl-RLC-BearerPreConfigList-r16 and their
%      IEs; BWP locationAndBandwidth (RIV, TS 38.214 5.1.2.2.2 with N = 275); SL-LogicalChannelConfig.
%Level 1: parse / save / reload round trip, validator rejections with clause-cited diagnostics.

path = '+cfg/configs/preconfig_example.json';
o = cfg.loadConfig(path, [58 56 23]);
rbs = o.preconfig.sl_RadioBearerPreConfigList_r16;
rl = o.preconfig.sl_RLC_BearerPreConfigList_r16;
assert(numel(rbs) == 3 && numel(rl) == 3, 'three SLRBs and three RLC bearers in the stored config');
assert(strcmp(rl(3).sl_RLC_Config_r16.case, 'sl-AM-RLC-r16') && strcmp(rl(1).sl_RLC_Config_r16.case, 'sl-UM-RLC-r16'), 'RLC modes');
assert(all(arrayfun(@(r) r.sl_PDCP_Config_r16.sl_OutOfOrderDelivery, rbs)), 'out-of-order delivery on every SLRB (no PDCP head-of-line hold)');

% Each SLRB's sl-DiscardTimer equals the PDB of the flows it carries, and its logical channel's
% sl-Priority equals their PQI priority level -- the stored config wires the PDB to PDCP discard
% (+pdcp/CLAUDE.md) and the PQI priority to LCP and SCI-1A (+sdap/CLAUDE.md).
pq = cfg.pqiTable();
for i = 1:3
    pc = pdcp.pdcpConfig(rbs(i).sl_PDCP_Config_r16, rbs(i).sl_SDAP_Config_r16.sl_CastType_r16, 0, 1);
    lch = mac.slLchConfig(rl([rl.sl_ServedRadioBearer_r16] == rbs(i).slrb_Uu_ConfigIndex_r16).sl_MAC_LogicalChannelConfig_r16);
    for f = rbs(i).sl_SDAP_Config_r16.sl_MappedQoS_FlowsList_r16
        row = cfg.pqiLookup(pq, f.sl_PQI_r16);
        assert(pc.discardTimerMs == row.PDB_ms, 'SLRB %d: discard %g ms vs PQI %d PDB %g ms', i, pc.discardTimerMs, f.sl_PQI_r16, row.PDB_ms);
        assert(lch.priority == row.priority, 'SLRB %d: sl-Priority %d vs PQI %d priority %d', i, lch.priority, f.sl_PQI_r16, row.priority);
    end
end

% Save and reload bit-identically (+cfg/CLAUDE.md interface rule).
tmp = [tempname '.json'];
cfg.saveConfig(o, tmp);
o2 = cfg.loadConfig(tmp, [58 56 23]);
delete(tmp);
assert(isequal(o2.preconfig, o.preconfig), 'the bearer lists survive save/reload unchanged');

% Validator: each broken variant is rejected with the field and the clause.
raw = jsondecode(fileread(path));
% Congestion-control mapping (check 19): a sl-Tx-ConfigIndexList entry beyond the PSSCH Tx configs.
expectReject(raw, @(r) setfield(r, 'preconfig', setCbrTxIndex(r.preconfig, 9)), ...
    'sl-Tx-ConfigIndexList-r16', 'a CBR mapping naming a PSSCH Tx config that does not exist');
% A GBR PQI on a broadcast SLRB: TS 23.287 Table 5.4.4-1 NOTE 1 makes GBR / DC-GBR unicast only.
expectReject(raw, @(r) setfield(r, 'preconfig', setMappedPqi(r.preconfig, 1, 23)), ...
    'sl-PQI-r16', 'a GBR PQI (23) mapped on a broadcast SLRB');
expectReject(raw, @(r) setfield(r, 'preconfig', setRlc(r.preconfig, 1, 'sl_ServedRadioBearer_r16', 9)), ...
    'sl-ServedRadioBearer-r16', 'an RLC bearer serving an SLRB that does not exist');
expectReject(raw, @(r) setfield(r, 'preconfig', setRlcUmSn(r.preconfig, 1, 'size12')), ...
    'sl-SN-FieldLengthUM-r16', 'a broadcast UM bearer with a 12-bit SN (TS 38.322 6.2.2.3)');
expectReject(raw, @(r) setfield(r, 'preconfig', setPdcpSn(r.preconfig, 1, 'len18bits')), ...
    'sl-PDCP-Config-r16', 'a broadcast SLRB with 18-bit PDCP SN (TS 38.323 6.3.2 NOTE)');
expectReject(raw, @(r) setfield(r, 'preconfig', setHeader(r.preconfig, 1, 'present')), ...
    'sl-SDAP-Header-r16', 'an SDAP header on a broadcast SLRB (TS 37.324 6.2.1)');
expectReject(raw, @(r) setfield(r, 'preconfig', setDefault(r.preconfig, 2, true)), ...
    'sl-SDAP-Header-r16', 'a broadcast default SLRB (a default needs a header, which gc/bc may not carry)');
expectReject(raw, @(r) setfield(r, 'preconfig', setLchLabel(r.preconfig, 1, 'kBps7')), ...
    'sl-MAC-LogicalChannelConfig-r16', 'a prioritised bit rate that is not in the enumeration');

% BWP RIV, TS 38.214 5.1.2.2.2 with N = 275.
[s, L] = cfg.bwpLocation(13475); assert(s == 0 && L == 50, 'RIV 13475 = 50 PRBs at 0');
[s, L] = cfg.bwpLocation(1099);  assert(s == 0 && L == 273, 'RIV 1099 = 273 PRBs at 0 (second branch)');
% Level 2 (independent-verifier): the surprising ends of the RIV space.
[s, L] = cfg.bwpLocation(37949); assert(s == 0 && L == 139, 'the largest RIV is NOT the widest BWP');
[s, L] = cfg.bwpLocation(37675); assert(s == 0 && L == 138, 'L-1 = 137 is still branch 1');
[s, L] = cfg.bwpLocation(549);   assert(s == 0 && L == 275, 'the full 275-PRB BWP encodes to 549');
[s, L] = cfg.bwpLocation(21164); assert(s == 10 && L == 200, '(10, 200) = 21164');
for start = [0 5 100 274]
    for len = [1 50 137 138 200 275]
        if start + len > 275, continue; end
        if len - 1 <= 137, riv = 275 * (len - 1) + start; else, riv = 275 * (275 - len + 1) + (275 - 1 - start); end
        [s, L] = cfg.bwpLocation(riv);
        assert(s == start && L == len, 'RIV round trip at start %d length %d', start, len);
    end
end

% Logical channel resolution.
lch = mac.slLchConfig(struct('sl_Priority_r16', 2, 'sl_PrioritisedBitRate_r16', 'infinity', ...
    'sl_BucketSizeDuration_r16', 'ms1000', 'sl_HARQ_FeedbackEnabled_r16_Present', true, 'sl_HARQ_FeedbackEnabled_r16', 'enabled'));
assert(lch.priority == 2 && isinf(lch.pbrBytesPerSec) && lch.bsdSec == 1 && lch.harqFeedbackEnabled, 'slLchConfig');
end

% =====================================================================================
function expectReject(raw, mutate, field, what)
r = mutate(raw);
p = cfg.preconfig(r.preconfig);
d = cfg.cfgValidate(p, cfg.pqiTable(), [58 56 23]);
assert(any(strcmp({d.field}, field)), 'validator must reject %s via field %s; got %s', what, field, strjoin({d.field}, ','));
k = find(strcmp({d.field}, field), 1);
assert(~isempty(d(k).clause), 'every diagnostic names its clause');
end
function p = setCbrTxIndex(p, v)
rp = p.sl_PreconfigFreqInfoList_r16(1).sl_BWP_List_r16(1).sl_BWP_PoolConfigCommon_r16.sl_TxPoolSelectedNormal_r16(1).sl_ResourcePool_r16.sl_UE_SelectedConfigRP_r16;
rp.sl_CBR_PriorityTxConfigList_r16(1).sl_Tx_ConfigIndexList_r16(end) = v;
p.sl_PreconfigFreqInfoList_r16(1).sl_BWP_List_r16(1).sl_BWP_PoolConfigCommon_r16.sl_TxPoolSelectedNormal_r16(1).sl_ResourcePool_r16.sl_UE_SelectedConfigRP_r16 = rp;
end
function p = setMappedPqi(p, i, pqi)
p.sl_RadioBearerPreConfigList_r16(i).sl_SDAP_Config_r16.sl_MappedQoS_FlowsList_r16(1).sl_PQI_r16.sl_StandardizedPQI_r16 = pqi;
end
function p = setRlc(p, i, f, v)
p.sl_RLC_BearerPreConfigList_r16(i).(f) = v;
end
function p = setRlcUmSn(p, i, v)
p.sl_RLC_BearerPreConfigList_r16(i).sl_RLC_Config_r16.sl_UM_RLC_r16.sl_SN_FieldLengthUM_r16 = v;
end
function p = setPdcpSn(p, i, v)
p.sl_RadioBearerPreConfigList_r16(i).sl_PDCP_Config_r16.sl_PDCP_SN_Size_r16 = v;
end
function p = setDefault(p, i, v)
p.sl_RadioBearerPreConfigList_r16(i).sl_SDAP_Config_r16.sl_DefaultRB_r16 = v;
end
function p = setHeader(p, i, v)
p.sl_RadioBearerPreConfigList_r16(i).sl_SDAP_Config_r16.sl_SDAP_Header_r16 = v;
end
function p = setLchLabel(p, i, v)
p.sl_RLC_BearerPreConfigList_r16(i).sl_MAC_LogicalChannelConfig_r16.sl_PrioritisedBitRate_r16 = v;
end
