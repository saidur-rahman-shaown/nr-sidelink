function scen = scenarioInit(nUe, seed)
%scenarioInit Build the baseline system-level scenario.
%Spec:   none -- scenario configuration. Every 3GPP quantity in it is resolved through the
%        package that owns it (poolSlotMap, mcsTableSelect, tbsDetermine, policy.defaults).
%Inputs: nUe   integer, >=2 -- number of UEs
%        seed  integer -- RNG seed. The ONE source of randomness in a run
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

if ~(nUe >= 2 && mod(nUe, 1) == 0)
    error('sls:scenarioInit:badNUe', 'scenarioInit: nUe must be an integer >= 2, got %s', num2str(nUe));
end

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
% PSCCH carries SCI-1A at a fixed robust format while PSSCH runs at the announced MCS, so the
% control channel decodes further out than the data. Modelled as an SINR advantage rather than
% a second curve, since there is only a placeholder curve to be advantaged against.
scen.sciSinrAdvantageDb = 6;

% ---- selection policy ------------------------------------------------------
scen.policy = phy.rx.policy.defaults();
scen.pool = struct( ...
    'sensingWindowMs',  100, ...
    'thresholdListDbm', repmat(-110, 1, 64), ...   % sl-Thres-RSRP-List, pre-resolved
    'txPercentage',     0.2, ...                   % sl-TxPercentage
    'allowedPeriodsMs', 100, ...                   % sl-ResourceReservePeriodList
    'T2minRaw',         20, ...                    % sl-SelectionWindow
    'slProbResourceKeep', 0.4, ...
    'slReselectAfter',  Inf);                      % not configured: never fires on unused periods

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
    'lcid',        4);

% ---- transport block size, from the real clause 8.1.3.2 arithmetic ---------
% L_subCH is DERIVED here, not taken from policy.defaults: the default is a documented stand-in
% for exactly this arithmetic, and using it blind is how a payload gets transmitted at the wrong
% size. The MAC PDU overhead is measured by building a PDU with muxSlSch rather than guessed --
% the subheader widths are clause 6.2.4's and belong to that function.
[~, Qm, R] = phy.ts38214.mcsTableSelect(scen.policy.mcs, '', 0);
scen.slLengthSymbols = 12;
scen.slPsfchPeriod   = 0;                % PSFCH disabled in the broadcast baseline
nReSci1 = 2 * scen.subchSizeRb * 12;     % PSCCH: 2 symbols over one sub-channel's PRBs

tbsBytesByLsubCH = zeros(1, scen.numSubchannel);
for L = 1:scen.numSubchannel
    nPrbAlloc = L * scen.subchSizeRb;
    nReSci2   = 2 * nPrbAlloc;           % 2nd-stage SCI, a modest fixed share of the allocation
    bits = phy.ts38214.tbsDetermine(Qm, R, 1, nPrbAlloc, scen.slLengthSymbols, ...
        scen.slPsfchPeriod, false, 0, [2 3], nReSci1, nReSci2);
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

% ---- geometry: a line of UEs, stationary -----------------------------------
scen.nUe   = nUe;
scen.spacingM = 20;
scen.posXY = [(0:nUe - 1)' * scen.spacingM, zeros(nUe, 1)];

% ---- the one source of randomness -----------------------------------------
% Every module below takes its draws as inputs; this is where they come from, and a seed
% reproduces a run exactly. +harness/CLAUDE.md's determinism test rests on this being the only
% stream in the simulator.
scen.seed   = seed;
scen.stream = RandStream('mt19937ar', 'Seed', seed);
end
