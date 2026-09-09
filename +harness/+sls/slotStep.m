function [ue, scen, resolved, air, rxLog, nRlf] = slotStep(ue, scen, nPhys)
%slotStep Advance the whole scenario by one slot.
%Spec:   none itself; it sequences modules that each cite their own clause. The intra-slot
%        ordering is +harness/CLAUDE.md's, with one documented reordering -- see below.
%Inputs: ue     1 x nUe struct array from +harness/+sls/ueInit
%        scen   from +harness/+sls/scenarioInit
%        nPhys  integer, >=0 -- the PHYSICAL slot to execute
%Outputs: ue        updated
%         scen      updated (only its RNG stream advances)
%         resolved  1 x n struct array of contexts that reached a terminal outcome this slot
%         air       1 x nTx struct array of what was transmitted, for logging
%         rxLog     scalar struct: .distM and .ok, one entry per (transmission, hearing
%         nRlf      integer -- radio link failures indicated this slot (clause 5.22.1.3.3)
%         rxLog fields, continued: one entry per (transmission, hearing receiver) PAIR. This is the raw material for PRR-versus-distance, which is
%                   a per-LINK statistic and cannot be recovered from packet outcomes -- see
%                   +harness/kpiReport
%
%THE ORDERING, AND THE ONE PLACE IT DEPARTS FROM +harness/CLAUDE.md
%------------------------------------------------------------------
%That file lists, per UE: TIMING, RX, MEASURE, MAC, TX. That is the right order for ONE UE.
%A slot-synchronous multi-UE simulator cannot use it directly: no UE's reception can be
%evaluated until every UE's transmission for the slot exists. So the order here is
%
%    TIMING -> APP -> EXPIRE -> TX -> CHANNEL -> RX -> MAC -> LOG
%
%and the per-UE order is preserved *in effect* rather than literally, because of causality that
%clause 8.1.4 guarantees: T1 >= T_proc,1 > 0, so a MAC decision taken in slot n can never
%produce a transmission in slot n. Everything transmitted here was decided at least T_proc,1
%slots ago, so running TX before RX and MAC cannot let a UE react to something it has not yet
%heard. The assertion below pins that.
%
%EXPIRE RUNS BEFORE TX
%---------------------
%A grant is never spent on data that is already dead. Expiring after transmission wastes the
%grant on packets that will be dropped anyway, which shows up as throughput loss with no
%visible cause.

codes    = sap.outcomeCodes();
resolved = repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0);
nUe      = scen.nUe;
rxLog    = struct('distM', zeros(1, 0), 'ok', false(1, 0));
nRlf     = 0;

% ---- 1. TIMING ------------------------------------------------------------
nLog = scen.logicalOfPhys(nPhys + 1);
if nLog < 0
    air = repmat(rf.toAir(sap.txReqInit(), 1, [0 0]), 1, 0);
    return;                                  % not a pool slot: nothing can happen in it
end
periodLogical = phy.ts38214.reservationPeriodToSlots(scen.policy.prsvpTxMs, scen.TmaxPrime);

% ---- 2. APP: generate, and cross the MAC SAP ------------------------------
for i = 1:nUe
    if app.trafficPeriodic(nPhys, scen.traffic.periodSlots, ue(i).trafficOffset)
        c = sap.ctxInit(ue(i).nextPktId, ue(i).srcL2Id, ue(i).dstL2Id, scen.traffic.pqi, ...
            scen.traffic.prio, scen.traffic.pdbMs, scen.traffic.sizeBytes, scen.traffic.lcid, nPhys);
        ue(i).lch       = sap.lchEnqueue(ue(i).lch, c, nPhys);
        ue(i).nextPktId = ue(i).nextPktId + 1;
    end
end

% ---- 3. EXPIRE: a spent budget is a LOSS, wherever the packet is ----------
% Both the queue AND the in-flight set. A packet dequeued into a transport block has left the
% logical channel, so lchExpire can no longer see it -- and without the second loop it would
% sit in flight forever if the block were never delivered, silently leaving the denominator of
% every ratio. That is precisely the arithmetic that makes a reliability figure look better
% than the run was, and it is invisible in a scenario where almost everything is delivered.
for i = 1:nUe
    [ue(i).lch, dead] = sap.lchExpire(ue(i).lch, nPhys, scen.mu);
    resolved = [resolved dead];  %#ok<AGROW>

    stillFlying = true(1, numel(ue(i).inFlight));
    for f = 1:numel(ue(i).inFlight)
        [~, spent] = phy.rx.policy.remainingPdbSlots(ue(i).inFlight(f).pdbMs, ...
            ue(i).inFlight(f).tGenSlot, nPhys, scen.mu);
        if spent
            resolved(end + 1) = sap.ctxFinish(ue(i).inFlight(f), codes.pdbExpired, nPhys); %#ok<AGROW>
            stillFlying(f) = false;
        end
    end
    ue(i).inFlight     = ue(i).inFlight(stillFlying);
    ue(i).inFlightProc = ue(i).inFlightProc(stillFlying);
end

% ---- 4. TX ----------------------------------------------------------------
airList = {};
for i = 1:nUe
    % The reservation period must close BEFORE the transmission that opens the next one.
    % grantOnTransmission rejects marking an opportunity twice within a period -- correctly, it
    % is how a counter decrementing at the wrong rate is caught -- so a period boundary
    % processed after the transmission raises on the first repeat of opportunity 1.
    [ue(i), scen] = periodPhase(ue(i), scen, nLog, periodLogical);
    [ue(i), t, sent] = txPhase(ue(i), scen, nPhys, nLog, periodLogical);
    if sent
        assert(t.slotLogical == nLog, 'slotStep: a transmission must be in the slot being executed');
        airList{end + 1} = rf.toAir(sap.txReqValidate(t, scen.numSubchannel), i, ue(i).posXY); %#ok<AGROW>
    end
end
if isempty(airList)
    air = repmat(rf.toAir(sap.txReqInit(), 1, [0 0]), 1, 0);
else
    air = [airList{:}];
end

% ---- 5. CHANNEL: once for the slot, so interference is a slot property ----
[sinrDb, rxPowerDbm, canHear] = harness.chanmodel.slotSinr(air, scen.posXY, scen.radio, scen.numSubchannel);

% ---- 6. RX ----------------------------------------------------------------
isTx = false(1, nUe);
for k = 1:numel(air)
    isTx(air(k).ueId) = true;
end
for i = 1:nUe
    if isTx(i)
        % Half-duplex: the slot is unsensed, and that is a first-class fact about the sensing
        % database, not an impairment bolted on later.
        ue(i).db = phy.ts38214.sensingDbMarkUnmonitored(ue(i).db, nLog);
        continue;
    end
    for k = 1:numel(air)
        if ~canHear(k, i)
            continue;                          % out of the pair statistic entirely: a
        end                                    % half-duplex slot is not a failed link
        % Every hearing pair is logged, decoded or not. PRR is a per-LINK quantity and the
        % denominator has to include the links that failed.
        dist = norm(scen.posXY(i, :) - air(k).posXY);
        gotTb = false;

        % SCI-1A first: a fixed robust format, so it decodes further out than the data. This
        % separation is what makes sensing see the far UEs whose reservations matter most.
        sciBler = harness.phyabs.blerLookup(scen.policy.mcs, sinrDb(k, i) + scen.sciSinrAdvantageDb, ...
            1, scen.channelModel, scen.speedKmh);
        if rand(scen.stream) >= sciBler
            ue(i).db = phy.ts38214.sensingDbRecord(ue(i).db, nLog, air(k).startSubch, air(k).LsubCH, ...
                air(k).prioTx, rxPowerDbm(k, i), true, scen.policy.prsvpTxMs, 1, 0, 0, 0, 0);

            tbBler = harness.phyabs.blerLookup(air(k).mcs, sinrDb(k, i), air(k).rv + 1, ...
                scen.channelModel, scen.speedKmh);
            gotTb = rand(scen.stream) >= tbBler;
            if gotTb
                [ue, resolved] = deliver(ue, resolved, air(k), nPhys, codes);
            end
            % Feedback is owed on the strength of the CONTROL decode, not the data decode: a
            % NACK is precisely the report that the SCI was seen and the transport block was
            % not. Owing feedback only on success would turn every data failure into a DTX,
            % and DTX drives radio link failure (clause 5.22.1.3.3) rather than
            % retransmission -- so lossy-but-alive links would be declared dead.
            if scen.isUnicast && air(k).harqFeedbackEnabled == 1 && air(k).dstL2Id == ue(i).srcL2Id
                ue(i).psfchTx(end + 1) = struct( ...
                    'slot',       phy.ts38213.psfchTiming(nLog, scen.minTimeGapPsfch, scen.slPsfchPeriod), ...
                    'toUeId',     air(k).ueId, ...
                    'ack',        gotTb, ...
                    'procIdx',    air(k).harqId + 1, ...
                    'psschSlot',  nLog, ...
                    'startSubch', air(k).startSubch, ...
                    'srcL1Id',    mod(air(k).srcL2Id, 256));
            end
        end
        rxLog.distM(end + 1) = dist;
        rxLog.ok(end + 1)    = gotTb;
    end
end

% ---- 7. PSFCH: transmit the feedback due here, and apply what comes back --
if scen.isUnicast
    [ue, scen, nRlf, fbResolved] = psfchPhase(ue, scen, nLog, nPhys);
    resolved = [resolved fbResolved];
end

% ---- 8. MAC: period boundaries, then the reselection check ----------------
for i = 1:nUe
    [ue(i), scen] = macPhase(ue(i), scen, nLog, periodLogical);
end
end

% =========================================================================
function [ue, scen, nRlf, resolvedFb] = psfchPhase(ue, scen, nLog, nSlotPhys)
%psfchPhase Transmit every PSFCH due in this slot and apply the feedback that arrives.
%Spec:   TS 38.213 V16.17.0 clause 16.3 for the slot, PRB and cyclic-shift-pair allocation
%        (via psfchTiming/psfchPrbRange/psfchResource) and TS 38.321 clause 5.22.1.3.1/.3.3 for
%        what the transmitter does with the result (via mac.harqOnFeedback).
%
%HALF-DUPLEX ON PSFCH IS PER-SYMBOL, NOT PER-SLOT
%-------------------------------------------------
%A UE transmitting PSSCH in slot n can still receive PSFCH in the same slot -- clause 8.1.2.1
%forbids PSSCH in the symbols configured for PSFCH, so the two never overlap in time. What a UE
%cannot do is transmit and receive PSFCH in the same slot. So the deafness test here is
%"did I transmit a PSFCH", not "did I transmit anything", which is a different and narrower set
%than the PSSCH half-duplex test in slotSinr.
%
%COLLISIONS ARE REAL AND ARE MODELLED
%-------------------------------------
%Two receivers replying to different transmitters can land on the same PRB and the same
%cyclic-shift pair -- clause 16.3's allocation is a function of the PSSCH slot, sub-channel and
%source ID, not of who is replying. Feedback sharing a resource is indistinguishable, so those
%transmissions interfere. Modelling PSFCH as a private channel would hide the one failure mode
%that scales with load.

nRlf       = 0;
nMaxTx     = 0;  %#ok<NASGU>
codes      = sap.outcomeCodes();
resolvedFb = repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0);

% ---- gather this slot's PSFCH transmissions ------------------------------
txUe = zeros(1, 0); txPrb = zeros(1, 0); txCs = zeros(1, 0);
txTo = zeros(1, 0); txAck = false(1, 0); txProc = zeros(1, 0);
for i = 1:numel(ue)
    due = [ue(i).psfchTx.slot] == nLog;
    for e = find(due)
        p = ue(i).psfchTx(e);
        iSlot = mod(p.psschSlot, scen.slPsfchPeriod);
        [prbStart, ~, MsubchSlot] = phy.ts38213.psfchPrbRange(iSlot, p.startSubch, ...
            scen.psfchRbSetSize, scen.numSubchannel, scen.slPsfchPeriod);
        % M_ID is 0 for unicast (clause 16.3: it is the member identity only for groupcast
        % with per-UE ACK/NACK).
        [prb, cs] = phy.ts38213.psfchResource(prbStart, MsubchSlot, scen.psfchNtype, ...
            scen.psfchNumMuxCsPair, p.srcL1Id, 0);
        txUe(end + 1) = i;        %#ok<AGROW>
        txPrb(end + 1) = prb;     %#ok<AGROW>
        txCs(end + 1) = cs;       %#ok<AGROW>
        txTo(end + 1) = p.toUeId; %#ok<AGROW>
        txAck(end + 1) = p.ack;   %#ok<AGROW>
        txProc(end + 1) = p.procIdx; %#ok<AGROW>
    end
    ue(i).psfchTx = ue(i).psfchTx(~due);
end

isPsfchTx = false(1, numel(ue));
isPsfchTx(txUe) = true;

% ---- received power of each PSFCH at each UE, over ONE PRB ---------------
nPsfch = numel(txUe);
if nPsfch > 0
    prbBwHz = 12 * 15e3 * 2^scen.mu;                 % one PRB: 12 subcarriers
    noiseMw = 10^(rf.noiseFloorDbm(prbBwHz, scen.radio.noiseFigureDb) / 10);
    rxMw    = zeros(nPsfch, numel(ue));
    for k = 1:nPsfch
        d  = sqrt(sum((scen.posXY - scen.posXY(txUe(k), :)).^2, 2))';
        pl = harness.chanmodel.pathlossDb(d, scen.radio.fcHz, scen.radio.plExponent, scen.radio.plRefDistM);
        rxMw(k, :) = 10.^((scen.pCmaxDbm - pl) / 10);
    end
end

% ---- apply the feedback each waiting transmitter should hear -------------
for i = 1:numel(ue)
    waiting = [ue(i).psfchWait.slot] == nLog;
    for w = find(waiting)
        proc = ue(i).psfchWait(w).procIdx;
        ack  = false;
        received = false;
        if nPsfch > 0 && ~isPsfchTx(i)
            k = find(txTo == i & txProc == proc, 1);
            if ~isempty(k)
                % Interference: any other PSFCH on the same PRB and cyclic-shift pair is
                % indistinguishable from this one.
                same = (txPrb == txPrb(k)) & (txCs == txCs(k));
                same(k) = false;
                interfMw = sum(rxMw(same, i), 1);
                sinrDb   = 10 * log10(rxMw(k, i) / (noiseMw + interfMw));
                if rand(scen.stream) < harness.phyabs.psfchDetect(sinrDb)
                    received = true;
                    ack      = txAck(k);
                end
            end
        end
        % A PSFCH that was never transmitted, never detected, or arrived while this UE was
        % itself transmitting PSFCH is a DTX -- absence, which clause 5.22.1.3.3 counts toward
        % radio link failure, and which is NOT the same as a NACK.
        [ue(i).harq, flushed, rlf] = mac.harqOnFeedback(ue(i).harq, proc, ack, received, ...
            scen.slMaxTransNum, scen.slMaxNumConsecutiveDTX);
        % Clause 5.22.1.3.3 indicates RLF exactly once, on the crossing. Counted rather than
        % acted on: RRC releases the connection on it, and there is no RRC here.
        nRlf = nRlf + double(rlf);
        if flushed
            % The buffer is gone, so no further retransmission of this TB can happen. Clearing
            % curTb is what makes harqRetransmission return `ignored` on the next reserved
            % opportunity -- the normative outcome, not an error.
            if ue(i).curProc == proc
                ue(i).curTb = false(0, 1);
            end
            % A flush WITHOUT an ACK is sl-MaxTransNum spent: the packets riding this process
            % are lost and must be resolved as such. A flush WITH an ACK has already had them
            % resolved as delivered at the receiver's decode, so nothing is left to find.
            if ~ack
                onProc = ue(i).inFlightProc == proc;
                for f = find(onProc)
                    nMaxTx = nMaxTx + 1;
                    resolvedFb(end + 1) = sap.ctxFinish(ue(i).inFlight(f), codes.maxTx, nSlotPhys); %#ok<AGROW>
                end
                ue(i).inFlight     = ue(i).inFlight(~onProc);
                ue(i).inFlightProc = ue(i).inFlightProc(~onProc);
            end
        end
    end
    ue(i).psfchWait = ue(i).psfchWait(~waiting);
end
end

% =========================================================================
function [u, t, sent] = txPhase(u, scen, nPhys, nLog, periodLogical)
%txPhase Emit this UE's transmission for slot nLog, if its grant has an opportunity here.
t    = sap.txReqInit();
sent = false;
if ~u.grant.hasGrant
    return;
end

opp = find(mod(nLog - u.grant.txOppSlot, periodLogical) == 0 & nLog >= u.grant.txOppSlot, 1);
if isempty(opp)
    return;
end

if opp == 1
    % Initial transmission: build a fresh MAC PDU from whatever LCP allocates.
    avail = sap.lchDataAvailable(u.lch);
    if ~any(avail > 0)
        return;                                 % a reserved opportunity with nothing to send
    end
    % The transport block is whatever THIS grant's L_subCH carries -- it varies per grant now
    % that L_subCH is derived per selection, so a single scenario-wide TBS would be wrong for
    % every grant but one.
    tbsBytes = scen.tbsBytesByLsubCH(u.grant.lSubch);
    usable   = tbsBytes - scen.macOverheadFixedBytes - scen.macOverheadPerSduBytes;
    [alloc, u.lch.Sbj, ~] = mac.slLcp(u.lch.Sbj, u.lch.prio, avail, u.lch.harqFeedbackEnabled, ...
        true(1, u.lch.nLch), usable);
    [u.lch, served] = sap.lchDequeue(u.lch, alloc);
    if isempty(served)
        return;
    end
    sduLen = [served.sizeBytes];
    pdu = mac.muxSlSch(u.srcL2Id, u.dstL2Id, uint8(zeros(1, sum(sduLen))), sduLen, ...
        repmat(scen.traffic.lcid, 1, numel(served)), false, 0, 0, tbsBytes);
    proc = mod(u.nextPktId, u.harq.nProcesses) + 1;
    [u.harq, ndi, rv] = mac.harqNewTransmission(u.harq, proc, [0 2 3 1], proc - 1, false);
    ndi = double(ndi);          % the HARQ entity keeps NDI as a logical toggle; the SCI field
                                % is a bit, and +sap/txReqValidate checks field widths
    % muxSlSch returns a double 0/1 column; the PHY SAP requires logical, so the conversion
    % happens once, here, at the boundary rather than being tolerated on both sides.
    u.curTb     = logical(pdu);
    u.curCtx    = served;
    u.curProc   = proc;
    u.curNdi    = ndi;
    for s = 1:numel(served)
        served(s) = sap.ctxTransmitted(served(s), nPhys);
    end
    u.inFlight     = [u.inFlight served];
    u.inFlightProc = [u.inFlightProc repmat(proc, 1, numel(served))];
else
    % Blind retransmission of the TB already in the buffer.
    if isempty(u.curTb)
        return;
    end
    [u.harq, rv, ignored] = mac.harqRetransmission(u.harq, u.curProc, [0 2 3 1]);
    if ignored
        return;                                 % a normative outcome, not an error
    end
    ndi = u.curNdi;
    for s = 1:numel(u.inFlight)
        if u.inFlightProc(s) == u.curProc
            u.inFlight(s) = sap.ctxTransmitted(u.inFlight(s), nPhys);
        end
    end
end

u.grant = mac.grantOnTransmission(u.grant, opp);

t.slotPhysical = nPhys;
t.slotLogical  = nLog;
t.startSubch   = u.grant.txOppStartSubch(opp);
t.LsubCH       = u.grant.lSubch;
t.mcs          = scen.policy.mcs;
t.tb           = u.curTb;
t.harqId       = u.curProc - 1;
t.ndi          = double(ndi);
t.rv           = rv;
t.srcL2Id      = u.srcL2Id;
t.dstL2Id      = u.dstL2Id;
if scen.isUnicast
    t.castType            = sap.castTypes().unicast;
    t.harqFeedbackEnabled = 1;
else
    t.castType            = sap.castTypes().broadcast;
    t.harqFeedbackEnabled = 0;
end
t.prioTx       = scen.traffic.prio;
t.txPowerDbm   = phy.ts38213.slPowerControl('PSSCH', scen.pCmaxDbm, 0, 0, 0, scen.mu, t.LsubCH * scen.subchSizeRb);
t.ctxIds       = [u.curCtx.pktId];
sent           = true;

% Register the PSFCH this transmission expects back. Clause 16.3 fixes the slot: the first
% PSFCH-bearing pool slot at or after sl-MinTimeGapPSFCH. Registered on EVERY transmission,
% including retransmissions, because each one is separately acknowledged -- an ACK for the
% first attempt must be able to stop the second.
if scen.isUnicast
    w = struct( ...
        'slot',     phy.ts38213.psfchTiming(nLog, scen.minTimeGapPsfch, scen.slPsfchPeriod), ...
        'fromUeId', u.peerUeId, ...
        'procIdx',  u.curProc);
    u.psfchWait(end + 1) = w;
end
end

% =========================================================================
function [ue, resolved] = deliver(ue, resolved, a, nPhys, codes)
%deliver Attribute a decoded transport block back to the packets inside it.
%Only the transmitter's own copies are resolved: a broadcast decoded by several receivers is
%ONE delivery of ONE packet, not one per listener. Counting it per listener inflates the
%delivered count by the neighbour density, which looks like a reliability improvement.
i = a.ueId;
for s = numel(ue(i).inFlight):-1:1
    if any(ue(i).inFlight(s).pktId == a.ctxIds) && ue(i).inFlight(s).outcome == codes.inFlight
        c = sap.ctxFinish(ue(i).inFlight(s), codes.delivered, nPhys);
        resolved = [resolved c]; %#ok<AGROW>
        ue(i).inFlight(s)     = [];
        ue(i).inFlightProc(s) = [];
    end
end
end

% =========================================================================
function [u, scen] = periodPhase(u, scen, nLog, periodLogical)
%periodPhase Close every reservation period that ended before this slot.
%A loop, not a single call: a grant whose opportunities all went unused for several periods
%must age by one count per period, and clause 5.22.1.2's sl-ReselectAfter counts PERIODS. A
%single call per slot would collapse an idle stretch into one decrement and make every grant
%outlive its counter.
if ~u.grant.hasGrant
    return;
end
idx = floor((nLog - u.grant.txOppSlot(1)) / periodLogical);
for k = 1:(idx - u.periodIdx)
    [u.grant, ~] = mac.grantOnPeriodEnd(u.grant, rand(scen.stream));
end
if idx > u.periodIdx
    u.periodIdx = idx;
end
end

% =========================================================================
function [u, scen] = macPhase(u, scen, nLog, periodLogical)  %#ok<INUSD>
%macPhase Clause 5.22.1.2's reselection check, and the (re)selection that follows it.
avail = sap.lchDataAvailable(u.lch);
if ~any(avail > 0) && u.grant.hasGrant
    return;                                     % nothing to reselect for
end

keptOk = u.grant.hasGrant && ~(u.grant.isPeriodic && u.grant.counter == 0 && ...
    ~mac.keepDecision(u.grant.keepDraw, scen.pool.slProbResourceKeep));
c = struct( ...
    'counterExpiredNotKept',  u.grant.hasGrant && u.grant.isPeriodic && u.grant.counter == 0 && ~keptOk, ...
    'poolReconfigured',       false, ...
    'noSelectedGrant',        ~u.grant.hasGrant, ...
    'noTxLastSecond',         false, ...
    'reselectAfterReached',   isfinite(scen.pool.slReselectAfter) && u.grant.consecutiveUnusedPeriods >= scen.pool.slReselectAfter, ...
    'cannotAccommodateSdu',   false, ...
    'pdbNotMet',              false);
if ~mac.reselectionTrigger(c)
    return;
end

% ---- (re)selection: policy chooses, +ts38214 says what is legal ----------
u.grant = mac.grantClear(u.grant);
if ~any(avail > 0)
    return;
end
oldest  = u.lch.q(1);
[remPhys, expired] = phy.rx.policy.remainingPdbSlots(oldest.pdbMs, oldest.tGenSlot, ...
    scen.physOfLogical(nLog + 1), scen.mu);
if expired
    return;
end
[remLogical, ~] = phy.rx.policy.pdbLogicalSlots(scen.logicalOfPhys, scen.physOfLogical(nLog + 1), remPhys);

[lo, hi] = mac.creselCounterRange(scen.policy.prsvpTxMs);
counter  = lo + floor(rand(scen.stream) * (hi - lo + 1));
cresel   = mac.cresel(counter, true);
% Size the grant from the data actually pending, capped at the largest transport block the
% pool can carry. Clause 5.22.1.1 selects "an amount of frequency resources"; this is that
% amount, and phy.rx.policy.selectionRequest turns it into L_subCH through the TBS table.
nSdu     = numel(u.lch.q);
pduBytes = min(scen.maxTbsBytes, ...
    scen.macOverheadFixedBytes + nSdu * scen.macOverheadPerSduBytes + sum(avail));
[req, feasible] = phy.rx.policy.selectionRequest(nLog, scen.mu, remLogical, scen.traffic.prio, cresel, scen.policy, pduBytes);
if ~feasible
    return;
end

[candY, candX, survivor] = phy.ts38214.candidateSet(req, scen.numSubchannel, ...
    scen.pool.sensingWindowMs, scen.mu, u.db, scen.pool.thresholdListDbm, scen.pool.txPercentage, ...
    scen.pool.allowedPeriodsMs, scen.pool.T2minRaw, scen.TmaxPrime, scen.policy.maxEscalations);

% One initial transmission plus policy.numRetx blind retransmissions, drawn independently.
nOpp = 1 + scen.policy.numRetx;
slots = zeros(1, nOpp); subch = zeros(1, nOpp);
for j = 1:nOpp
    [slots(j), subch(j)] = phy.rx.policy.resourcePick(candY, candX, survivor, rand(scen.stream));
end
[slots, order] = sort(slots);
subch = subch(order);
% Distinct slots only: two opportunities in one slot is one transmission, not two.
[slots, keep] = unique(slots, 'stable');
subch = subch(keep);

u.grant     = mac.grantSelect(u.grant, slots, subch, req.LsubCH, scen.policy.prsvpTxMs, true, counter);
u.periodIdx = 0;
end
