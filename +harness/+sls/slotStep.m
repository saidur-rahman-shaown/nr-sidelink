function [ue, scen, resolved, air, rxLog, nRlf, nReeval, nPreempt, nCongestionDrop] = slotStep(ue, scen, nPhys)
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
%         nReeval   integer -- resources re-evaluation flagged for replacement this slot
%         nPreempt  integer -- resources pre-emption flagged this slot
%         nCongestionDrop  integer -- transmissions dropped by clause 8.1.6 congestion control
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
nReeval  = 0;
nPreempt = 0;
nCongestionDrop = 0;

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
            ue(i).prio, scen.traffic.pdbMs, scen.traffic.sizeBytes, scen.traffic.lcid, nPhys);
        ue(i).lch       = sap.lchEnqueue(ue(i).lch, c, nPhys);
        ue(i).nextPktId = ue(i).nextPktId + 1;
    end
end

% ---- 3. BUCKETS: clause 5.22.1.4.1.1's token refill -----------------------
% Bj is incremented by sl-PrioritisedBitRate x T before every LCP run, and capped at
% sl-PrioritisedBitRate x sl-BucketSizeDuration. Leaving sl-PrioritisedBitRate at 0, as this
% scenario first did, makes the buckets inert: SBj never rises above 0, so LCP's first
% (SBj-limited) pass allocates nothing at all and every byte is served by the second pass. The
% totals still come out right, so nothing looks wrong -- but the prioritised-bit-rate mechanism
% that is the entire point of clause 5.22.1.4.1 is not being exercised.
elapsedSeconds = 1 / (1000 * 2^scen.mu);      % one slot
for i = 1:nUe
    ue(i).lch.Sbj = mac.slLcpBucket(ue(i).lch.Sbj, ue(i).lch.pbr, ue(i).lch.bsd, elapsedSeconds);
end

% ---- 4. EXPIRE: a spent budget is a LOSS, wherever the packet is ----------
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

% ---- 5. TX ----------------------------------------------------------------
airList = {};
for i = 1:nUe
    % The reservation period must close BEFORE the transmission that opens the next one.
    % grantOnTransmission rejects marking an opportunity twice within a period -- correctly, it
    % is how a counter decrementing at the wrong rate is caught -- so a period boundary
    % processed after the transmission raises on the first repeat of opportunity 1.
    [ue(i), scen] = periodPhase(ue(i), scen, nLog, periodLogical);
    [ue(i), t, sent, dropped] = txPhase(ue(i), scen, nPhys, nLog, periodLogical);
    nCongestionDrop = nCongestionDrop + double(dropped);
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

% ---- 6. CHANNEL: once for the slot, so interference is a slot property ----
[sinrDb, rxPowerDbm, canHear, sinrPscchDb] = harness.chanmodel.slotSinr(air, scen.posXY, ...
    scen.radio, scen.numSubchannel, scen.pscchPrb, scen.subchSizeRb);

% ---- 7. RX ----------------------------------------------------------------
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
    % ---- BLIND PSCCH SEARCH, one hypothesis per sub-channel start ---------
    % A receiver is not handed the transmission list. It searches for a PSCCH at the start of
    % EVERY sub-channel, because clause 8.1.2.2 puts the PSCCH in the lowest sub-channel of
    % whatever allocation carries it and the receiver does not know the allocation yet. This
    % loop is over candidate POSITIONS, not over transmissions -- iterating the transmissions
    % directly, as this loop did before, is genie-aided: it silently grants the receiver
    % knowledge of exactly what was sent and where.
    for x = 0:scen.numSubchannel - 1
        here = find([air.startSubch] == x);
        here = here(canHear(here, i));
        if isempty(here)
            continue;                      % nothing transmitted at this position
        end
        % Two transmissions starting at the same sub-channel put their PSCCHs on the same PRBs.
        % The receiver has ONE hypothesis per position, so at most one can be decoded: the
        % strongest, if it survives the others as interference. That is the capture effect, and
        % it is why a collision is not automatically a double loss.
        [~, order] = sort(sinrPscchDb(here, i), 'descend');
        here = here(order);

        for k = here
            dist  = norm(scen.posXY(i, :) - air(k).posXY);
            gotTb = false;

            % The MEASURED PSCCH curve, not a low-MCS PSSCH lookup standing in for it. The
            % control channel's advantage over data is 1.75 to 16 dB depending on the data's
            % MCS -- a spread no single proxy MCS can express, and one that was guessed while
            % the curves were a placeholder.
            sciBler = harness.phyabs.pscchBler(air(k).mcs, sinrPscchDb(k, i));
            if rand(scen.stream) >= sciBler
                % ---- SCI-1A decoded: recover the announced reservation -----
                % Fed to the sensing database from the DECODED fields, not from the
                % transmitter's own state. A sensing database populated from a genie cannot be
                % wrong about a reservation, so it cannot show what an undecoded SCI costs.
                [nRes, t1, t2] = phy.ts38212.trivDecode(air(k).trivIdx, scen.maxNumPerReserve);
                [nStart1, nStart2] = phy.ts38212.frivDecode(air(k).frivIdx, air(k).LsubCH, ...
                    scen.numSubchannel, scen.maxNumPerReserve);
                periodMs = scen.reservePeriodListMs(air(k).prsvpTxIdx + 1);
                ue(i).db = phy.ts38214.sensingDbRecord(ue(i).db, nLog, x, air(k).LsubCH, ...
                    air(k).prioTx, rxPowerDbm(k, i), periodMs > 0, periodMs, ...
                    nRes, t1, t2, nStart1, nStart2);

                tbBler = harness.phyabs.blerLookup(air(k).mcs, sinrDb(k, i), air(k).rv + 1, ...
                    scen.channelModel, scen.speedKmh);
                gotTb = rand(scen.stream) >= tbBler;
                if gotTb
                    [ue, resolved] = deliver(ue, resolved, air(k), nPhys, codes);
                end
                % Feedback is owed on the strength of the CONTROL decode, not the data decode:
                % a NACK is precisely the report that the SCI was seen and the transport block
                % was not. Owing feedback only on success would turn every data failure into a
                % DTX, and DTX drives radio link failure (clause 5.22.1.3.3) rather than
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
                rxLog.distM(end + 1) = dist;
                rxLog.ok(end + 1)    = gotTb;
                break;                     % this position's hypothesis is spent
            end
            % Control lost. Still a link that existed and failed, so it belongs in the pair
            % statistic's denominator.
            rxLog.distM(end + 1) = dist;
            rxLog.ok(end + 1)    = false;
        end
    end
end

% ---- 8. MEASURE: SL RSSI per sub-channel, into the CBR window -------------
% +harness/CLAUDE.md's ordering puts MEASURE after RX, and it matters: the CBR window is
% [n-a, n-1], so slot n's measurement is written AFTER slot n's transmissions have been
% evaluated and is read by slot n+1's transmit decision. Measuring before RX would put slot n
% into its own window.
%
% phy.ts38215.slRssi takes a resource grid and belongs to the waveform path. Here the RSSI of
% a sub-channel is the summed received power of every transmission overlapping it, plus noise
% -- the same quantities slotSinr already computed, aggregated per sub-channel instead of per
% link. A UE that transmitted measures nothing: those entries stay NaN, which phy.ts38215.cbr
% reads as "not measured" rather than as "idle". Scoring an unmonitored slot as idle would
% make a busy channel look emptier the busier it gets, since a UE transmits more when it has
% more to send.
subchBwHz  = scen.radio.bwHz / scen.numSubchannel;
noiseSubMw = 10^(rf.noiseFloorDbm(subchBwHz, scen.radio.noiseFigureDb) / 10);
row = mod(nPhys, scen.cbrWindowSlots) + 1;
for i = 1:nUe
    if isTx(i)
        ue(i).rssiWindow(row, :) = NaN;
        continue;
    end
    pwrMw = repmat(noiseSubMw, 1, scen.numSubchannel);
    for k = 1:numel(air)
        if ~canHear(k, i)
            continue;
        end
        occupied = air(k).startSubch + (0:air(k).LsubCH - 1) + 1;
        pwrMw(occupied) = pwrMw(occupied) + 10^(rxPowerDbm(k, i) / 10) / air(k).LsubCH;
    end
    ue(i).rssiWindow(row, :) = 10 * log10(pwrMw);
end

% ---- 9. PSFCH: transmit the feedback due here, and apply what comes back --
if scen.isUnicast
    [ue, scen, nRlf, fbResolved] = psfchPhase(ue, scen, nLog, nPhys);
    resolved = [resolved fbResolved];
end

% ---- 10. MAC: re-evaluation and pre-emption, then the reselection check ----
% Clause 5.22.1.2a's two checks run BEFORE clause 5.22.1.2's, because they are what can make
% the grant unusable: a resource that fails either is cleared, and the reselection check then
% sees "there is no selected sidelink grant" and reselects. Running them after would let a
% doomed grant survive one more period.
for i = 1:nUe
    [ue(i), scen, nR, nP] = reevalPreemptPhase(ue(i), scen, nLog, periodLogical);
    nReeval  = nReeval + nR;
    nPreempt = nPreempt + nP;
    [ue(i), scen] = macPhase(ue(i), scen, nLog, periodLogical);
end
end

% =========================================================================
function [u, scen, nReeval, nPreempt] = reevalPreemptPhase(u, scen, nLog, periodLogical)
%reevalPreemptPhase Clause 5.22.1.2a's re-evaluation and pre-emption checks.
%Spec:   TS 38.321 V16.22.0 clause 5.22.1.2a, via +mac/reevaluation and +mac/preemption; the
%        lead time T_3 is TS 38.214 clause 8.1.4's T_proc,1^SL.
%
%THE TWO CHECKS ARE COMPLEMENTS AND ARE NEVER MERGED
%----------------------------------------------------
%+mac/CLAUDE.md is explicit: "Re-evaluation and pre-emption operate on different resource sets
%with different timing. Never merge them; never let one call the other." Re-evaluation covers
%resources NOT YET announced by an SCI and asks "is my intended resource still a good choice?";
%pre-emption covers ALREADY-announced ones and asks "has someone higher-priority taken it?".
%`signalled` is the exact partition between them, computed once here and handed to both.
%
%WHAT `signalled` MEANS FOR A PERIODIC GRANT
%--------------------------------------------
%  - The anchor (resource 1) is announced by the PREVIOUS period's SCI, through the reservation
%    period field -- so it is signalled from the second period onward, and only then.
%  - The chained resources are announced by THIS period's anchor SCI, so they become signalled
%    the moment that transmission goes out (grant.txOppUsed(1)).
%This is a model of the announcement, not a quotation: the clause defines m per resource and
%leaves the bookkeeping to the implementation.

nReeval  = 0;
nPreempt = 0;
nCongestionDrop = 0;
if ~u.grant.hasGrant
    return;
end
T3   = phy.ts38214.procTimeSelection(scen.mu);
nOpp = numel(u.grant.txOppSlot);

resSlot  = u.grant.txOppSlot + u.periodIdx * periodLogical;
resSubch = u.grant.txOppStartSubch;

signalled = false(1, nOpp);
signalled(1) = u.periodIdx > 0;
if nOpp > 1
    signalled(2:end) = u.grant.txOppUsed(1);
end

% Run the check at EXACTLY m - T_3, not anywhere in [m - T_3, m).
%
% This is not a performance choice, it is a correctness one, and getting it wrong is silent.
% The comparison asks "is my reserved resource still in S_A?", and S_A is enumerated over
% [n + T1, n + T2] with T1 >= T_proc,1 = T_3. A resource CLOSER than T_3 to the current slot
% therefore cannot appear in any legal candidate set -- not because it is a bad resource, but
% because it is too soon to select anything there. Checking at any slot after m - T_3 makes
% every resource look excluded, so every grant gets cleared, every period, forever. The
% symptom is subtle: transmissions per delivery collapses to 1.00 because no grant survives
% long enough to reach its own retransmission opportunity, while delivery still mostly works.
%
% Clause 5.22.1.2a NOTE 1 does permit checking later ("before 'm - T_3' or after 'm - T_3' but
% before 'm'"), but a later check must compare against something other than a fresh S_A, and
% that is a different algorithm rather than a different constant.
due = (nLog == resSlot - T3);
if ~any(due)
    return;
end

% The window then starts exactly on the resource under check. Setting the remaining PDB equal
% to T2 keeps the request legal in both of clause 8.1.4's branches without needing to know
% which one it is in -- the same argument phy.rx.policy.selectionWindow makes.
T1 = T3;
T2 = max(resSlot(due)) - nLog;
if T2 < T1
    return;
end
req = struct('n', nLog, 'T1', T1, 'T2', T2, 'remainingPdbSlots', T2, ...
    'LsubCH', u.grant.lSubch, 'prioTx', u.prio, ...
    'prsvpTxMs', scen.policy.prsvpTxMs, 'Cresel', max(1, u.grant.counter * 10));
[candY, candX, survivor, ~, ~, thrOffsetDb] = phy.ts38214.candidateSet(req, ...
    scen.numSubchannel, scen.pool.sensingWindowMs, scen.mu, u.db, scen.pool.thresholdListDbm, ...
    scen.pool.txPercentage, scen.pool.allowedPeriodsMs, scen.pool.T2minRaw, scen.TmaxPrime, ...
    scen.policy.maxEscalations);

% ONLY the resources due at this exact slot are passed. Both modules re-derive due-ness from
% `currentSlot >= grantSlot - T3`, which is also true for every resource ALREADY IN THE PAST --
% and a past resource can never be in a candidate set built forward from now, so it is flagged
% for reselection every single time. Filtering to the due subset here is what makes the
% modules' own due test agree with this caller's rather than fight it.
needsReselect = mac.reevaluation(resSlot(due), resSubch(due), signalled(due), nLog, T3, ...
    candY, candX, survivor);

% Pre-emption consumes candidateSet's ESCALATED threshold offset, which
% +phy/+ts38214/CLAUDE.md records as being returned specifically for this. Using the raw table
% value makes a congested pool pre-empt far more than it should.
preempted = mac.preemption(resSlot(due), resSubch(due), u.grant.lSubch, signalled(due), ...
    u.prio, nLog, T3, u.db, scen.pool.thresholdListDbm, thrOffsetDb, ...
    scen.pool.slPreemptionEnable);

nReeval  = nnz(needsReselect);
nPreempt = nnz(preempted);
if nReeval == 0 && nPreempt == 0
    return;
end

% Clause 5.22.1.2a is explicit about what happens next, and it is NOT "clear the grant":
%   "2> remove the resource(s) from the selected sidelink grant ..."
%   "2> randomly select the time and frequency resource from the resources indicated by the
%       physical layer ... for either the removed resource or the dropped resource ..."
%   "2> replace the removed or dropped resource(s) by the selected resource(s) ..."
% So each flagged resource is swapped individually and the rest of the grant survives. Clearing
% the whole grant -- which this loop did first -- is conservative but over-reacts: it discards
% good resources with the bad, costs more reselections than a conformant UE performs, and
% inflates the access delay every one of those reselections adds.
% Address the flagged resources by SLOT, not by index. Every grantReplaceResource call
% re-sorts the grant, so an index captured before the first replacement points at a DIFFERENT
% resource after it -- and the second replacement then swaps out a perfectly good resource
% while leaving the flagged one in place.
dueIdx       = find(due);
flaggedSlots = resSlot(dueIdx([needsReselect | preempted]));
for fs = flaggedSlots
    r = find(u.grant.txOppSlot + u.periodIdx * periodLogical == fs, 1);
    if isempty(r)
        continue;                    % already replaced by an earlier iteration of this loop
    end
    nOppNow = numel(u.grant.txOppSlot);
    kept = u.grant.txOppSlot(setdiff(1:nOppNow, r)) + u.periodIdx * periodLogical;
    minGap = phy.rx.policy.minResourceGapSlots(nLog, scen.slPsfchPeriod, ...
        scen.minTimeGapPsfch, scen.policy.psfchProcSlots);
    [newSlot, newSubch, found] = phy.rx.policy.resourceReplace(candY, candX, survivor, ...
        kept, minGap, scen.maxNumPerReserve, rand(scen.stream));
    if found
        u.grant = mac.grantReplaceResource(u.grant, r, newSlot - u.periodIdx * periodLogical, newSubch);
    else
        % NOTE 2 leaves the no-candidate case to UE implementation. Clearing the grant is this
        % implementation's answer: the reselection check then sees "there is no selected
        % sidelink grant" and starts a fresh selection, which is the only option that does not
        % keep a resource clause 5.22.1.2a has just said to remove.
        u.grant = mac.grantClear(u.grant);
        return;
    end
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
        pl = harness.chanmodel.pathloss(scen.radio.plModel, d);
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
function [u, t, sent, dropped] = txPhase(u, scen, nPhys, nLog, periodLogical)
%txPhase Emit this UE's transmission for slot nLog, if its grant has an opportunity here.
t       = sap.txReqInit();
sent    = false;
dropped = false;
% The slot's own occupancy entry is cleared before anything can write it, so a stale value from
% crWindowTotal slots ago cannot survive into this window.
u.usedHistory(mod(nPhys, scen.crWindowTotal) + 1) = 0;
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
        % Clause 5.22.1.3.1's FOURTH flush condition: an initial-transmission grant for which
        % the multiplexing entity produced no MAC PDU ("3> else: 4> flush the HARQ buffer").
        % Not feedback-driven, which is why mac.harqFlush is its own function. Without it the
        % previous MAC PDU stays in the buffer and gets retransmitted at this period's
        % retransmission opportunity -- a stale TB sent again under a fresh grant, wasting the
        % resource and, worse, delivering a duplicate whose packets were already resolved.
        if u.curProc >= 1 && ~isempty(u.curTb)
            u.harq  = mac.harqFlush(u.harq, u.curProc);
            u.curTb = false(0, 1);
        end
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
    % A Sidelink process whose buffer still holds an unresolved TB cannot take a new one --
    % clause 5.22.1.3.1a gives each process exactly one TB. Keying the process off nextPktId,
    % as this loop did, is not a cycle at all: nextPktId advances on GENERATION, so a TB built
    % while an earlier one is still in flight can land on the same process, and the second
    % overwrites the first's buffer and loses the packets riding it.
    busy = false(1, u.harq.nProcesses);
    if ~isempty(u.inFlightProc)
        busy(u.inFlightProc) = true;
    end
    proc = 0;
    for c = 1:u.harq.nProcesses
        cand = mod(u.nextProc + c - 1, u.harq.nProcesses) + 1;
        if ~busy(cand)
            proc = cand;
            break;
        end
    end
    if proc == 0
        return;                      % every Sidelink process occupied: nothing to transmit on
    end
    u.nextProc = proc;
    % The feedback flag must follow the cast type. Hardcoding false told the HARQ entity every
    % process was feedback-disabled even in unicast, so harqOnFeedback's own bookkeeping
    % disagreed with the SCI actually sent.
    [u.harq, ndi, rv] = mac.harqNewTransmission(u.harq, proc, [0 2 3 1], proc - 1, scen.isUnicast);
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

% ---- congestion control, TS 38.214 clause 8.1.6 --------------------------
% The limit is normative and the response is not: congestionControlCheck REPORTS, and
% phy.rx.policy.congestionDrop decides. The check happens here, immediately before committing
% the transmission, because clause 8.1.6 constrains transmissions in slot n rather than grants.
[withinLimit, u] = congestionCheck(u, scen, nLog, nPhys);
if phy.rx.policy.congestionDrop(withinLimit)
    dropped = true;
    return;
end

u.grant = mac.grantOnTransmission(u.grant, opp);
% This UE's OWN occupancy this slot, for CR. Other UEs' transmissions belong to CBR, not here:
% counting them would throttle this UE against traffic that is not its own.
u.usedHistory(mod(nPhys, scen.crWindowTotal) + 1) = u.grant.lSubch;

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
t.prioTx       = u.prio;
t.txPowerDbm   = phy.ts38213.slPowerControl('PSSCH', scen.pCmaxDbm, 0, 0, 0, scen.mu, t.LsubCH * scen.subchSizeRb);

% ---- the SCI-1A reservation fields, actually encoded ---------------------
% Announcing the reservation is the whole reason sensing works: a receiver that decodes this
% SCI learns where this UE will transmit NEXT, both the chained retransmissions (TRIV/FRIV)
% and the periodic repetition (reservation period). Leaving these at zero -- as this loop did
% until the fields were wired -- leaves every UE's sensing database blind to the future and
% makes phy.ts38214.candidateSet exclude nothing, which looks like an empty, healthy pool.
t.prsvpTxIdx = phy.ts38213.reservationPeriodIndex(scen.policy.prsvpTxMs, scen.reservePeriodListMs);
remaining    = u.grant.txOppSlot(opp:end) - u.grant.txOppSlot(opp);
nAnnounce    = min(numel(remaining), scen.maxNumPerReserve);
tOff = [0 0];
tOff(1:max(0, nAnnounce - 1)) = remaining(2:nAnnounce);
t.trivIdx = phy.ts38212.trivEncode(nAnnounce, tOff(1), tOff(2), scen.maxNumPerReserve);
nStart = [0 0];
chained = u.grant.txOppStartSubch(opp:end);
nStart(1:max(0, nAnnounce - 1)) = chained(2:nAnnounce);
t.frivIdx = phy.ts38212.frivEncode(nStart(1), nStart(2), t.LsubCH, scen.numSubchannel, scen.maxNumPerReserve);
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
% Measured from the FIXED reference captured at selection, not from txOppSlot(1). Clause
% 5.22.1.2a's replacement can land earlier than the old anchor, and grantReplaceResource
% re-sorts, so reading the reference back off the grant makes the period index jump -- firing
% grantOnPeriodEnd the wrong number of times and decrementing the counter at the wrong rate.
idx = floor((nLog - u.periodRefSlot) / periodLogical);
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
% Clause 5.22.1.1's keep branch is not a no-op: between "clear the selected sidelink grant"
% and "reuse the previously selected sidelink grant" it RE-DRAWS the counter. Without that the
% counter stays at 0 and the SAME stored draw is re-evaluated every period, so a grant that
% kept once keeps forever and sl-ProbResourceKeep becomes a single coin flip deciding the
% grant's whole lifetime rather than a per-period one. Nothing errors and the reservation
% pattern still looks plausible.
%
% It runs BEFORE the data-availability return below, because a periodic grant's counter is
% maintained whether or not there is anything to send right now -- gating it on pending data
% leaves the counter parked at zero through every idle period.
if u.grant.hasGrant && u.grant.isPeriodic && u.grant.counter == 0 && ...
        mac.keepDecision(u.grant.keepDraw, scen.pool.slProbResourceKeep)
    [lo, hi] = mac.creselCounterRange(scen.policy.prsvpTxMs);
    u.grant  = mac.grantOnKeep(u.grant, lo + floor(rand(scen.stream) * (hi - lo + 1)));
end

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
[req, feasible] = phy.rx.policy.selectionRequest(nLog, scen.mu, remLogical, u.prio, cresel, scen.policy, pduBytes);
if ~feasible
    return;
end

[candY, candX, survivor] = phy.ts38214.candidateSet(req, scen.numSubchannel, ...
    scen.pool.sensingWindowMs, scen.mu, u.db, scen.pool.thresholdListDbm, scen.pool.txPercentage, ...
    scen.pool.allowedPeriodsMs, scen.pool.T2minRaw, scen.TmaxPrime, scen.policy.maxEscalations);

% The chained resources must land inside TRIV's reach of the anchor -- 1..31 logical slots,
% TS 38.214 clause 8.1.5. Drawing them independently over a selection window hundreds of slots
% wide, as this loop did before the SCI fields were encoded, produces a grant no conformant UE
% could announce, and nothing notices while the SCI is never built.
draws  = rand(scen.stream, 1, scen.maxNumPerReserve);
% The minimum time gap binds at selection too, not only at replacement: clause 5.22.1.1 states
% it for "a selected sidelink grant" generally.
minGap = phy.rx.policy.minResourceGapSlots(nLog, scen.slPsfchPeriod, scen.minTimeGapPsfch, ...
    scen.policy.psfchProcSlots);
[slots, subch] = phy.rx.policy.resourcePickChained(candY, candX, survivor, draws, ...
    scen.maxNumPerReserve, minGap);

u.grant         = mac.grantSelect(u.grant, slots, subch, req.LsubCH, scen.policy.prsvpTxMs, true, counter);
u.periodIdx     = 0;
u.periodRefSlot = slots(1);
end

% =========================================================================
function [withinLimit, u] = congestionCheck(u, scen, nLog, nPhys)
%congestionCheck CBR, CR and the clause 8.1.6 limit test for one UE in one slot.
%Spec:   TS 38.215 V16.7.0 clauses 5.1.25 (CBR) and 5.1.26 (CR); TS 38.214 V16.17.0 clause
%        8.1.6 (the limit). The measurement window lengths are normative, the past/future split
%        and the response are not.

% CBR over [n-a, n-1]: the circular buffer already holds exactly that, since slot n's own row
% is not written until the MEASURE phase at the end of this slot.
u.cbr = phy.ts38215.cbr(u.rssiWindow, scen.pool.threshSRssiCbrDbm);

% The CR limit for this UE's priority at the measured CBR. Clause 8.1.6 evaluates CBR in slot
% n-N, N from procTimeCongestion -- the measurement cannot be acted on instantly. Modelled by
% using the window that ends at n-1 and noting that N is smaller than the CBR window itself, so
% the value is the same to within one window's smoothing.
level = phy.ts38214.cbrRangeIndex(u.cbr, scen.pool.cbrRangeUpperBounds);
crLimitPerPriority = repmat(scen.pool.crLimitByLevel(level), 1, 8);

% CR: this UE's own occupancy over [n-a, n+b]. With b = 0 the future half is empty.
idxPast = mod(nPhys - (1:scen.crPastSlots), scen.crWindowTotal) + 1;
subchUsedPast = sum(u.usedHistory(idxPast));
crRatio = phy.ts38215.cr(subchUsedPast, 0, scen.numSubchannel, ...
    scen.crPastSlots, scen.crFutureSlots, scen.crWindowTotal);

crPerPriority = zeros(1, 8);
crPerPriority(u.prio) = crRatio;
withinLimit = phy.ts38214.congestionControlCheck(crPerPriority, crLimitPerPriority, true(1, 8));
end
