function [ue, iq, tx] = txSlot(ue, n)
%txSlot One slot of the transmit side: timers, resource selection, LCP, RLC, MAC PDU, SCI, IQ.
%Spec:   none itself; the order is +phy/CLAUDE.md's runtime contract (... MAC -> TX -> POWER) and
%        every step is the owning package's:
%          TS 38.323 5.3        PDCP discardTimer -> indicated to RLC (pdcp.pdcpTxTimer, rlc.*Discard)
%          TS 38.322 5.3.3.4    t-PollRetransmit, and the AM receive timers (rlc.amTxTimer/amRxTimer)
%          TS 38.321 5.22.1.4.1.1  SBj (mac.slLcpBucket)
%          TS 38.321 5.22.1.1 + TS 38.214 8.1.4  Mode-2 selection of a grant for a single MAC PDU:
%                               phy.rx.policy.selectionRequest -> phy.ts38214.candidateSet ->
%                               phy.rx.policy.resourcePickChained (initial + blind retx resources)
%          TS 38.321 5.22.1.4.1 LCP (mac.slLcp), then each logical channel's RLC fills its share
%                               (rlc.umTxBuild / rlc.amTxOpportunity)
%          TS 38.321 6.1.6      MAC PDU (mac.muxSlSch)
%          TS 38.321 5.22.1.3   HARQ (mac.harqNewTransmission / harqRetransmission / harqFlush)
%          TS 38.212 8.3.1.1, 8.4.1.1  SCI-1A / SCI-2A fields, incl. TRIV/FRIV (TS 38.214 8.1.5)
%          stack.phySlotTx      PHY to IQ
%Inputs: ue  struct from stack.ueInit
%        n   integer, >=0 -- the slot (physical == logical in the supported pool)
%Outputs: ue  updated
%         iq  nSamples x 1 complex, or empty when this UE does not transmit in slot n
%         tx  struct describing what was sent (empty struct array when nothing):
%             .slot .startSubch .LsubCH .prio .peerL2Id .cast .harqId .ndi .rv .tbBytes
%             .lcids .sduBytes (per MAC SDU) .isRetx
%
%PRIORITY PATH, END TO END (the trace +sdap/CLAUDE.md asks for): PQI --sdap.sdapTxMap--> SLRB
%--its RLC bearer's sl-MAC-LogicalChannelConfig--> sl-Priority --> LCP order here, prio_TX of the
%selection (TS 38.214 8.1.4 p_j via candidateSet), and SCI-1A 'Priority' = the highest-priority
%logical channel in the MAC PDU (TS 38.321 5.22.1.3.1).

g = ue.g;
nowMs = n * g.slotMs;
iq = complex(zeros(0, 1));
tx = repmat(struct('slot', 0, 'startSubch', 0, 'LsubCH', 0, 'prio', 0, 'peerL2Id', 0, 'cast', 0, ...
    'harqId', 0, 'ndi', 0, 'rv', 0, 'tbBytes', 0, 'lcids', zeros(1, 0), 'sduBytes', zeros(1, 0), 'isRetx', false), 1, 0);

% ---- timers, buckets -----------------------------------------------------------
for i = 1:numel(ue.ent)
    e = ue.ent(i);
    if e.isTx
        [e.pdcpTx, dCount] = pdcp.pdcpTxTimer(e.pdcpTx, nowMs);
        ue.stats.pdcpTimerExpired = ue.stats.pdcpTimerExpired + numel(dCount);
        for c = dCount
            if strcmp(e.mode, 'am')
                [e.rlcTx, gone] = rlc.amTxDiscard(e.rlcTx, c);
            else
                [e.rlcTx, gone] = rlc.umTxDiscard(e.rlcTx, c);
            end
            ue.stats.lostToDiscard = ue.stats.lostToDiscard + gone;   % discarded unsent = LOST
        end
        e.Sbj = mac.slLcpBucket(e.Sbj, e.pbr, e.bsd, g.slotMs / 1000);
    end
    if strcmp(e.mode, 'am')
        [e.rlcTx, ~, mr] = rlc.amTxTimer(e.rlcTx, nowMs);
        ue.stats.maxRetx = ue.stats.maxRetx + numel(mr);
        e.rlcRx = rlc.amRxTimer(e.rlcRx, nowMs);
    end
    ue.ent(i) = e;
end

% ---- PSFCH this UE owes in this slot (HARQ-ACK for PSSCH it received, TS 38.213 16.3) -----
nsf = mod(n, 10 * 2^g.mu);
grid = complex(zeros(g.nSubcarriers, g.NsymbSlot));
hasPsfch = false;
if ~isempty(ue.psfchOut)
    due = [ue.psfchOut.slot] == n;
    for f = ue.psfchOut(due)
        grid = stack.psfchGridAdd(grid, g, nsf, f.prb, f.m0, f.ackBit);
        hasPsfch = true;
        ue.stats.psfchSent = ue.stats.psfchSent + 1;
    end
    ue.psfchOut = ue.psfchOut(~due);
end

% ---- grant housekeeping: resources that went by without a transmission ------------------
ue = grantHousekeeping(ue, n);
% ---- re-evaluation and pre-emption at m - T3 (TS 38.321 5.22.1.2a) ----------------------
if ue.k.reevaluation
    ue = reevalPreempt(ue, n);
end

% ---- selection: one grant per Destination that has data and no grant -----------------
% TS 38.321 5.22.1.1 lets the MAC entity hold a selected sidelink grant per Sidelink process, so
% Destinations do not queue behind each other: a unicast grant drawn far into its 200 ms window
% must not hold a 100 ms broadcast flow hostage (the first version kept ONE grant per UE, and the
% broadcast packets behind it expired in PDCP -- counted, but lost for no radio reason).
ue = selectAll(ue, n, nowMs);
[ue, grid, tx, hasPssch] = psschPart(ue, n, nowMs, nsf, grid);
ue.lastTx = struct('slot', n, 'pssch', hasPssch, 'psfch', hasPsfch);
if hasPssch || hasPsfch
    % One waveform for the slot; slPowerControl is max-power, so PSSCH and PSFCH share P_CMAX.
    pTxDbm = phy.ts38213.slPowerControl('PSSCH', ue.k.pCmaxDbm, 0, 0, 0, g.mu, g.nRbBwp);
    iq = stack.slotModulate(g, grid, nsf, pTxDbm);
end
end

% =========================================================================================
function [ue, grid, tx, hasPssch] = psschPart(ue, n, nowMs, nsf, grid)
% The PSCCH/PSSCH of a grant resource falling in slot n, if any, added to the slot grid.
g = ue.g;
hasPssch = false;
tx = repmat(struct('slot', 0, 'startSubch', 0, 'LsubCH', 0, 'prio', 0, 'peerL2Id', 0, 'cast', 0, ...
    'harqId', 0, 'ndi', 0, 'rv', 0, 'tbBytes', 0, 'lcids', zeros(1, 0), 'sduBytes', zeros(1, 0), 'isRetx', false), 1, 0);
gi = 0;
for q = 1:numel(ue.grants)
    gq = ue.grants(q);
    if gq.next <= numel(gq.slots) && gq.slots(gq.next) == n
        gi = q;
    end
end
if gi == 0
    return;
end
gr = ue.grants(gi);

% ---- congestion control (TS 38.214 8.1.6): drop this transmission if it would break a CR limit --
% The resource is left unused; grantHousekeeping steps past it next slot (a dropped initial
% transmission leaves the data in RLC for the grant's next resource or a new selection).
prioNow = gr.prio;
if gr.proc == 0
    prioNow = destPrio(ue, gr.peerL2Id, gr.cast, nowMs, gr.selPrio);
end
[ok, ue.cbrLast] = congestionOk(ue, n, gr.L, prioNow);
if ~ok
    ue.stats.ccDropped = ue.stats.ccDropped + 1;
    return;
end

% ---- the MAC PDU ------------------------------------------------------------------
% A transmission is a retransmission once the grant holds a MAC PDU. Not "next > 1": a dropped
% or missed first resource leaves the grant's next resource to carry the initial transmission.
isRetx = gr.proc > 0;
if ~isRetx
    [ue, tb, lcids, sduLen, prio, harqFb] = buildMacPdu(ue, gr, nowMs);
    if isempty(tb)
        % Nothing to send. A dynamic grant is simply not used; an SPS grant skips this period
        % (it counts toward sl-ReselectAfter) and keeps its resources for the next one.
        ue = dropOrSkip(ue, gi, gr, 'unused');
        return;
    end
    % Sidelink process: round-robin over the free ones (the choice is the UE's, TS 38.321
    % 5.22.1.3.1). NOT the lowest free one: that reuses process 1 for every Destination in turn,
    % and since NDI toggles per process, a Destination's next TB on it can carry the SAME NDI as
    % its last -- the receiver keys on (source, destination, process) and discards it as a
    % duplicate of a TB it already delivered (5.22.2.2.1 NOTE 1a, within its window). Found when
    % a second broadcast grant during a unicast exchange lost a broadcast packet at 60 dB SNR.
    nP = numel(ue.harq.bufferOccupied);
    order = mod(ue.nextProc - 1 + (0:nP - 1), nP) + 1;
    proc = order(find(~ue.harq.bufferOccupied(order), 1));
    if isempty(proc)
        ue = dropOrSkip(ue, gi, gr, 'unused');      % every Sidelink process busy
        return;
    end
    ue.nextProc = mod(proc, nP) + 1;
    [ue.harq, ndi, rv] = mac.harqNewTransmission(ue.harq, proc, ue.k.rvSequence, -1, harqFb);
    gr.proc = proc; gr.ndi = double(ndi); gr.prio = prio; gr.harqFb = harqFb;
    gr.tb = tb; gr.lcids = lcids; gr.sduLen = sduLen;
    ue.stats.macPdus = ue.stats.macPdus + 1;
else
    [ue.harq, rv, ignored] = mac.harqRetransmission(ue.harq, gr.proc, ue.k.rvSequence);
    if ignored
        ue = dropOrSkip(ue, gi, gr, 'done');
        return;
    end
end

% ---- SCI ----------------------------------------------------------------------------
% An SPS grant entering its last period (counter 1) makes its keep draw now, before the SCI, so
% the reservation it announces can say whether the resources will still be there next period.
if gr.isPeriodic && gr.mg.counter == 1 && isnan(gr.keepDrawPre)
    gr.keepDrawPre = rand(ue.rng);
end
remSlots = gr.slots(gr.next:end);
remSub = gr.subch(gr.next:end);
N = min(numel(remSlots), g.maxNumPerReserve);
t = [0 0]; s = [0 0];
t(1:N - 1) = remSlots(2:N) - remSlots(1);
s(1:N - 1) = remSub(2:N);
sci1a = struct('priority', gr.prio, ...
    'friv', phy.ts38212.frivEncode(s(1), s(2), gr.L, g.numSubchannel, g.maxNumPerReserve), ...
    'triv', phy.ts38212.trivEncode(N, t(1), t(2), g.maxNumPerReserve), ...
    'reservationPeriodIndex', announcedPeriodIndex(ue, gr), 'dmrsPatternIndex', g.dmrsPatternIndex, 'sci2Format', 'A', ...
    'betaOffsetIndex', g.betaOffsetIndex, 'numDmrsPort', 0, 'mcs', g.mcs, ...
    'additionalMcsTableIndex', 0, 'psfchOverhead', 0);
castSci = sciCastType(gr.cast);
srcId8 = mod(ue.srcL2Id, 2^8);
sci2 = struct('harqProcessNumber', gr.proc - 1, 'ndi', gr.ndi, 'rv', rv, ...
    'sourceID', srcId8, 'destinationID', mod(gr.peerL2Id, 2^16), ...
    'harqFeedbackEnabled', double(gr.harqFb), 'castType', castSci, 'csiRequest', 0);
[~, grid] = stack.phySlotTx(g, remSub(1), gr.L, nsf, sci1a, sci2, gr.tb, rv, NaN, grid);
hasPssch = true;
ue.db = phy.ts38214.sensingDbMarkUnmonitored(ue.db, n);   % half duplex: this slot is not sensed
ue.stats.transmissions = ue.stats.transmissions + 1;
% Own usage for SL CR (TS 38.215 5.1.26: "sub-channels used for its transmissions"), per SCI priority.
ue.txHist(end + 1, :) = [n, gr.L, gr.prio];
ue.txHist = ue.txHist(ue.txHist(:, 1) > n - g.crWindowSlots, :);

tx = struct('slot', n, 'startSubch', remSub(1), 'LsubCH', gr.L, 'prio', gr.prio, 'peerL2Id', gr.peerL2Id, ...
    'cast', gr.cast, 'harqId', gr.proc - 1, 'ndi', gr.ndi, 'rv', rv, 'tbBytes', numel(gr.tb) / 8, ...
    'lcids', gr.lcids, 'sduBytes', gr.sduLen, 'isRetx', isRetx);

if gr.isPeriodic
    gr.mg = mac.grantOnTransmission(gr.mg, gr.next);   % this period's opportunity gr.next is used
end
gr.next = gr.next + 1;
isLast = gr.next > numel(gr.slots);
if gr.harqFb
    % TS 38.321 5.22.1.3.2 / TS 38.213 16.3: expect the HARQ-ACK on the PSFCH resource derived from
    % this PSSCH's sub-channel and our Source ID, in the first PSFCH slot >= sl-MinTimeGapPSFCH later.
    [prb, m0] = stack.psfchResourceFor(g, remSub(1), srcId8);
    ue.psfchWait(end + 1) = struct('slot', phy.ts38213.psfchTiming(n, g.minTimeGapPsfch, g.psfchPeriod), ...
        'proc', gr.proc, 'prb', prb, 'm0', m0, 'isLast', isLast);
end
if isLast
    % Last reserved resource. Without feedback the blind-retransmission TB is done: free the
    % process. With feedback the process stays busy until that last PSFCH is resolved (rxSlot).
    if ~gr.harqFb
        ue.harq = mac.harqFlush(ue.harq, gr.proc);
    end
    ue = dropOrSkip(ue, gi, gr, 'done');
else
    ue.grants(gi) = gr;
end
end

% =========================================================================================
function ue = dropOrSkip(ue, gi, gr, why)
% The end of a grant's use for this period. A dynamic grant (one MAC PDU) is finished; an SPS
% grant closes the period (counter, keep draw, unused count) and either moves to the next period's
% resources or is released, in which case the next data triggers a new selection.
if ~gr.isPeriodic
    ue.grants(gi) = [];
    return;
end
if strcmp(why, 'unused')
    ue.stats.spsUnusedPeriods = ue.stats.spsUnusedPeriods + 1;
end
[ue, gr, keep] = spsPeriodEnd(ue, gr);
if keep
    ue.grants(gi) = gr;
else
    ue.grants(gi) = [];
end
end

function [ue, gr, keep] = spsPeriodEnd(ue, gr)
% TS 38.321 5.22.1.1 / 5.22.1.2 at the end of one reservation period, through the normative MAC:
% grantOnPeriodEnd decrements SL_RESOURCE_RESELECTION_COUNTER and ages the unused-period count;
% at 0 the sl-ProbResourceKeep draw keeps the resources (grantOnKeep, a new counter) or releases
% them; sl-ReselectAfter consecutive unused periods also release them.
g = ue.g;
kd = rand(ue.rng);
if ~isnan(gr.keepDrawPre), kd = gr.keepDrawPre; end
[gr.mg, ~] = mac.grantOnPeriodEnd(gr.mg, kd);
ue.stats.spsPeriods = ue.stats.spsPeriods + 1;
keep = true;
if gr.mg.counter == 0
    if mac.keepDecision(gr.mg.keepDraw, g.probResourceKeep)
        [lo, hi] = mac.creselCounterRange(gr.prsvpMs);
        gr.mg = mac.grantOnKeep(gr.mg, lo + floor(rand(ue.rng) * (hi - lo + 1)));
        ue.stats.spsKept = ue.stats.spsKept + 1;
    else
        keep = false;
    end
end
if keep && gr.mg.consecutiveUnusedPeriods >= g.reselectAfter
    keep = false;
end
if ~keep
    ue.stats.spsReleased = ue.stats.spsReleased + 1;
    return;
end
gr.slots = gr.slots + gr.periodSlots;
gr.periodIdx = gr.periodIdx + 1;
gr.next = 1; gr.proc = 0; gr.keepDrawPre = NaN;
gr.tb = false(0, 1); gr.lcids = zeros(1, 0); gr.sduLen = zeros(1, 0);
end

function idx = announcedPeriodIndex(ue, gr)
% SCI-1A's resource reservation period (TS 38.212 8.3.1.1), present only with
% sl-MultiReserveResource. A dynamic grant announces 0 ms. An SPS grant announces P_rsvp_TX, except
% in its last period when it will not be kept: TS 38.321 5.22.1.1 sets the reservation interval
% to 0 ms there, so neighbours stop excluding resources nobody will use. That needs the keep draw
% before the period's transmission: psschPart makes it at counter 1 and spsPeriodEnd reuses it.
g = ue.g;
idx = 0;
if ~g.multiReserve
    return;
end
pMs = 0;
if gr.isPeriodic
    pMs = gr.prsvpMs;
    if gr.mg.counter == 1 && ~isnan(gr.keepDrawPre) && ~mac.keepDecision(gr.keepDrawPre, g.probResourceKeep)
        pMs = 0;                                  % last period, will be released: announce 0 ms
    end
end
idx = phy.ts38213.reservationPeriodIndex(pMs, g.reservePeriodListMs);
end

function ue = grantHousekeeping(ue, n)
% Resources whose slot has passed without a transmission: another grant took the slot (one PSSCH
% per slot), or the UE was busy. They are skipped; a grant with nothing left is finished (dynamic)
% or closes its period (SPS). Without this a grant whose resource was missed would wait forever.
q = 1;
while q <= numel(ue.grants)
    gr = ue.grants(q);
    moved = false;
    while gr.next <= numel(gr.slots) && gr.slots(gr.next) < n
        gr.next = gr.next + 1; moved = true;
        ue.stats.missedResources = ue.stats.missedResources + 1;
    end
    if moved && gr.next > numel(gr.slots)
        if gr.proc > 0 && ~gr.harqFb
            ue.harq = mac.harqFlush(ue.harq, gr.proc);
        end
        nBefore = numel(ue.grants);
        ue = dropOrSkip(ue, q, gr, 'done');
        if numel(ue.grants) < nBefore, continue; end
    elseif moved
        ue.grants(q) = gr;
    end
    q = q + 1;
end
end

% =========================================================================================
function ue = selectAll(ue, n, nowMs)
% One selection per Destination with data and no unused grant, highest-priority Destination first
% so it gets first pick of the window.
%
% TS 38.321 5.22.1.2, "pdbNotMet": a grant not yet used for its MAC PDU whose first resource falls
% after the remaining PDB of the data now waiting is cleared and reselected. Without it, all
% broadcast flows share one Destination -- so one grant -- and an event-triggered DENM (20 ms
% PDB) waited on the grant a CAM (100 ms) had drawn 30 ms out: delivered late, or discarded in
% PDCP (found by the first field run, harness.field). NOTE 2 leaves the response to the UE; the
% gate is the one +harness/CLAUDE.md records -- reselect only while more than T_proc,1 remains,
% or the UE thrashes, clearing grant after grant none of which can make the deadline.
% A grant whose MAC PDU is already built (next > 1, retransmitting) does not block: new data gets
% its own grant and Sidelink process (5.22.1.1 allows one per process).
g = ue.g;
tProc1 = phy.ts38214.procTimeSelection(g.mu);
[avail, ~] = volumes(ue, nowMs);
dest = zeros(0, 3);                                    % [peer cast prio]
for i = find(avail > 0)
    e = ue.ent(i);
    if any(dest(:, 1) == e.peerL2Id & dest(:, 2) == e.cast)
        k = find(dest(:, 1) == e.peerL2Id & dest(:, 2) == e.cast, 1);
        dest(k, 3) = min(dest(k, 3), e.prio);
        continue;
    end
    unused = find([ue.grants.peerL2Id] == e.peerL2Id & [ue.grants.cast] == e.cast & [ue.grants.next] == 1);
    if ~isempty(unused)
        deadline = destDeadline(ue, e.peerL2Id, e.cast, nowMs);
        late = ue.grants(unused(1)).slots(1) * g.slotMs >= deadline;   % deadline slot: already discarded
        % TS 38.321 5.22.1.2: an SPS grant that cannot accommodate the pending data, where the MAC
        % entity selects not to segment, is reselected. The grant was sized when selected; a
        % larger load since then would otherwise be segmented across periods, a period each.
        tooSmall = false;
        if ue.grants(unused(1)).isPeriodic
            inD = find([ue.ent.isTx] & [ue.ent.peerL2Id] == e.peerL2Id & [ue.ent.cast] == e.cast);
            [~, dph] = volumes(ue, nowMs);
            tooSmall = sum(dph(inD)) + 4 > g.tbsBytesByLsubCH(ue.grants(unused(1)).L) && ...
                sum(dph(inD)) + 4 <= g.tbsBytesByLsubCH(end);
        end
        if ~((late || tooSmall) && (deadline - nowMs) / g.slotMs > tProc1)
            continue;
        end
        if tooSmall && ~late, ue.stats.spsTooSmall = ue.stats.spsTooSmall + 1; end
        ue.grants(unused) = [];
        ue.stats.pdbReselect = ue.stats.pdbReselect + 1;
    end
    dest(end + 1, :) = [e.peerL2Id, e.cast, e.prio]; %#ok<AGROW>
end
[~, order] = sort(dest(:, 3));
for k = order'
    ue = select(ue, n, nowMs, dest(k, 1), dest(k, 2));
end
end

function deadline = destDeadline(ue, peer, cast, nowMs)
% The earliest PDCP discard deadline at a Destination -- PDCP discard IS the PDB here (the stored
% config sets each sl-DiscardTimer to its flows' PDB). With no discardTimer running: either only
% RLC control PDUs (AM STATUS) are pending -- the peer's ARQ loop is waiting, so the short control
% deadline -- or the SLRB has no discard timer, so maxPdbMs.
inDest = find([ue.ent.isTx] & [ue.ent.peerL2Id] == peer & [ue.ent.cast] == cast);
deadline = Inf;
for i = inDest
    if ~isempty(ue.ent(i).pdcpTx.discExpiry)
        deadline = min(deadline, min(ue.ent(i).pdcpTx.discExpiry));
    end
end
if isfinite(deadline)
    return;
end
dataBytes = 0;
for i = inDest
    if strcmp(ue.ent(i).mode, 'am')
        dataBytes = dataBytes + rlc.amTxDataVolume(ue.ent(i).rlcTx);
    else
        dataBytes = dataBytes + rlc.umTxDataVolume(ue.ent(i).rlcTx);
    end
end
if dataBytes == 0
    deadline = nowMs + ue.k.controlPdbMs;
else
    deadline = nowMs + ue.k.maxPdbMs;
end
end

% =========================================================================================
function ue = select(ue, n, nowMs, peer, cast)
% Mode-2 selection of a single-MAC-PDU grant for one Destination.
g = ue.g;
[avail, dataPlusHdr] = volumes(ue, nowMs);
has = avail > 0;
inDest = find([ue.ent.isTx] & [ue.ent.peerL2Id] == peer & [ue.ent.cast] == cast);
prio = min([ue.ent(inDest(has(inDest))).prio]);
deadline = destDeadline(ue, peer, cast, nowMs);
% The last usable slot is the one BEFORE the deadline: timers run first in txSlot, so a resource
% in the deadline slot itself finds its SDU already discarded by PDCP. Counting that slot (floor of
% the difference) lost a CAM unsent in the first field run -- drawn exactly at its 100 ms PDB.
remSlots = max(0, ceil((deadline - nowMs) / g.slotMs) - 1 - ue.k.decodeMarginSlots);

SL_SCH_SUBHEADER = 4;                                 % TS 38.321 6.1.6
pduBytes = SL_SCH_SUBHEADER + sum(dataPlusHdr(inDest));
pduBytes = min(pduBytes, g.tbsBytesByLsubCH(end));
p = phy.rx.policy.defaults();
p.tbsBytesByLsubCH = g.tbsBytesByLsubCH;
p.mcs = g.mcs;
% P_rsvp_TX = 0: a single MAC PDU, no reservation, C_resel = 1. P_rsvp_TX > 0: sensing-based SPS,
% a grant for multiple MAC PDUs with SL_RESOURCE_RESELECTION_COUNTER drawn here (TS 38.321
% 5.22.1.1) and C_resel = 10 x counter (TS 38.214 8.1.4), so the candidate set also excludes
% resources whose FUTURE periods would collide with a sensed reservation.
isPer = ue.k.prsvpTxMs > 0;
counter = 0;
if isPer
    if ~g.multiReserve || ~any(g.reservePeriodListMs == ue.k.prsvpTxMs)
        error('stack:txSlot:noSps', ['txSlot: prsvpTxMs = %g ms needs sl-MultiReserveResource enabled and the period ' ...
            'in sl-ResourceReservePeriodList (%s ms)'], ue.k.prsvpTxMs, mat2str(g.reservePeriodListMs));
    end
    [lo, hi] = mac.creselCounterRange(ue.k.prsvpTxMs);
    counter = lo + floor(rand(ue.rng) * (hi - lo + 1));
end
p.prsvpTxMs = ue.k.prsvpTxMs;
[req, feasible] = phy.rx.policy.selectionRequest(n, g.mu, remSlots, prio, mac.cresel(counter, isPer), p, pduBytes);
if ~feasible
    ue.stats.infeasible = ue.stats.infeasible + 1;
    return;
end
% UE latency policy (stack.defaults.t2MaxMs): shrink T2 toward T2min. Legal in both branches of
% TS 38.214 8.1.4 -- the cap is never below T2min, and when T2min >= the remaining PDB the cap is
% too, so T2 stays the PDB as the clause requires. candidateSet re-checks the bounds.
T2minSlots = g.T2minRawByPrio(prio) * 2^g.mu;
capSlots = max(T2minSlots, floor(ue.k.t2MaxMs / g.slotMs));
req.T2 = max(req.T1, min(req.T2, capSlots));
TmaxPrime = 10240 * 2^g.mu;                            % every slot is a pool slot (poolGeometry)
[candY, candX, survivor] = phy.ts38214.candidateSet(req, g.numSubchannel, g.sensingWindowMs, g.mu, ...
    ue.db, g.thresListDbm, g.txPercentageByPrio(prio), g.reservePeriodListMs, g.T2minRawByPrio(prio), ...
    TmaxPrime, p.maxEscalations);
draws = rand(ue.rng, 1, g.maxNumPerReserve);
% This UE's own already-reserved slots are not candidates: it transmits one PSSCH per slot, and
% a second grant landing on the first's slot would have to drop one of them.
own = [ue.grants.slots];
survivor = survivor & ~ismember(candY, own);
if ~any(survivor)
    return;
end
% TS 38.321 5.22.1.1: with PSFCH configured, the resources of one grant must be at least the
% minimum time gap apart -- PSFCH timing plus processing -- so a retransmission can follow the
% feedback for the transmission before it. Only Destinations whose MAC PDU will request feedback.
minGap = 0;
if g.psfchPeriod > 0 && any([ue.ent(inDest(has(inDest))).harqFb])
    minGap = phy.rx.policy.minResourceGapSlots(n, g.psfchPeriod, g.minTimeGapPsfch, ue.k.psfchProcSlots);
end
[slots, subch] = phy.rx.policy.resourcePickChained(candY, candX, survivor, draws, g.maxNumPerReserve, minGap);
gr = stack.grantNone();
gr.active = true; gr.peerL2Id = peer; gr.cast = cast;
gr.slots = slots; gr.subch = subch; gr.L = req.LsubCH;
gr.selPrio = prio; gr.minGap = minGap;
if isPer
    gr.isPeriodic = true;
    gr.prsvpMs = ue.k.prsvpTxMs;
    gr.periodSlots = phy.ts38214.reservationPeriodToSlots(gr.prsvpMs, g.TmaxPrime);
    gr.mg = mac.grantSelect(mac.grantInit(), slots, subch, req.LsubCH, gr.prsvpMs, true, counter);
end
ue.grants(end + 1) = gr;
ue.stats.selections = ue.stats.selections + 1;
end

function [avail, dataPlusHdr] = volumes(ue, nowMs)
% Per-entity data available for LCP: TS 38.322 5.5 data volume, plus a pending AM STATUS PDU.
% dataPlusHdr is what LCP is asked to allocate: the bytes, their RLC headers AND one MAC SDU
% subheader (TS 38.321 6.2.4). Leaving the subheader out made every allocation exactly one
% subheader short, so RLC re-segmented the last 3 bytes of every SDU into a PDU of their own,
% stranded until a later grant -- found by the first end-to-end run, where nothing was delivered.
SDU_SUBHEADER_MAX = 3;
avail = zeros(1, numel(ue.ent));
dataPlusHdr = zeros(1, numel(ue.ent));
for i = 1:numel(ue.ent)
    e = ue.ent(i);
    if ~e.isTx, continue; end
    if strcmp(e.mode, 'am')
        [d, h, s] = rlc.amDataVolume(e.rlcTx, e.rlcRx, nowMs);
    else
        [d, h] = rlc.umTxDataVolume(e.rlcTx);
        s = 0;
    end
    avail(i) = d + s;
    if avail(i) > 0
        dataPlusHdr(i) = d + h + s + SDU_SUBHEADER_MAX;
    end
end
end

function [ue, tb, lcids, sduLen, prio, harqFb] = buildMacPdu(ue, gr, nowMs)
% LCP across the Destination's logical channels, then each channel's RLC fills its allocation.
SL_SCH_SUBHEADER = 4; SDU_SUBHEADER_MAX = 3;
g = ue.g;
tbsBytes = g.tbsBytesByLsubCH(gr.L);
inDest = find([ue.ent.isTx] & [ue.ent.peerL2Id] == gr.peerL2Id & [ue.ent.cast] == gr.cast);
[~, dataPlusHdr] = volumes(ue, nowMs);
avail = dataPlusHdr(inDest);
tb = []; lcids = zeros(1, 0); sduLen = zeros(1, 0); prio = 8; harqFb = false;
usable = tbsBytes - SL_SCH_SUBHEADER;
if usable <= 0 || ~any(avail > 0)
    return;
end
e = ue.ent(inDest);
[alloc, sbjNew] = mac.slLcp([e.Sbj], [e.prio], avail, [e.harqFb], true(1, numel(e)), usable);
sduBytes = zeros(1, 0);
for q = 1:numel(e)
    if alloc(q) < SDU_SUBHEADER_MAX + 2
        continue;                                      % too little to carry a header and a byte
    end
    % Each RLC PDU is its own MAC SDU with its own subheader (TS 38.321 6.2.4), so the RLC budget
    % is the allocation less one subheader per PDU it produces -- unknown until it has built
    % them. Reserve for r PDUs, build, and if it made more, reserve for that many and rebuild
    % from the untouched entity (every entity is a value, so a rebuild is free of side effects).
    r = 1;
    while true
        budget = floor(alloc(q)) - r * SDU_SUBHEADER_MAX;
        if budget <= 0, pl = zeros(1, 0); break; end
        if strcmp(e(q).mode, 'am')
            [rlcTx, rlcRx, pb, pl] = rlc.amTxOpportunity(e(q).rlcTx, e(q).rlcRx, budget, nowMs);
        else
            [rlcTx, pb, pl] = rlc.umTxBuild(e(q).rlcTx, budget);
            rlcRx = e(q).rlcRx;
        end
        if numel(pl) <= r, break; end
        r = numel(pl);
    end
    if isempty(pl), continue; end
    e(q).rlcTx = rlcTx;
    e(q).rlcRx = rlcRx;
    sduBytes = [sduBytes, pb]; %#ok<AGROW>
    sduLen = [sduLen, pl]; %#ok<AGROW>
    lcids = [lcids, repmat(e(q).lcid, 1, numel(pl))]; %#ok<AGROW>
    prio = min(prio, e(q).prio);
    harqFb = harqFb || e(q).harqFb;
end
for q = 1:numel(e), e(q).Sbj = sbjNew(q); end
ue.ent(inDest) = e;
if isempty(sduLen)
    return;
end
tb = logical(mac.muxSlSch(ue.srcL2Id, gr.peerL2Id, sduBytes, sduLen, lcids, false, 0, 0, tbsBytes));
end

function prio = destPrio(ue, peer, cast, nowMs, fallback)
% prio_TX before the MAC PDU exists: the highest priority (lowest value) of the Destination's
% logical channels with data, or the priority the grant was selected for when none has data yet.
[avail, ~] = volumes(ue, nowMs);
inDest = find([ue.ent.isTx] & [ue.ent.peerL2Id] == peer & [ue.ent.cast] == cast & avail > 0);
prio = fallback;
if ~isempty(inDest)
    prio = min([ue.ent(inDest).prio]);
end
end

% =========================================================================================
function [ok, cbrRatio] = congestionOk(ue, n, L, prio)
% TS 38.214 8.1.6: "the UE shall ensure the following limits for any priority value k:
% sum_{i>=k} CR(i) <= CR_limit(k)", CR(i) evaluated in slot n-N and CR_limit(k) the sl-CR-Limit of
% priority k for the CBR range containing the CBR measured in slot n-N (sl-DefaultTxConfigIndex
% while no CBR measurement exists). Evaluated as if this transmission is made, so ok = false means
% making it would break a limit; "dropping the transmissions in slot n" is this UE's response.
%   SL CBR (TS 38.215 5.1.27) over [n-N-a, n-N-1] from the RSSI ring (stack.rxSlot);
%   SL CR (TS 38.215 5.1.26) at slot m = n-N with the UE's split b = N, a = total-1-b (NOTE 1:
%   "determined by UE implementation", b < (a+b+1)/2): used = own transmissions in [m-a, m-1],
%   granted = those in [m, n] including this one. Slots before 0 count as unused.
g = ue.g;
ok = true;
cbrRatio = NaN;
if ~any([g.crTab.configured])
    return;
end
N = ue.congN;
m = n - N;
if g.cbrMeasured
    a = g.cbrWindowSlots;
    W = numel(ue.rssiRingSlot);
    M = nan(a, g.numSubchannel);
    for s = max(0, m - a):m - 1
        r = mod(s, W) + 1;
        if ue.rssiRingSlot(r) == s
            M(s - (m - a) + 1, :) = ue.rssiRing(r, :);
        end
    end
    cbrRatio = phy.ts38215.cbr(M, g.threshRssiCbrDbm);
end
crLimit = zeros(1, 8); crPresent = false(1, 8);
for k = 1:8
    t = g.crTab(k);
    if ~t.configured, continue; end
    lvl = t.defaultLevel;
    if ~isnan(cbrRatio)
        lvl = phy.ts38214.cbrRangeIndex(cbrRatio, t.levelUpper);
    end
    crLimit(k) = t.crLimit(lvl);
    crPresent(k) = t.crLimitPresent(lvl);
end
total = g.crWindowSlots;
b = N;
a = total - 1 - b;
h = ue.txHist;
past = h(:, 1) >= m - a & h(:, 1) <= m - 1;
granted = h(:, 1) >= m & h(:, 1) <= n;
crPer = zeros(1, 8);
for i = 1:8
    used = sum(h(past & h(:, 3) == i, 2));
    fut = sum(h(granted & h(:, 3) == i, 2)) + (prio == i) * L;
    crPer(i) = phy.ts38215.cr(used, fut, g.numSubchannel, a, b, total);
end
ok = phy.ts38214.congestionControlCheck(crPer, crLimit, crPresent);
end

% =========================================================================================
function ue = reevalPreempt(ue, n)
% TS 38.321 5.22.1.2a at T3 = T_proc,1 before each reserved resource m (TS 38.214 8.1.4), run at
% exactly m - T3 (the +harness/+sls reasoning: a later check against a fresh S_A flags every
% resource, since nothing closer than T3 can be a candidate). Through the normative MAC:
%   mac.reevaluation  resources NOT yet announced by an SCI: is the resource still in S_A?
%   mac.preemption    resources ALREADY announced: has a higher-priority reservation above the
%                     (escalated) RSRP threshold taken it? Gated by sl-PreemptionEnable.
% S_A is the one selection would produce now: T1 = T3, T2 from the remaining PDB as in select().
% What counts as announced: in the first period, a resource after a transmission of the grant (its
% SCI-1A TRIV covers it); from the second period on, all of them (the previous period's SCI-1A
% reserved them with P_rsvp_TX). Each flagged resource is replaced on its own
% (phy.rx.policy.resourceReplace, mac.grantReplaceResource for SPS); with no replacement the grant
% is released and the next data reselects (NOTE 2 leaves this to the UE).
g = ue.g;
T3 = phy.ts38214.procTimeSelection(g.mu);
nowMs = n * g.slotMs;
q = 1;
while q <= numel(ue.grants)
    gr = ue.grants(q);
    idx = gr.next:numel(gr.slots);
    due = idx(gr.slots(idx) == n + T3);
    if isempty(due)
        q = q + 1; continue;
    end
    prioTx = gr.prio;
    if gr.proc == 0
        prioTx = destPrio(ue, gr.peerL2Id, gr.cast, nowMs, gr.selPrio);
    end
    signalled = repmat(gr.periodIdx > 0 || gr.proc > 0, 1, numel(due));
    deadline = destDeadline(ue, gr.peerL2Id, gr.cast, nowMs);
    remSlots = max(0, ceil((deadline - nowMs) / g.slotMs) - 1 - ue.k.decodeMarginSlots);
    T2minSlots = g.T2minRawByPrio(prioTx) * 2^g.mu;
    capSlots = max(T2minSlots, floor(ue.k.t2MaxMs / g.slotMs));
    T2 = max(T3, min([remSlots, capSlots]));
    Cresel = 1;
    if gr.isPeriodic, Cresel = max(1, gr.mg.counter * 10); end
    req = struct('n', n, 'T1', T3, 'T2', T2, 'remainingPdbSlots', max(T2, remSlots), 'LsubCH', gr.L, ...
        'prioTx', prioTx, 'prsvpTxMs', gr.prsvpMs, 'Cresel', Cresel);
    p = phy.rx.policy.defaults();
    [candY, candX, survivor, ~, ~, thrOffsetDb] = phy.ts38214.candidateSet(req, g.numSubchannel, ...
        g.sensingWindowMs, g.mu, ue.db, g.thresListDbm, g.txPercentageByPrio(prioTx), ...
        g.reservePeriodListMs, g.T2minRawByPrio(prioTx), g.TmaxPrime, p.maxEscalations);
    needs = mac.reevaluation(gr.slots(due), gr.subch(due), signalled, n, T3, candY, candX, survivor);
    pre = mac.preemption(gr.slots(due), gr.subch(due), gr.L, signalled, prioTx, n, T3, ue.db, ...
        g.thresListDbm, thrOffsetDb, g.preemptionEnable);
    ue.stats.reevalFlagged = ue.stats.reevalFlagged + nnz(needs);
    ue.stats.preemptFlagged = ue.stats.preemptFlagged + nnz(pre);
    flagged = gr.slots(due(needs | pre));
    if isempty(flagged)
        q = q + 1; continue;
    end
    others = ue.grants([1:q - 1, q + 1:end]);
    pick = survivor & ~ismember(candY, [others.slots]);
    released = false;
    for fs = flagged
        r = find(gr.slots == fs, 1);
        kept = gr.slots([1:r - 1, r + 1:end]);
        [ns, nsub, found] = phy.rx.policy.resourceReplace(candY, candX, pick, kept, gr.minGap, ...
            g.maxNumPerReserve, rand(ue.rng));
        if ~found
            released = true;
            break;
        end
        if gr.isPeriodic
            gr.mg = mac.grantReplaceResource(gr.mg, r, ns - gr.periodIdx * gr.periodSlots, nsub);
        end
        gr.slots(r) = ns; gr.subch(r) = nsub;
        [gr.slots, o] = sort(gr.slots);
        gr.subch = gr.subch(o);
        ue.stats.replaced = ue.stats.replaced + 1;
    end
    if released
        ue.stats.replaceFailed = ue.stats.replaceFailed + 1;
        if gr.proc > 0
            ue.harq = mac.harqFlush(ue.harq, gr.proc);
            if ~isempty(ue.psfchWait)
                ue.psfchWait = ue.psfchWait([ue.psfchWait.proc] ~= gr.proc);
            end
        end
        ue.grants(q) = [];
        continue;
    end
    ue.grants(q) = gr;
    q = q + 1;
end
end

function c = sciCastType(code)
% sdap.castCode -> TS 38.212 Table 8.4.1.1-1 cast type indicator. Groupcast is the ACK/NACK
% flavour here; NACK-only needs zone/range signalling (SCI-2B) this stack does not send.
ct = sap.castTypes();
switch code
    case 1, c = ct.broadcast;
    case 2, c = ct.groupcastAckNack;
    case 3, c = ct.unicast;
end
end
