function test_sls()
%test_sls End-to-end tests for the system-level simulator.
%SPEC: none directly -- this is +harness/, non-normative. The assertions are +harness/CLAUDE.md's
%      gate conditions (determinism, intra-slot ordering, PRR-versus-distance shape) plus the
%      conservation laws that make a KPI trustworthy.

%% ---- it closes the loop and conserves packets ---------------------------
k = harness.sls.run(6, 800, 11);
assert(k.nGenerated > 0, 'run: the traffic model must generate something in 800 slots');
assert(k.nDelivered + k.nExpired + k.nInFlight == k.nGenerated, ...
    'run: every packet must be delivered, expired or still in flight -- got %d + %d + %d vs %d generated', ...
    k.nDelivered, k.nExpired, k.nInFlight, k.nGenerated);
assert(k.nInFlight >= 0, 'run: in-flight cannot be negative -- a context was resolved twice');
% A packet left in flight at the end is excluded from every ratio, so it must not be able to
% flatter the result: assert it is a small tail, not the bulk of the run.
assert(k.nInFlight < 0.1 * k.nGenerated, 'run: %d of %d packets unresolved -- the run is too short to interpret', k.nInFlight, k.nGenerated);

%% ---- determinism, which every KPI claim rests on ------------------------
% isequaln, not isequal: empty distance bins carry NaN and NaN ~= NaN, so isequal reports a
% difference that is not one. That distinction is the test, not a detail.
a = harness.sls.run(6, 600, 3);
b = harness.sls.run(6, 600, 3);
c = harness.sls.run(6, 600, 4);
assert(isequaln(a, b), 'run: the same seed must reproduce a run exactly');
assert(~isequaln(a, c), 'run: a different seed must produce a different run, or the seed is not reaching the stream');

%% ---- latency is measured from generation, and honestly ------------------
[~, ue, scen] = harness.sls.run(6, 800, 11);
assert(all(k.latencyMs >= 0), 'latency cannot be negative');
assert(all(k.latencyMs <= scen.traffic.pdbMs), 'no DELIVERED packet may exceed its PDB -- lchExpire should have dropped it first');
assert(abs(k.latencyMeanMs - mean(k.latencyMs)) < 1e-9, 'the reported mean must be the mean of the reported samples');
assert(k.latencyP50Ms <= k.latencyP90Ms && k.latencyP90Ms <= k.latencyP99Ms && k.latencyP99Ms <= k.latencyMaxMs, ...
    'the latency percentiles must be ordered');
% Goodput is payload only. Recompute it independently from the delivered count.
runMs = 800 / 2^scen.mu;
assert(abs(k.goodputKbps - k.nDelivered * scen.traffic.sizeBytes * 8 / runMs) < 1e-6, ...
    'goodput must be delivered payload over wall-clock time, with no MAC overhead counted');

%% ---- the two reliability figures are different, and both are reported ---
% Packet-level PRR asks "did anyone decode it" and reads ~1 in any dense scenario regardless of
% the channel. Link-level PRR asks "of the receivers that could have heard it, how many did".
% Conflating them is how a simulator reports perfect reliability over a channel that is
% failing most of its links.
% 50 UEs at 20 m spacing spans ~1 km, which is what makes the far bins reach the floor of the
% curve. A shorter line simply does not contain any link far enough to fail outright, and the
% shape assertion below would then be testing the scenario rather than the channel.
big = harness.sls.run(50, 1000, 5);
assert(big.nPairs > 0, 'the pair statistic must have a denominator');
assert(big.prrLink <= big.prr, 'link-level PRR cannot exceed packet-level PRR: any decode satisfies the packet');
assert(big.prrLink < 0.99, 'in a 1 km line the far links must fail; a link PRR of ~1 means the pair statistic is not being collected');

%% ---- PRR versus distance has the expected shape -------------------------
% BUILD.md's B10 gate. Not a fixed curve -- that would pin the placeholder path loss model --
% but the shape: monotone non-increasing, high at the near end, ~zero at the far end.
p = big.prrByDistance;
valid = ~isnan(p);
pv = p(valid);
assert(numel(pv) >= 4, 'the scenario must span enough distance bins to show a shape, got %d', numel(pv));
assert(pv(1) > 0.9, 'PRR in the nearest bin must be high, got %.3f', pv(1));
assert(pv(end) < 0.05, 'PRR in the farthest bin must be at the floor of the curve, got %.3f', pv(end));
% and the far bins must actually be populated, or "near zero" is measuring an empty bin.
assert(big.pairsByDistance(find(valid, 1, 'last')) > 100, 'the farthest populated bin must hold enough pairs to mean anything');
% Monotone within tolerance: the placeholder channel is deterministic in distance, so the only
% non-monotonicity should be finite-sample noise in sparse bins.
drops = diff(pv);
assert(all(drops < 0.05), 'PRR must not rise with distance beyond sampling noise; got increases of %s', mat2str(drops(drops >= 0.05)));

%% ---- half-duplex is recorded, not merely modelled -----------------------
% A UE that transmits marks the slot unsensed. Without this the sensing database believes it
% observed slots it was deaf in, and the pool looks emptier than it is.
anyUnmonitored = false;
for i = 1:numel(ue)
    if isfield(ue(i).db, 'unmonitoredSlot') && ~isempty(ue(i).db.unmonitoredSlot)
        anyUnmonitored = true;
    end
end
assert(anyUnmonitored, 'every transmitting UE must have marked its own transmit slots unmonitored');

%% ---- transmissions per delivery reflects the configured retransmissions -
% policy.numRetx = 1, so an initial transmission plus one blind repeat. The ratio is below 2
% only because some transport blocks are still in flight when the run ends.
assert(k.txPerDelivery > 1.5 && k.txPerDelivery <= 2.5, ...
    'with one blind retransmission configured, transmissions per delivery must be near 2, got %.2f', k.txPerDelivery);

%% ---- a transmission can never be decided in the slot it occupies --------
% The causality that lets the slot loop run TX before RX and MAC: clause 8.1.4 forces
% T1 >= T_proc,1 > 0, so a grant selected in slot n first transmits at n + T1 or later.
scen2 = harness.sls.scenarioInit(4, 2);
assert(phy.ts38214.procTimeSelection(scen2.mu) > 0, 'T_proc,1 must be positive, or the slot loop ordering is unsound');

fprintf('test_sls: all assertions passed.\n');
end
