function [preempted, checkedIdx] = preemption(grantSlot, grantStartSubch, grantLsubch, signalledBySci, ownPriority, currentSlot, T3, db, thresholdListDbm, thresholdOffsetDb, slPreemptionEnable)
%preemption Pre-emption check for already-signalled grant resources, TS 38.321 clause 5.22.1.2a.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2a: "A resource(s) of the selected sidelink grant
%        WHICH HAS BEEN INDICATED BY A PRIOR SCI for a MAC PDU to transmit from multiplexing and
%        assembly entity could be checked for pre-emption by physical layer at T_3 before the
%        slot where the RESOURCE(S) IS LOCATED as specified in clause 8.1.4 of TS 38.214 [7].
%        [...] For pre-emption, m is the slot where the resource(s) is located." Action: "if any
%        resource(s) of the selected sidelink grant which has been indicated by a prior SCI is
%        indicated for pre-emption by the physical layer [...]: remove the resource(s) from the
%        selected sidelink grant [...]; randomly select the time and frequency resource [...];
%        replace the removed or dropped resource(s) by the selected resource(s)."
%        The pre-emption condition itself is TS 38.214 V16.17.0 clause 8.1.4's closing text: a
%        resource is pre-empted when another UE's reservation overlaps it, that UE's priority is
%        HIGHER than the UE's own (prio_RX < prio_TX numerically), and its measured SL-RSRP
%        exceeds the clause-8.1.4 threshold for that priority pair.
%Inputs: grantSlot          1 x nRes integer row vector -- logical pool slot of each grant resource
%        grantStartSubch    1 x nRes integer row vector -- starting sub-channel of each
%        grantLsubch        integer, >=1 -- L_subCH, the sub-channel width shared by the grant's
%                           resources
%        signalledBySci     1 x nRes logical row vector -- whether each resource HAS ALREADY been
%                           announced by a prior SCI. Pre-emption applies ONLY where this is true,
%                           the exact complement of reevaluation's resource set.
%        ownPriority        integer, 1..8 -- prio_TX, this MAC PDU's own priority (the highest
%                           priority of the logical channels and MAC CE it carries, per clause
%                           5.22.1.3.1a)
%        currentSlot        integer -- the logical pool slot the check runs in
%        T3                positive integer, slots -- the lead time, T_proc,1^SL from
%                           +phy/+ts38214/procTimeSelection(mu)
%        db                 struct from +phy/+ts38214/sensingDbInit and friends -- the sensing
%                           history, read to find overlapping reservations. Read-only here.
%        thresholdListDbm   64-entry vector, real, dBm -- sl-Thres-RSRP-List pre-resolved, indexed
%                           thresholdListDbm(p_i + (p_j-1)*8) exactly as candidateSet indexes it
%        thresholdOffsetDb  nonnegative integer, dB -- candidateSet's thresholdOffsetFinalDb, "the
%                           final threshold after executing steps 1)-7)". +phy/+ts38214/CLAUDE.md
%                           records that candidateSet returns this SPECIFICALLY so this check can
%                           consume it: the pre-emption comparison must use the escalated
%                           threshold that selection actually converged on, not the unescalated
%                           table value, or a congested pool pre-empts far more than it should.
%        slPreemptionEnable char row vector -- sl-PreemptionEnable-r16, as resolved by
%                           +cfg/private/resolveEnum.m, which keeps the label: '' when the field
%                           is NOT PROVIDED, 'enabled', or 'pl1'..'pl8'. TS 38.214 clause 8.1.4
%                           makes this a THREE-way gate, not a boolean, and the third case is the
%                           one that is easy to miss:
%                             ''         -- not provided. BOTH of clause 8.1.4's pre-emption
%                                           bullets begin "sl-PreemptionEnable is provided", so
%                                           neither can be satisfied and NOTHING is ever
%                                           pre-empted. Re-evaluation is unaffected: its own
%                                           sentence carries no such gate.
%                             'enabled'  -- pre-empt on any strictly higher priority, i.e.
%                                           prio_TX > prio_RX.
%                             'plN'      -- prio_pre = N. BOTH prio_RX < prio_pre AND
%                                           prio_TX > prio_RX must hold, each strict. So a
%                                           reservation of higher priority than ours still does
%                                           not pre-empt unless it is also above the configured
%                                           pre-emption priority level.
%Outputs: preempted   1 x nRes logical row vector -- true for each resource that must be removed
%                     and replaced
%         checkedIdx  1 x nRes logical row vector -- which resources were examined this call
%
%The priority test is STRICT and it is the thing that makes pre-emption different from ordinary
%exclusion. Clause 8.1.4 pre-empts only for a reservation of HIGHER priority than the UE's own,
%and because sl-Priority runs 1 (highest) to 8 (lowest), "higher priority" means a NUMERICALLY
%SMALLER value: prio_RX < prio_TX. An equal-priority reservation does NOT pre-empt -- if it did,
%two UEs at the same priority would pre-empt each other indefinitely and neither would ever
%transmit. Writing the comparison as <= produces exactly that livelock, and it is invisible in
%any test where the two priorities differ.
%
%Why this is a different module from reevaluation, restated because merging them is the standing
%trap: m is the slot where the RESOURCE IS LOCATED here, not where it is first announced; the
%resource set is the already-signalled complement; and the trigger is an RSRP-and-priority test
%against sensed reservations rather than "did my pick fall out of S_A". +mac/CLAUDE.md: "Never
%merge them; never let one call the other."
%
%As with reevaluation, this only IDENTIFIES resources. Replacement selection is a
%+phy/+rx/+policy/ decision, and clause 5.22.1.2a NOTE 4 additionally leaves it "up to UE
%implementation whether to set the resource reservation interval in the re-selected resource to
%replace pre-empted resource".
nRes = numel(grantSlot);
if ~isrow(grantSlot) || ~isequal(size(grantStartSubch), size(grantSlot)) || ~isequal(size(signalledBySci), size(grantSlot))
    error('mac:preemption:badGrant', 'preemption: grantSlot, grantStartSubch and signalledBySci must be row vectors of the same length');
end
if grantLsubch < 1 || mod(grantLsubch, 1) ~= 0
    error('mac:preemption:badLsubch', 'preemption: grantLsubch must be a positive integer, got %s', num2str(grantLsubch));
end
if ~(ownPriority >= 1 && ownPriority <= 8 && mod(ownPriority, 1) == 0)
    error('mac:preemption:badPriority', 'preemption: ownPriority must be an integer in 1..8 (prio_TX), got %s', num2str(ownPriority));
end
if numel(thresholdListDbm) ~= 64
    error('mac:preemption:badThresholdList', 'preemption: thresholdListDbm must have 64 entries (sl-Thres-RSRP-List, 8x8 priority pairs), got %d', numel(thresholdListDbm));
end
if T3 < 1 || mod(T3, 1) ~= 0
    error('mac:preemption:badT3', 'preemption: T3 must be a positive integer number of slots, got %s', num2str(T3));
end
if thresholdOffsetDb < 0
    error('mac:preemption:badOffset', 'preemption: thresholdOffsetDb must be nonnegative (candidateSet''s thresholdOffsetFinalDb), got %s', num2str(thresholdOffsetDb));
end
if ~ischar(slPreemptionEnable) || (~isempty(slPreemptionEnable) && ~isrow(slPreemptionEnable))
    error('mac:preemption:badPreemptionEnable', 'preemption: slPreemptionEnable must be a char row vector: '''' (not provided), ''enabled'', or ''pl1''..''pl8''');
end
prioPre = 0;   % 0 means "no prio_pre gate", used only in the 'enabled' case
if isempty(slPreemptionEnable)
    % TS 38.214 clause 8.1.4: both bullets require sl-PreemptionEnable to be provided, so with
    % the field absent no resource is ever reported for pre-emption.
    preempted = false(1, nRes);
    checkedIdx = false(1, nRes);
    return;
elseif strcmp(slPreemptionEnable, 'enabled')
    prioPre = 0;
elseif numel(slPreemptionEnable) == 3 && strncmp(slPreemptionEnable, 'pl', 2) && any(slPreemptionEnable(3) == '12345678')
    prioPre = slPreemptionEnable(3) - '0';
else
    error('mac:preemption:badPreemptionEnable', 'preemption: slPreemptionEnable must be '''', ''enabled'' or ''pl1''..''pl8'' (sl-PreemptionEnable-r16), got ''%s''', slPreemptionEnable);
end
signalledBySci = logical(signalledBySci);

preempted = false(1, nRes);
checkedIdx = false(1, nRes);
for i = 1:nRes
    if ~signalledBySci(i)
        continue;   % not yet announced -> reevaluation's resource set, not this one
    end
    % clause 5.22.1.2a: at T_3 before m, where m is the slot the resource is LOCATED in.
    if currentSlot < grantSlot(i) - T3
        continue;
    end
    checkedIdx(i) = true;
    preempted(i) = overlapsHigherPriority(db, grantSlot(i), grantStartSubch(i), grantLsubch, ...
        ownPriority, thresholdListDbm, thresholdOffsetDb, prioPre);
end
end

function hit = overlapsHigherPriority(db, slot, startSubch, lSubch, prioTx, thresholdListDbm, offsetDb, prioPre)
%overlapsHigherPriority One sensed reservation overlapping this resource, higher priority, above Th.
hit = false;
ownLo = startSubch;
ownHi = startSubch + lSubch - 1;
for k = 1:numel(db.slot)
    if db.priority(k) >= prioTx
        continue;   % clause 8.1.4: only a STRICTLY higher priority (numerically smaller) pre-empts
    end
    if prioPre > 0 && ~(db.priority(k) < prioPre)
        continue;   % clause 8.1.4's non-'enabled' branch: prio_RX < prio_pre, also strict
    end
    Th = thresholdListDbm(db.priority(k) + (prioTx - 1) * 8) + offsetDb;
    if db.rsrp(k) <= Th
        continue;   % below the (escalated) threshold -> not strong enough to pre-empt
    end
    if resourceHits(db.slot(k), db.startSubch(k), db.lSubch(k), slot, ownLo, ownHi)
        hit = true;
        return;
    end
    if db.chainedCount(k) >= 1 && resourceHits(db.chainedSlot1(k), db.chainedStart1(k), db.lSubch(k), slot, ownLo, ownHi)
        hit = true;
        return;
    end
    if db.chainedCount(k) >= 2 && resourceHits(db.chainedSlot2(k), db.chainedStart2(k), db.lSubch(k), slot, ownLo, ownHi)
        hit = true;
        return;
    end
end
end

function tf = resourceHits(resSlot, resStart, resLen, slot, ownLo, ownHi)
%resourceHits Same-slot, overlapping-sub-channel test.
tf = resSlot == slot && ownLo <= resStart + resLen - 1 && ownHi >= resStart;
end
