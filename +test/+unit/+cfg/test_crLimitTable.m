function test_crLimitTable()
%test_crLimitTable cfg.crLimitTable: (priority, CBR range) -> sl-CR-Limit through the TS 38.331
%sl-CBR-PriorityTxConfigList-r16 -> sl-CBR-CommonTxConfigList-r16 indirection.
%SPEC: TS 38.331 V16.22.0, SL-CBR-PriorityTxConfigList-r16 / SL-CBR-CommonTxConfigList-r16 field
%      descriptions (sl-PriorityThreshold, sl-DefaultTxConfigIndex, sl-CBR-ConfigIndex,
%      sl-Tx-ConfigIndexList, SL-CBR-r16, sl-CR-Limit).
%Level 2: the expected values are the independent-verifier's worked example (computed from the
%      spec text without this code): two priority ranges, 1..3 and 4..8, with different CBR range
%      lists, and one Tx config whose sl-CR-Limit is absent. Agreed in full (2026-10-28);
%      pending-human on the verifier's inferences: entry j of sl-Tx-ConfigIndexList pairs with CBR
%      range j (no field description), CBR upper bounds inclusive, absent sl-CR-Limit = no limit.
%      Exact equality is asserted on purpose: the conversions divide (v/10000), never multiply.

common.sl_CBR_RangeConfigList_r16_Present = true;
common.sl_CBR_RangeConfigList_r16 = struct('sl_CBR_LevelsConfig_r16', {[20 40 60 80 100], [50 100]});
common.sl_CBR_PSSCH_TxConfigList_r16_Present = true;
common.sl_CBR_PSSCH_TxConfigList_r16 = struct('sl_CR_Limit_r16_Present', {true, true, true, true, true, false}, ...
    'sl_CR_Limit_r16', {10000, 6000, 3000, 1200, 500, 0});
e = @(thr, def, cbrIdx, txList) struct('sl_PriorityThreshold_r16_Present', true, 'sl_PriorityThreshold_r16', thr, ...
    'sl_DefaultTxConfigIndex_r16_Present', true, 'sl_DefaultTxConfigIndex_r16', def, ...
    'sl_CBR_ConfigIndex_r16_Present', true, 'sl_CBR_ConfigIndex_r16', cbrIdx, ...
    'sl_Tx_ConfigIndexList_r16_Present', true, 'sl_Tx_ConfigIndexList_r16', txList);
pool.sl_UE_SelectedConfigRP_r16.sl_CBR_PriorityTxConfigList_r16_Present = true;
pool.sl_UE_SelectedConfigRP_r16.sl_CBR_PriorityTxConfigList_r16 = [e(3, 1, 1, [0 5]), e(8, 0, 0, [0 1 2 3 4])];

% priorities 1..3: the first entry (lower bound 1), CBR ranges [0.5 1.0], Tx configs 0 and 5
for k = [1 3]
    [lv, lim, pres, def, conf] = cfg.crLimitTable(pool, common, k);
    assert(conf && isequal(lv, [0.5 1.0]) && isequal(lim, [1 0]) && isequal(pres, [true false]) && def == 2, ...
        'priority %d: ranges [0.5 1], CR limit [1 absent], default range 2', k);
end
% priorities 4..8: the second entry, five ranges, all limits present, default range 1
for k = [4 6 8]
    [lv, lim, pres, def, conf] = cfg.crLimitTable(pool, common, k);
    assert(conf && isequal(lv, [0.2 0.4 0.6 0.8 1.0]) && isequal(lim, [1 0.6 0.3 0.12 0.05]) ...
        && all(pres) && def == 1, 'priority %d: five ranges, CR limits 1/0.6/0.3/0.12/0.05, default range 1', k);
end
% the range lookup on top (TS 38.214 8.1.6 via phy.ts38214.cbrRangeIndex): 0.40 is in range 2, 0.41 in 3
[lv, lim] = cfg.crLimitTable(pool, common, 6);
assert(lim(phy.ts38214.cbrRangeIndex(0.40, lv)) == 0.6 && lim(phy.ts38214.cbrRangeIndex(0.41, lv)) == 0.3, ...
    'CBR 0.40 -> range 2 (limit 0.6), 0.41 -> range 3 (limit 0.3): upper bounds inclusive');
% no entry covers the priority: no limit (not a limit of 1)
pool.sl_UE_SelectedConfigRP_r16.sl_CBR_PriorityTxConfigList_r16 = e(3, 1, 1, [0 5]);
[~, ~, ~, ~, conf] = cfg.crLimitTable(pool, common, 4);
assert(~conf, 'priority 4 above every sl-PriorityThreshold: not configured');
% the stored config: every priority under one entry, CR limit 0.05 at the top range
o = cfg.loadConfig('+cfg/configs/preconfig_example.json', [58 56 23]);
g = stack.poolGeometry(o, 7);
assert(all([g.crTab.configured]) && g.crTab(6).crLimit(end) == 0.05 && g.threshRssiCbrDbm == -94 && ...
    g.cbrWindowSlots == 200 && g.crWindowSlots == 2000, 'stored config: CBR -94 dBm, 100 ms / 1000 ms windows at mu = 1');
fprintf('test_crLimitTable: all assertions passed.\n');
end
