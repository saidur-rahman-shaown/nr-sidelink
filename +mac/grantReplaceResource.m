function g = grantReplaceResource(g, idx, newSlot, newStartSubch)
%grantReplaceResource Remove one resource from the selected grant and put another in its place.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2a, the three bullets under the re-evaluation /
%        pre-emption condition:
%          "2> remove the resource(s) from the selected sidelink grant associated to the
%              Sidelink process;"
%          "2> randomly select the time and frequency resource from the resources indicated by
%              the physical layer ... for either the removed resource or the dropped resource"
%          "2> replace the removed or dropped resource(s) by the selected resource(s) for the
%              selected sidelink grant."
%        The random selection itself is not here -- it is a UE-implementation choice and lives
%        in +phy/+rx/+policy/. This function is the "remove" and "replace" halves, which are
%        normative grant bookkeeping.
%Inputs: g              struct with a grant installed
%        idx            integer, 1..nOpp -- which resource is being replaced
%        newSlot        integer -- logical pool slot of the replacement
%        newStartSubch  integer, >=0 -- its starting sub-channel
%Outputs: g  the grant with that one resource swapped, resources re-sorted ascending, and the
%            per-opportunity used flags carried with their resources
%
%THE GRANT KEEPS ITS SIZE
%------------------------
%The clause replaces, it does not drop. A grant that loses a resource without gaining one would
%quietly lose a retransmission opportunity and, over several checks, decay to a single
%transmission -- which looks like a working grant and reads as a reliability loss with no cause.
%Callers that genuinely cannot find a replacement must decide what to do explicitly; this
%function is not the place to express "gave up".
%
%RE-SORTING IS NOT COSMETIC
%---------------------------
%grantSelect fixes the ordering "index 1 is the initial transmission opportunity, higher indices
%are retransmission opportunities", and grantOnTransmission, the TRIV encoding and the
%signalled/not-signalled partition in clause 5.22.1.2a all read that ordering. A replacement can
%land earlier than the resource it replaced, so the array is re-sorted and `txOppUsed` is
%permuted with it. Leaving the array unsorted silently makes resource 1 stop being the anchor.
%
%The replacement's used flag is FALSE: it is a resource that has not been transmitted on. That
%is true even when the resource it replaced had been used -- which cannot happen for
%re-evaluation (its resources are not yet signalled, let alone transmitted) but can for
%pre-emption, whose resources are announced. A pre-empted resource that was already transmitted
%on is not a resource with a future, so the caller should not be replacing it.

if ~g.hasGrant
    error('mac:grantReplaceResource:noGrant', 'grantReplaceResource: no selected sidelink grant is installed');
end
nOpp = numel(g.txOppSlot);
if ~(isscalar(idx) && mod(idx, 1) == 0 && idx >= 1 && idx <= nOpp)
    error('mac:grantReplaceResource:badIndex', 'grantReplaceResource: idx must be an integer in 1..%d, got %s', nOpp, num2str(idx));
end
if ~(isscalar(newSlot) && mod(newSlot, 1) == 0 && newSlot >= 0)
    error('mac:grantReplaceResource:badSlot', 'grantReplaceResource: newSlot must be a nonnegative integer logical slot, got %s', num2str(newSlot));
end
if ~(isscalar(newStartSubch) && mod(newStartSubch, 1) == 0 && newStartSubch >= 0)
    error('mac:grantReplaceResource:badSubch', 'grantReplaceResource: newStartSubch must be a nonnegative integer, got %s', num2str(newStartSubch));
end
others = setdiff(1:nOpp, idx);
if any(g.txOppSlot(others) == newSlot)
    error('mac:grantReplaceResource:duplicateSlot', 'grantReplaceResource: slot %s already holds another resource of this grant', num2str(newSlot));
end

g.txOppSlot(idx)       = newSlot;
g.txOppStartSubch(idx) = newStartSubch;
g.txOppUsed(idx)       = false;

[g.txOppSlot, order]  = sort(g.txOppSlot);
g.txOppStartSubch     = g.txOppStartSubch(order);
g.txOppUsed           = g.txOppUsed(order);
end
