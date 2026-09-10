function g = grantOnKeep(g, counter)
%grantOnKeep Re-arm a selected grant whose counter expired and whose keep draw succeeded.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.1, the branch beginning "else if
%        SL_RESOURCE_RESELECTION_COUNTER = 0 and when SL_RESOURCE_RESELECTION_COUNTER was equal
%        to 1 the MAC entity randomly selected ... a value ... less than or equal to ...
%        sl-ProbResourceKeep":
%          "3> clear the selected sidelink grant, if available;"
%          "3> randomly select ... an integer value in the interval [5, 15] ... and set
%              SL_RESOURCE_RESELECTION_COUNTER to the selected value;"
%          "3> reuse the previously selected sidelink grant ..."
%Inputs: g        struct with a grant installed, whose counter has reached 0 and whose stored
%                 keep draw kept it (mac.keepDecision returned true)
%        counter  integer, >=1 -- the freshly drawn SL_RESOURCE_RESELECTION_COUNTER, from
%                 mac.creselCounterRange. Drawn by the caller, never here: this package
%                 generates no randomness
%Outputs: g  the same resources, with the counter re-armed and the spent keep draw cleared
%
%THE COUNTER IS RE-DRAWN ON KEEP. WITHOUT THIS THE GRANT IS IMMORTAL.
%---------------------------------------------------------------------
%The clause's keep branch is three bullets and the middle one is easy to lose, because the
%first ("clear the selected sidelink grant") and the third ("reuse the previously selected
%sidelink grant") read like they cancel out and the whole branch reads like a no-op. It is not:
%between them the counter is re-selected from the same interval as an initial selection.
%
%Skipping it leaves the counter at 0 and the stored keep draw in place, so every subsequent
%period re-evaluates the SAME draw against the SAME probability and gets the SAME answer. A
%grant that kept once keeps forever. The symptom is subtle in a KPI: SPS looks stable and
%well-behaved, resource reselection simply stops happening after the first keep, and
%sl-ProbResourceKeep becomes a one-shot coin flip that decides a grant's entire lifetime rather
%than a per-period one. Nothing errors, and the reservation pattern still looks plausible.
%
%The stored draw is cleared because it has been spent. Leaving it pending would let the next
%counter expiry act on a stale value drawn several periods earlier, which is the same class of
%error the draw's careful capture timing exists to prevent (see keepDecision and
%grantOnPeriodEnd).

if ~g.hasGrant
    error('mac:grantOnKeep:noGrant', 'grantOnKeep: no selected sidelink grant is installed');
end
if ~g.isPeriodic
    error('mac:grantOnKeep:notPeriodic', 'grantOnKeep: only a grant for multiple MAC PDUs has a counter to re-arm');
end
if g.counter ~= 0
    error('mac:grantOnKeep:counterNotExpired', 'grantOnKeep: the keep branch is reached only at SL_RESOURCE_RESELECTION_COUNTER = 0, got %s', num2str(g.counter));
end
if ~(isscalar(counter) && mod(counter, 1) == 0 && counter >= 1)
    error('mac:grantOnKeep:badCounter', 'grantOnKeep: counter must be an integer >= 1, got %s', num2str(counter));
end

g.counter                  = counter;
g.keepDrawPending          = false;
g.keepDraw                 = 0;
g.consecutiveUnusedPeriods = 0;
end
