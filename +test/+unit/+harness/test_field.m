function test_field()
%test_field The waveform-level field scenario (harness.field.run): five UEs, CAM + DENM + unicast,
%path loss and thermal noise between them, every packet through the full stack.
%SPEC: composition test -- each layer is tested in its own package. What this pins is what only a
%      multi-UE, multi-flow run exposes; both regressions below passed every two-UE test.
%Level 1: both ends are this tree.

c = fieldConfig();
% A fixed, static geometry (the original road layout), not fieldConfig's random drop: the
% assertions below depend on these link budgets (8.8-32.5 dB), not on whatever a drop gives.
c.ue.x = [0 120 260 450 700]; c.ue.y = [0 0 0 3.5 3.5]; c.ue.vMps = zeros(1, 5);
c.uni.to = 2;
c.sim.durationMs = 400;
c.denm.startMs = 100; c.denm.count = 2;
c.radio.fading = '';                          % path loss + noise only
c.impl.tReorderingMs = 0;                     % no first-packet hold at gc/bc receivers (see below)
r = harness.field.run(c);
s = harness.field.report(r);

% ---- reliability: high, not perfect -- Mode 2 collides --------------------------------------
% Two UEs selecting in the same slot cannot see each other's choice (nothing is announced yet),
% and a UE transmitting cannot receive (half duplex). Both cost CAM copies in this run, so the
% floor is a floor, not 1.
for t = 1:numel(s)
    assert(s(t).expected > 0, '%s: something was generated and finished inside the run', s(t).type);
    assert(s(t).late == 0, '%s: nothing delivered after its PDB (got %d)', s(t).type, s(t).late);
end
cam = s(strcmp({s.type}, 'cam'));
assert(cam.prr >= 0.9, 'CAM PRR %.3f on links of 8.8-32.5 dB without fading', cam.prr);

% ---- the collision record is consistent with itself ----------------------------------------
k = s(1).coll;
assert(k.nTx == numel(r.txLog) && k.nCollided <= k.nConcurrent && k.nSameStart <= k.nCollided, ...
    'collided transmissions are a subset of slot-sharing ones; same-start ones a subset of those');
assert(sum(k.outcome(:)) == sum(~[r.txLog.isRetx]) * (numel(r.ues) - 1), 'one outcome per (initial transmission, other UE)');
assert(k.outcome(1, 1) / sum(k.outcome(1, 1:3)) > 0.9, 'clean initial transmissions decode at listening receivers on these links');

% ---- TS 38.321 5.22.1.2 pdbNotMet: the DENM does not wait on a CAM's grant ------------------
% CAM and DENM are both broadcast, so one Destination and one grant. Before the check was wired,
% the DENM rode the grant the CAM had drawn up to 100 ms out and missed its 20 ms PDB.
denm = s(strcmp({s.type}, 'denm'));
assert(denm.onTime == denm.expected, 'every DENM copy within its 20 ms PDB (%d of %d, worst %.1f ms)', ...
    denm.onTime, denm.expected, denm.maxMs);
assert(r.ues(c.denm.ueIdx).stats.pdbReselect >= 1, ...
    'the DENM source cleared at least one grant that could not meet the DENM''s PDB');

% ---- round-robin HARQ process choice: no false duplicates -----------------------------------
% With the lowest free process, process 1 alternated between Destinations, a Destination's next
% TB repeated its last NDI, and the receiver discarded a new TB as a duplicate.
uni = s(strcmp({s.type}, 'uni'));
assert(uni.onTime == uni.expected, 'unicast: every packet delivered alongside broadcast');
assert(r.ues(c.uni.from).stats.ackRx >= 1, 'unicast HARQ feedback is running (ACKs received)');
pair = [c.uni.from c.uni.to];
others = setdiff(1:numel(r.ues), pair);
assert(all(arrayfun(@(u) u.stats.psfchSent, r.ues(pair)) >= 1) && ...
    all(arrayfun(@(u) u.stats.psfchSent, r.ues(others)) == 0), ...
    'PSFCH is sent by the unicast pair only: broadcast never requests feedback');

% ---- TS 38.323 7.1: the first packet from a new gc/bc source --------------------------------
% With in-order delivery (sl-OutOfOrderDelivery absent at the receiver) the first DENM waits
% t-Reordering, because the receive window starts below its SN. With out-of-order delivery (the
% stack default, gcbcRxOutOfOrder = true; TS 38.331 9.1.1.5 leaves it to the receiving UE) it is
% delivered at once: no head-of-line hold. The transmit side is identical in all three runs, so
% the first DENM is the same transport blocks.
c.impl.tReorderingMs = 10;
c.impl.gcbcRxOutOfOrder = false;
r10 = harness.field.run(c);
c.impl.gcbcRxOutOfOrder = true;
r10o = harness.field.run(c);
id = r.pkt(find(strcmp({r.pkt.type}, 'denm'), 1)).id;
t0 = [r.rx([r.rx.id] == id).rxMs];
t10 = [r10.rx([r10.rx.id] == id).rxMs];
t10o = [r10o.rx([r10o.rx.id] == id).rxMs];
fprintf('first DENM arrival, t-Reordering 0: %s ms; 10 in order: %s ms; 10 out of order: %s ms\n', ...
    mat2str(t0), mat2str(t10), mat2str(t10o));
% Within one slot, not exactly: timers are evaluated once per slot, so even t-Reordering = 0
% expires at the NEXT slot's check (114.0 -> 114.5 ms here) while 10 ms expires on the dot.
held = sort(t10) - sort(t0);
assert(numel(t0) == 4 && numel(t10) == 4 && all(abs(held - 10) <= r.ues(1).g.slotMs), ...
    'in order, the first DENM is held t-Reordering (to within a slot) at each of the 4 receivers, got %s', mat2str(held));
assert(numel(t10o) == 4 && all(sort(t10o) <= sort(t0)), ...
    'out of order, the first DENM is not held, got %s vs %s', mat2str(t10o), mat2str(t0));
end
