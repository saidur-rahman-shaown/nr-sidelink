function diagnostics = cfgValidate(preconfig, pqiTbl, configuredPQIs)
%cfgValidate Cross-field consistency checks over a resolved preconfig tree, clause-cited.
%Spec:   TS 38.331 clause 6.3.5 (field-level constraints); TS 38.211/38.213 (slot/PSFCH timing
%        sanity bounds, see per-check notes below for the fidelity of each). Implements the
%        checklist from +cfg/CLAUDE.md "Validator check list (minimum)".
%Inputs: preconfig       scalar struct from cfg.preconfig()
%        pqiTbl          1xN struct array from cfg.pqiTable()
%        configuredPQIs  row vector of PQI values actually used by this deployment (optional,
%                        default empty -- no traffic model exists at B0; +app/+sdap supply
%                        this once built, for check 10)
%Outputs: diagnostics  1xN struct array, empty iff the config is valid. Fields: path (where in
%                      the tree), field (the ASN.1 identifier), clause (spec clause violated),
%                      message (human-readable). Every non-empty result names both field and
%                      clause, per +cfg/CLAUDE.md ("every failure names the clause it
%                      violates").
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
end

% ======================================================================
% Local helpers. Not callable outside this file.
% ======================================================================

function d = emptyDiag()
d = struct('path', '', 'field', '', 'clause', '', 'message', '');
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
