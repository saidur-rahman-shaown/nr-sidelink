function gap = minResourceGapSlots(anchorSlot, psfchPeriod, minTimeGapPsfch, prepSlots)
%minResourceGapSlots Minimum time gap between any two resources of one selected grant.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.1: "For a selected sidelink grant, the minimum time
%        gap between any two selected resources comprises: - a time gap between the end of the
%        last symbol of a PSSCH transmission of the first resource and the start of the first
%        symbol of the corresponding PSFCH reception determined by sl-MinTimeGapPSFCH and
%        sl-PSFCH-Period for the pool of resources; and - a time required for PSFCH reception
%        and processing plus sidelink retransmission preparation including multiplexing of
%        necessary physical channels and any TX-RX/RX-TX switching time."
%        The clause's own NOTE leaves the second term to UE implementation, which is why this
%        is a policy function and not a +mac/ one -- the FIRST term is fully determined and is
%        computed here from the spec's own timing module.
%Inputs: anchorSlot       integer, >=0 -- logical pool slot of the earlier resource. The first
%                         term depends on it, because PSFCH occasions are periodic and the wait
%                         to the next one varies with where in the period the PSSCH lands
%        psfchPeriod      integer, 0, 1, 2 or 4 -- sl-PSFCH-Period. **0 means PSFCH is disabled
%                         and the gap is 0**: the constraint exists only "in case that PSFCH is
%                         configured for this pool of resources"
%        minTimeGapPsfch  integer, >=1 -- sl-MinTimeGapPSFCH, in pool slots
%        prepSlots        integer, >=0 -- the UE-implementation term: PSFCH reception and
%                         processing, retransmission preparation, multiplexing and switching
%Outputs: gap  integer, >=0, logical pool slots -- the minimum separation between this resource
%              and any other resource of the same selected grant
%
%WHY THIS CONSTRAINT EXISTS AND WHAT IGNORING IT LOOKS LIKE
%-----------------------------------------------------------
%A retransmission scheduled before its own feedback could arrive is not a retransmission, it is
%a blind repeat that also happens to be unacknowledgeable. A simulator that ignores the gap
%reports the HARQ gain of feedback while actually running open loop, and the error flatters
%every reliability figure: the two transmissions are closer together, so the packet completes
%sooner and the latency looks better too. Nothing in the KPI set contradicts it.
%
%The first term is `psfchTiming(anchorSlot, ...) - anchorSlot`, i.e. exactly the wait to the
%PSFCH occasion that will carry this resource's feedback. It is computed rather than
%approximated by minTimeGapPsfch alone, because a PSFCH occasion falls only every
%sl-PSFCH-Period slots: with period 4 the true wait is up to 3 slots longer than the configured
%minimum, and using the minimum would place a retransmission before the feedback for it exists.

if ~any(psfchPeriod == [0 1 2 4])
    error('policy:minResourceGapSlots:badPeriod', 'minResourceGapSlots: psfchPeriod must be 0, 1, 2 or 4 (sl-PSFCH-Period), got %s', num2str(psfchPeriod));
end
if ~(prepSlots >= 0 && mod(prepSlots, 1) == 0)
    error('policy:minResourceGapSlots:badPrep', 'minResourceGapSlots: prepSlots must be a nonnegative integer, got %s', num2str(prepSlots));
end

if psfchPeriod == 0
    gap = 0;                      % no PSFCH configured: the clause's condition is not met
    return;
end

psfchSlot = phy.ts38213.psfchTiming(anchorSlot, minTimeGapPsfch, psfchPeriod);
gap       = (psfchSlot - anchorSlot) + prepSlots;
end
