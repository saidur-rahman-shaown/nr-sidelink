function [slots, subch, N] = resourcePickChained(candY, candX, survivor, draws, maxReserve)
%resourcePickChained Draw one initial resource and its chained retransmissions from S_A.
%Spec:   the DRAW is unspecified -- TS 38.321 clause 5.22.1.1 says only "randomly selects".
%        The CONSTRAINT is not: TS 38.214 clause 8.1.5 and TS 38.212 clause 8.3.1.1 let TRIV
%        signal a chained resource only 1..31 logical slots after the one carrying the SCI, and
%        FRIV requires every resource of the reservation to share one L_subCH.
%Inputs: candY, candX  1 x Mtotal integer -- the candidate enumeration from
%                      phy.ts38214.candidateSet
%        survivor      1 x Mtotal logical -- membership of S_A
%        draws         1 x maxReserve real in [0,1) -- one uniform draw per resource. Inputs,
%                      never generated here, following +mac/'s rule so a grant replays exactly
%        maxReserve    integer, 2 or 3 -- sl-MaxNumPerReserve
%Outputs: slots  1 x N integer -- logical pool slots, ascending, slots(1) carrying the SCI
%         subch  1 x N integer -- starting sub-channel of each
%         N      integer, 1..maxReserve -- resources actually reserved
%
%WHY THE CHAINED RESOURCES CANNOT BE DRAWN INDEPENDENTLY
%--------------------------------------------------------
%The selection window is bounded by the packet delay budget and is routinely hundreds of slots
%wide; TRIV reaches 31. Drawing each resource uniformly over the whole window therefore
%produces a gap that cannot be signalled **most of the time** -- and nothing downstream would
%notice, because a simulator that never encodes the SCI never discovers the field will not hold
%the value. The transmissions still happen, the KPI still comes out, and the grant is one no
%conformant UE could announce. This function draws the anchor freely and every chained resource
%from the anchor's reachable window only.
%
%N DEGRADES RATHER THAN FAILING
%-------------------------------
%If S_A holds nothing within reach of the anchor, N simply comes back smaller -- one resource
%instead of two, a transmission with no retransmission. That is a real outcome (a congested
%pool has no nearby free resource) and not an error, so it is reported as a value. Raising here
%would make a busy pool crash rather than degrade.
%
%The anchor is drawn from ALL of S_A rather than being biased early, so this function inherits
%whatever latency behaviour phy.rx.policy.resourcePick has -- see its note on the uniform draw
%and +phy/+rx/+policy/CLAUDE.md on T2.

if ~any(maxReserve == [2 3])
    error('policy:resourcePickChained:badMaxReserve', 'resourcePickChained: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
if numel(draws) < maxReserve
    error('policy:resourcePickChained:tooFewDraws', 'resourcePickChained: need %d draws, got %d', maxReserve, numel(draws));
end

% ---- the anchor: the resource that carries the SCI -------------------------
[anchorSlot, anchorSubch] = phy.rx.policy.resourcePick(candY, candX, survivor, draws(1));
slots = anchorSlot;
subch = anchorSubch;
N     = 1;

% ---- chained resources, each inside TRIV's reach --------------------------
for r = 2:maxReserve
    [t1Max, t2Max] = phy.ts38212.trivOffsetRange(r);
    if r == 2
        gapMax = t1Max;
    else
        gapMax = t2Max;
    end
    % Strictly after the previous resource and within reach of the ANCHOR: clause 8.1.5's
    % offsets are all measured from the SCI-carrying resource, not from each other.
    reachable = survivor & (candY > slots(end)) & (candY <= anchorSlot + gapMax);
    if ~any(reachable)
        break;                       % nothing in reach: reserve fewer resources, do not fail
    end
    [s, x] = phy.rx.policy.resourcePick(candY, candX, reachable, draws(r));
    slots(end + 1) = s;  %#ok<AGROW>
    subch(end + 1) = x;  %#ok<AGROW>
    N = N + 1;
end
end
