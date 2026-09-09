function [g, counterHitZero] = grantOnPeriodEnd(g, keepDraw)
%grantOnPeriodEnd Close one reservation period: decrement the counter, age the unused count.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1a -- "if this transmission corresponds to the last
%        transmission of the MAC PDU: decrement SL_RESOURCE_RESELECTION_COUNTER by 1, if
%        available"; and clause 5.22.1.2 -- the sl-ReselectAfter count is incremented "by 1 when
%        none of the resources of the selected sidelink grant within a resource reservation
%        interval is used". Both are PER RESERVATION PERIOD events, which is why they live in one
%        function called once per period rather than being sprinkled through the slot loop.
%Inputs: g         struct with a grant installed
%        keepDraw  real in [0,1] -- a freshly drawn uniform value, used ONLY on the transition
%                  where the counter goes from 1 to 0. Clauses 5.22.1.1 and 5.22.1.2 both take
%                  the sl-ProbResourceKeep draw "when SL_RESOURCE_RESELECTION_COUNTER WAS EQUAL
%                  TO 1" and act on it once the counter reads 0, so it is captured here, one
%                  period early, and stored in g.keepDraw for keepDecision to consume. On every
%                  other period the value is ignored -- pass anything in range.
%Outputs: g               updated state
%         counterHitZero  logical -- true on exactly the period where the counter reached 0, i.e.
%                         the period after which the caller must resolve the keep-vs-reselect
%                         branch via keepDecision(g.keepDraw, sl-ProbResourceKeep)
%
%KNOWN TRAP (+mac/CLAUDE.md's third): the counter decrements ONCE PER RESERVED OCCASION -- once
%per MAC PDU, i.e. once per reservation period -- NOT once per slot and NOT once per transmission.
%A grant with an initial transmission plus two retransmission opportunities carries ONE MAC PDU
%per period and so costs ONE count, not three. Decrementing per transmission burns the counter
%at the retransmission multiple and shortens every grant's life by that factor, while still
%producing a plausible-looking SPS pattern.
%
%The unused-period count is likewise per period and resets on ANY use: clause 5.22.1.2 increments
%it only when NONE of the period's resources was used, so a single transmission anywhere in the
%period clears the streak.
if ~g.hasGrant
    error('mac:grantOnPeriodEnd:noGrant', 'grantOnPeriodEnd: no selected sidelink grant is installed');
end
if ~isscalar(keepDraw) || ~isreal(keepDraw) || keepDraw < 0 || keepDraw > 1
    error('mac:grantOnPeriodEnd:badDraw', 'grantOnPeriodEnd: keepDraw must be a real scalar in [0,1], got %s', num2str(keepDraw));
end

% clause 5.22.1.2: increment only when NONE of the period's resources was used; any use resets.
if any(g.txOppUsed)
    g.consecutiveUnusedPeriods = 0;
else
    g.consecutiveUnusedPeriods = g.consecutiveUnusedPeriods + 1;
end
g.txOppUsed = false(1, numel(g.txOppSlot));   % a new reservation period starts unused

counterHitZero = false;
if g.isPeriodic && g.counter > 0
    if g.counter == 1
        % clauses 5.22.1.1 / 5.22.1.2: the draw is taken while the counter is still 1, stored,
        % and acted upon once it reads 0.
        g.keepDraw = keepDraw;
        g.keepDrawPending = true;
    end
    g.counter = g.counter - 1;   % once per MAC PDU / reservation period, never once per slot
    counterHitZero = g.counter == 0;
end
end
