function test_policy()
%test_policy Unit tests for +phy/+rx/+policy/, the Mode-2 selection policy.
%SPEC: the policy itself is non-normative -- TS 38.214 V16.17.0 clause 8.1.4 leaves T1, T2 and
%      the draw from S_A to UE implementation. What IS testable, and what these tests assert,
%      is that every choice this package makes lands inside the bounds clause 8.1.4 does fix,
%      and that phy.ts38214.candidateSet accepts it. Per +phy/+rx/CLAUDE.md there is no
%      correctness test for a policy; there is a legality test, which is this file.

pol = phy.rx.policy.defaults();

%% ---- remainingPdbSlots -------------------------------------------------
% 100 ms PDB at mu=1 (0.5 ms slots) is 200 slots. Nothing elapsed yet.
[rem, expired] = phy.rx.policy.remainingPdbSlots(100, 0, 0, 1);
assert(rem == 200 && ~expired, 'remainingPdbSlots: 100 ms at mu=1 is 200 slots, got %d', rem);
% Numerology scaling: the same PDB is half as many slots at mu=0.
assert(phy.rx.policy.remainingPdbSlots(100, 0, 0, 0) == 100, 'remainingPdbSlots: must scale with 2^mu');
assert(phy.rx.policy.remainingPdbSlots(100, 0, 0, 3) == 800, 'remainingPdbSlots: must scale with 2^mu at mu=3');
% Elapsed time comes off the budget, one slot at a time.
assert(phy.rx.policy.remainingPdbSlots(100, 10, 60, 1) == 150, 'remainingPdbSlots: 50 slots elapsed must leave 150');
% Exactly exhausted, and past exhausted, both clamp to 0 and report expired.
[rem, expired] = phy.rx.policy.remainingPdbSlots(100, 0, 200, 1);
assert(rem == 0 && expired, 'remainingPdbSlots: budget exactly spent must report expired');
[rem, expired] = phy.rx.policy.remainingPdbSlots(100, 0, 500, 1);
assert(rem == 0 && expired, 'remainingPdbSlots: overrun must clamp at 0, not go negative, got %d', rem);
% A budget shorter than one slot floors to zero rather than rounding up to one.
assert(phy.rx.policy.remainingPdbSlots(0.4, 0, 0, 1) == 0, 'remainingPdbSlots: must floor, not round -- a partial slot is not usable');
mustError(@() phy.rx.policy.remainingPdbSlots(100, 50, 10, 1), 'policy:remainingPdbSlots:negativeAge', 'currentSlot before genSlot');

%% ---- selectionWindow ---------------------------------------------------
% T1 is T_proc,1 exactly, at every numerology, and is never the 2.5 ms figure written down.
for mu = 0:3
    [T1, ~, ~] = phy.rx.policy.selectionWindow(mu, 1000);
    assert(T1 == phy.ts38214.procTimeSelection(mu), 'selectionWindow: T1 must equal T_proc,1 at mu=%d', mu);
end
% The mu=1 case the simulator is configured around: 5 slots, which is 2.5 ms at 0.5 ms/slot.
[T1, T2, feasible] = phy.rx.policy.selectionWindow(1, 200);
assert(T1 == 5, 'selectionWindow: T_proc,1 at mu=1 is 5 slots (= 2.5 ms), got %d', T1);
assert(T2 == 200, 'selectionWindow: T2 must be the whole remaining PDB, got %d', T2);
assert(feasible, 'selectionWindow: a 200-slot budget comfortably admits a 5-slot processing time');
% T2 tracks the budget as it drains, so the window closes rather than sliding.
[~, T2, ~] = phy.rx.policy.selectionWindow(1, 37);
assert(T2 == 37, 'selectionWindow: T2 must follow the remaining PDB, not a constant');
% The feasibility boundary sits exactly at T_proc,1: T2 == T1 is a one-slot window and legal.
[~, ~, feasible] = phy.rx.policy.selectionWindow(1, 5);
assert(feasible, 'selectionWindow: remainingPdb == T_proc,1 gives the single slot n+T1 and must be feasible');
[~, ~, feasible] = phy.rx.policy.selectionWindow(1, 4);
assert(~feasible, 'selectionWindow: remainingPdb below T_proc,1 has no legal non-empty window and must report infeasible');
[~, ~, feasible] = phy.rx.policy.selectionWindow(1, 0);
assert(~feasible, 'selectionWindow: an exhausted budget must report infeasible');

%% ---- the policy is legal by candidateSet's own reckoning ---------------
% The point of this block: candidateSet re-derives both clause 8.1.4 bounds and raises on a
% violation. Feeding it this policy's output over a wide sweep of budgets is the strongest
% statement available that the choice is inside the spec -- and it covers BOTH of the clause's
% T2 branches without the policy testing which one it is in.
db = phy.ts38214.sensingDbInit();
for mu = 0:3
    T2minRaw = 20;                       % the largest sl-SelectionWindow, so T2min = 20*2^mu
    tProc1   = phy.ts38214.procTimeSelection(mu);
    % Budgets spanning well below T2min (forcing the "T2 = PDB outright" branch) to well above
    % it (the "[T2min, PDB]" range branch).
    for remPdb = [tProc1, tProc1 + 3, 20 * 2^mu, 20 * 2^mu + 25]
        [req, feasible] = phy.rx.policy.selectionRequest(1000, mu, remPdb, 4, 5, pol);
        assert(feasible, 'selectionRequest: budget %d at mu=%d should be feasible', remPdb, mu);
        % Does not raise => T1 and T2 both passed candidateSet's clause 8.1.4 validation.
        [candY, candX, survivor, Mtotal] = phy.ts38214.candidateSet( ...
            req, 10, 100, mu, db, repmat(-110, 1, 64), 0.2, [100], T2minRaw, 100000, pol.maxEscalations);
        assert(Mtotal > 0, 'candidateSet: a feasible window must enumerate at least one candidate');
        assert(all(candY >= 1000 + req.T1) && all(candY <= 1000 + req.T2), 'candidateSet: every candidate must lie in [n+T1, n+T2]');
        % An empty sensing database excludes nothing, so S_A is every candidate.
        assert(all(survivor), 'candidateSet: with no sensed reservations nothing may be excluded');
        assert(numel(candX) == Mtotal, 'candidateSet: candX must be M_total long');
    end
end

% The infeasible case must be caught by the policy, not by candidateSet's emptyWindow error.
[req, feasible] = phy.rx.policy.selectionRequest(1000, 1, 3, 4, 5, pol);
assert(~feasible, 'selectionRequest: a 3-slot budget at mu=1 is below T_proc,1 = 5 and must report infeasible');
assert(req.T2 == 3, 'selectionRequest: req is still fully formed on the infeasible path, for the discard log');

%% ---- selectionRequest field plumbing -----------------------------------
[req, ~] = phy.rx.policy.selectionRequest(4242, 1, 200, 2, 30, pol);
assert(req.n == 4242 && req.prioTx == 2 && req.Cresel == 30, 'selectionRequest: trigger values must pass through unchanged');
assert(req.remainingPdbSlots == 200 && req.T2 == 200, 'selectionRequest: T2 and remainingPdbSlots must agree under this policy');
assert(req.LsubCH == pol.LsubCH && req.prsvpTxMs == pol.prsvpTxMs, 'selectionRequest: policy defaults must reach req');
% Varying the policy per call is the whole point of passing it in.
alt = pol; alt.LsubCH = 5; alt.prsvpTxMs = 50;
[reqAlt, ~] = phy.rx.policy.selectionRequest(4242, 1, 200, 2, 30, alt);
assert(reqAlt.LsubCH == 5 && reqAlt.prsvpTxMs == 50, 'selectionRequest: an alternative policy struct must be honoured');
% Clause 8.1.4's aperiodic constraint.
aper = pol; aper.prsvpTxMs = 0;
mustError(@() phy.rx.policy.selectionRequest(1000, 1, 200, 4, 5, aper), 'policy:selectionRequest:aperiodicCresel', 'Cresel must be 1 when aperiodic');
[reqAper, ~] = phy.rx.policy.selectionRequest(1000, 1, 200, 4, 1, aper);
assert(reqAper.Cresel == 1, 'selectionRequest: aperiodic with Cresel = 1 must be accepted');
mustError(@() phy.rx.policy.selectionRequest(1000, 1, 200, 0, 5, pol), 'policy:selectionRequest:badPrio', 'prioTx 0 is out of 1..8');
mustError(@() phy.rx.policy.selectionRequest(1000, 1, 200, 9, 5, pol), 'policy:selectionRequest:badPrio', 'prioTx 9 is out of 1..8');

%% ---- resourcePick ------------------------------------------------------
candY    = [10 10 11 11 12 12];
candX    = [ 0  2  0  2  0  2];
survivor = logical([0 1 1 0 0 1]);       % S_A = indices 2, 3, 6
% draw is partitioned into nSurv = 3 equal intervals, in survivor order.
[slot, subch, idx] = phy.rx.policy.resourcePick(candY, candX, survivor, 0.0);
assert(idx == 2 && slot == 10 && subch == 2, 'resourcePick: draw 0 must give the first survivor, got idx %d', idx);
[~, ~, idx] = phy.rx.policy.resourcePick(candY, candX, survivor, 0.34);
assert(idx == 3, 'resourcePick: draw 0.34 of 3 survivors must give the second, got idx %d', idx);
[slot, subch, idx] = phy.rx.policy.resourcePick(candY, candX, survivor, 0.999);
assert(idx == 6 && slot == 12 && subch == 2, 'resourcePick: draw just below 1 must give the last survivor, got idx %d', idx);
% It must never return a non-survivor, at any draw.
for d = 0:0.01:0.99
    [~, ~, idx] = phy.rx.policy.resourcePick(candY, candX, survivor, d);
    assert(survivor(idx), 'resourcePick: draw %.2f returned excluded candidate %d', d, idx);
end
% Uniformity over S_A: each of the 3 survivors must take exactly a third of the draws.
counts = zeros(1, numel(candY));
draws  = (0:999) / 1000;
for d = draws
    [~, ~, idx] = phy.rx.policy.resourcePick(candY, candX, survivor, d);
    counts(idx) = counts(idx) + 1;
end
assert(isequal(counts, [0 334 333 0 0 333]), 'resourcePick: the draw must partition [0,1) uniformly over S_A, got %s', mat2str(counts));
% Single survivor: every draw must reach it, including the top of the range.
one = logical([0 0 0 0 0 1]);
assert(phy.rx.policy.resourcePick(candY, candX, one, 0.99999999) == 12, 'resourcePick: a single survivor must absorb every draw');
mustError(@() phy.rx.policy.resourcePick(candY, candX, false(1, 6), 0.5), 'policy:resourcePick:emptySA', 'an empty S_A');
mustError(@() phy.rx.policy.resourcePick(candY, candX, survivor, 1.0), 'policy:resourcePick:badDraw', 'draw must be < 1');
mustError(@() phy.rx.policy.resourcePick(candY, candX(1:3), survivor, 0.5), 'policy:resourcePick:sizeMismatch', 'mismatched vector lengths');

%% ---- defaults ----------------------------------------------------------
% Not correctness -- these assert the defaults stay inside the ranges their consumers document,
% so a careless edit to defaults.m fails here rather than deep inside candidateSet.
assert(pol.LsubCH >= 1 && mod(pol.LsubCH, 1) == 0, 'defaults: LsubCH must be a positive integer');
assert(pol.mcs >= 0 && pol.mcs <= 31 && mod(pol.mcs, 1) == 0, 'defaults: mcs must be in 0..31 (SCI-1A field range)');
assert(pol.prsvpTxMs >= 0, 'defaults: prsvpTxMs must be nonnegative');
assert(pol.numRetx >= 0 && mod(pol.numRetx, 1) == 0, 'defaults: numRetx must be a nonnegative integer');
assert(pol.maxEscalations >= 1 && mod(pol.maxEscalations, 1) == 0, 'defaults: maxEscalations must be a positive integer');
% The default MCS must resolve in the default (no additional) MCS table.
[modulation, Qm, ~] = phy.ts38214.mcsTableSelect(pol.mcs, '', 0);
assert(Qm == 2 && strcmp(modulation, 'QPSK'), 'defaults: mcs %d must be QPSK for a no-CSI broadcast default, got %s', pol.mcs, modulation);

%% ---- pdbLogicalSlots: wall clock -> pool opportunities -----------------
% On the baseline pool the conversion is the identity, which is exactly why the unit confusion
% it prevents is invisible there.
mu = 1;
[~, loAll, ~] = harness.poolAllSlots(mu);
[remLog, nLog] = phy.rx.policy.pdbLogicalSlots(loAll, 1000, 200);
assert(nLog == 1000, 'pdbLogicalSlots: on the identity pool the logical index equals the physical, got %d', nLog);
assert(remLog == 200, 'pdbLogicalSlots: on the all-slots pool the budget is unchanged, got %d', remLog);

% A pool holding every other slot: the same wall-clock budget buys HALF the opportunities.
% This is the case that separates a correct conversion from passing physical slots straight
% through -- the shortcut would claim 200 opportunities where only 100 exist.
N     = 10240 * 2^mu;
none  = false(1, N);
alt   = repmat([true false], 1, 5);        % L_bitmap = 10, every other slot
[~, loAlt, TpAlt] = phy.ts38214.poolSlotMap(mu, none, none, alt);
assert(TpAlt == N / 2, 'test setup: the alternating bitmap must halve the pool, got %d', TpAlt);
[remHalf, nHalf] = phy.rx.policy.pdbLogicalSlots(loAlt, 1000, 200);
assert(nHalf == 500, 'pdbLogicalSlots: physical slot 1000 is logical slot 500 in a half pool, got %d', nHalf);
assert(remHalf == 100, 'pdbLogicalSlots: a 200-physical-slot budget buys 100 opportunities in a half pool, got %d', remHalf);
% ...and the naive pass-through would have been 200, i.e. double. Pin the discrepancy.
assert(remHalf * 2 == 200, 'the half pool must halve the budget, or this test proves nothing');

% Strictly after `now`: the current slot is never one of the remaining opportunities.
[remZero, ~] = phy.rx.policy.pdbLogicalSlots(loAll, 1000, 0);
assert(remZero == 0, 'pdbLogicalSlots: a spent budget offers no further opportunity, got %d', remZero);
[remOne, ~] = phy.rx.policy.pdbLogicalSlots(loAll, 1000, 1);
assert(remOne == 1, 'pdbLogicalSlots: one physical slot of budget is exactly one opportunity on the identity pool, got %d', remOne);

% n must be a pool slot -- clause 8.1.4's n is defined only there.
mustError(@() phy.rx.policy.pdbLogicalSlots(loAlt, 1001, 200), 'policy:pdbLogicalSlots:notPoolSlot', 'a trigger slot outside the pool');
mustError(@() phy.rx.policy.pdbLogicalSlots(loAll, N, 200), 'policy:pdbLogicalSlots:nowOutOfRange', 'a slot past the DFN period');
mustError(@() phy.rx.policy.pdbLogicalSlots(loAll, -1, 200), 'policy:pdbLogicalSlots:badNow', 'a negative slot');
% The clamp at the end of the period, rather than a wrap.
[remEnd, ~] = phy.rx.policy.pdbLogicalSlots(loAll, N - 5, 200);
assert(remEnd == 4, 'pdbLogicalSlots: the budget must clamp at the end of the DFN period, got %d', remEnd);

%% ---- the full chain, in the order callers must use it ------------------
% PQI 55: 100 ms PDB. mu=1 -> 200 physical slots -> 100 opportunities in the half pool.
t   = cfg.pqiTable();
row = t([t.PQI] == 55);
[remPhys, expired] = phy.rx.policy.remainingPdbSlots(row.PDB_ms, 900, 1000, mu);
assert(remPhys == 100 && ~expired, 'chain: 200-slot budget with 100 elapsed leaves 100 physical slots, got %d', remPhys);
[remLogical, nTrig] = phy.rx.policy.pdbLogicalSlots(loAlt, 1000, remPhys);
assert(remLogical == 50, 'chain: 100 physical slots is 50 opportunities in a half pool, got %d', remLogical);
[reqChain, feasChain] = phy.rx.policy.selectionRequest(nTrig, mu, remLogical, row.priority, 5, pol);
assert(feasChain, 'chain: 50 opportunities comfortably exceeds T_proc,1 = 5');
assert(reqChain.T2 == 50 && reqChain.n == nTrig, 'chain: T2 must be the logical budget and n the logical trigger slot');
% candidateSet accepts it, and every candidate lies inside the window.
[cy, ~, ~, Mt] = phy.ts38214.candidateSet(reqChain, 10, 100, mu, db, repmat(-110, 1, 64), 0.2, [100], 20, 100000, pol.maxEscalations);
assert(Mt > 0 && all(cy >= nTrig + reqChain.T1) && all(cy <= nTrig + reqChain.T2), 'chain: candidates must lie in the logical window');

fprintf('test_policy: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
%mustError Assert fh() raises, with the expected identifier.
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_policy:noError', 'expected an error for %s, none raised', what);
end
