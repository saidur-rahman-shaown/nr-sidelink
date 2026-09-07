function [candY, candX, survivor, Mtotal, nEscalations, thresholdOffsetFinalDb] = candidateSet( ...
    req, numSubchannel, sensingWindowMs, mu, db, ...
    thresholdListDbm, txPercentage, allowedPeriodsMs, T2minRaw, TmaxPrime, maxEscalations)
%candidateSet Mode-2 candidate resource set S_A, TS 38.214 clause 8.1.4 steps 1-7.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4 ("UE procedure for determining the subset of
%        resources to be reported to higher layers in PSSCH resource selection in sidelink
%        resource allocation mode 2"). Re-evaluation and pre-emption (clause 8.1.4's closing
%        paragraphs) are deliberately NOT implemented here -- see +phy/+ts38214/CLAUDE.md:
%        they live in +mac/, with a different resource set and trigger. The final escalated
%        threshold offset is still returned, since +mac/'s pre-emption check needs it.
%Inputs: req              scalar struct, the MAC-provided trigger parameters (clause 8.1.4,
%                         "the higher layer provides the following parameters"):
%                           .n           integer -- the triggering slot, already expressed as
%                                        a LOGICAL pool slot index (see "Logical slots only"
%                                        below)
%                           .T1          integer, 0<=T1<=T_proc,1^SL -- selection-window start
%                                        offset. T_proc,1 is a spec-fixed floor (procTimeSelection),
%                                        but the actual choice within [0,T_proc,1] is UE
%                                        implementation and lives in +phy/+rx/+policy/ per
%                                        +phy/+ts38214/CLAUDE.md -- this function validates T1
%                                        against the floor, it does not choose it.
%                           .T2          integer -- selection-window end offset, already chosen
%                                        by the caller (also a +phy/+rx/+policy/ decision)
%                                        within clause 8.1.4's bounds; validated here against
%                                        those bounds (see T2minRaw/remainingPdbSlots).
%                           .remainingPdbSlots  integer, >=0 -- remaining packet delay budget,
%                                        in slots
%                           .LsubCH      integer, >=1 -- L_subCH, sub-channels per candidate
%                           .prioTx      integer, 1..8 -- own L1 priority, prio_TX
%                           .prsvpTxMs   real, >=0 -- own reservation period, ms (0 = aperiodic)
%                           .Cresel      integer, >=1 -- number of reserved periods (clause
%                                        8.1.5, "=10*SL_RESOURCE_RESELECTION_COUNTER if
%                                        configured else 1"); resolved by +mac/, taken as given.
%                                        Must be 1 when prsvpTxMs==0.
%        numSubchannel    integer, >=1 -- sl-NumSubchannel
%        sensingWindowMs  real, one of {100,1100} -- sl-SensingWindow, ms (T_0's raw value)
%        mu               integer, 0..3 -- mu_SL, SCS configuration of the SL BWP. Used for
%                         every numerology-dependent conversion this clause requires: T_0 and
%                         T2min from ms to slots (x2^mu -- for T2min this is the exact
%                         resolution +cfg/resourcePool.m's own comment defers to
%                         "+phy/+ts38214"), and T2 (slots) back to T_scal (ms) in step 6c.
%        db               struct from sensingDbInit/sensingDbRecord/sensingDbMarkUnmonitored
%        thresholdListDbm 64-entry vector, real, dBm -- sl-Thres-RSRP-List, ALREADY RESOLVED
%                         to dBm by the caller (the raw config field is an unresolved
%                         INTEGER(0..66) index per +cfg/resourcePool.m; that resolution isn't
%                         built yet -- same "pre-resolved units taken as input" pattern as
%                         +phy/+ts38213/reservationPeriodIndex.m). Indexed
%                         thresholdListDbm(p_i + (p_j-1)*8), p_i/p_j in 1..8, which lands
%                         directly on MATLAB's 1-based indexing with no adjustment.
%        txPercentage     real, 0<txPercentage<=1 -- X for req.prioTx, ALREADY CONVERTED from
%                         the sl-TxPercentageList percentage label (e.g. 'p20'->0.20)
%        allowedPeriodsMs vector, real -- every periodicity permitted by
%                         sl-ResourceReservePeriodList; entries <=0 (the aperiodic/"ms0" entry,
%                         if present) are ignored internally, since step 5's hypothetical test
%                         only makes sense for a real periodicity
%        T2minRaw         integer, one of {1,5,10,20} -- the raw sl-SelectionWindowList value
%                         for req.prioTx (NOT yet scaled by numerology -- see mu)
%        TmaxPrime        positive integer -- T'_max (clause 8.1.7); the pool-timeline
%                         machinery that computes this (slotIsInPool over a full DFN) is not
%                         built yet (+phy/+ts38213/CLAUDE.md), so it is taken as an input here,
%                         same as +phy/+ts38213/mode2ResourceSelect.m takes higher-layer
%                         selection as an input rather than performing it.
%        maxEscalations   positive integer -- safety bound on step 7's escalation loop; the
%                         loop is guaranteed to converge (once thresholds exceed every sensed
%                         RSRP, step 6 excludes nothing and S_A=all candidates), but this bound
%                         turns a logic defect into a clear error instead of a silent hang
%Outputs: candY, candX  1 x Mtotal row vectors, integer -- the full initial enumeration of
%                       R_{x,y}: candY is the logical slot, candX the starting sub-channel, of
%                       every candidate single-slot resource in the selection window
%         survivor      1 x Mtotal logical row vector -- true where the corresponding
%                       candidate survives as a member of S_A
%         Mtotal         positive integer -- M_total, the INITIAL candidate count (computed
%                       once; +phy/+ts38214/CLAUDE.md's own "Known traps" names recomputing
%                       this after escalation as the single most common defect in this
%                       algorithm)
%         nEscalations   nonnegative integer -- number of 3 dB escalation rounds actually
%                       applied before S_A converged (0 = no escalation needed)
%         thresholdOffsetFinalDb  nonnegative integer, dB -- 3*nEscalations; the final,
%                       fully-escalated offset applied to every Th(p_i,p_j) pair, returned for
%                       a future +mac/ pre-emption check (clause 8.1.4's own text: pre-emption
%                       uses "the final threshold after executing steps 1)-7)")
%
%Logical slots only: every slot quantity here (req.n, db.slot, the window bounds) is a LOGICAL
%pool slot index (TS 38.214 clause 8's re-indexed t'^SL_i numbering), not a physical/DFN slot.
%+phy/CLAUDE.md's cross-package rule requires the logical<->physical mapping be applied exactly
%once; this package declares itself the "logical side" and never converts -- that conversion,
%and the underlying full-DFN pool timeline, live outside this package (not yet built; see
%TmaxPrime above). One consequence, taken as an explicit simplification: clause 8.1.4 step 6c's
%t'_n' ("=n if slot n belongs to the pool, else the first pool slot after n") is always just n
%here, since in a purely-logical, contiguously-re-indexed numbering every integer already
%denotes a pool slot by construction -- there is no "does n belong to the pool" question left
%to ask once n itself is given as a logical index. This also means slot arithmetic here does
%not wrap at TmaxPrime (a full 10240 ms DFN period): sensing/selection windows are tens to a
%few hundred slots, orders of magnitude below a realistic TmaxPrime, so wraparound never
%triggers in practice; a caller spanning a DFN wrap boundary would need to unwrap first.

if ~(req.prioTx >= 1 && req.prioTx <= 8 && mod(req.prioTx, 1) == 0)
    error('ts38214:candidateSet:badPrioTx', 'candidateSet: req.prioTx must be an integer in 1..8, got %s', num2str(req.prioTx));
end
if req.prsvpTxMs < 0
    error('ts38214:candidateSet:badPrsvpTx', 'candidateSet: req.prsvpTxMs must be >= 0, got %s', num2str(req.prsvpTxMs));
end
if req.Cresel < 1 || mod(req.Cresel, 1) ~= 0
    error('ts38214:candidateSet:badCreselRange', 'candidateSet: req.Cresel must be an integer >= 1, got %s', num2str(req.Cresel));
end
if req.remainingPdbSlots < 0
    error('ts38214:candidateSet:badPdb', 'candidateSet: req.remainingPdbSlots must be >= 0, got %s', num2str(req.remainingPdbSlots));
end
if numSubchannel < 1 || mod(numSubchannel, 1) ~= 0
    error('ts38214:candidateSet:badNumSubchannel', 'candidateSet: numSubchannel must be a positive integer, got %s', num2str(numSubchannel));
end
if ~any(sensingWindowMs == [100 1100])
    error('ts38214:candidateSet:badSensingWindow', 'candidateSet: sensingWindowMs must be one of {100,1100} (sl-SensingWindow), got %s', num2str(sensingWindowMs));
end
if numel(thresholdListDbm) ~= 64
    error('ts38214:candidateSet:badThresholdList', 'candidateSet: thresholdListDbm must have 64 entries (sl-Thres-RSRP-List, 8x8 priority pairs), got %d', numel(thresholdListDbm));
end
if ~(txPercentage > 0 && txPercentage <= 1)
    error('ts38214:candidateSet:badTxPercentage', 'candidateSet: txPercentage must be in (0,1], got %s', num2str(txPercentage));
end
if ~any(T2minRaw == [1 5 10 20])
    error('ts38214:candidateSet:badT2minRaw', 'candidateSet: T2minRaw must be one of {1,5,10,20} (sl-SelectionWindow), got %s', num2str(T2minRaw));
end
if TmaxPrime <= 0 || mod(TmaxPrime, 1) ~= 0
    error('ts38214:candidateSet:badTmaxPrime', 'candidateSet: TmaxPrime must be a positive integer, got %s', num2str(TmaxPrime));
end
if maxEscalations <= 0 || mod(maxEscalations, 1) ~= 0
    error('ts38214:candidateSet:badMaxEscalations', 'candidateSet: maxEscalations must be a positive integer, got %s', num2str(maxEscalations));
end

tProc1 = phy.ts38214.procTimeSelection(mu);
if ~(req.T1 >= 0 && req.T1 <= tProc1 && mod(req.T1, 1) == 0)
    error('ts38214:candidateSet:badT1', 'candidateSet: req.T1 must be an integer in 0..%d (T_proc,1 at mu=%d), got %s', tProc1, mu, num2str(req.T1));
end

T2minSlots = T2minRaw * 2^mu;
if T2minSlots < req.remainingPdbSlots
    if ~(req.T2 >= T2minSlots && req.T2 <= req.remainingPdbSlots)
        error('ts38214:candidateSet:badT2', 'candidateSet: req.T2 must be in [%d,%d] (T2min=%d < remaining PDB=%d), got %s', T2minSlots, req.remainingPdbSlots, T2minSlots, req.remainingPdbSlots, num2str(req.T2));
    end
else
    if req.T2 ~= req.remainingPdbSlots
        error('ts38214:candidateSet:badT2', 'candidateSet: T2min=%d >= remaining PDB=%d, so req.T2 must equal the remaining PDB, got %s', T2minSlots, req.remainingPdbSlots, num2str(req.T2));
    end
end
if req.LsubCH < 1 || req.LsubCH > numSubchannel
    error('ts38214:candidateSet:badLsubCH', 'candidateSet: req.LsubCH must be in 1..numSubchannel(%d), got %s', numSubchannel, num2str(req.LsubCH));
end
if req.prsvpTxMs == 0 && req.Cresel ~= 1
    error('ts38214:candidateSet:badCresel', 'candidateSet: req.Cresel must be 1 when req.prsvpTxMs==0 (aperiodic), got %s', num2str(req.Cresel));
end

% ---- step 1: enumerate all R_{x,y} in [n+T1, n+T2] --------------------
y = (req.n + req.T1):(req.n + req.T2);
x = 0:(numSubchannel - req.LsubCH);
if isempty(y)
    error('ts38214:candidateSet:emptyWindow', 'candidateSet: selection window [n+%d,n+%d] is empty', req.T1, req.T2);
end
[Ymesh, Xmesh] = ndgrid(y, x);
candY = reshape(Ymesh, 1, []);
candX = reshape(Xmesh, 1, []);
Mtotal = numel(candY);

% ---- step 2: sensing window [n-T0, n-Tproc0), right end exclusive -----
T0Slots = sensingWindowMs * 2^mu;
tProc0 = phy.ts38214.procTimeSensing(mu);
loSens = req.n - T0Slots;
hiSensExcl = req.n - tProc0;
recIdx = find(db.slot >= loSens & db.slot < hiSensExcl);
unmonSlots = unique(db.unmonitoredSlot(db.unmonitoredSlot >= loSens & db.unmonitoredSlot < hiSensExcl));
periods = allowedPeriodsMs(allowedPeriodsMs > 0);

nEsc = 0;
while true
    % ---- step 4: initialise S_A to all candidates ---------------------
    alive = true(1, Mtotal);

    % ---- step 5: unmonitored slots, hypothetical SCI reserving everything
    for m = unmonSlots(:)'
        for P = periods(:)'
            excl = overlapMask(candY, candX, req.LsubCH, m, 0, numSubchannel, true, P, ...
                req, TmaxPrime, mu);
            alive = alive & ~excl;
        end
    end

    % ---- step 5a: re-initialise if step 5 over-excluded ----------------
    if nnz(alive) < txPercentage * Mtotal
        alive = true(1, Mtotal);
    end

    % ---- step 6: sensed reservations, conditions (a)+(b)+(c) -----------
    thOffset = 3 * nEsc;   % clause 8.1.4 step 7: "Th(p_i,p_j) increased by 3 dB" per round
    for k = recIdx(:)'
        pRx = db.priority(k);
        % clause 8.1.4 step 3: i = p_i + (p_j-1)*8 (8 priority values per sl-Thres-RSRP-List block)
        Th = thresholdListDbm(pRx + (req.prioTx - 1) * 8) + thOffset;
        if db.rsrp(k) <= Th
            continue;
        end
        excl = overlapMask(candY, candX, req.LsubCH, db.slot(k), db.startSubch(k), db.lSubch(k), ...
            db.reservationPeriodPresent(k), db.reservationPeriodMs(k), req, TmaxPrime, mu);
        alive = alive & ~excl;
        if db.chainedCount(k) >= 1
            excl = overlapMask(candY, candX, req.LsubCH, db.chainedSlot1(k), db.chainedStart1(k), db.lSubch(k), ...
                db.reservationPeriodPresent(k), db.reservationPeriodMs(k), req, TmaxPrime, mu);
            alive = alive & ~excl;
        end
        if db.chainedCount(k) >= 2
            excl = overlapMask(candY, candX, req.LsubCH, db.chainedSlot2(k), db.chainedStart2(k), db.lSubch(k), ...
                db.reservationPeriodPresent(k), db.reservationPeriodMs(k), req, TmaxPrime, mu);
            alive = alive & ~excl;
        end
    end

    % ---- step 7: report, or escalate every pair by 3 dB and restart ----
    if nnz(alive) >= txPercentage * Mtotal
        survivor = alive;
        nEscalations = nEsc;
        thresholdOffsetFinalDb = thOffset;
        return;
    end
    if nEsc >= maxEscalations
        error('ts38214:candidateSet:noConvergence', 'candidateSet: step 7 escalation did not converge within %d rounds', maxEscalations);
    end
    nEsc = nEsc + 1;
end
end

function excl = overlapMask(candY, candX, LsubCH, resSlot, resStart, resLen, periodPresent, periodMs, req, TmaxPrime, mu)
%overlapMask TS 38.214 clause 8.1.4 step 6 condition (c): two-sided periodic overlap test.
%Shared by step 5 (hypothetical SCI, periodPresent forced true) and step 6 (a real sensed
%resource, periodPresent = whether its own 'Resource reservation period' field was present).
%Frequency overlap is tested once; the sensed side recurs q=1..Q times (clause 8.1.4 step 6c,
%clause 8.1.7 for the ms->slots conversion), the candidate's own side recurs j=0..Cresel-1
%times at its own reservation period (clause 8.1.5).
%Inputs: candY, candX  1 x Mtotal row vectors -- the full candidate enumeration from step 1:
%                      candY(i) is candidate i's logical slot, candX(i) its starting
%                      sub-channel (unrelated to resStart below, which is the RESERVATION's
%                      own starting sub-channel, not a candidate's)
%        LsubCH        integer, >=1 -- L_subCH, sub-channels per candidate (shared by every
%                      candidate; NOT the reservation's own width, see resLen)
%        resSlot       integer -- logical slot the reservation occupies (the anchor/chained
%                      slot of a real sensed SCI-1A record for step 6, or the unmonitored slot
%                      itself for step 5's hypothetical SCI)
%        resStart      integer, >=0 -- x, starting sub-channel of the reservation's occupied
%                      resource (the observed PSCCH location for a sensed record; 0 for step
%                      5's hypothetical SCI, which instead spans the whole pool width via
%                      resLen to conservatively assume worst-case frequency overlap)
%        resLen        integer, >=1 -- L_subCH of the RESERVATION's occupied resource (may
%                      differ from the candidate's own LsubCH above -- step 5's hypothetical
%                      SCI passes resLen=numSubchannel to cover every sub-channel)
%        periodPresent logical scalar -- whether this reservation recurs periodically (forced
%                      true for step 5's hypothetical SCI; for step 6, whether the sensed
%                      SCI-1A's own 'Resource reservation period' field was present)
%        periodMs      real -- the reservation's own period, ms (ignored when periodPresent is
%                      false) -- P_rsvp_RX for a sensed record, or the step-5 hypothetical
%                      period drawn from allowedPeriodsMs
%        req           the caller's own req struct, passed through unchanged for req.n,
%                      req.T2, req.prsvpTxMs, req.Cresel -- the CANDIDATE's own prospective
%                      reservation, distinct from periodPresent/periodMs above which describe
%                      the OTHER, already-sensed-or-hypothetical reservation being tested
%                      against
%        TmaxPrime, mu passed through unchanged to reservationPeriodToSlots and the T2
%                      ms<->slot conversion
%Outputs: excl  1 x Mtotal logical row vector -- true where that candidate collides (frequency
%              overlap AND a time-domain hit per condition (c)) with this one reservation and
%              must be excluded from S_A
M = numel(candY);
excl = false(1, M);

candLo = candX;
candHi = candX + LsubCH - 1;
resLo = resStart;
resHi = resStart + resLen - 1;
freqHit = candLo <= resHi & candHi >= resLo;
if ~any(freqHit)
    return;
end

Q = 1;
PpRx = 0;
if periodPresent
    PpRx = phy.ts38214.reservationPeriodToSlots(periodMs, TmaxPrime);
    Tscal = req.T2 / 2^mu;   % T2 (slots) -> ms
    nPrime = req.n;          % logical-slot space: n already denotes a pool slot (see header)
    if periodMs < Tscal && (nPrime - resSlot) <= PpRx
        Q = ceil(Tscal / periodMs);
    end
end

if req.prsvpTxMs > 0
    PpTx = phy.ts38214.reservationPeriodToSlots(req.prsvpTxMs, TmaxPrime);
    jMax = req.Cresel - 1;
else
    PpTx = 0;
    jMax = 0;
end

occSlots = resSlot;
if periodPresent
    occSlots = [occSlots, resSlot + (1:Q) * PpRx];
end

for s = occSlots
    for j = 0:jMax
        yNeeded = s - j * PpTx;
        excl = excl | (candY == yNeeded & freqHit);
        if PpTx == 0
            break;
        end
    end
end
end
