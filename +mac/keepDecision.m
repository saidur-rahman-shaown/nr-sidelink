function keep = keepDecision(draw, slProbResourceKeep)
%keepDecision The sl-ProbResourceKeep branch taken when the counter reaches zero.
%Spec:   TS 38.321 V16.22.0, clauses 5.22.1.1 and 5.22.1.2. The two clauses state the SAME draw
%        with OPPOSITE comparisons, and between them they partition the outcome:
%          5.22.1.1 (reuse the grant): "if SL_RESOURCE_RESELECTION_COUNTER = 0 and when
%            SL_RESOURCE_RESELECTION_COUNTER was equal to 1 the MAC entity randomly selected,
%            with equal probability, a value in the interval [0, 1] which is LESS THAN OR EQUAL
%            TO the probability configured by RRC in sl-ProbResourceKeep"
%          5.22.1.2 (trigger reselection): "... a value in the interval [0, 1] which is ABOVE
%            the probability configured by RRC in sl-ProbResourceKeep"
%        so keep <=> draw <= sl-ProbResourceKeep, and reselect <=> draw > sl-ProbResourceKeep,
%        with the boundary belonging to KEEP.
%Inputs: draw                real in [0,1] -- the value the MAC entity "randomly selected, with
%                            equal probability" from [0,1] at the moment the counter was equal to
%                            1. Passed in rather than drawn here: this package generates no
%                            randomness internally (no rand(), no persistent RNG state), because
%                            the normative-packages rule forbids hidden state and because a grant
%                            lifecycle has to be replayable and diffable. The caller owns the RNG.
%        slProbResourceKeep  real, one of {0, 0.2, 0.4, 0.6, 0.8} -- sl-ProbResourceKeep-r16,
%                            already resolved from its enum label by +cfg/private/resolveEnum.m
%                            (which maps 'v0'->0, 'v0dot2'->0.2, ... and keeps it as a double).
%Outputs: keep  logical scalar -- true to REUSE the previously selected sidelink grant (clause
%               5.22.1.1's branch: redraw the counter and keep the resources), false to trigger
%               TX resource reselection (clause 5.22.1.2's branch: clear the grant).
%
%Note what the timing actually is, because the wording hides it: the draw happens when the
%counter was equal to ONE, but the decision is acted on when the counter reaches ZERO. Both
%clauses say "SL_RESOURCE_RESELECTION_COUNTER = 0 and WHEN [it] WAS EQUAL TO 1 the MAC entity
%randomly selected ...". So the draw is made one MAC PDU early and stored; it is not a fresh draw
%at expiry. A lifecycle that draws at zero instead of at one still produces the right long-run
%keep rate and is therefore invisible to a statistical test -- grantOnTransmission is where this
%package pins the timing down, by capturing the draw on the 1->0 transition.
%
%sl-ProbResourceKeep = 0 means never keep: draw >= 0 always, and draw <= 0 only when the draw is
%exactly 0, an event of probability zero for a continuous draw. The boundary is left as the spec
%writes it ("less than or equal to") rather than special-cased.
if ~isscalar(draw) || ~isreal(draw) || draw < 0 || draw > 1
    error('mac:keepDecision:badDraw', 'keepDecision: draw must be a real scalar in [0,1] (clause 5.22.1.1: "a value in the interval [0, 1]"), got %s', num2str(draw));
end
if ~isscalar(slProbResourceKeep) || ~any(slProbResourceKeep == [0 0.2 0.4 0.6 0.8])
    error('mac:keepDecision:badProb', 'keepDecision: slProbResourceKeep must be one of {0, 0.2, 0.4, 0.6, 0.8} (sl-ProbResourceKeep-r16 resolved), got %s', num2str(slProbResourceKeep));
end

keep = draw <= slProbResourceKeep;   % clause 5.22.1.1's comparison; 5.22.1.2 is its complement
end
