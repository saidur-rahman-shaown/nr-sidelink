function test_agreement()
%test_agreement LLS and SLS must agree on link outcome. +harness/CLAUDE.md's Phase 3 gate.
%SPEC: none -- this is the calibration check between the two fidelities. "for a scenario simple
%      enough to run in both, PRR must agree within a stated tolerance. If it does not, the
%      abstraction is wrong, not the LLS."
%
%WHY THIS IS NOT TAUTOLOGICAL
%-----------------------------
%The table harness.phyabs.blerLookup reads was measured by the very link-level chain this test
%re-runs, so agreement AT a measured grid point proves only that the emitter copied the numbers
%correctly. The test therefore probes BETWEEN grid points, where the answer comes from
%harness.phyabs.blerInterp's interpolation rule rather than from a stored value, and at MCS
%values the table did not measure, where it comes from the nearest-MCS rule. Those two rules are
%what an SLS run actually exercises, and neither is checked by the sweep that produced the table.
%
%It also pins the thing most likely to drift: that both paths mean the SAME THING by "SINR".
%The link level defines it as Es/N0 per resource element after the channel; the system level
%computes it from received power over noise plus interference in the allocation's bandwidth. If
%those definitions diverge -- a factor for the occupied-subcarrier ratio, a per-RE versus
%per-allocation convention -- every curve shifts horizontally and nothing else in the simulator
%contradicts it.

tbl  = harness.phyabs.blerTable();
scen = harness.sls.scenarioInit(4, 1);
tol  = 0.15;                          % stated tolerance, absolute BLER

%% ---- the table itself is well formed -----------------------------------
assert(issorted(tbl.snrDb), 'the SNR axis must be ascending for interpolation');
assert(all(tbl.pssch(:) >= 0 & tbl.pssch(:) <= 1), 'every BLER must be a probability');
assert(all(tbl.pscch(:) >= 0 & tbl.pscch(:) <= 1), 'every PSCCH BLER must be a probability');
% Saturated at both ends, or the grid was too narrow and the clamp will show up as a floor in
% the KPI rather than as an error.
assert(all(tbl.pssch(:, 1, 1) > 0.9), 'the lowest SNR must be at BLER ~1 for every MCS, got %s', mat2str(tbl.pssch(:, 1, 1)', 3));
assert(all(tbl.pssch(:, end, 1) < 0.1), 'the highest SNR must be at BLER ~0 for every MCS, got %s', mat2str(tbl.pssch(:, end, 1)', 3));
% Monotone in SNR, allowing for finite-sample noise.
for m = 1:numel(tbl.mcs)
    c = squeeze(tbl.pssch(m, :, 1));
    assert(all(diff(c) < 0.25), 'MCS %d BLER must not rise with SNR beyond sampling noise: %s', tbl.mcs(m), mat2str(c, 3));
end
% Higher MCS needs more SNR: the waterfall midpoint must move right with the index.
mid = zeros(1, numel(tbl.mcs));
for m = 1:numel(tbl.mcs)
    c = squeeze(tbl.pssch(m, :, 1));
    k = find(c <= 0.5, 1);
    mid(m) = tbl.snrDb(k);
end
assert(all(diff(mid) > 0), 'the waterfall must move right with MCS, got midpoints %s', mat2str(mid));

%% ---- interpolation and out-of-range behave as documented ---------------
lowest = harness.phyabs.blerLookup(tbl.mcs(1), tbl.snrDb(1) - 50, 1, 'awgn', 0);
assert(abs(lowest - tbl.pssch(1, 1, 1)) < 1e-12, 'below the grid the answer must CLAMP, not extrapolate');
highest = harness.phyabs.blerLookup(tbl.mcs(1), tbl.snrDb(end) + 50, 1, 'awgn', 0);
assert(abs(highest - tbl.pssch(1, end, 1)) < 1e-12, 'above the grid the answer must clamp');
assert(harness.phyabs.blerLookup(tbl.mcs(1), NaN, 1, 'awgn', 0) == 1, 'an unheard link never decodes');
% An off-key lookup is an error, never a substitution.
mustError(@() harness.phyabs.blerLookup(tbl.mcs(1), 0, 1, 'tdl-c', 0), 'phyabs:blerLookup:unknownModel', 'a channel model the table was not measured under');
mustError(@() harness.phyabs.blerLookup(tbl.mcs(1), 0, 1, 'awgn', 60), 'phyabs:blerLookup:unknownSpeed', 'a speed the table was not measured at');
% Retransmissions may only help.
for m = tbl.mcs
    b = arrayfun(@(a) harness.phyabs.blerLookup(m, 2, a, 'awgn', 0), 1:numel(tbl.attempt));
    assert(all(diff(b) <= 1e-12), 'MCS %d: BLER must not rise with attempts, got %s', m, mat2str(b, 3));
end

%% ---- THE GATE: measured link outcome vs the abstraction, between grid points
% Probing halfway between measured SNRs, so the prediction comes from the interpolation rule.
mcs = tbl.mcs(2);
lc  = harness.lls.linkConfig(mcs, tbl.meta.LsubCH, scen);
st  = RandStream('mt19937ar', 'Seed', 4242);

% Pick probe points that straddle the waterfall, where disagreement would actually show.
c   = squeeze(tbl.pssch(2, :, 1));
kMid = find(c <= 0.5, 1);
probes = tbl.snrDb(max(1, kMid - 1)) + 0.5 + [0 1];

nTrials = 40;
for j = 1:numel(probes)
    snr = probes(j);
    predicted = harness.phyabs.blerLookup(mcs, snr, 1, 'awgn', 0);
    fails = 0;
    for t = 1:nTrials
        r = harness.lls.linkSlot(lc, snr, st, 0, []);
        fails = fails + ~r.psschOk;
    end
    measured = fails / nTrials;
    assert(abs(measured - predicted) <= tol, ...
        'LLS and SLS disagree at MCS %d, SNR %.1f dB: link level measured %.3f, the abstraction predicts %.3f (tolerance %.2f). Per +harness/CLAUDE.md the abstraction is wrong, not the LLS.', ...
        mcs, snr, measured, predicted, tol);
end

%% ---- the PSCCH curve is to the LEFT of the PSSCH curve -----------------
% The system-level model decodes SCI at a lower effective MCS than data, on the argument that
% control is far lower rate. This is the measurement that either supports that or does not.
for m = 1:numel(tbl.mcs)
    cData = squeeze(tbl.pssch(m, :, 1));
    cCtrl = tbl.pscch(m, :);
    kD = find(cData <= 0.5, 1);
    kC = find(cCtrl <= 0.5, 1);
    assert(~isempty(kC), 'the PSCCH curve must reach BLER 0.5 somewhere in the grid for MCS %d', tbl.mcs(m));
    assert(tbl.snrDb(kC) <= tbl.snrDb(kD), ...
        'PSCCH must decode at or below the PSSCH''s SNR (MCS %d: control %.0f dB, data %.0f dB)', ...
        tbl.mcs(m), tbl.snrDb(kC), tbl.snrDb(kD));
end

fprintf('test_agreement: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_agreement:noError', 'expected an error for %s, none raised', what);
end
