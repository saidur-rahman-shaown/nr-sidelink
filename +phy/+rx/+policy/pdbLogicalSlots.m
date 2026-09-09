function [remLogical, nLogical] = pdbLogicalSlots(logicalOfPhys, nowPhys, remPhys)
%pdbLogicalSlots Convert a wall-clock delay budget into pool-slot opportunities.
%Spec:   none directly, but it exists because of one: TS 38.214 clause 8.1.4 bounds T2 by "the
%        remaining packet delay budget" while every window in that clause is counted in LOGICAL
%        pool slots. A delay budget is wall clock, so the two are different units and something
%        has to convert. This does, and it is non-normative because the pool timeline it reads
%        is a configuration, not a procedure.
%Inputs: logicalOfPhys  1 x (10240*2^mu) integer -- from phy.ts38214.poolSlotMap; the logical
%                       index of each physical slot, or -1 where the slot is not in the pool
%        nowPhys        integer, >=0 -- the current PHYSICAL slot. Must be a pool slot: this is
%                       called at a selection trigger, and clause 8.1.4's n is a pool slot.
%        remPhys        integer, >=0 -- remaining budget in PHYSICAL slots, from
%                       phy.rx.policy.remainingPdbSlots
%Outputs: remLogical  integer, >=0 -- the budget expressed as a count of pool slots strictly
%                     after nowPhys and no later than the deadline. This is what
%                     candidateSet's req.remainingPdbSlots wants, and therefore the largest
%                     legal T2.
%         nLogical    integer, >=0 -- the logical index of nowPhys, i.e. clause 8.1.4's n
%
%WHY THIS IS NOT A MULTIPLICATION
%--------------------------------
%The tempting shortcut is remLogical = round(remPhys * T'max / nDfnSlots) -- scale by the pool's
%duty cycle. That is right on average and wrong in every particular, because pool slots are not
%evenly spaced: an S-SSB burst or a TDD pattern clusters the gaps. Near a cluster the average
%over-counts the opportunities actually reachable before the deadline, which is the direction
%that makes a packet look like it had time it did not have. Counting the actual slots in the
%window is exact, and the window is at most a few hundred slots, so the cost does not matter.
%
%STRICTLY AFTER nowPhys
%----------------------
%The count excludes nowPhys itself. T2 is an OFFSET from n, so T2 = k means logical slot n+k;
%the budget must therefore answer "how many pool slots come after n and still meet the
%deadline". Including n would return one too many and let T2 point one opportunity past the
%deadline -- a single-slot overrun, invisible in any statistic except a deadline-miss count.
%
%In the baseline pool (harness.poolAllSlots, every slot a sidelink slot) this function is the
%identity: remLogical == remPhys. That is a property of that configuration, not of the units,
%and is exactly why the confusion this function resolves is invisible there.
%
%No DFN wrap. Like phy.ts38214.candidateSet, this assumes the window does not cross the end of
%the 10240 ms period; selection windows are orders of magnitude shorter.

if ~(nowPhys >= 0 && mod(nowPhys, 1) == 0)
    error('policy:pdbLogicalSlots:badNow', 'pdbLogicalSlots: nowPhys must be a nonnegative integer, got %s', num2str(nowPhys));
end
if ~(remPhys >= 0 && mod(remPhys, 1) == 0)
    error('policy:pdbLogicalSlots:badRem', 'pdbLogicalSlots: remPhys must be a nonnegative integer, got %s', num2str(remPhys));
end
nDfnSlots = numel(logicalOfPhys);
if nowPhys >= nDfnSlots
    error('policy:pdbLogicalSlots:nowOutOfRange', 'pdbLogicalSlots: nowPhys %s is beyond the %s-slot DFN period', num2str(nowPhys), num2str(nDfnSlots));
end

nLogical = logicalOfPhys(nowPhys + 1);
if nLogical < 0
    error('policy:pdbLogicalSlots:notPoolSlot', 'pdbLogicalSlots: physical slot %s is not in the pool, so clause 8.1.4''s n is undefined there', num2str(nowPhys));
end

% The deadline is the last physical slot the packet may still be transmitted in. Clamp to the
% end of the period rather than wrapping.
deadlinePhys = min(nowPhys + remPhys, nDfnSlots - 1);
window       = logicalOfPhys(nowPhys + 2 : deadlinePhys + 1);   % strictly after nowPhys
remLogical   = nnz(window >= 0);
end
