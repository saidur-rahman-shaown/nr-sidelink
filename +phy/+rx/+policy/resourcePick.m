function [slot, subch, idx] = resourcePick(candY, candX, survivor, draw)
%resourcePick Draw one resource from the candidate set S_A.
%Spec:   TS 38.214 clause 8.1.4 stops at reporting S_A to higher layers, and TS 38.321 clause
%        5.22.1.1 says only that the MAC entity "randomly selects" from what was reported,
%        with the distribution unspecified. So this is the single decision the whole sensing
%        chain exists to inform, and it is entirely ours. +mac/grantSelect takes the chosen
%        resources as inputs precisely so this function, not it, makes the choice.
%Inputs: candY     1 x Mtotal integer row vector -- candidate logical slots, from candidateSet
%        candX     1 x Mtotal integer row vector -- candidate starting sub-channels
%        survivor  1 x Mtotal logical row vector -- true where the candidate is in S_A
%        draw      real in [0,1) -- the uniform random draw. An INPUT, never generated here:
%                  the same rule +mac/keepDecision and +mac/grantSelect follow, so a whole
%                  grant lifecycle replays exactly from its seed and diffs.
%Outputs: slot   integer -- logical pool slot of the chosen resource
%         subch  integer -- starting sub-channel of the chosen resource
%         idx    integer, 1..Mtotal -- its index in candY/candX, for logging and for the
%                re-evaluation and pre-emption checks in +mac/ that must refer to the same
%                resource later
%
%Uniform over S_A, which is the default reading of "randomly selects" and the one the 3GPP
%evaluation assumptions use. It is also deliberately latency-blind: it treats a resource one
%slot away and one 100 ms away as equally good, which together with T2 = PDB in
%phy.rx.policy.selectionWindow is what puts the mean access delay at half the window. An
%earliest-first or delay-weighted draw is the other obvious end of that trade and belongs
%here, as a sibling of this function -- but it trades collision probability for latency rather
%than improving both, so it has to be measured, not assumed.

if ~isequal(size(candY), size(candX)) || ~isequal(size(candY), size(survivor))
    error('policy:resourcePick:sizeMismatch', 'resourcePick: candY, candX and survivor must be the same size');
end
if ~islogical(survivor)
    error('policy:resourcePick:notLogical', 'resourcePick: survivor must be a logical vector');
end
if ~(draw >= 0 && draw < 1)
    error('policy:resourcePick:badDraw', 'resourcePick: draw must be in [0,1), got %s', num2str(draw));
end

idxAll = find(survivor);
nSurv  = numel(idxAll);
if nSurv == 0
    error('policy:resourcePick:emptySA', 'resourcePick: S_A is empty; candidateSet guarantees it is not, so the caller has corrupted the survivor mask');
end

% floor(draw*n)+1 is uniform on 1..n for draw uniform on [0,1). The min() guards only against
% a caller passing a draw that rounds to exactly 1 in floating point.
k   = min(nSurv, floor(draw * nSurv) + 1);
idx = idxAll(k);

slot  = candY(idx);
subch = candX(idx);
end
