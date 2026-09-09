function [lo, hi] = creselCounterRange(pRsvpTxMs)
%creselCounterRange Draw range for SL_RESOURCE_RESELECTION_COUNTER.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.1: "randomly select, with equal probability, an
%        integer value in the interval [5, 15] for the resource reservation interval higher than
%        or equal to 100ms or in the interval [5 x ceil(100/max(20, P_rsvp_TX)), 15 x
%        ceil(100/max(20, P_rsvp_TX))] for the resource reservation interval lower than 100ms
%        and set SL_RESOURCE_RESELECTION_COUNTER to the selected value". The same sentence
%        appears twice in the clause -- once when reselection is triggered, once on the
%        sl-ProbResourceKeep "keep" branch -- and this function serves both.
%Inputs: pRsvpTxMs  real, >0 -- P_rsvp_TX, the resource reservation interval in ms, already
%                   chosen by the caller from sl-ResourceReservePeriodList (clause 5.22.1.1
%                   selects it one step earlier; NOTE 3A wants it larger than the remaining PDB,
%                   which is a caller decision). An aperiodic grant has no counter at all --
%                   clause 5.22.1.3.1a: the counter exists only for "transmissions of multiple
%                   MAC PDUs with Sidelink resource allocation mode 2" -- so 0 is not a valid
%                   input here, callers branch on periodicity before calling.
%Outputs: lo, hi  positive integers -- the inclusive bounds of the uniform draw. The draw itself
%                 is NOT performed here: randomness is an explicit input everywhere in this
%                 package (see +mac/CLAUDE.md) so that a lifecycle can be replayed and diffed.
%
%The multiplier is a scale factor on the whole interval, not an offset: at P_rsvp_TX >= 100 ms
%the interval is literally [5,15], and below 100 ms both endpoints are multiplied by the same
%ceil(100/max(20,P_rsvp_TX)). The effect is to keep the counter's WALL-CLOCK lifetime roughly
%constant -- a UE reserving every 20 ms burns through counts five times faster than one
%reserving every 100 ms, so it is given five times as many.
%
%KNOWN TRAP, and the reason this function exists as its own module: the ceil() argument is a
%FRACTION, 100/max(20, P_rsvp_TX). The reformatted spec notes in Documentations/Notes/
%01-TS38321-MAC-Sidelink-Procedures.md render it with the division bar lost, as
%"5 x ceil(100 max(20, P_rsvp_TX))", which reads as a product and is off by orders of magnitude.
%This formula was therefore re-read from Documentations/38321-gm0.pdf directly (clause 5.22.1.1,
%around the SL_RESOURCE_RESELECTION_COUNTER sentence) rather than from the notes -- the same
%pdftotext-mangles-formulas failure +phy/+ts38214/CLAUDE.md records for its own N_symb^sh term.
%The max(20, .) floor matters too: without it a 10 ms reservation period would give
%ceil(100/10)=10 rather than ceil(100/20)=5, doubling the counter.
if ~isscalar(pRsvpTxMs) || ~isreal(pRsvpTxMs) || pRsvpTxMs <= 0
    error('mac:creselCounterRange:badPeriod', 'creselCounterRange: pRsvpTxMs must be a real scalar > 0 ms (an aperiodic grant maintains no SL_RESOURCE_RESELECTION_COUNTER), got %s', num2str(pRsvpTxMs));
end

baseLo = 5;    % clause 5.22.1.1, the [5, 15] interval
baseHi = 15;
periodThresholdMs = 100;   % clause 5.22.1.1: the "higher than or equal to 100ms" branch point
periodFloorMs = 20;        % clause 5.22.1.1: the max(20, P_rsvp_TX) floor inside the ceiling

if pRsvpTxMs >= periodThresholdMs
    scale = 1;
else
    scale = ceil(periodThresholdMs / max(periodFloorMs, pRsvpTxMs));
end
lo = baseLo * scale;
hi = baseHi * scale;
end
