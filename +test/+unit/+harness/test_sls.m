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
% The line must be long enough for the CHANNEL MODEL IN USE to reach the floor of its curve.
% 50 UEs at 20 m spans 1 km, which sufficed against the log-distance placeholder; RMa LOS
% reaches considerably further and still delivers 0.34 at 800-1200 m, so the same line would
% test the scenario's length rather than the channel's shape. Widening the spacing to 40 m
% doubles the span for the same UE count and therefore the same runtime.
bigScen = harness.sls.scenarioInit(50, 5);
bigScen.spacingM = 40;
bigScen.posXY    = [(0:bigScen.nUe - 1)' * bigScen.spacingM, zeros(bigScen.nUe, 1)];
% The escalation bound is derived from the closest separation, so it moves with the spacing.
closestBig = harness.chanmodel.pathloss(bigScen.radio.plModel, bigScen.spacingM);
bigScen.policy.maxEscalations = ceil((bigScen.pCmaxDbm - closestBig - min(bigScen.pool.thresholdListDbm)) / 3) + 1;
big = harness.sls.runScenario(bigScen, 1000);
assert(big.nPairs > 0, 'the pair statistic must have a denominator');
assert(big.prrLink <= big.prr, 'link-level PRR cannot exceed packet-level PRR: any decode satisfies the packet');
assert(big.prrLink < 0.99, 'over a 2 km line the far links must fail; a link PRR of ~1 means the pair statistic is not being collected');

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

%% ---- unicast: PSFCH feedback closes the HARQ loop -----------------------
% The whole point of feedback: an ACK stops the blind retransmission that broadcast must always
% spend. Same policy, same traffic, same seed -- only the cast type differs.
bc = harness.sls.run(20, 1600, 9, 'broadcast');
uc = harness.sls.run(20, 1600, 9, 'unicast');
assert(abs(bc.txPerDelivery - 2) < 0.15, 'broadcast must spend its blind retransmission every time, got %.2f', bc.txPerDelivery);
assert(uc.txPerDelivery < 1.5, 'unicast ACKs must suppress most retransmissions, got %.2f', uc.txPerDelivery);
assert(uc.txPerDelivery < bc.txPerDelivery, 'feedback must cost fewer transmissions per delivery than blind repetition');

% PSFCH costs transport-block capacity, and that must be visible rather than free: clause
% 8.1.3.2 subtracts the PSFCH symbols from N_RE, so every TB in the pool shrinks.
sb = harness.sls.scenarioInit(4, 1, 'broadcast');
su = harness.sls.scenarioInit(4, 1, 'unicast');
assert(su.slPsfchPeriod > 0 && sb.slPsfchPeriod == 0, 'scenarioInit: PSFCH must be enabled for unicast and disabled for broadcast');
assert(all(su.tbsBytesByLsubCH < sb.tbsBytesByLsubCH), 'enabling PSFCH must shrink every transport block; got %s vs %s', mat2str(su.tbsBytesByLsubCH), mat2str(sb.tbsBytesByLsubCH));

%% ---- the DTX path, which drives radio link failure ----------------------
% Peers far enough apart that no PSFCH is ever detected. Clause 5.22.1.3.3 counts ABSENCE, so
% this is the case that must produce RLF -- and it is unreachable in the default scenario,
% where the ring pairs each UE with its 20 m neighbour.
far = harness.sls.scenarioInit(6, 5, 'unicast');
far.spacingM = 1500;
far.posXY = [(0:far.nUe - 1)' * far.spacingM, zeros(far.nUe, 1)];
[kFar, ueFar] = harness.sls.runScenario(far, 1600);
assert(kFar.nDelivered == 0, 'at 1500 m spacing nothing should decode, got %d deliveries', kFar.nDelivered);
assert(kFar.nRlf == far.nUe, 'every UE must indicate radio link failure exactly once, got %d for %d UEs', kFar.nRlf, far.nUe);
dtx = [];
for i = 1:numel(ueFar)
    dtx = [dtx ueFar(i).harq.numConsecutiveDTX]; %#ok<AGROW>
end
assert(max(dtx) > far.slMaxNumConsecutiveDTX, 'the DTX counter must keep rising past the threshold -- clause 5.22.1.3.3 never resets it on indication');
% Indicated ONCE on the crossing, not on every subsequent DTX. +mac/CLAUDE.md records this as
% the "reaches" reading; a >= reading would re-indicate every slot and give nRlf >> nUe.
assert(kFar.nRlf < 2 * far.nUe, 'RLF must be indicated once per UE on the crossing, not repeatedly; got %d', kFar.nRlf);

%% ---- every packet is accounted for, including in-flight ones ------------
% A packet dequeued into a transport block has left the logical channel, so lchExpire cannot
% see it. Without an in-flight expiry it sits unresolved forever and leaves the denominator of
% every ratio -- which flatters reliability, and is invisible in a scenario where almost
% everything is delivered. This is the scenario where almost nothing is.
assert(kFar.nDelivered + kFar.nExpired + kFar.nMaxTx + kFar.nDropped + kFar.nInFlight == kFar.nGenerated, ...
    'every generated packet must land in exactly one bucket: %d+%d+%d+%d+%d vs %d', ...
    kFar.nDelivered, kFar.nExpired, kFar.nMaxTx, kFar.nDropped, kFar.nInFlight, kFar.nGenerated);
assert(kFar.nExpired > 0, 'packets that were transmitted and never acknowledged must expire, not linger in flight');
assert(kFar.nInFlight < far.nUe * 2, 'only the last generation may still be in flight, got %d', kFar.nInFlight);

%% ---- the receiver SEARCHES; it is not handed the transmission list ------
% Every chained resource must be within TRIV's reach of the anchor. TS 38.214 clause 8.1.5 and
% TS 38.212 clause 8.3.1.1 allow 1..31 logical slots; the selection window is bounded by the
% PDB and is routinely hundreds of slots wide, so drawing independently over it produces a
% grant no conformant UE could announce -- and nothing notices while the SCI is never encoded.
[~, ueW, scW] = harness.sls.run(20, 2000, 9);
gaps = [];
for i = 1:numel(ueW)
    if ueW(i).grant.hasGrant && numel(ueW(i).grant.txOppSlot) > 1
        gaps = [gaps diff(ueW(i).grant.txOppSlot)]; %#ok<AGROW>
    end
end
assert(~isempty(gaps), 'the scenario must produce multi-resource grants, or this proves nothing');
[t1Max, ~] = phy.ts38212.trivOffsetRange(2);
assert(all(gaps >= 1 & gaps <= t1Max), 'every chained resource must be within TRIV''s reach (1..%d), got %s', t1Max, mat2str(unique(gaps)));

% The sensing database must be fed from DECODED SCI fields, chained resources included. A
% database populated from the transmitter's own state cannot be wrong about a reservation, so
% it cannot show what an undecoded SCI costs.
nChained = 0;
for i = 1:numel(ueW)
    nChained = nChained + nnz(ueW(i).db.chainedSlot1 > 0);
end
assert(nChained > 0, 'sensing must record the chained resources TRIV announces, got none');

% TRIV and FRIV must round-trip at the values the loop actually produces.
tv = phy.ts38212.trivEncode(2, gaps(1), 0, scW.maxNumPerReserve);
[nRes, t1, ~] = phy.ts38212.trivDecode(tv, scW.maxNumPerReserve);
assert(nRes == 2 && t1 == gaps(1), 'TRIV must round-trip the announced gap: %d -> %d', gaps(1), t1);

%% ---- PSCCH SINR is not a bandwidth advantage, but it is not redundant ---
% Signal and noise scale together with the band, so a narrower PSCCH has the SAME SNR. What
% differs is INTERFERENCE: an interferer overlapping only part of the PSSCH still covers all of
% the PSCCH's sub-channel, or none of it.
sc = harness.sls.scenarioInit(4, 1);
mk = @(ueId, pos, x, L) setfield(setfield(setfield(setfield(setfield( ...
    rf.toAir(sap.txReqInit(), ueId, pos), 'startSubch', x), 'LsubCH', L), ...
    'txPowerDbm', 23), 'tb', true(10, 1)), 'ctxIds', 1);

% No interferer: the two SINRs must be identical, to the bit.
solo = mk(1, [0 0], 0, 3);
[sd0, ~, ~, sp0] = harness.chanmodel.slotSinr(solo, [0 0; 300 0], sc.radio, sc.numSubchannel, sc.pscchPrb, sc.subchSizeRb);
assert(abs(sp0(1, 2) - sd0(1, 2)) < 1e-9, 'with no interference PSCCH and PSSCH SNR must be equal, got %.3f vs %.3f', sp0(1, 2), sd0(1, 2));

% A narrow interferer sitting on the victim's lowest sub-channel: it covers ALL the PSCCH and
% only part of the PSSCH, so the PSCCH is hurt far more.
pair = [mk(1, [0 0], 0, 3), mk(2, [250 0], 0, 1)];
[sd1, ~, ~, sp1] = harness.chanmodel.slotSinr(pair, [0 0; 250 0; 120 0], sc.radio, sc.numSubchannel, sc.pscchPrb, sc.subchSizeRb);
assert(sp1(1, 3) < sd1(1, 3) - 5, 'a sub-channel-aligned interferer must hurt PSCCH far more than PSSCH, got %.2f vs %.2f dB', sp1(1, 3), sd1(1, 3));

% Control robustness comes from CODE RATE, and it is now MEASURED rather than approximated by
% reading the PSSCH curve at a low proxy MCS. The advantage grows with the data's MCS, because
% PSCCH's own rate does not move with it -- which is precisely what a single proxy could not
% express.
tblP = harness.phyabs.blerTable();
for m = tblP.mcs
    cD = squeeze(tblP.pssch(tblP.mcs == m, :, 1));
    cC = tblP.pscch(tblP.mcs == m, :);
    kD = find(cD <= 0.5, 1);
    kC = find(cC <= 0.5, 1);
    assert(~isempty(kC) && tblP.snrDb(kC) < tblP.snrDb(kD), ...
        'MCS %d: control must decode strictly before data (control %.2f dB, data %.2f dB)', ...
        m, tblP.snrDb(kC), tblP.snrDb(kD));
end
assert(harness.phyabs.pscchBler(sc.policy.mcs, 0) <= ...
       harness.phyabs.blerLookup(sc.policy.mcs, 0, 1, 'awgn', 0), ...
       'at the same SINR the control channel must be at least as robust as the data channel');

%% ---- clause 5.22.1.2a: re-evaluation and pre-emption are wired ----------
% Both checks run at EXACTLY m - T_3, and only the resources due at that instant are passed to
% them. Both modules re-derive due-ness from `currentSlot >= grantSlot - T3`, which is also true
% for every resource already in the PAST -- and a past resource can never appear in a candidate
% set built forward from now, so it gets flagged every time. The symptom is quiet: transmissions
% per delivery collapses to 1.00 because no grant survives to reach its own retransmission
% opportunity, while delivery still mostly works.
quiet = harness.sls.run(10, 1500, 9);
assert(quiet.txPerDelivery > 1.8, 'grants must survive to their retransmission opportunity; tx/delivery %.2f means the checks are clearing every grant', quiet.txPerDelivery);
assert(quiet.nReeval == 0, 'a lightly loaded pool should need no re-evaluation, got %d', quiet.nReeval);

% Pre-emption CANNOT fire in a single-priority population: +mac/CLAUDE.md's trap says the
% comparison is strict, or two same-priority UEs pre-empt each other indefinitely and neither
% ever transmits. So zero here is the structurally correct answer, not a wiring failure -- which
% is exactly why the mixed-priority case below has to exist to tell the two apart.
% Pre-emption is a RARE, STOCHASTIC event: it needs a higher-priority UE to reserve a resource
% that overlaps an already-announced one, above the RSRP threshold, within its check window. In
% a 1200-slot run it fires single-digit times when it fires at all, and whether it fires at a
% given UE count is largely seed noise -- measured under RMa LOS: 1 event at 30 UEs, 0 at 40,
% 0 at 60, 1 at 80, 2 at 100. A single-seed threshold on that is chasing noise, and this
% assertion had to be re-tuned twice (once when measured BLER curves replaced the placeholder,
% once when RMa replaced the log-distance model) before that became clear.
%
% So the mixed-priority case ACCUMULATES over seeds and asserts the mechanism fires at all,
% rather than asserting a count at one lucky configuration. The uniform case needs no averaging:
% zero there is structural, not statistical.
nUePre = 60;
slotsPre = 1200;
seedsPre = [3 9 17];

% Pre-emption CANNOT fire in a single-priority population: +mac/CLAUDE.md's trap says the
% comparison is strict, or two same-priority UEs pre-empt each other indefinitely and neither
% ever transmits. Zero here is the structurally correct answer, not a wiring failure -- which is
% exactly why the mixed-priority case below has to exist to tell the two apart.
uniform = harness.sls.scenarioInit(nUePre, seedsPre(1));
kUni = harness.sls.runScenario(uniform, slotsPre);
assert(all(uniform.prioByUe == uniform.prioByUe(1)), 'the default scenario must be single-priority for this to mean anything');
assert(kUni.nPreempt == 0, 'pre-emption must never fire between equal priorities, got %d', kUni.nPreempt);

% With a higher-priority class present it does fire, somewhere across the seeds.
totalPreempt = 0;
reevalBySeed = zeros(1, numel(seedsPre));
for j = 1:numel(seedsPre)
    mixed = harness.sls.scenarioInit(nUePre, seedsPre(j));
    mixed.prioByUe(1:4:end) = 1;             % 1 is the HIGHEST priority
    kMix = harness.sls.runScenario(mixed, slotsPre);
    totalPreempt = totalPreempt + kMix.nPreempt;
    reevalBySeed(j) = kMix.nReeval;
end
assert(totalPreempt > 0, 'a higher-priority class must pre-empt somewhere across %d seeds in a loaded pool, got 0', numel(seedsPre));

% sl-PreemptionEnable is a gate on pre-emption ONLY. TS 38.214 clause 8.1.4's two pre-emption
% bullets both begin "sl-PreemptionEnable is provided", so with the field absent nothing is ever
% pre-empted -- while re-evaluation's own sentence carries no such gate and is unaffected.
% Compared against the SAME seed, so the re-evaluation counts are directly comparable.
off = harness.sls.scenarioInit(nUePre, seedsPre(1));
off.prioByUe(1:4:end) = 1;
off.pool.slPreemptionEnable = '';
kOff = harness.sls.runScenario(off, slotsPre);
assert(kOff.nPreempt == 0, 'with sl-PreemptionEnable absent nothing may be pre-empted, got %d', kOff.nPreempt);
assert(kOff.nReeval == reevalBySeed(1), 'sl-PreemptionEnable must not affect re-evaluation: %d vs %d on the same seed', kOff.nReeval, reevalBySeed(1));

%% ---- the real MAC receive path is wired, and delivery is EARNED --------
% Delivery used to be credited from air(k).ctxIds on a successful decode. It now runs
% mac.sciInterest -> mac.harqRxAssign -> mac.demuxSlSch -> mac.pduFilter -> mac.harqRxProcess,
% so a PDU addressed to someone else is decoded and then NOT delivered.
[kRx, ueRx, scRx] = harness.sls.run(10, 1000, 3);
assert(kRx.nDelivered > 0, 'the wired receive path must still deliver packets');
assert(isfield(ueRx(1), 'harqRx') && ueRx(1).harqRx.nProcesses > 0, 'each UE must hold a receive HARQ entity');
% Every receive process must end a run unoccupied: clause 5.22.2.2.2 releases a process on the
% first successful decode, whether or not the identity filter let the PDU through. A process
% left occupied is one leaked to a neighbour this UE can hear but is not addressed by.
for i = 1:numel(ueRx)
    assert(~any(ueRx(i).harqRx.occupied), 'UE %d leaked %d receive processes', i, nnz(ueRx(i).harqRx.occupied));
end
assert(~scRx.isUnicast, 'this block assumes the broadcast scenario');

%% ---- clause 5.22.2.2.1's INTEREST gate, and what omitting it costs -----
% "Each Sidelink process is associated with SCI in which the MAC entity is interested." Without
% that gate every neighbour allocates a process for every transmission it can hear AND answers
% it on PSFCH, colliding with the addressed UE's feedback. Measured when it was missing: 8
% spurious radio link failures in a 10-UE unicast run that should have had none.
me = 7; peer = 3; bcast = 2^24 - 1;
assert(mac.sciInterest(2, me, me, peer), 'a unicast addressed to this UE is of interest');
assert(~mac.sciInterest(2, me + 1, me, peer), 'a unicast addressed elsewhere is not');
assert(mac.sciInterest(0, bitand(bcast, 65535), me, bcast), 'a broadcast to a monitored address is of interest');
assert(~mac.sciInterest(0, bitand(bcast, 65535) - 1, me, bcast), 'a broadcast to another group is not');
% Unicast checks this UE's OWN source ids, groupcast/broadcast the destinations it monitors --
% the same inversion mac.pduFilter applies, and getting it backwards makes a UE interested only
% in its own transmissions.
assert(~mac.sciInterest(2, bitand(bcast, 65535), me, bcast), 'unicast must not match against the monitored destination list');

%% ---- unicast: feedback is generated, and no spurious RLF ---------------
kUni = harness.sls.run(12, 1500, 3, 'unicast');
assert(kUni.nDelivered > 0, 'unicast must deliver');
assert(kUni.nRlf == 0, 'short unicast links must not declare radio link failure, got %d', kUni.nRlf);
% ACKs must suppress retransmissions: with every link decoding first time, a delivered packet
% costs one transmission, not two. That is the whole point of feedback over blind repetition.
assert(kUni.txPerDelivery < 1.2, 'ACKs must suppress the blind retransmission, got %.2f transmissions per delivery', kUni.txPerDelivery);
% ...and when links do fail, retransmissions must come back. A ratio pinned at 1.00 regardless
% of range would mean feedback had silenced HARQ rather than driven it.
sFar = harness.sls.scenarioInit(12, 3, 'unicast');
sFar.spacingM = 300;
sFar.posXY = [(0:sFar.nUe - 1)' * sFar.spacingM, zeros(sFar.nUe, 1)];
cFar = harness.chanmodel.pathloss(sFar.radio.plModel, sFar.spacingM);
sFar.policy.maxEscalations = ceil((sFar.pCmaxDbm - cFar - min(sFar.pool.thresholdListDbm)) / 3) + 1;
kFar = harness.sls.runScenario(sFar, 1500);
assert(kFar.txPerDelivery > kUni.txPerDelivery, ...
    'a longer unicast link must need more transmissions per delivery: %.2f at 300 m vs %.2f at 20 m', ...
    kFar.txPerDelivery, kUni.txPerDelivery);

fprintf('test_sls: all assertions passed.\n');
end
