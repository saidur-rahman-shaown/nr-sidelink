function g = poolGeometry(o, mcs)
%poolGeometry Every PHY quantity the stack needs, derived from the stored configuration once.
%Spec:   none itself -- each quantity is resolved by the package that owns it: cfg.bwpLocation
%        (TS 38.214 5.1.2.2.2 RIV), cfg.bootFromPreconfig (numerology), phy.ts38214.subchannelMap
%        (TS 38.214 clause 8 sub-channels), phy.ts38211.slPSSCHDMRSTimePattern (TS 38.211 Table
%        8.4.1.1.2-1), phy.ts38213.betaOffsetSci2 (TS 38.212 Table 8.3.1.1-2 / TS 38.213 Table
%        9.3-2), phy.ts38214.mcsTableSelect / tbsDetermine (TS 38.214 8.1.3), and
%        phy.ts38212.sci2OutputLength (TS 38.212 8.4.4).
%Inputs: o    struct from cfg.loadConfig (the stored JSON)
%        mcs  integer, 0..27 -- I_MCS the UE uses (a UE choice, stack.defaults)
%Outputs: g  scalar struct: the transmit pool (.pool, a cfg.resourcePool struct, for SCI-1A
%            packing), the receive pool (.rxPool), BWP geometry, slot structure, PSCCH/PSSCH
%            geometry and the transport block size for every L_subCH.
%
%SCOPE THIS FUNCTION ASSERTS RATHER THAN SILENTLY ASSUMES
%--------------------------------------------------------
%  * Every slot is a sidelink pool slot (sl-TimeResource all ones, no S-SSB configured), so the
%    logical pool slot index equals the physical slot index and the conversion is the identity.
%    A pool that skips slots needs phy.ts38214.poolSlotMap threaded through the stack first.
%  * sl-PSFCH-Period is sl0 or sl1. With sl1 every slot has a PSFCH occasion, so every slot has the
%    same shape: l_d = sl-LengthSymbols - 4 (guard, two PSFCH symbols, the gap before them). sl2/sl4
%    make l_d slot-dependent and add the SCI-1A PSFCH-overhead bit; not supported.
%  * The BWP and the pool start at PRB 0 of the grid the receiver demodulates, which is what
%    phy.rx.det.pscchSearch assumes when it places candidate n at n x sl-SubchannelSize.
%  * The first transmit pool and the first receive pool are the ones used.

SUBCARRIERS_PER_RB = 12;
NSYMB_SLOT = 14;                         % normal CP, TS 38.211 Table 4.3.2-1
SCI1A_FORMAT_A = 0;                      % sci2Format field value of SCI-2A (Table 8.3.1.1-1)

pre = o.preconfig;
freq = pre.sl_PreconfigFreqInfoList_r16(1);
bwp = freq.sl_BWP_List_r16(1);
gen = bwp.sl_BWP_Generic_r16;
pcc = bwp.sl_BWP_PoolConfigCommon_r16;
if ~pcc.sl_TxPoolSelectedNormal_r16_Present || ~pcc.sl_RxPool_r16_Present
    error('stack:poolGeometry:noPool', 'poolGeometry: the stored config needs a TX (UE-selected) pool and an RX pool');
end
g.pool = pcc.sl_TxPoolSelectedNormal_r16(1).sl_ResourcePool_r16;
g.rxPool = pcc.sl_RxPool_r16(1);
pool = g.pool;

[g.bwpStartRb, g.nRbBwp] = cfg.bwpLocation(gen.sl_BWP_r16.locationAndBandwidth);
if g.bwpStartRb ~= 0
    error('stack:poolGeometry:bwpOffset', 'poolGeometry: a BWP not starting at PRB 0 is not supported (see header)');
end
g.mu = o.numerology.muBwp;
g.slotMs = 1 / 2^g.mu;
g.nSubcarriers = g.nRbBwp * SUBCARRIERS_PER_RB;
g.NsymbSlot = NSYMB_SLOT;
g.slLengthSymbols = gen.sl_LengthSymbols_r16;
g.slStartSymbol = gen.sl_StartSymbol_r16;
if ~all(pool.sl_TimeResource_r16) || freq.sl_SyncConfigList_r16_Present
    error('stack:poolGeometry:poolSlots', 'poolGeometry: only an every-slot pool without S-SSB is supported (see header)');
end
g.psfchPeriod = 0;
if pool.sl_PSFCH_Config_r16_Present && pool.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16_Present
    g.psfchPeriod = pool.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16;
end
if ~any(g.psfchPeriod == [0 1])
    error('stack:poolGeometry:psfchPeriod', ['poolGeometry: sl-PSFCH-Period %d puts PSFCH in only some slots, so ' ...
        'l_d and the SCI-1A PSFCH overhead field vary per slot; only sl0 and sl1 are supported'], g.psfchPeriod);
end
% TS 38.214 8.1.2.1: PSSCH starts at sl-StartSymbol+1, and never uses the last sidelink symbol, the
% PSFCH symbols, or the symbol immediately before them. TS 38.213 16.3: the second PSFCH symbol is
% l' = sl-StartSymbol + sl-LengthSymbols - 2, so PSFCH is l'-1 (its AGC copy) and l'.
PSFCH_SYMBOLS = 2;                                    % TS 38.211 8.3.4.2.2: AGC copy + content
PSFCH_GAP_SYMBOLS = 1;                                % the symbol before PSFCH (TS 38.214 8.1.2.1)
GUARD_SYMBOLS = 1;                                    % the last symbol (TS 38.211 8.2.1)
g.firstSymbol = g.slStartSymbol + 1;                  % the AGC duplicate precedes it
if g.psfchPeriod == 0
    g.ld = g.slLengthSymbols - GUARD_SYMBOLS;
else
    g.ld = g.slLengthSymbols - GUARD_SYMBOLS - PSFCH_SYMBOLS - PSFCH_GAP_SYMBOLS;
    pc = pool.sl_PSFCH_Config_r16;
    if ~strcmp(pc.sl_PSFCH_CandidateResourceType_r16, 'startSubCH')
        error('stack:poolGeometry:psfchType', 'poolGeometry: only sl-PSFCH-CandidateResourceType startSubCH is supported (phy.ts38213.psfchResource scope)');
    end
    g.psfchCfg = pc;
    g.psfchSymbol = g.slStartSymbol + g.slLengthSymbols - 2;      % l', TS 38.213 16.3
    % sl-PSFCH-RB-Set: "the leftmost bit of the bitmap refers to the lowest RB index in the
    % resource pool" -- so set bit k is pool PRB k-1, i.e. BWP PRB sl-StartRB-Subchannel + k-1.
    g.psfchRbAbs = pool.sl_StartRB_Subchannel_r16 + find(pc.sl_PSFCH_RB_Set_r16) - 1;
    g.psfchMPrbSet = numel(g.psfchRbAbs);
    g.psfchNcs = pc.sl_NumMuxCS_Pair_r16;
    g.minTimeGapPsfch = pc.sl_MinTimeGapPSFCH_r16;
    if mod(g.psfchMPrbSet, g.psfchPeriod * pool.sl_NumSubchannel_r16) ~= 0
        error('stack:poolGeometry:psfchRbSet', ['poolGeometry: M_PRB,set (%d) must be a multiple of N_subch x ' ...
            'N_PSSCH^PSFCH (TS 38.213 16.3)'], g.psfchMPrbSet);
    end
end

g.numSubchannel = pool.sl_NumSubchannel_r16;
g.subchSizeRb = pool.sl_SubchannelSize_r16;
g.subchStartRb = phy.ts38214.subchannelMap(pool.sl_StartRB_Subchannel_r16, g.subchSizeRb, ...
    g.numSubchannel, pool.sl_RB_Number_r16);
if pool.sl_StartRB_Subchannel_r16 ~= 0
    error('stack:poolGeometry:poolOffset', 'poolGeometry: pscchSearch needs sl-StartRB-Subchannel 0 (see header)');
end
g.pscchSymbols = pool.sl_PSCCH_Config_r16.sl_TimeResourcePSCCH_r16;
g.pscchPrb = pool.sl_PSCCH_Config_r16.sl_FreqResourcePSCCH_r16;
g.dmrsPatternList = pool.sl_PSSCH_Config_r16.sl_PSSCH_DMRS_TimePatternList_r16;
g.betaList = pool.sl_PSSCH_Config_r16.sl_BetaOffsets2ndSCI_r16;
g.alpha = pool.sl_PSSCH_Config_r16.sl_Scaling_r16;
g.maxNumPerReserve = pool.sl_UE_SelectedConfigRP_r16.sl_MaxNumPerReserve_r16;
g.sensingWindowMs = pool.sl_UE_SelectedConfigRP_r16.sl_SensingWindow_r16;
rp = pool.sl_UE_SelectedConfigRP_r16.sl_ResourceReservePeriodList_r16;
g.reservePeriodListMs = [rp.sl_ResourceReservePeriod_ms];
g.multiReserve = logical(pool.sl_UE_SelectedConfigRP_r16.sl_MultiReserveResource_r16);   % SCI-1A period field
% SPS keep / reselect parameters, sl-UE-SelectedPreConfig-r16 (TS 38.321 5.22.1.1, 5.22.1.2).
sel = pre.sl_UE_SelectedPreConfig_r16;
g.probResourceKeep = 0; if sel.sl_ProbResourceKeep_r16_Present, g.probResourceKeep = sel.sl_ProbResourceKeep_r16; end
g.reselectAfter = Inf;  if sel.sl_ReselectAfter_r16_Present, g.reselectAfter = sel.sl_ReselectAfter_r16; end
g.TmaxPrime = 10240 * 2^g.mu;           % every slot is a pool slot (the select() assumption)
% Pre-emption gate (TS 38.214 8.1.4): '' not provided, 'enabled', or 'pl1'..'pl8' (mac.preemption).
g.preemptionEnable = pool.sl_PreemptionEnable_r16;
% Congestion control (TS 38.214 8.1.6, TS 38.215 5.1.26/5.1.27). Absent sl-ThreshS-RSSI-CBR means
% no CBR measurement, so the default Tx configuration of each priority applies throughout.
RSSI_BASE_DBM = -112; RSSI_STEP_DB = 2;         % TS 38.331 sl-ThreshS-RSSI-CBR: value n -> -112 + 2n dBm
g.cbrMeasured = pool.sl_ThreshS_RSSI_CBR_r16_Present && pool.sl_TimeWindowSizeCBR_r16_Present;
g.threshRssiCbrDbm = RSSI_BASE_DBM + RSSI_STEP_DB * pool.sl_ThreshS_RSSI_CBR_r16;
g.cbrWindowSlots = 0;
if g.cbrMeasured, g.cbrWindowSlots = phy.ts38215.cbrWindowSlots(pool.sl_TimeWindowSizeCBR_r16, g.mu); end
g.crWindowSlots = 0;
if pool.sl_TimeWindowSizeCR_r16_Present, g.crWindowSlots = phy.ts38215.crWindowSlots(pool.sl_TimeWindowSizeCR_r16, g.mu); end
for k = 1:8
    [lv, lim, pres, dl, conf] = cfg.crLimitTable(pool, sel.sl_CBR_CommonTxConfigList_r16, k);
    g.crTab(k) = struct('levelUpper', lv, 'crLimit', lim, 'crLimitPresent', pres, 'defaultLevel', dl, ...
        'configured', conf && g.crWindowSlots > 0);
end
sw = pool.sl_UE_SelectedConfigRP_r16.sl_SelectionWindowList_r16;
g.T2minRawByPrio = zeros(1, 8);
for k = 1:numel(sw), g.T2minRawByPrio(sw(k).sl_Priority_r16) = sw(k).sl_SelectionWindow_r16; end
tp = pool.sl_TxPercentageList_r16;
g.txPercentageByPrio = zeros(1, 8);
for k = 1:numel(tp), g.txPercentageByPrio(tp(k).sl_Priority_r16) = tp(k).sl_TxPercentage_r16 / 100; end
g.thresListDbm = rsrpThresholdDbm(pool.sl_UE_SelectedConfigRP_r16.sl_Thres_RSRP_List_r16);

% ---- the transmission's fixed choices: DM-RS pattern index 0, beta indicator 0, SCI-2A ----
g.dmrsPatternIndex = 0;
g.nDmrs = g.dmrsPatternList(g.dmrsPatternIndex + 1);
g.dmrsSymbols = phy.ts38211.slPSSCHDMRSTimePattern(g.ld, g.pscchSymbols, g.nDmrs);
g.betaOffsetIndex = 0;
g.beta = phy.ts38213.betaOffsetSci2(g.betaList, g.betaOffsetIndex);
g.sci2Format = SCI1A_FORMAT_A;
g.sci2BitLen = numel(phy.ts38212.sci2aPack(struct('harqProcessNumber', 0, 'ndi', 0, 'rv', 0, ...
    'sourceID', 0, 'destinationID', 0, 'harqFeedbackEnabled', 0, 'castType', 0, 'csiRequest', 0)));

% ---- MCS and the TBS for every L_subCH ----------------------------------
g.mcs = mcs;
[g.modScheme, g.Qm, g.R] = phy.ts38214.mcsTableSelect(mcs, pool.sl_Additional_MCS_Table_r16, 0);
nReSci1 = g.pscchSymbols * g.pscchPrb * SUBCARRIERS_PER_RB;
g.tbsBytesByLsubCH = zeros(1, g.numSubchannel);
g.Gsci2ByLsubCH = zeros(1, g.numSubchannel);
for L = 1:g.numSubchannel
    m = stack.psschMapping(g, 0, L, 0);
    g.Gsci2ByLsubCH(L) = m.Gsci2;
    tbs = phy.ts38214.tbsDetermine(g.Qm, g.R, 1, L * g.subchSizeRb, g.slLengthSymbols, g.psfchPeriod, ...
        false, 0, g.dmrsPatternList, nReSci1, m.Gsci2 / 2);
    g.tbsBytesByLsubCH(L) = tbs / 8;
end
end

function th = rsrpThresholdDbm(raw)
%rsrpThresholdDbm sl-Thres-RSRP-List values to dBm. TS 38.331 SL-Thres-RSRP-r16 INTEGER (0..66):
%"Value 0 corresponds to minus infinity dBm, value 1 corresponds to -128dBm, value 2 corresponds
%to -126dBm, value n corresponds to (-128 + (n-1)*2) dBm and so on, value 66 corresponds to
%infinity dBm."
RSRP_BASE_DBM = -128;
RSRP_STEP_DB = 2;
RAW_MAX = 66;
th = RSRP_BASE_DBM + (raw - 1) * RSRP_STEP_DB;
th(raw == 0) = -Inf;
th(raw == RAW_MAX) = Inf;
end
