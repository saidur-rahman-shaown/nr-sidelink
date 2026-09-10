function scen = scenarioInit(nUe, seed, castLabel)
%scenarioInit Build the baseline system-level scenario.
%Spec:   none -- scenario configuration. Every 3GPP quantity in it is resolved through the
%        package that owns it (poolSlotMap, mcsTableSelect, tbsDetermine, policy.defaults).
%Inputs: nUe        integer, >=2 -- number of UEs
%        seed       integer -- RNG seed. The ONE source of randomness in a run
%        castLabel  char, 'broadcast' (default) or 'unicast'. Unicast pairs each UE with the
%                   next in a ring, enables HARQ feedback, and turns on PSFCH -- which changes
%                   the transport block size, because clause 8.1.3.2 subtracts the PSFCH
%                   symbols from N_RE. That coupling is why this is a scenario switch and not
%                   a flag read at transmit time.
%Outputs: scen  scalar struct, everything a slot step needs that does not change per slot
%
%A DELIBERATELY MINIMAL SCENARIO
%-------------------------------
%UEs on a straight line at a fixed spacing, stationary, all broadcasting the same CAM-like
%flow with staggered phases. No mobility, no cast-type mix, no traffic mix. That is enough to
%exercise every path in the loop and to make the first latency and throughput numbers
%interpretable; a scenario with more moving parts makes an unexpected KPI impossible to
%attribute. Mobility and mixed traffic are additions to this, not rewrites of it.
%
%Every UE broadcasts, so nothing here exercises PSFCH. Unicast is supported by the SAPs and the
%slot loop; the scenario that uses it is a separate constructor.

if nargin < 3
    castLabel = 'broadcast';
end
if ~(nUe >= 2 && mod(nUe, 1) == 0)
    error('sls:scenarioInit:badNUe', 'scenarioInit: nUe must be an integer >= 2, got %s', num2str(nUe));
end
if ~any(strcmp(castLabel, {'broadcast', 'unicast'}))
    error('sls:scenarioInit:badCast', 'scenarioInit: castLabel must be ''broadcast'' or ''unicast'', got ''%s''', castLabel);
end
scen.castLabel = castLabel;
scen.isUnicast = strcmp(castLabel, 'unicast');

scen.mu            = 1;                  % 30 kHz SCS, the FR1 V2X numerology
scen.slotsPerMs    = 2^scen.mu;
scen.numSubchannel = 10;
scen.subchSizeRb   = 10;                 % sl-SubchannelSize
scen.nPrb          = scen.numSubchannel * scen.subchSizeRb;
scen.startRb       = 0;

% ---- the pool: every slot is a sidelink slot (the Mode-2 baseline) ----------
[scen.physOfLogical, scen.logicalOfPhys, scen.TmaxPrime] = harness.poolAllSlots(scen.mu);

% ---- radio ----------------------------------------------------------------
scen.radio = struct( ...
    'fcHz',          5.9e9, ...          % ITS band
    'bwHz',          scen.nPrb * 12 * 30e3, ...   % PRBs x 12 subcarriers x 30 kHz
    'noiseFigureDb', 9, ...
    'plExponent',    2.7, ...            % placeholder; see chanmodel/pathlossDb
    'plRefDistM',    1);
scen.pCmaxDbm     = 23;     % P_CMAX; slPowerControl is a max-power-always policy for now
scen.channelModel = 'awgn';
scen.speedKmh     = 0;
% PSCCH decodes further out than PSSCH because its code rate is far lower and does not move
% with the data's -- NOT because it is narrower: +harness/+chanmodel/slotSinr shows signal and
% noise scale together with the band, leaving the SNR identical. There is no
% pscchEffectiveMcs knob any more: the control curve is measured directly by +harness/+lls/ and
% read through harness.phyabs.pscchBler.

% ---- selection policy ------------------------------------------------------
scen.policy = phy.rx.policy.defaults();
scen.pool = struct( ...
    'sensingWindowMs',  100, ...
    'thresholdListDbm', repmat(-110, 1, 64), ...   % sl-Thres-RSRP-List, pre-resolved
    'txPercentage',     0.2, ...                   % sl-TxPercentage
    'allowedPeriodsMs', 100, ...                   % sl-ResourceReservePeriodList
    'T2minRaw',         20, ...                    % sl-SelectionWindow
    'slProbResourceKeep', 0.4, ...
    'slReselectAfter',  Inf, ...
    'slPreemptionEnable', 'enabled', ...
    'threshSRssiCbrDbm', -94, ...           % sl-Thres-RSSI-CBR, pre-resolved to dBm
    'timeWindowSizeCBR', 'ms100', ...       % sl-TimeWindowSizeCBR-r16
    'timeWindowSizeCR',  'ms1000', ...      % sl-TimeWindowSizeCR-r16
    'cbrRangeUpperBounds', [0.2 0.4 0.6 0.8 1.0], ...  % one SL-CBR-LevelsConfig, as ratios
    'crLimitByLevel', [1.0 0.6 0.3 0.12 0.05]);        % sl-CR-Limit per CBR level, pre-resolved       % sl-PreemptionEnable-r16; '' disables it entirely                      % not configured: never fires on unused periods

% ---- traffic ---------------------------------------------------------------
pqi = 55;                                % CAM-like periodic awareness, the pqiTable default row
t   = cfg.pqiTable();
row = t([t.PQI] == pqi);
scen.traffic = struct( ...
    'pqi',         pqi, ...
    'prio',        row.priority, ...
    'pdbMs',       row.PDB_ms, ...
    'periodSlots', 100 * scen.slotsPerMs, ...      % 100 ms CAM period
    'sizeBytes',   300, ...
    'lcid',        4, ...
    'pbrBytesPerSec', 300 * 10, ...      % sl-PrioritisedBitRate: one 300-byte CAM per 100 ms
    'bsdSeconds',     0.1);              % sl-BucketSizeDuration, so the bucket holds one CAM

% ---- transport block size, from the real clause 8.1.3.2 arithmetic ---------
% L_subCH is DERIVED here, not taken from policy.defaults: the default is a documented stand-in
% for exactly this arithmetic, and using it blind is how a payload gets transmitted at the wrong
% size. The MAC PDU overhead is measured by building a PDU with muxSlSch rather than guessed --
% the subheader widths are clause 6.2.4's and belong to that function.
[~, Qm, R] = phy.ts38214.mcsTableSelect(scen.policy.mcs, '', 0);
scen.slLengthSymbols = 12;
% PSFCH costs transport-block capacity: clause 8.1.3.2 subtracts the PSFCH symbols from N_RE,
% so enabling feedback shrinks every TB in the pool whether or not a given transmission uses
% it. Computing the TBS table with the real period is what makes that cost visible rather than
% free.
if scen.isUnicast
    scen.slPsfchPeriod = 1;              % sl-PSFCH-Period: a PSFCH occasion every pool slot
else
    scen.slPsfchPeriod = 0;              % disabled in the broadcast baseline
end
% PSCCH occupies sl-FreqResourcePSCCH PRBs over sl-TimeResourcePSCCH symbols, inside the
% LOWEST sub-channel of the PSSCH allocation (clause 8.1.2.2). These are the values the TBS
% arithmetic below already assumes for N_RE^SCI1, so they are named once and reused rather than
% written twice with a chance of drifting apart.
scen.pscchPrb        = scen.subchSizeRb;
scen.pscchSymbols    = 2;
scen.maxNumPerReserve = 2;               % sl-MaxNumPerReserve; matches policy.numRetx = 1
scen.reservePeriodListMs = [0 100];      % sl-ResourceReservePeriodList, pre-resolved to ms
scen.minTimeGapPsfch = 2;                % sl-MinTimeGapPSFCH, in pool slots
scen.psfchRbSetSize  = scen.numSubchannel * max(1, scen.slPsfchPeriod);  % M_PRB,set^PSFCH
scen.psfchNumMuxCsPair = 6;              % sl-NumMuxCS-Pair, N_CS^PSFCH
scen.psfchNtype        = 1;              % sl-PSFCH-CandidateResourceType = startSubCH
scen.slMaxTransNum             = 1 + scen.policy.numRetx + 2;
scen.slMaxNumConsecutiveDTX    = 4;
nReSci1 = scen.pscchSymbols * scen.pscchPrb * 12;   % PSCCH REs, from the fields above

tbsBytesByLsubCH = zeros(1, scen.numSubchannel);
for L = 1:scen.numSubchannel
    nPrbAlloc = L * scen.subchSizeRb;
    nReSci2   = 2 * nPrbAlloc;           % 2nd-stage SCI, a modest fixed share of the allocation
    bits = phy.ts38214.tbsDetermine(Qm, R, 1, nPrbAlloc, scen.slLengthSymbols, ...
        scen.slPsfchPeriod, scen.slPsfchPeriod > 0, 0, [2 3], nReSci1, nReSci2);
    tbsBytesByLsubCH(L) = floor(bits / 8);
end

% MAC PDU overhead, measured rather than guessed, and separated into its fixed and per-SDU
% parts. Clause 6.2.4 gives every subPDU its own subheader, so a PDU carrying two SDUs costs
% more than one carrying one; a single measured constant would understate a multi-SDU PDU and
% size the grant too small for it.
probeBytes = tbsBytesByLsubCH(end);
oh = zeros(1, 2);
for nSdu = 1:2
    len = repmat(scen.traffic.sizeBytes, 1, nSdu);
    [~, nPad, nInc] = mac.muxSlSch(1, 2, uint8(zeros(1, sum(len))), len, ...
        repmat(scen.traffic.lcid, 1, nSdu), false, 0, 0, probeBytes);
    if nInc ~= nSdu
        error('sls:scenarioInit:probeFailed', 'scenarioInit: the %d-SDU overhead probe carried %d SDUs', nSdu, nInc);
    end
    oh(nSdu) = probeBytes - sum(len) - nPad;
end
scen.macOverheadPerSduBytes = oh(2) - oh(1);
scen.macOverheadFixedBytes  = oh(1) - scen.macOverheadPerSduBytes;

% L_subCH is NOT set here. It is derived per selection by phy.rx.policy.selectionRequest from
% the MAC PDU actually pending, gated by this table at the chosen MCS -- so a UE with more
% queued data selects a wider allocation, and no path can select one too small for its own
% payload. All this scenario supplies is the table.
scen.policy.tbsBytesByLsubCH = tbsBytesByLsubCH;
scen.tbsBytesByLsubCH        = tbsBytesByLsubCH;
scen.maxTbsBytes             = tbsBytesByLsubCH(end);

% Sanity: one SDU must fit somewhere in the table, or no grant can ever carry this traffic.
onePdu = scen.macOverheadFixedBytes + scen.macOverheadPerSduBytes + scen.traffic.sizeBytes;
if onePdu > scen.maxTbsBytes
    error('sls:scenarioInit:sduTooLarge', 'scenarioInit: a %d-byte MAC PDU (a %d-byte SDU plus overhead) does not fit even L_subCH = %d (%d bytes) at MCS %d', onePdu, scen.traffic.sizeBytes, scen.numSubchannel, scen.maxTbsBytes, scen.policy.mcs);
end

scen.nUe      = nUe;
scen.spacingM = 20;
scen.posXY    = [(0:nUe - 1)' * scen.spacingM, zeros(nUe, 1)];

% ---- congestion control windows (TS 38.215 clause 5.1.25 / 5.1.26) ---------
% The window LENGTHS are normative; the CR window's split into past and future halves is not
% (clause 5.1.26 NOTE 1: "determined by UE implementation"), so it comes from
% phy.rx.policy.crWindowSplit. N is the measurement-to-action processing delay from
% clause 8.1.6.
scen.cbrWindowSlots = phy.ts38215.cbrWindowSlots(scen.pool.timeWindowSizeCBR, scen.mu);
crTotal             = phy.ts38215.crWindowSlots(scen.pool.timeWindowSizeCR, scen.mu);
[scen.crPastSlots, scen.crFutureSlots] = phy.rx.policy.crWindowSplit(crTotal);
scen.crWindowTotal  = crTotal;
scen.congestionProcSlots = phy.ts38214.procTimeCongestion(scen.mu, 1);

% ---- the escalation bound, DERIVED rather than guessed ---------------------
% Clause 8.1.4 step 7 raises every RSRP threshold by 3 dB and repeats until S_A reaches
% sl-TxPercentage of M_total. The loop provably terminates -- once the thresholds exceed every
% sensed RSRP, step 6 excludes nothing -- so the only question is how many rounds that takes,
% and the answer is set by the scenario's geometry, not by a round number.
%
% The strongest signal any UE can sense is one at the closest separation in the deployment. The
% threshold must climb from the lowest configured value past that, in 3 dB steps. Leaving
% phy.rx.policy.defaults' generic bound of 10 in place gives only 30 dB of headroom, while a
% 20 m neighbour at P_CMAX sits about 50 dB above a -110 dBm threshold -- so candidateSet
% raises ts38214:candidateSet:escalationLimit partway through a long run, which is the bound
% doing its job and reporting that it was set too low.
escalationStepDb = 3;                    % clause 8.1.4 step 7
closestPl = harness.chanmodel.pathlossDb(scen.spacingM, scen.radio.fcHz, ...
    scen.radio.plExponent, scen.radio.plRefDistM);
strongestRsrpDbm = scen.pCmaxDbm - closestPl;
scen.policy.maxEscalations = ceil((strongestRsrpDbm - min(scen.pool.thresholdListDbm)) / escalationStepDb) + 1;

% ---- geometry: a line of UEs, stationary -----------------------------------
% Per-UE sl-Priority, uniform by default. A vector rather than a scalar because pre-emption's
% comparison is STRICT (+mac/CLAUDE.md: only a numerically smaller sl-Priority pre-empts, or
% two same-priority UEs pre-empt each other indefinitely) -- so in a single-priority population
% clause 5.22.1.2a's pre-emption check can NEVER fire, by construction. Leaving priority a
% scalar would make that structural impossibility look like a wiring bug, and would make it
% impossible to tell the two apart.
scen.prioByUe = repmat(scen.traffic.prio, 1, nUe);

% ---- the one source of randomness -----------------------------------------
% Every module below takes its draws as inputs; this is where they come from, and a seed
% reproduces a run exactly. +harness/CLAUDE.md's determinism test rests on this being the only
% stream in the simulator.
scen.seed   = seed;
scen.stream = RandStream('mt19937ar', 'Seed', seed);
end
