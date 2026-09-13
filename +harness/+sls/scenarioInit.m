function scen = scenarioInit(nUe, seed, castLabel, ov)
%scenarioInit Build the baseline system-level scenario.
%Spec:   none -- scenario configuration. Every 3GPP quantity in it is resolved through the
%        package that owns it (poolSlotMap, mcsTableSelect, tbsDetermine, policy.defaults).
%Inputs: nUe        integer, >=2 -- number of UEs
%        seed       integer -- RNG seed. The ONE source of randomness in a run
%        ov         scalar struct, optional -- primitive overrides applied BEFORE the
%                   derivations that consume them, so a caller can change the MCS or the pool
%                   geometry and have the transport block table, L_subCH, the escalation bound
%                   and the measurement windows all follow. simConfig via
%                   harness.sls.scenarioFromConfig is the intended caller; every field is
%                   optional and anything absent keeps the default below.
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

if nargin < 3 || isempty(castLabel)
    castLabel = 'broadcast';
end
if nargin < 4
    ov = struct();
end
if ~(nUe >= 2 && mod(nUe, 1) == 0)
    error('sls:scenarioInit:badNUe', 'scenarioInit: nUe must be an integer >= 2, got %s', num2str(nUe));
end
if ~any(strcmp(castLabel, {'broadcast', 'unicast'}))
    error('sls:scenarioInit:badCast', 'scenarioInit: castLabel must be ''broadcast'' or ''unicast'', got ''%s''', castLabel);
end
scen.castLabel = castLabel;
scen.isUnicast = strcmp(castLabel, 'unicast');

scen.mu            = ovGet(ov, 'mu', 1);              % 30 kHz SCS, the FR1 V2X numerology
scen.slotsPerMs    = 2^scen.mu;
scen.numSubchannel = ovGet(ov, 'numSubchannel', 10);
scen.subchSizeRb   = ovGet(ov, 'subchSizeRb', 10);    % sl-SubchannelSize
scen.nPrb          = scen.numSubchannel * scen.subchSizeRb;
scen.startRb       = 0;

% ---- the pool: every slot is a sidelink slot (the Mode-2 baseline) ----------
[scen.physOfLogical, scen.logicalOfPhys, scen.TmaxPrime] = harness.poolAllSlots(scen.mu);

% ---- radio ----------------------------------------------------------------
scen.radio = struct( ...
    'fcHz',          ovGet(ov, 'fcHz', 5.9e9), ...    % ITS band
    'bwHz',          scen.nPrb * 12 * 30e3, ...   % PRBs x 12 subcarriers x 30 kHz
    'noiseFigureDb', ovGet(ov, 'noiseFigureDb', 9), ...
    'plModel',       []);                % filled in below, once the geometry is known

% The path loss model, chosen by NAME through the one entry point. Swapping it is a one-line
% change here and touches no other file -- which is what harness.chanmodel.pathlossModel and
% harness.chanmodel.pathloss exist to guarantee.
%
% RMa is TR 38.901's Rural Macro, a CELLULAR model applied to a V2V geometry; see
% harness.chanmodel.pathlossRma for what that does and does not justify. TR 37.885's V2V models
% are the ones a sidelink study should use, and neither a local PDF nor a toolbox
% implementation exists for them.
%
% LOS is FIXED rather than drawn per link. TR 38.901 Table 7.4.2-1 gives a distance-dependent
% LOS probability and there is no local PDF to extract it from, so a fixed mode is stated
% rather than a recalled formula quietly applied. 'los' is the optimistic bound, 'nlos' the
% pessimistic one, and the two bracket the real answer.
scen.radio.plModel = harness.chanmodel.pathlossModel('rma', struct( ...
    'fcHz',    scen.radio.fcHz, ...
    'losMode', ovGet(ov, 'losMode', 'los'), ...
    'hTxM',    ovGet(ov, 'hTxM', 1.5), ...            % vehicle-mounted antenna
    'hRxM',    ovGet(ov, 'hRxM', 1.5)));
scen.pCmaxDbm     = ovGet(ov, 'pCmaxDbm', 23);     % P_CMAX; slPowerControl is a max-power-always policy for now
% The BLER table is measured under ONE channel and speed, and harness.phyabs.blerLookup
% raises rather than interpolating across models -- so these two are a KEY into that table,
% not a knob that changes the propagation. Changing them without measuring a matching table
% is an error by construction, which is the point.
scen.channelModel = ovGet(ov, 'channelModel', 'tdld');
scen.speedKmh     = ovGet(ov, 'speedKmh', 120);
% PSCCH decodes further out than PSSCH because its code rate is far lower and does not move
% with the data's -- NOT because it is narrower: +harness/+chanmodel/slotSinr shows signal and
% noise scale together with the band, leaving the SNR identical. There is no
% pscchEffectiveMcs knob any more: the control curve is measured directly by +harness/+lls/ and
% read through harness.phyabs.pscchBler.

% ---- selection policy ------------------------------------------------------
scen.policy = phy.rx.policy.defaults();
% Policy overrides go in BEFORE the transport block table is built, so a changed MCS changes
% the table, which changes L_subCH, which changes the TB size. Applying them afterwards would
% leave every one of those derived from the old value.
scen.policy.mcs       = ovGet(ov, 'mcs', scen.policy.mcs);
scen.policy.prsvpTxMs = ovGet(ov, 'prsvpTxMs', scen.policy.prsvpTxMs);
scen.policy.numRetx   = ovGet(ov, 'numRetx', scen.policy.numRetx);
scen.pool = struct( ...
    'sensingWindowMs',  ovGet(ov, 'sensingWindowMs', 100), ...
    'thresholdListDbm', repmat(ovGet(ov, 'thresRsrpDbm', -110), 1, 64), ...   % sl-Thres-RSRP-List, pre-resolved
    'txPercentage',     ovGet(ov, 'txPercentage', 0.2), ...                   % sl-TxPercentage
    'allowedPeriodsMs', 100, ...                   % sl-ResourceReservePeriodList
    'T2minRaw',         ovGet(ov, 'selectionWindowRaw', 20), ...                    % sl-SelectionWindow
    'slProbResourceKeep', ovGet(ov, 'probResourceKeep', 0.4), ...
    'slReselectAfter',  Inf, ...
    'slPreemptionEnable', ovGet(ov, 'preemptionEnable', 'enabled'), ...
    'threshSRssiCbrDbm', ovGet(ov, 'threshSRssiCbrDbm', -94), ...           % sl-Thres-RSSI-CBR, pre-resolved to dBm
    'timeWindowSizeCBR', 'ms100', ...       % sl-TimeWindowSizeCBR-r16
    'timeWindowSizeCR',  'ms1000', ...      % sl-TimeWindowSizeCR-r16
    'cbrRangeUpperBounds', ovGet(ov, 'cbrRangeUpperBounds', [0.2 0.4 0.6 0.8 1.0]), ...  % one SL-CBR-LevelsConfig, as ratios
    'crLimitByLevel', ovGet(ov, 'crLimitByLevel', [1.0 0.6 0.3 0.12 0.05]));        % sl-CR-Limit per CBR level, pre-resolved       % sl-PreemptionEnable-r16; '' disables it entirely                      % not configured: never fires on unused periods

% ---- traffic: one or more FLOWS, each on its own logical channel -----------
% A flow is one application generator mapped to one STCH. Several of them on one UE is the
% case clause 5.22.1.4.1's logical channel prioritisation exists for, and the MAC SAP has been
% multi-channel since +sap/lchInit -- only this harness was single-flow. The scalar `pqi`,
% `periodMs`, `sizeBytes` and `lcid` overrides remain as the shorthand for the one-flow case;
% passing `flows` supersedes them. They are a shorthand, not a second source of truth: they
% build flows(1) and are then never read again.
scen.flows = buildFlows(ov, scen.slotsPerMs);
scen.nFlow = numel(scen.flows);

% ---- transport block size, from the real clause 8.1.3.2 arithmetic ---------
% L_subCH is DERIVED here, not taken from policy.defaults: the default is a documented stand-in
% for exactly this arithmetic, and using it blind is how a payload gets transmitted at the wrong
% size. The MAC PDU overhead is measured by building a PDU with muxSlSch rather than guessed --
% the subheader widths are clause 6.2.4's and belong to that function.
[~, Qm, R] = phy.ts38214.mcsTableSelect(scen.policy.mcs, '', 0);
scen.slLengthSymbols = ovGet(ov, 'slLengthSymbols', 12);
% PSFCH costs transport-block capacity: clause 8.1.3.2 subtracts the PSFCH symbols from N_RE,
% so enabling feedback shrinks every TB in the pool whether or not a given transmission uses
% it. Computing the TBS table with the real period is what makes that cost visible rather than
% free.
if scen.isUnicast
    scen.slPsfchPeriod = ovGet(ov, 'psfchPeriodSlots', 1);   % sl-PSFCH-Period
else
    scen.slPsfchPeriod = 0;              % disabled in the broadcast baseline
end
% PSCCH occupies sl-FreqResourcePSCCH PRBs over sl-TimeResourcePSCCH symbols, inside the
% LOWEST sub-channel of the PSSCH allocation (clause 8.1.2.2). These are the values the TBS
% arithmetic below already assumes for N_RE^SCI1, so they are named once and reused rather than
% written twice with a chance of drifting apart.
scen.pscchPrb        = ovGet(ov, 'pscchPrb', scen.subchSizeRb);
scen.pscchSymbols    = ovGet(ov, 'pscchSymbols', 2);
scen.maxNumPerReserve = ovGet(ov, 'maxNumPerReserve', 2);   % sl-MaxNumPerReserve
scen.reservePeriodListMs = unique([0, 100, scen.policy.prsvpTxMs]);   % sl-ResourceReservePeriodList, ms
scen.minTimeGapPsfch = ovGet(ov, 'minTimeGapPsfch', 2);     % sl-MinTimeGapPSFCH, pool slots
scen.psfchRbSetSize  = scen.numSubchannel * max(1, scen.slPsfchPeriod);  % M_PRB,set^PSFCH
scen.psfchNumMuxCsPair = 6;              % sl-NumMuxCS-Pair, N_CS^PSFCH
scen.psfchNtype        = 1;              % sl-PSFCH-CandidateResourceType = startSubCH
scen.slMaxTransNum             = 1 + scen.policy.numRetx + 2;
scen.slMaxNumConsecutiveDTX    = 4;
% Slots reserved at the end of the delay budget for the RECEIVER to decode. The PDB is a
% deadline for delivery, so the transmission deadline is the PDB less this. Subtracted inside
% phy.rx.policy.remainingPdbSlots, which keeps T2 = "the remaining PDB" legal in both of clause
% 8.1.4's branches -- see that function's header.
scen.decodeMarginSlots = ovGet(ov, 'decodeMarginSlots', 2);
% How long a receive Sidelink process may sit idle before it is released. A policy, not a clause
% deadline (clause 5.22.2.2.1 NOTE 1) -- see mac.harqRxAge -- and DERIVED from how long one TB's
% transmissions can legitimately span, which differs by cast type:
%
%   broadcast: every copy of a TB is CHAINED to the same SCI, so all of them fall within TRIV's
%              reach of the anchor -- 31 logical slots. One reservation period is six times that
%              and is what is used: generous without being loose.
%   unicast:   a NACK-driven retransmission lands in a LATER reservation period, so the span
%              runs to sl-MaxTransNum periods.
%
% The cast type also decides how many processes are under pressure, and it cuts the other way:
% in broadcast every audible neighbour is "interesting" (mac.sciInterest passes them all), while
% in unicast only the addressed peer is. The case needing the SHORT bound is exactly the case
% with many peers -- which is why a single bound for both was wrong. Measured at 50 UEs
% broadcast over 2000 slots, worst single UE: 16 of 16 processes occupied at a 1600-slot bound,
% 15 of 16 at 400, and 6 of 16 at 200.
periodSlots = phy.ts38214.reservationPeriodToSlots(scen.policy.prsvpTxMs, 10240 * 2^scen.mu);
if scen.isUnicast
    scen.rxProcStaleSlots = scen.slMaxTransNum * periodSlots;
else
    scen.rxProcStaleSlots = periodSlots;
end
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
%
% The probe SIZE matters, because clause 6.1.2's subheader is not a constant width: the F field
% selects an 8-bit or a 16-bit L field, so a 100-byte SDU costs one byte less than a 200-byte
% one. The probe therefore runs at the WIDEST subheader any configured flow will produce -- the
% largest SDU size, or 128 bytes if that is larger than any flow, since 128 is where L widens.
% Sizing the grant off a narrow-L measurement and then transmitting a wide-L PDU is a one-byte
% overrun, and mac.muxSlSch errors rather than truncating.
probeBytes = tbsBytesByLsubCH(end);
probeSize  = max(128, max([scen.flows.sizeBytes]));
% Two of them must fit in the probe, or the increment cannot be measured at all. When they do
% not -- a payload more than half the largest transport block -- the probe shrinks to the
% largest size that does fit, which is still at or above 128 and so still the wide-L case.
if 2 * probeSize + 32 > probeBytes
    probeSize = floor((probeBytes - 32) / 2);
end
if probeSize < 128
    error('sls:scenarioInit:probeTooSmall', 'scenarioInit: the largest transport block (%d bytes) cannot hold two 128-byte SDUs, so the per-SDU overhead cannot be measured', probeBytes);
end
oh = zeros(1, 2);
for nSdu = 1:2
    len = repmat(probeSize, 1, nSdu);
    [~, nPad, nInc] = mac.muxSlSch(1, 2, uint8(zeros(1, sum(len))), len, ...
        repmat(scen.flows(1).lcid, 1, nSdu), false, 0, 0, probeBytes);
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
biggest = max([scen.flows.sizeBytes]);
onePdu  = scen.macOverheadFixedBytes + scen.macOverheadPerSduBytes + biggest;
if onePdu > scen.maxTbsBytes
    error('sls:scenarioInit:sduTooLarge', 'scenarioInit: a %d-byte MAC PDU (a %d-byte SDU plus overhead) does not fit even L_subCH = %d (%d bytes) at MCS %d', onePdu, biggest, scen.numSubchannel, scen.maxTbsBytes, scen.policy.mcs);
end

scen.nUe      = nUe;
% Which UEs generate traffic. All of them by default; harness.sls.scenarioFromConfig narrows it
% to model a single link. A UE outside this mask still RECEIVES and still senses -- it is a
% silent neighbour, not an absent one, which is the distinction that makes a one-link scenario
% inside a populated pool possible.
scen.txUeMask = true(1, nUe);
scen.spacingM = ovGet(ov, 'spacingM', 20);
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
closestPl = harness.chanmodel.pathloss(scen.radio.plModel, scen.spacingM);
strongestRsrpDbm = scen.pCmaxDbm - closestPl;
scen.policy.maxEscalations = ceil((strongestRsrpDbm - min(scen.pool.thresholdListDbm)) / escalationStepDb) + 1;

% ---- geometry: a line of UEs, stationary -----------------------------------
% Per-UE sl-Priority, uniform by default. A vector rather than a scalar because pre-emption's
% comparison is STRICT (+mac/CLAUDE.md: only a numerically smaller sl-Priority pre-empts, or
% two same-priority UEs pre-empt each other indefinitely) -- so in a single-priority population
% clause 5.22.1.2a's pre-emption check can NEVER fire, by construction. Leaving priority a
% scalar would make that structural impossibility look like a wiring bug, and would make it
% impossible to tell the two apart.
% The priority of a UE's TRANSMISSION, which is not the same thing as the priority of a logical
% channel. Clause 5.22.1.4.1.1's sl-Priority is per channel and drives LCP; the priority in
% SCI-1A -- the one sensing, the RSRP thresholds, CR limits and pre-emption all compare -- is
% the priority of the data being sent, so with several flows multiplexed it is the HIGHEST of
% them (numerically the lowest). Derived here so a single-flow scenario is unchanged, and left
% as a plain vector so a caller can override it per UE to build a mixed-priority population.
scen.prioByUe = repmat(min([scen.flows.prio]), 1, nUe);

% ---- the one source of randomness -----------------------------------------
% Every module below takes its draws as inputs; this is where they come from, and a seed
% reproduces a run exactly. +harness/CLAUDE.md's determinism test rests on this being the only
% stream in the simulator.
scen.seed   = seed;
scen.stream = RandStream('mt19937ar', 'Seed', seed);
end

% =========================================================================
function v = ovGet(ov, name, dflt)
%ovGet One override field, or its default. Empty counts as absent, so a config may carry a
%placeholder [] for a value it does not wish to set (pdbMsOverride uses exactly that).
if isfield(ov, name) && ~isempty(ov.(name))
    v = ov.(name);
else
    v = dflt;
end
end

function flows = buildFlows(ov, slotsPerMs)
%buildFlows Resolve the traffic FLOWS: one application generator per sidelink logical channel.
%Spec:   the flow itself is ours, but every field it resolves is not -- pqi/prio/pdbMs come from
%        TS 23.287 clause 5.4.4 Table 5.4.4-1 via +cfg/pqiTable, lcid is TS 38.321 Table 6.2.4-1
%        (4..19 is STCH), and pbr/bsd are clause 5.22.1.4.1.1's sl-PrioritisedBitRate and
%        sl-BucketSizeDuration.
%Inputs: ov          the override struct. `flows` supersedes the scalar shorthand
%        slotsPerMs  integer -- for the numerology conversion
%Outputs: flows  1 x nFlow struct array, one per logical channel
%
%WHY EVERY FLOW NEEDS A DISTINCT LCID
%-------------------------------------
%+sap/lchInit requires it, and so does the receiver: mac.demuxSlSch hands each subPDU back with
%its LCID and nothing else distinguishes two flows sharing one. Two generators on one LCID are
%one logical channel with twice the arrival rate, which is a different experiment.

if isfield(ov, 'flows') && ~isempty(ov.flows)
    raw = ov.flows;
else
    % The one-flow shorthand. Identical in effect to a one-element `flows`, and kept because
    % most scenarios are single-flow and should not have to write a struct array to say so.
    raw = struct('pqi', ovGet(ov, 'pqi', 55), 'periodMs', ovGet(ov, 'periodMs', 100), ...
        'sizeBytes', ovGet(ov, 'sizeBytes', 300), 'lcid', ovGet(ov, 'lcid', 4), ...
        'pdbMsOverride', ovGet(ov, 'pdbMsOverride', []), 'nPackets', ovGet(ov, 'nPackets', inf));
end

t = cfg.pqiTable();
flows = repmat(flowTemplate(), 1, numel(raw));
for f = 1:numel(raw)
    r = raw(f);
    pqi = fGet(r, 'pqi', 55);
    row = t([t.PQI] == pqi);
    if isempty(row)
        error('sls:scenarioInit:unknownPqi', 'buildFlows: flow %d asks for PQI %d, which is not a row of cfg.pqiTable', f, pqi);
    end
    periodMs = fGet(r, 'periodMs', 100);
    if ~(periodMs > 0 && mod(periodMs * slotsPerMs, 1) == 0)
        error('sls:scenarioInit:badPeriod', 'buildFlows: flow %d has periodMs %g, which is not a whole number of slots at this numerology', f, periodMs);
    end
    flows(f).lcid        = fGet(r, 'lcid', 3 + f);      % Table 6.2.4-1: STCH starts at 4
    flows(f).pqi         = pqi;
    flows(f).prio        = row.priority;
    flows(f).pdbMs       = fGet(r, 'pdbMsOverride', row.PDB_ms);
    flows(f).periodMs    = periodMs;
    flows(f).periodSlots = periodMs * slotsPerMs;
    flows(f).sizeBytes   = fGet(r, 'sizeBytes', 300);
    flows(f).nPackets    = fGet(r, 'nPackets', inf);
    % sl-PrioritisedBitRate defaults to exactly this flow's own arrival rate, so the first
    % (SBj-limited) pass of clause 5.22.1.4.1.2 can carry the flow's steady-state load and no
    % more. Leaving it at zero makes the buckets inert and hands everything to the second pass;
    % setting it far above the arrival rate makes the first pass unbounded and the priority
    % ordering between flows stops meaning anything.
    flows(f).pbrBytesPerSec = fGet(r, 'pbrBytesPerSec', flows(f).sizeBytes * 1000 / periodMs);
    flows(f).bsdSeconds     = fGet(r, 'bsdSeconds', periodMs / 1000);
end

if numel(unique([flows.lcid])) ~= numel(flows)
    error('sls:scenarioInit:duplicateLcid', 'buildFlows: every flow needs its own logical channel, got LCIDs %s', mat2str([flows.lcid]));
end
if any([flows.lcid] < 4 | [flows.lcid] > 19)
    error('sls:scenarioInit:notStch', 'buildFlows: STCH is LCID 4..19 in Table 6.2.4-1, got %s', mat2str([flows.lcid]));
end
end

function f = flowTemplate()
f = struct('lcid', 4, 'pqi', 55, 'prio', 5, 'pdbMs', 100, 'periodMs', 100, ...
    'periodSlots', 200, 'sizeBytes', 300, 'nPackets', inf, ...
    'pbrBytesPerSec', 3000, 'bsdSeconds', 0.1);
end

function v = fGet(r, name, dflt)
%fGet One field of a flow spec, or its default. Empty counts as absent, as in ovGet.
if isfield(r, name) && ~isempty(r.(name))
    v = r.(name);
else
    v = dflt;
end
end
