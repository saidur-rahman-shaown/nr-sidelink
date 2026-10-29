function [levelUpper, crLimit, crLimitPresent, defaultLevel, configured] = crLimitTable(pool, commonTx, prio)
%crLimitTable The CBR ranges and per-range sl-CR-Limit that apply to one priority value.
%Spec:   TS 38.331 V16.22.0, SL-CBR-PriorityTxConfigList-r16 (in SL-UE-SelectedConfigRP-r16) and
%        SL-CBR-CommonTxConfigList-r16 (in SL-UE-SelectedPreConfig-r16), field descriptions:
%          sl-PriorityThreshold   "the upper bound of priority range which is associated with the
%                                 configurations in sl-CBR-ConfigIndex and in sl-Tx-ConfigIndexList.
%                                 The upper bounds of the priority ranges are configured in
%                                 ascending order [...] For the first entry [...] the lower bound
%                                 of the priority range is 1."
%          sl-CBR-ConfigIndex     the entry of sl-CBR-RangeConfigList giving the CBR ranges
%          sl-Tx-ConfigIndexList  one entry per CBR range, an index into sl-CBR-PSSCH-TxConfigList
%          sl-DefaultTxConfigIndex "the PSSCH transmission parameters to be used by the UEs which
%                                 do not have available CBR measurement results, by means of an
%                                 index to the corresponding entry in sl-Tx-ConfigIndexList"
%          SL-CBR-r16             "Value 0 corresponds to 0, value 1 to 0.01 [...]"
%          sl-CR-Limit            "Value 0 corresponds to 0, value 1 to 0.0001 [...] until value
%                                 10000, which corresponds to 1"
%        This is the indirection TS 38.214 clause 8.1.6 needs for "the high layer parameter
%        sl-CR-Limit that is associated with the priority value k and the CBR range which
%        includes the CBR measured in slot n-N"; the range lookup itself is
%        phy.ts38214.cbrRangeIndex, which takes levelUpper from here.
%Inputs: pool      struct from cfg.resourcePool -- the TX pool (its sl-UE-SelectedConfigRP-r16)
%        commonTx  struct -- sl-UE-SelectedPreConfig-r16.sl-CBR-CommonTxConfigList-r16 as parsed by
%                  cfg.preconfig (with its _Present flags)
%        prio      integer, 1..8 -- priority value k
%Outputs: levelUpper      1 x nLevels real in [0,1], ascending -- CBR range upper bounds (ratio)
%         crLimit         1 x nLevels real in [0,1] -- sl-CR-Limit per range (ratio)
%         crLimitPresent  1 x nLevels logical -- sl-CR-Limit configured for that range
%         defaultLevel    integer, 1..nLevels -- the range whose Tx config applies before any CBR
%                         measurement exists (sl-DefaultTxConfigIndex + 1)
%         configured      logical -- false when no entry of the list covers prio (or the lists
%                         are absent): then no CR limit applies to k at all, which is clause
%                         8.1.6's "if a UE is configured with higher layer parameter sl-CR-Limit"
%                         failing, not a limit of 1

CBR_PER_UNIT = 100;             % SL-CBR-r16: value v is v/100 (division, not v*0.01: exact for every v)
CR_LIMIT_PER_UNIT = 10000;      % sl-CR-Limit-r16: value v is v/10000 (1200*1e-4 is not 0.12)
FIRST_PRIO_LOWER_BOUND = 1;
levelUpper = zeros(1, 0); crLimit = zeros(1, 0); crLimitPresent = false(1, 0);
defaultLevel = 1; configured = false;
if prio < 1 || prio > 8 || mod(prio, 1) ~= 0
    error('cfg:crLimitTable:prio', 'crLimitTable: priority value must be an integer 1..8, got %g', prio);
end
rp = pool.sl_UE_SelectedConfigRP_r16;
if ~rp.sl_CBR_PriorityTxConfigList_r16_Present || ~commonTx.sl_CBR_RangeConfigList_r16_Present ...
        || ~commonTx.sl_CBR_PSSCH_TxConfigList_r16_Present
    return;
end
lst = rp.sl_CBR_PriorityTxConfigList_r16;
lower = FIRST_PRIO_LOWER_BOUND;
j = 0;
for i = 1:numel(lst)
    upper = lst(i).sl_PriorityThreshold_r16;
    if lst(i).sl_PriorityThreshold_r16_Present && prio >= lower && prio <= upper
        j = i;
        break;
    end
    if lst(i).sl_PriorityThreshold_r16_Present
        lower = upper + 1;
    end
end
if j == 0 || ~lst(j).sl_CBR_ConfigIndex_r16_Present || ~lst(j).sl_Tx_ConfigIndexList_r16_Present
    return;
end
e = lst(j);
levelUpper = commonTx.sl_CBR_RangeConfigList_r16(e.sl_CBR_ConfigIndex_r16 + 1).sl_CBR_LevelsConfig_r16 / CBR_PER_UNIT;
nLevels = numel(levelUpper);
if numel(e.sl_Tx_ConfigIndexList_r16) ~= nLevels
    error('cfg:crLimitTable:levels', 'crLimitTable: sl-Tx-ConfigIndexList has %d entries for %d CBR ranges (cfgValidate check 19)', ...
        numel(e.sl_Tx_ConfigIndexList_r16), nLevels);
end
tx = commonTx.sl_CBR_PSSCH_TxConfigList_r16(e.sl_Tx_ConfigIndexList_r16 + 1);
crLimit = [tx.sl_CR_Limit_r16] / CR_LIMIT_PER_UNIT;
crLimitPresent = [tx.sl_CR_Limit_r16_Present];
if e.sl_DefaultTxConfigIndex_r16_Present
    defaultLevel = e.sl_DefaultTxConfigIndex_r16 + 1;
end
configured = true;
end
