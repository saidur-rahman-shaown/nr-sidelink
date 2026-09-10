function [a, b] = crWindowSplit(totalSlots)
%crWindowSplit Split the CR measurement window [n-a, n+b] into its past and future halves.
%Spec:   TS 38.215 V16.7.0, clause 5.1.26 NOTE 1 fixes the TOTAL span (a+b+1, from
%        phy.ts38215.crWindowSlots) and the constraint b < (a+b+1)/2, and states that a and b
%        are otherwise "determined by UE implementation". So the split is a policy choice and
%        lives here; +phy/+ts38215/crWindowSlots' own header says the same.
%Inputs: totalSlots  integer, >=1 -- a + b + 1, from phy.ts38215.crWindowSlots
%Outputs: a  integer, >=1 -- past window length, slots
%         b  integer, >=0 -- future window length, slots, satisfying b < (a+b+1)/2
%
%THIS CUT: b = 0, ALL PAST.
%--------------------------
%CR is measured entirely from what the UE has already transmitted, with no projection of its
%current grant forward. That is the most conservative reading of the two and the easiest to
%reason about: the measurement is a fact rather than a forecast.
%
%It is also the one that reacts LATEST. Clause 5.1.26 NOTE 3 lets the future half assume "the
%transmission parameter used at slot n is reused according to the existing grant(s) in slot
%[n+1, n+b] without packet dropping" -- so a UE that has just selected a dense grant can see
%its own future occupancy immediately, and throttle before spending it, rather than a full
%window later. Raising b trades that responsiveness against acting on a projection that a
%reselection may invalidate. Which wins is measurable, which is why this is a function rather
%than a constant somewhere.
%
%b = 0 trivially satisfies b < (a+b+1)/2 for every legal total.

if ~(totalSlots >= 1 && mod(totalSlots, 1) == 0)
    error('policy:crWindowSplit:badTotal', 'crWindowSplit: totalSlots must be a positive integer, got %s', num2str(totalSlots));
end

b = 0;
a = totalSlots - 1;
if a < 1
    error('policy:crWindowSplit:tooShort', 'crWindowSplit: a CR window of %d slot(s) leaves no past to measure', totalSlots);
end
end
