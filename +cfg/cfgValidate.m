function diagnostics = cfgValidate(preconfig, pqiTbl, configuredPQIs)
%cfgValidate Cross-field consistency checks over a resolved preconfig tree, clause-cited.
%Spec:   TS 38.331 clause 6.3.5 (field-level constraints); TS 38.211/38.213 (slot/PSFCH timing
%        sanity bounds, see per-check notes below for the fidelity of each). Implements the
%        checklist from +cfg/CLAUDE.md "Validator check list (minimum)".
%Inputs: preconfig       scalar struct from cfg.preconfig()
%        pqiTbl          1xN struct array from cfg.pqiTable()
%        configuredPQIs  row vector of PQI values actually used by this deployment (optional,
%                        default empty; checks 10 and 17)
%Outputs: diagnostics  1xN struct array, empty iff the config is valid. Fields: path (where in
%                      the tree), field (the ASN.1 identifier), clause (spec clause violated),
%                      message (human-readable). Every non-empty result names both field and
%                      clause, per +cfg/CLAUDE.md ("every failure names the clause it
%                      violates").
%
%Checks 11-17 cover sl-RadioBearerPreConfigList-r16 / sl-RLC-BearerPreConfigList-r16 (served SLRB
%exists, one logical channel per SLRB, every leaf resolves through its owning layer's resolver,
%default SLRBs, mapped PQIs, gc/bc UM 6-bit and PDCP 12-bit, every configured PQI maps somewhere);
%check 18 decodes the BWP RIV (cfg.bwpLocation) and requires it inside the carrier. Checks 13
%and 17 call +rlc/+pdcp/+mac/+sdap resolvers: those layers own the enumeration tables, and a
%second copy here would drift (see cfg.slrbPreconfig).
%
%Checks 4 and 5 (selection-window and RSRP-threshold coverage) are structurally guaranteed
%whenever those lists are present at all, since both are ASN.1 SIZE(8)/SIZE(64) FIXED
%sequences -- resourcePool.m already rejects a present list of the wrong length. What remains
%checkable here is *presence when the pool is in UE-selected (sensing) mode*.
if nargin < 3, configuredPQIs = zeros(1, 0); end
diagnostics = repmat(emptyDiag(), 1, 0);

for fi = 1:numel(preconfig.sl_PreconfigFreqInfoList_r16)
    freqCfg = preconfig.sl_PreconfigFreqInfoList_r16(fi);
    if ~freqCfg.sl_BWP_List_r16_Present, continue; end
    for bi = 1:numel(freqCfg.sl_BWP_List_r16)
        bwp = freqCfg.sl_BWP_List_r16(bi);
        base = sprintf('freq(%d).bwp(%d)', fi, bi);

        % Check 9: both numerologies present and resolvable for this (freq, bwp) pair.
        try
            cfg.bootFromPreconfig(preconfig, fi, bi);
        catch e
            diagnostics(end+1) = addDiag(base, 'numerology', 'TS 38.331 cl. 6.3.5', e.message); %#ok<AGROW>
        end

        % Check 18: the BWP lies inside the carrier of its own subcarrier spacing. The RIV is
        % decoded with N_BWP^size = 275 (38.331 locationAndBandwidth), so nothing in the field
        % itself bounds it by the carrier; 38.331 SCS-SpecificCarrier bounds the carrier.
        if bwp.sl_BWP_Generic_r16.sl_BWP_r16_Present
            g = bwp.sl_BWP_Generic_r16.sl_BWP_r16;
            try
                [rbStart, nRb] = cfg.bwpLocation(g.locationAndBandwidth);
                carriers = freqCfg.sl_SCS_SpecificCarrierList_r16;
                c = carriers([carriers.subcarrierSpacing] == g.subcarrierSpacing);
                if isempty(c)
                    diagnostics(end+1) = addDiag(base, 'subcarrierSpacing', 'TS 38.331 cl. 6.3.2, BWP', ...
                        'no sl-SCS-SpecificCarrier exists for the BWP subcarrier spacing'); %#ok<AGROW>
                elseif rbStart + nRb > c(1).carrierBandwidth
                    diagnostics(end+1) = addDiag(base, 'locationAndBandwidth', 'TS 38.331 cl. 6.3.2, BWP / TS 38.214 cl. 5.1.2.2.2', ...
                        sprintf('BWP PRBs %d..%d exceed the %d-PRB carrier', rbStart, rbStart + nRb - 1, c(1).carrierBandwidth)); %#ok<AGROW>
                end
            catch e
                diagnostics(end+1) = addDiag(base, 'locationAndBandwidth', 'TS 38.214 cl. 5.1.2.2.2', e.message); %#ok<AGROW>
            end
        end

        if ~bwp.sl_BWP_PoolConfigCommon_r16_Present, continue; end
        pcc = bwp.sl_BWP_PoolConfigCommon_r16;

        if pcc.sl_RxPool_r16_Present
            for pi = 1:numel(pcc.sl_RxPool_r16)
                diagnostics = [diagnostics, validatePool(pcc.sl_RxPool_r16(pi), ...
                    sprintf('%s.rxPool(%d)', base, pi))]; %#ok<AGROW>
            end
        end
        if pcc.sl_TxPoolSelectedNormal_r16_Present
            for pi = 1:numel(pcc.sl_TxPoolSelectedNormal_r16)
                entry = pcc.sl_TxPoolSelectedNormal_r16(pi);
                if entry.sl_ResourcePool_r16_Present
                    diagnostics = [diagnostics, validatePool(entry.sl_ResourcePool_r16, ...
                        sprintf('%s.txPoolNormal(%d)', base, pi))]; %#ok<AGROW>
                    diagnostics = [diagnostics, validateCbrMapping(entry.sl_ResourcePool_r16, preconfig, ...
                        sprintf('%s.txPoolNormal(%d)', base, pi))]; %#ok<AGROW>
                end
            end
        end
        if pcc.sl_TxPoolExceptional_r16_Present && pcc.sl_TxPoolExceptional_r16.sl_ResourcePool_r16_Present
            diagnostics = [diagnostics, validatePool(pcc.sl_TxPoolExceptional_r16.sl_ResourcePool_r16, ...
                sprintf('%s.txPoolExceptional', base))]; %#ok<AGROW>
        end
    end
end

% Check 10: every configured PQI exists in the table.
for i = 1:numel(configuredPQIs)
    try
        cfg.pqiLookup(pqiTbl, configuredPQIs(i));
    catch e
        diagnostics(end+1) = addDiag('configuredPQIs', 'PQI', 'TS 23.287 cl. 5.4.4', e.message); %#ok<AGROW>
    end
end

% Checks 11-17: the sidelink radio bearer and RLC bearer lists.
if isfield(preconfig, 'sl_RadioBearerPreConfigList_r16')
    diagnostics = [diagnostics, validateSlrb(preconfig, pqiTbl, configuredPQIs)];
end
end

% ======================================================================
function diagnostics = validateSlrb(preconfig, pqiTbl, configuredPQIs)
%validateSlrb Consistency of sl-RadioBearerPreConfigList-r16 / sl-RLC-BearerPreConfigList-r16.
%Each enumerated leaf is resolved by the layer that owns its table (rlc.umConfig/amConfig,
%pdcp.pdcpConfig, mac.slLchConfig), so a label those reject is reported here, with the clause.
GC_BC_UM_SN = 6;              % TS 38.322 6.2.2.3: "only 6 bit SN length is configured"
PROBE_TIMER = 'ms0';          % any legal T-Reassembly/T-StatusProhibit label: these are the
                              % RECEIVING UE's choices (38.331 9.1.1.4), not config, so the leaf
                              % is resolved with a placeholder only to validate its own labels
PROBE_T_REORDERING_MS = 0;    % likewise for PDCP t-Reordering (TS 38.323 7.3)
PROBE_SDU_TYPE = 1;           % Non-IP, TS 38.323 Table 6.3.12-1
diagnostics = repmat(emptyDiag(), 1, 0);
rbs = preconfig.sl_RadioBearerPreConfigList_r16;
rlcs = preconfig.sl_RLC_BearerPreConfigList_r16;
rbIdx = zeros(1, numel(rbs));
for i = 1:numel(rbs), rbIdx(i) = rbs(i).slrb_Uu_ConfigIndex_r16; end
served = zeros(1, 0);

for j = 1:numel(rlcs)
    r = rlcs(j);
    path = sprintf('rlcBearer(%d)', j);
    % Check 11: the served SLRB exists.
    if ~r.sl_ServedRadioBearer_r16_Present || ~any(rbIdx == r.sl_ServedRadioBearer_r16)
        diagnostics(end+1) = addDiag(path, 'sl-ServedRadioBearer-r16', 'TS 38.331 cl. 6.3.5, SL-RLC-BearerConfig-r16', ...
            'the RLC bearer must name a configured slrb-Uu-ConfigIndex-r16'); %#ok<AGROW>
        continue;
    end
    served(end+1) = r.sl_ServedRadioBearer_r16; %#ok<AGROW>
    rb = rbs(rbIdx == r.sl_ServedRadioBearer_r16);
    castLbl = 'unicast';
    if rb.sl_SDAP_Config_r16_Present && rb.sl_SDAP_Config_r16.sl_CastType_r16_Present
        castLbl = rb.sl_SDAP_Config_r16.sl_CastType_r16;
    end
    isGcBc = ~strcmp(castLbl, 'unicast');
    % Check 13a: the RLC leaf resolves; check 16a: gc/bc is UM with a 6-bit SN.
    if ~r.sl_RLC_Config_r16_Present
        diagnostics(end+1) = addDiag(path, 'sl-RLC-Config-r16', 'TS 38.331 cl. 6.3.5 (Cond LCH-Setup)', 'missing'); %#ok<AGROW>
    else
        try
            switch r.sl_RLC_Config_r16.case
                case 'sl-UM-RLC-r16'
                    c = rlc.umConfig(r.sl_RLC_Config_r16.sl_UM_RLC_r16, PROBE_TIMER);
                    if isGcBc && c.snFieldLength ~= GC_BC_UM_SN
                        diagnostics(end+1) = addDiag(path, 'sl-SN-FieldLengthUM-r16', 'TS 38.322 cl. 6.2.2.3', ...
                            'groupcast/broadcast UM uses only the 6-bit SN'); %#ok<AGROW>
                    end
                case 'sl-AM-RLC-r16'
                    rlc.amConfig(r.sl_RLC_Config_r16.sl_AM_RLC_r16, PROBE_TIMER, PROBE_TIMER);
                    if isGcBc
                        diagnostics(end+1) = addDiag(path, 'sl-RLC-Config-r16', 'TS 38.322 cl. 4.2.1.2.1 NOTE', ...
                            'groupcast and broadcast support only uni-directional UM'); %#ok<AGROW>
                    end
            end
        catch e
            diagnostics(end+1) = addDiag(path, 'sl-RLC-Config-r16', 'TS 38.331 cl. 6.3.5, SL-RLC-Config-r16', e.message); %#ok<AGROW>
        end
    end
    % Check 13b: the logical channel leaf resolves.
    if ~r.sl_MAC_LogicalChannelConfig_r16_Present
        diagnostics(end+1) = addDiag(path, 'sl-MAC-LogicalChannelConfig-r16', 'TS 38.331 cl. 6.3.5 (Cond LCH-Setup)', 'missing'); %#ok<AGROW>
    else
        try
            mac.slLchConfig(r.sl_MAC_LogicalChannelConfig_r16);
        catch e
            diagnostics(end+1) = addDiag(path, 'sl-MAC-LogicalChannelConfig-r16', 'TS 38.331 cl. 6.3.5, SL-LogicalChannelConfig-r16', e.message); %#ok<AGROW>
        end
    end
end

for i = 1:numel(rbs)
    rb = rbs(i);
    path = sprintf('slrb(%d)', rbIdx(i));
    % Check 12: exactly one logical channel per SLRB.
    if nnz(served == rbIdx(i)) ~= 1
        diagnostics(end+1) = addDiag(path, 'sl-ServedRadioBearer-r16', 'TS 38.322 cl. 4.2.1', sprintf( ...
            'an SLRB is carried by exactly one RLC entity on one logical channel; %d RLC bearers serve it', nnz(served == rbIdx(i)))); %#ok<AGROW>
    end
    castLbl = 'unicast';
    if rb.sl_SDAP_Config_r16_Present && rb.sl_SDAP_Config_r16.sl_CastType_r16_Present
        castLbl = rb.sl_SDAP_Config_r16.sl_CastType_r16;
    end
    % Check 13c / 16b: the PDCP leaf resolves, and gc/bc uses the 12-bit SN.
    if rb.sl_PDCP_Config_r16_Present
        try
            pdcp.pdcpConfig(rb.sl_PDCP_Config_r16, castLbl, PROBE_T_REORDERING_MS, PROBE_SDU_TYPE);
        catch e
            diagnostics(end+1) = addDiag(path, 'sl-PDCP-Config-r16', 'TS 38.331 SL-PDCP-Config-r16 / TS 38.323 cl. 6.3.2', e.message); %#ok<AGROW>
        end
    end
    if rb.sl_SDAP_Config_r16_Present
        s = rb.sl_SDAP_Config_r16;
        % Check 16c: no SDAP header on groupcast/broadcast (TS 37.324 6.2.1). With check 14b this
        % also means a gc/bc SLRB cannot be a default SLRB: 38.331 ties sl-DefaultRB = true to a
        % header, which 37.324 forbids there.
        if s.sl_CastType_r16_Present && ~strcmp(s.sl_CastType_r16, 'unicast') && strcmp(s.sl_SDAP_Header_r16, 'present')
            diagnostics(end+1) = addDiag(path, 'sl-SDAP-Header-r16', 'TS 37.324 V19.0.0 cl. 6.2.1', ...
                'groupcast and broadcast support only SDAP data PDUs without SDAP header'); %#ok<AGROW>
        end
        % Check 14b: a default SLRB carries an SDAP header.
        if s.sl_DefaultRB_r16 && ~strcmp(s.sl_SDAP_Header_r16, 'present')
            diagnostics(end+1) = addDiag(path, 'sl-SDAP-Header-r16', 'TS 38.331 SL-SDAP-Config field descriptions', ...
                'set to present if sl-DefaultRB is set to true'); %#ok<AGROW>
        end
        % Check 15: every mapped PQI is in the table.
        for q = 1:numel(s.sl_MappedQoS_FlowsList_r16)
            if s.sl_MappedQoS_FlowsList_r16(q).sl_PQI_r16_Present
                try
                    row = cfg.pqiLookup(pqiTbl, s.sl_MappedQoS_FlowsList_r16(q).sl_PQI_r16);
                catch e
                    diagnostics(end+1) = addDiag(path, 'sl-PQI-r16', 'TS 23.287 cl. 5.4.4', e.message); %#ok<AGROW>
                    continue;
                end
                % Check 15b: GBR and DC-GBR PQIs can only be used for unicast (TS 23.287 Table
                % 5.4.4-1 NOTE 1), so a groupcast or broadcast SLRB may map only 55..59.
                if row.unicastOnly && s.sl_CastType_r16_Present && ~strcmp(s.sl_CastType_r16, 'unicast')
                    diagnostics(end+1) = addDiag(path, 'sl-PQI-r16', 'TS 23.287 V19.0.0 Table 5.4.4-1 NOTE 1', ...
                        sprintf('PQI %d is %s and can only be used for unicast PC5 communications', row.PQI, row.resourceType)); %#ok<AGROW>
                end
            end
        end
    end
end

% Check 14a: at most one default SLRB per cast type.
try
    rules = sdap.sdapRules(rbs);
catch e
    diagnostics(end+1) = addDiag('slrb', 'sl-DefaultRB-r16', 'TS 38.331 SL-SDAP-Config field descriptions', e.message);
    return;
end
% Check 17: every PQI the deployment uses maps to an SLRB for at least one cast type -- the
% mapping is total, so no flow falls through to "no bearer" at runtime (+sdap/CLAUDE.md).
for i = 1:numel(configuredPQIs)
    mapped = false;
    for c = {'broadcast', 'groupcast', 'unicast'}
        mapped = mapped || sdap.sdapTxMap(rules, configuredPQIs(i), c{1}) > 0;
    end
    if ~mapped
        diagnostics(end+1) = addDiag('configuredPQIs', 'sl-MappedQoS-FlowsList-r16', 'TS 38.331 V16.22.0 cl. 5.8.9.1a.2 / TS 37.324 V19.0.0 cl. 5.2.3', ...
            sprintf('PQI %d maps to no sidelink radio bearer and no default exists', configuredPQIs(i))); %#ok<AGROW>
    end
end
end

% ======================================================================
% Local helpers. Not callable outside this file.
% ======================================================================

function d = emptyDiag()
d = struct('path', '', 'field', '', 'clause', '', 'message', '');
end

function diagnostics = validateCbrMapping(pool, preconfig, path)
% Check 19: the pool's SL-CBR-PriorityTxConfigList-r16 indexes into sl-UE-SelectedPreConfig's
% SL-CBR-CommonTxConfigList-r16 consistently (TS 38.331 field descriptions): priority thresholds
% ascend; sl-CBR-ConfigIndex names an existing CBR range set; sl-Tx-ConfigIndexList has one entry
% per CBR range of that set, each an existing sl-CBR-PSSCH-TxConfigList entry; the default index
% is an entry of sl-Tx-ConfigIndexList. A broken index here would make congestion control read a
% limit that does not exist.
CLAUSE = 'TS 38.331 V16.22.0 SL-CBR-PriorityTxConfigList / SL-CBR-CommonTxConfigList field descriptions';
diagnostics = repmat(addDiag('', '', '', ''), 1, 0);
rp = pool.sl_UE_SelectedConfigRP_r16;
if ~rp.sl_CBR_PriorityTxConfigList_r16_Present
    return;
end
sel = preconfig.sl_UE_SelectedPreConfig_r16;
if ~sel.sl_CBR_CommonTxConfigList_r16_Present
    diagnostics(end+1) = addDiag(path, 'sl-CBR-PriorityTxConfigList-r16', CLAUSE, ...
        'the pool maps priorities to CBR configurations but sl-CBR-CommonTxConfigList-r16 is absent');
    return;
end
cc = sel.sl_CBR_CommonTxConfigList_r16;
nRange = numel(cc.sl_CBR_RangeConfigList_r16);
nTx = numel(cc.sl_CBR_PSSCH_TxConfigList_r16);
e = rp.sl_CBR_PriorityTxConfigList_r16;
th = [e.sl_PriorityThreshold_r16];
if any(diff(th) <= 0)
    diagnostics(end+1) = addDiag(path, 'sl-PriorityThreshold-r16', CLAUSE, 'priority thresholds must ascend over the entries');
end
for i = 1:numel(e)
    if e(i).sl_CBR_ConfigIndex_r16 + 1 > nRange
        diagnostics(end+1) = addDiag(path, 'sl-CBR-ConfigIndex-r16', CLAUSE, ...
            sprintf('entry %d names CBR range set %d of %d', i, e(i).sl_CBR_ConfigIndex_r16, nRange)); %#ok<AGROW>
        continue;
    end
    nLev = numel(cc.sl_CBR_RangeConfigList_r16(e(i).sl_CBR_ConfigIndex_r16 + 1).sl_CBR_LevelsConfig_r16);
    if numel(e(i).sl_Tx_ConfigIndexList_r16) ~= nLev
        diagnostics(end+1) = addDiag(path, 'sl-Tx-ConfigIndexList-r16', CLAUSE, ...
            sprintf('entry %d has %d indices for %d CBR ranges', i, numel(e(i).sl_Tx_ConfigIndexList_r16), nLev)); %#ok<AGROW>
    end
    if any(e(i).sl_Tx_ConfigIndexList_r16 + 1 > nTx)
        diagnostics(end+1) = addDiag(path, 'sl-Tx-ConfigIndexList-r16', CLAUSE, ...
            sprintf('entry %d names a PSSCH Tx config beyond the %d configured', i, nTx)); %#ok<AGROW>
    end
    if e(i).sl_DefaultTxConfigIndex_r16 + 1 > numel(e(i).sl_Tx_ConfigIndexList_r16)
        diagnostics(end+1) = addDiag(path, 'sl-DefaultTxConfigIndex-r16', CLAUSE, ...
            sprintf('entry %d default index %d is not an entry of sl-Tx-ConfigIndexList', i, e(i).sl_DefaultTxConfigIndex_r16)); %#ok<AGROW>
    end
end
end

function d = addDiag(path, field, clause, message)
d.path = path; d.field = field; d.clause = clause; d.message = message;
end

function diagnostics = validatePool(pool, path)
diagnostics = repmat(emptyDiag(), 1, 0);

% Check 1: sl-StartRB-Subchannel + sl-NumSubchannel x sl-SubchannelSize <= BWP size.
% "BWP size" is read from sl-RB-Number-r16, which the pool carries for exactly this purpose
% (the alternative, decoding the BWP's RIV-encoded locationAndBandwidth, is +ts38213's job).
if pool.sl_RB_Number_r16_Present && pool.sl_StartRB_Subchannel_r16_Present && ...
        pool.sl_NumSubchannel_r16_Present && pool.sl_SubchannelSize_r16_Present
    span = pool.sl_StartRB_Subchannel_r16 + pool.sl_NumSubchannel_r16 * pool.sl_SubchannelSize_r16;
    if span > pool.sl_RB_Number_r16
        diagnostics(end+1) = addDiag(path, 'sl-StartRB-Subchannel-r16/sl-NumSubchannel-r16/sl-SubchannelSize-r16', ...
            'TS 38.331 cl. 6.3.5, SL-ResourcePool-r16', sprintf( ...
            'sl-StartRB-Subchannel-r16 (%d) + sl-NumSubchannel-r16 (%d) x sl-SubchannelSize-r16 (%d) = %d exceeds sl-RB-Number-r16 (%d)', ...
            pool.sl_StartRB_Subchannel_r16, pool.sl_NumSubchannel_r16, pool.sl_SubchannelSize_r16, span, pool.sl_RB_Number_r16));
    end
end

% Check 2: sl-SubchannelSize permitted for this SCS. STRUCTURE ONLY -- the ASN.1 enumerated
% set is already validated by resolveEnum() at decode time; a verified per-SCS restriction
% table (which values TS 38.331/38.214 actually forbid at a given numerology) is not yet
% populated here. Until it is, this check cannot fail -- do not treat its silence as
% confirmation that a given (SCS, subchannel size) pair is spec-legal.

% Check 3: sl-TimeResource bitmap length permitted (10..160). The second half of this check
% (its interaction with S-SSB slots) needs S-SSB slot positions, which come from a
% +phy/+ts38213 procedure over sl-SyncConfigList-r16/sl-PSBCH-Config-r16, not from a stored
% +cfg field -- deferred until that package exists.
if pool.sl_TimeResource_r16_Present
    n = numel(pool.sl_TimeResource_r16);
    if n < 10 || n > 160
        diagnostics(end+1) = addDiag(path, 'sl-TimeResource-r16', 'TS 38.331 cl. 6.3.5, SL-ResourcePool-r16', ...
            sprintf('sl-TimeResource-r16 bitmap length %d outside the permitted SIZE(10..160)', n));
    end
end

% Check 4: selection window list covers every priority in use (structurally total whenever
% present, since it is a fixed SIZE(8) sequence -- what remains checkable is presence).
if pool.sl_UE_SelectedConfigRP_r16_Present && ~pool.sl_UE_SelectedConfigRP_r16.sl_SelectionWindowList_r16_Present
    diagnostics(end+1) = addDiag(path, 'sl-SelectionWindowList-r16', 'TS 38.331 cl. 6.3.5, SL-UE-SelectedConfigRP-r16', ...
        'UE-selected (sensing) mode is configured but sl-SelectionWindowList-r16 is absent');
end

% Check 5: RSRP threshold list indexed for every (p_i, p_j) pair the pool permits
% (structurally total whenever present, fixed SIZE(64); presence is what remains checkable).
if pool.sl_UE_SelectedConfigRP_r16_Present && ~pool.sl_UE_SelectedConfigRP_r16.sl_Thres_RSRP_List_r16_Present
    diagnostics(end+1) = addDiag(path, 'sl-Thres-RSRP-List-r16', 'TS 38.331 cl. 6.3.5, SL-UE-SelectedConfigRP-r16', ...
        'UE-selected (sensing) mode is configured but sl-Thres-RSRP-List-r16 is absent');
end

% Check 6: PSFCH period and sl-MinTimeGapPSFCH consistent with the pool slot set. Implemented
% as a conservative sanity bound (the gap cannot exceed the number of configured sidelink
% slots), not the full 38.213 PSFCH-occasion timing formula.
if pool.sl_PSFCH_Config_r16_Present && pool.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16_Present && ...
        pool.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16 > 0 && pool.sl_TimeResource_r16_Present
    nSlots = nnz(pool.sl_TimeResource_r16);
    gap = pool.sl_PSFCH_Config_r16.sl_MinTimeGapPSFCH_r16;
    if pool.sl_PSFCH_Config_r16.sl_MinTimeGapPSFCH_r16_Present && gap > nSlots
        diagnostics(end+1) = addDiag(path, 'sl-MinTimeGapPSFCH-r16', 'TS 38.331 cl. 6.3.5, SL-PSFCH-Config-r16', ...
            sprintf('sl-MinTimeGapPSFCH-r16 (%d slots) exceeds the %d sidelink slots the pool configures', gap, nSlots));
    end
end

% Check 7: DMRS pattern set non-empty, every entry a permitted symbol count (2..4).
if pool.sl_PSSCH_Config_r16_Present
    pat = pool.sl_PSSCH_Config_r16.sl_PSSCH_DMRS_TimePatternList_r16;
    if isempty(pat)
        diagnostics(end+1) = addDiag(path, 'sl-PSSCH-DMRS-TimePatternList-r16', 'TS 38.331 cl. 6.3.5, SL-PSSCH-Config-r16', ...
            'sl-PSSCH-DMRS-TimePatternList-r16 is present but empty');
    elseif any(pat < 2 | pat > 4)
        diagnostics(end+1) = addDiag(path, 'sl-PSSCH-DMRS-TimePatternList-r16', 'TS 38.331 cl. 6.3.5, SL-PSSCH-Config-r16', ...
            sprintf('sl-PSSCH-DMRS-TimePatternList-r16 entries must be in {2,3,4}, got [%s]', num2str(pat)));
    end
end

% Check 8: MCS table selection consistent with the modulation orders the pool allows.
if pool.sl_MinMaxMCS_List_r16_Present
    permitted = {'qam64'};
    if pool.sl_Additional_MCS_Table_r16_Present
        switch pool.sl_Additional_MCS_Table_r16
            case 'qam256',              permitted = {'qam64', 'qam256'};
            case 'qam64LowSE',          permitted = {'qam64', 'qam64LowSE'};
            case 'qam256-qam64LowSE',   permitted = {'qam64', 'qam256', 'qam64LowSE'};
        end
    end
    for i = 1:numel(pool.sl_MinMaxMCS_List_r16)
        tbl = pool.sl_MinMaxMCS_List_r16(i).sl_MCS_Table_r16;
        if ~ismember(tbl, permitted)
            diagnostics(end+1) = addDiag(path, 'sl-MinMaxMCS-List-r16/sl-Additional-MCS-Table-r16', ...
                'TS 38.331 cl. 6.3.5, SL-ResourcePool-r16', sprintf( ...
                'sl-MinMaxMCS-List-r16 entry %d selects MCS table "%s", not permitted by sl-Additional-MCS-Table-r16', ...
                i, tbl));
        end
    end
end
end
