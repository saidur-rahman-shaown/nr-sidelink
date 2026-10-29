function s = report(r)
%report Summarise a field run: per-message PRR and latency against the PDB, per-link SNR, MAC/PHY counters.
%Spec:   none -- KPIs as docs/INTEGRATION.md defines them: reliability = delivered within the PDB /
%        expected; latency = application delivery time - generation time, reported as
%        percentiles against the PDB (never a mean alone); late deliveries counted as losses.
%        A packet whose PDB runs past the end of the run is IN FLIGHT: reported, and excluded
%        from every ratio (+harness/CLAUDE.md: otherwise the run's last 100 ms read as losses).
%Inputs: r  struct from harness.field.run
%Outputs: s  struct of the numbers printed (.type rows), for tests and plots; s(1).coll holds
%            harness.field.collisions(r). .lostCause is
%            [notSent halfDuplex collision radio] for the lost copies of that flow
%
%LOSS CAUSES ARE ATTRIBUTED FROM THE TRANSMIT LOG, not from receiver internals. For a lost copy,
%the source's transmissions of that flow's logical channel inside [generation, generation + PDB]
%are its candidates: if there are none, NOT SENT (discarded at the source -- a MAC/scheduling
%loss, every receiver loses it); if the receiver was itself transmitting in every one, HALF DUPLEX; else if
%another UE's PSSCH overlapped one of them in slot and sub-channel, COLLISION; else RADIO (path
%loss, fading, noise). "Likely" cause: a transmission in the window is not proven to carry it.

N = numel(r.ues);
types = {'cam', 'denm', 'uni'};
names = {'CAM  (periodic broadcast, PQI 58)', 'DENM (event broadcast,    PQI 56)', 'UNI  (sensor sharing,     PQI 23)'};
fprintf('\n=== field run: %d UEs, %.0f ms, config %s ===\n', N, r.c.sim.durationMs, r.c.cfgPath);
fprintf('Channel evaluated at %.3f GHz; the preconfiguration''s Point A is %.3f GHz (not used by the channel).\n', ...
    r.c.radio.fcHz / 1e9, r.pointAHz / 1e9);
fprintf('Per-link SNR per RE at t=0 for a 10-PRB PSSCH at 23 dBm (path loss only), dB:\n');
d = hypot(r.c.ue.x(:) - r.c.ue.x(:)', r.c.ue.y(:) - r.c.ue.y(:)');
fprintf('      '); fprintf('  rx%-4d', 1:N); fprintf('\n');
for i = 1:N
    fprintf('tx%-3d ', i); fprintf('%7.1f ', r.linkSnrDb(i, :)); fprintf('\n');
end
fprintf('Distances at t=0, m:\n');
for i = 1:N
    fprintf('ue%-3d ', i); fprintf('%7.0f ', d(i, :)); fprintf('\n');
end
s = struct('type', types, 'expected', 0, 'onTime', 0, 'late', 0, 'lost', 0, 'prr', 0, ...
    'p50Ms', NaN, 'p95Ms', NaN, 'maxMs', NaN, 'inFlight', 0, 'lostCause', [0 0 0 0]);
% [cast LCID] of each flow: +stack assigns LCIDs per Destination in SLRB order (sdap.castCode 1 = bc, 3 = uc)
FLOW = struct('cam', [1 4], 'denm', [1 5], 'uni', [3 4]);
fprintf('\n%-36s %5s %8s %8s %6s %6s %7s %8s %8s %8s\n', 'flow (packets x receivers)', 'pkts', 'expected', 'on-time', 'late', 'lost', 'PRR', 'p50 ms', 'p95 ms', 'max ms');
for t = 1:numel(types)
    P = r.pkt(strcmp({r.pkt.type}, types{t}));
    inFlight = [P.genMs] + [P.pdbMs] > r.c.sim.durationMs;
    s(t).inFlight = sum(inFlight);
    P = P(~inFlight);
    lat = zeros(1, 0); exp = 0; onTime = 0; late = 0;
    for p = P
        if p.dst == 0, rcv = setdiff(1:N, p.src); else, rcv = p.dst; end
        for j = rcv
            exp = exp + 1;
            hit = r.rx([r.rx.id] == p.id & [r.rx.rxUe] == j);
            if isempty(hit)
                s(t).lostCause = s(t).lostCause + lossCause(r.txLog, p, j, FLOW.(types{t}));
                continue;
            end
            L = hit(1).rxMs - p.genMs;
            lat(end + 1) = L; %#ok<AGROW>
            if L <= p.pdbMs, onTime = onTime + 1; else, late = late + 1; end
        end
    end
    s(t).expected = exp; s(t).onTime = onTime; s(t).late = late; s(t).lost = exp - onTime - late;
    s(t).prr = onTime / max(exp, 1);
    if ~isempty(lat)
        s(t).p50Ms = prctile(lat, 50); s(t).p95Ms = prctile(lat, 95); s(t).maxMs = max(lat);
    end
    fprintf('%-36s %5d %8d %8d %6d %6d %7.3f %8.1f %8.1f %8.1f\n', names{t}, numel(P), exp, onTime, late, s(t).lost, ...
        s(t).prr, s(t).p50Ms, s(t).p95Ms, s(t).maxMs);
end
fprintf('(in flight at the end, excluded: %s)\n', num2str([s.inFlight]));
fprintf('Lost copies by likely cause [not-sent half-duplex collision radio]: CAM %s  DENM %s  UNI %s\n', ...
    mat2str(s(1).lostCause), mat2str(s(2).lostCause), mat2str(s(3).lostCause));
k = harness.field.collisions(r);
s(1).coll = k;
fprintf('\nCollisions (PSSCH on a common sub-channel in the same slot):\n');
fprintf('  %d transmissions, %d collided (%.1f%%), %d of them on the same starting sub-channel (PSCCH on PSCCH)\n', ...
    k.nTx, k.nCollided, 100 * k.nCollided / max(k.nTx, 1), k.nSameStart);
fprintf('  %d shared their slot with another transmission (the two senders cannot hear each other)\n', k.nConcurrent);
fprintf('  outcome per (initial tx, other UE)     %7s %8s %7s %6s   %s\n', 'tbOk', 'sciOnly', 'missed', 'deaf', 'TB decode rate when listening');
lbl = {'clean', 'collided'};
for q = 1:2
    o = k.outcome(q, :);
    fprintf('  %-38s %7d %8d %7d %6d   %.3f\n', lbl{q}, o, o(1) / max(sum(o(1:3)), 1));
end
if ~isempty(k.capture)
    cap = k.capture;
    fprintf('  capture: collided receptions with SIR >= 3 dB decoded %d/%d; with SIR < 3 dB %d/%d\n', ...
        sum(cap(cap(:, 1) >= 3, 3)), sum(cap(:, 1) >= 3), sum(cap(cap(:, 1) < 3, 3)), sum(cap(:, 1) < 3));
end
fprintf('\nPer-UE counters (MAC/PHY):\n');
fprintf('%-4s %6s %6s %6s %6s %6s %6s %7s %6s %6s %6s %6s %6s\n', 'UE', 'macPDU', 'txPSSCH', 'PSCCH', 'tbOK', 'tbBAD', 'ACK', 'NACK', 'DTX', 'PSFCH', 'rescue', 'disc', 'pdbRes');
for u = 1:N
    st = r.ues(u).stats;
    fprintf('%-4d %6d %6d %6d %6d %6d %6d %7d %6d %6d %6d %6d %6d\n', u, st.macPdus, st.transmissions, st.pscchFound, ...
        st.tbOk, st.tbFailed, st.ackRx, st.nackRx, st.dtxRx, st.psfchSent, st.combinedRescue, st.lostToDiscard, st.pdbReselect);
end
end

function cause = lossCause(txLog, p, j, flow)
% [notSent halfDuplex collision radio] one-hot for one lost copy of packet p at receiver j.
mine = txLog([txLog.ue] == p.src & [txLog.ms] >= p.genMs & [txLog.ms] <= p.genMs + p.pdbMs & ...
    [txLog.cast] == flow(1) & arrayfun(@(t) any(t.lcids == flow(2)), txLog));
if isempty(mine), cause = [1 0 0 0]; return; end
cause = [0 0 0 1];
deaf = arrayfun(@(t) any([txLog.ue] == j & [txLog.ms] == t.ms), mine);
if all(deaf), cause = [0 1 0 0]; return; end
for t = mine(~deaf)
    o = txLog([txLog.ms] == t.ms & [txLog.ue] ~= p.src & [txLog.ue] ~= j);
    for q = o
        if q.startSubch < t.startSubch + t.LsubCH && t.startSubch < q.startSubch + q.LsubCH
            cause = [0 0 1 0]; return;
        end
    end
end
end
