function [newSlot, newSubch, found] = resourceReplace(candY, candX, survivor, keptSlots, minGapSlots, maxReserve, draw)
%resourceReplace Draw a replacement for one resource removed by re-evaluation or pre-emption.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2a: "randomly select the time and frequency resource
%        from the resources indicated by the physical layer as specified in clause 8.1.4 of
%        TS 38.214 for either the removed resource or the dropped resource, according to the
%        amount of selected frequency resources, the selected number of HARQ retransmissions
%        and the remaining PDB of either SL data available in the logical channel(s) by
%        ensuring the minimum time gap between any two selected resources of the selected
%        sidelink grant in case that PSFCH is configured for this pool of resources, and that a
%        resource can be indicated by the time resource assignment of an SCI for a
%        retransmission according to clause 8.3.1.1 of TS 38.212."
%        The DRAW is "randomly select" and is therefore ours; the four qualifiers on it are not.
%Inputs: candY, candX  1 x Mtotal integer -- candidate enumeration from candidateSet, built with
%                      the grant's own L_subCH. That is the clause's "according to the amount of
%                      selected frequency resources", and it is satisfied by construction rather
%                      than re-checked here
%        survivor      1 x Mtotal logical -- S_A membership. The window candidateSet was called
%                      with carries "the remaining PDB", likewise by construction
%        keptSlots     1 x nKept integer -- logical slots of the grant's OTHER resources, the
%                      ones not being replaced
%        minGapSlots   integer, >=0 -- from phy.rx.policy.minResourceGapSlots
%        maxReserve    integer, 2 or 3 -- sl-MaxNumPerReserve
%        draw          real in [0,1) -- the uniform draw, an input as everywhere else
%Outputs: newSlot, newSubch  integer -- the replacement
%         found             logical -- false when no candidate satisfies every constraint
%
%THE THREE FILTERS, AND WHY EACH IS THE CLAUSE'S AND NOT A PREFERENCE
%---------------------------------------------------------------------
%  1. **Minimum time gap** from every kept resource. Clause 5.22.1.1 defines it as the PSFCH
%     wait plus processing; a replacement closer than that produces a retransmission scheduled
%     before its own feedback could arrive.
%  2. **TRIV encodability.** After the swap the whole resource set must still fit
%     clause 8.3.1.1's time resource assignment, i.e. span no more than
%     phy.ts38212.trivOffsetRange allows. Checking only the replaced resource against the old
%     anchor is not enough: the replacement can BECOME the anchor, moving the whole window.
%  3. **Distinct slots.** Two resources of one grant in one slot is one transmission.
%
%NOTE 2 IS WHY `found` IS A RETURN VALUE
%----------------------------------------
%The clause anticipates failure: "If retransmission resource(s) cannot be selected by ensuring
%that the resource(s) can be indicated by the time resource assignment of a prior SCI, how to
%select the time and frequency resources ... is left for UE implementation by ensuring the
%minimum time gap". So no-candidate is a normal outcome with an implementation-defined
%response, not an error. This function reports it and lets the caller decide; raising here would
%make a congested pool crash rather than degrade.

if ~any(maxReserve == [2 3])
    error('policy:resourceReplace:badMaxReserve', 'resourceReplace: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
if ~(draw >= 0 && draw < 1)
    error('policy:resourceReplace:badDraw', 'resourceReplace: draw must be in [0,1), got %s', num2str(draw));
end

nAfter = numel(keptSlots) + 1;
if nAfter > maxReserve
    error('policy:resourceReplace:tooManyResources', 'resourceReplace: replacing would give %d resources, above sl-MaxNumPerReserve = %d', nAfter, maxReserve);
end
[t1Max, t2Max] = phy.ts38212.trivOffsetRange(min(3, max(2, nAfter)));
spanMax = max(t1Max, t2Max);

eligible = survivor;
for k = 1:numel(keptSlots)
    eligible = eligible & (abs(candY - keptSlots(k)) >= max(1, minGapSlots));
end
if ~isempty(keptSlots)
    % The post-swap set must span no more than TRIV can express, measured from whichever
    % resource ends up earliest -- which may be the replacement itself.
    lo = min(keptSlots);
    hi = max(keptSlots);
    eligible = eligible & (max(candY, hi) - min(candY, lo) <= spanMax);
end

if ~any(eligible)
    newSlot = 0; newSubch = 0; found = false;
    return;
end

[newSlot, newSubch] = phy.rx.policy.resourcePick(candY, candX, eligible, draw);
found = true;
end
