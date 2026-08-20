function cfg = defaultPreconfig()
%defaultPreconfig Rel-16 sidelink preconfiguration (struct mirror).
%SPEC: TS 38.331 9.3 / 6.3.5 — SL-PreconfigurationNR-r16 subset
%
%   Field names mirror the ASN.1 identifiers (with '_' for '-') per
%   Plan.md §5 B1. Baseline profile per Plan.md §0.3:
%   FR1 n47, 20 MHz, SCS 30 kHz, mu = 1, slot = 0.5 ms.

% ---- numerology -------------------------------------------------------
cfg.mu          = 1;
cfg.scs_kHz     = 30;
cfg.slotsPerMs  = 2;             % 2^mu
cfg.slotDur_ms  = 0.5;

% ---- SL-ResourcePool-r16 ---------------------------------------------
cfg.sl_TimeResource_r16      = true(1, 20);  % slot bitmap, repeats (10..160)
cfg.sl_NumSubchannel_r16     = 5;            % 1..27
cfg.sl_SubchannelSize_r16    = 10;           % PRB {10,12,15,20,25,50,75,100}
cfg.sl_StartRB_Subchannel_r16 = 0;
cfg.sl_RB_Number_r16         = 50;

% Slot-map exclusions (Plan.md §4.2): TDD UL mask + S-SSB slots.
cfg.tdd_ULSlotMask       = true(1, 20);      % slots usable for sidelink
cfg.sssb_SlotsInPeriod   = [];               % abs slots (mod period) excluded
cfg.sssb_Period_slots    = 320;              % 160 ms @ 30 kHz

% ---- SL-UE-SelectedConfigRP-r16 (pool-nested) -------------------------
cfg.sl_SensingWindow_ms             = 100;   % {100, 1100}
% sl-SelectionWindowList-r16: T2min per priority 1..8, value n*2^mu slots
cfg.sl_SelectionWindowList_slots    = 20 * 2^cfg.mu * ones(1, 8);   % n20
% sl-Thres-RSRP-List-r16: 64 entries, index i = pRx + (pTx-1)*8
cfg.sl_Thres_RSRP_List_dBm          = -110 * ones(1, 64);
cfg.sl_RS_ForSensing                = 'pssch';   % {'pscch','pssch'}
cfg.sl_ResourceReservePeriodList_ms = [0 100 200 500 1000];
cfg.sl_MultiReserveResource         = true;
cfg.sl_MaxNumPerReserve             = 3;         % {2,3}
% sl-TxPercentageList-r16: X per priority 1..8 (p20 default)
cfg.sl_TxPercentageList             = 0.20 * ones(1, 8);
% sl-PreemptionEnable-r16: '' (absent) | 'enabled' | 'pl1'..'pl8'
cfg.sl_PreemptionEnable             = 'enabled';

% ---- SL-UE-SelectedConfig-r16 (BWP level) -----------------------------
cfg.sl_ProbResourceKeep    = 0.0;    % {0,.2,.4,.6,.8}
cfg.sl_ReselectAfter       = 5;      % n1..n9, [] = not configured
cfg.sl_MaxTxTransNumPSSCH  = 3;      % total TX of a TB (1 initial + 2 blind)

% ---- Policy / implementation caps (Plan.md §0.4) ----------------------
cfg.maxThresholdEscalations = 30;    % step-7 iteration cap (assertion guard)
end
