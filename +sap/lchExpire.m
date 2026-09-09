function [lchSet, expired] = lchExpire(lchSet, nowPhys, mu)
%lchExpire Discard every queued SDU whose packet delay budget has run out.
%Spec:   the PDB is TS 23.287 clause 5.4.4; the discard is not specified anywhere. TS 38.321
%        has no sidelink discard timer (clause 5.22 has no analogue of the Uu
%        discardTimer), so the decision to drop rather than transmit late is ours, and it is
%        made here rather than in +mac/ for that reason.
%Inputs: lchSet   from +sap/lchInit
%        nowPhys  integer -- current PHYSICAL slot
%        mu       integer, 0..3 -- mu_SL
%Outputs: lchSet   with the expired contexts removed from the queue
%         expired  1 x nExpired struct array of contexts, each already resolved with
%                  +sap/ctxFinish(.pdbExpired). Hand them to the KPI log; they are LOSSES.
%
%THIS FUNCTION IS WHY THE LATENCY NUMBERS WILL BE HONEST
%--------------------------------------------------------
%Without it a packet sits in the queue until something eventually transmits it, and is then
%counted as a very slow success. That inflates throughput and stretches the latency tail with
%samples that should not exist, both in the flattering direction, and no other statistic in the
%run contradicts it. +phy/+rx/+policy/CLAUDE.md records the same trap on the selection side.
%
%Called once per slot, before LCP, so that a grant is never sized around data that is already
%dead. Ordering matters: expiring after allocation wastes the grant on packets that will be
%dropped anyway, which shows up as a throughput loss with no visible cause.
%
%A packet is expired on the budget's own boundary, not one slot later: +phy/+rx/+policy/
%remainingPdbSlots reports `expired` when the remaining budget reaches zero, and this function
%uses that verdict rather than recomputing the comparison, so the discard point and the
%selection-window feasibility point cannot drift apart.

codes = sap.outcomeCodes();
nQ    = numel(lchSet.q);
isDead = false(1, nQ);

for k = 1:nQ
    [~, dead] = phy.rx.policy.remainingPdbSlots(lchSet.q(k).pdbMs, lchSet.q(k).tGenSlot, nowPhys, mu);
    isDead(k) = dead;
end

expired = lchSet.q(isDead);
for k = 1:numel(expired)
    expired(k) = sap.ctxFinish(expired(k), codes.pdbExpired, nowPhys);
end

lchSet.q    = lchSet.q(~isDead);
lchSet.qLch = lchSet.qLch(~isDead);
end
