function S = ueStats(r)
%ueStats Per-UE and per-flow statistics of a deployment run, every loss given a likely cause.
%Spec:   none -- KPI definitions as in INTEGRATION.md and +experiments: a (packet, receiver) pair
%        counts for every receiver within c.sim.rangeM of the source AT GENERATION TIME; it is on
%        time if delivered within the packet's PDB; a flow meets its QoS when the on-time share is
%        at least 1 - PER (PQI 58: 99 %, PQI 56: 90 %). Packets whose PDB runs past the end are excluded.
%Inputs: r  from harness.deploy.run
%Outputs: S  struct:
%   .perUe   table, one row per UE: tx counts; as RECEIVER the on-time share and p50/p95 latency of
%            CAM and events from neighbours in range; as SOURCE the on-time share of its own
%            packets at its neighbours; lost copies by cause [notSent halfDuplex collision radio];
%            CBR mean and p95 (S-RSSI > sl-ThreshS-RSSI-CBR over the CBR window); AGC gain and clipping
%   .flow    table, one row per flow: PQI, pairs, on time, late, lost, causes, latency percentiles,
%            the required on-time share 1 - PER of THAT flow's PQI, and the verdict: PASS/FAIL
%            against it, 'N/A' when the flow has no eligible pairs (nothing to judge)
%   .pairs   struct of row vectors, one per (packet, receiver) pair: .src .rx .type .distM .latMs
%            (NaN if lost) .onTime .cause (0 delivered, 1..4 as above) -- for figures
%LOSS CAUSE, from the transmit log (as harness.field.report): no transmission of that flow by the
%source inside [gen, gen + PDB] -> NOT SENT; the receiver transmitting in every such slot -> HALF
%DUPLEX; another UE's PSSCH sharing a slot and sub-channel with one of them -> COLLISION;
%otherwise RADIO (path loss, fading, noise, hardware). "Likely": a transmission in the window is
%not proven to carry that packet.
c = r.c; N = numel(r.ues);
g = r.ues(1).g;
THRES_RSSI_CBR_DBM = g.threshRssiCbrDbm;      % sl-ThreshS-RSSI-CBR of the stored pool
CBR_WINDOW_SLOTS = g.cbrWindowSlots;          % sl-TimeWindowSizeCBR, in slots
types = {'cam', 'evt'};
pqiOf = [c.cam.pqi, c.evt.pqi];
% Each flow's LCID at each UE, from the flow's own QoS mapping: PQI -> SLRB (sdap.sdapTxMap, as
% stack.appSend does) -> the transmit entity of that SLRB towards the broadcast Destination. Not
% from the logical channel priority: that once hard-coded {cam 6, evt 3} after the PQIs moved to
% 58 (priority 4) and 56 (priority 6), so CAM read the event LCID and every loss was "not sent".
lcid = zeros(N, 2);
for u = 1:N
    e = r.ues(u).ent;
    for ti = 1:2
        rb = sdap.sdapTxMap(r.ues(u).rules, pqiOf(ti), 'broadcast');
        q = find([e.isTx] & [e.rb] == rb & [e.cast] == sdap.castCode('broadcast') & [e.peerL2Id] == c.broadcastL2Id, 1);
        if rb > 0 && ~isempty(q), lcid(u, ti) = e(q).lcid; end
    end
end
P = r.pkt([r.pkt.genMs] + [r.pkt.pdbMs] <= c.sim.durationMs);
tx = r.txLog;
txUe = [tx.ue]; txMs = [tx.ms];
pr = struct('src', [], 'rx', [], 'type', [], 'distM', [], 'latMs', [], 'onTime', [], 'cause', []);
rxId = [r.rx.id]; rxUe = [r.rx.rxUe]; rxMs = [r.rx.rxMs];
for p = P
    pos = harness.deploy.positions(r.drop, p.genMs / 1000, c.field.sizeM);
    d = hypot(pos(:, 1) - pos(p.src, 1), pos(:, 2) - pos(p.src, 2));
    rcv = find(d <= c.sim.rangeM)'; rcv(rcv == p.src) = [];
    ti = find(strcmp(types, p.type));
    flowL = lcid(p.src, ti);
    cand = find(txUe == p.src & txMs >= p.genMs & txMs <= p.genMs + p.pdbMs & ...
        arrayfun(@(t) any(t.lcids == flowL), tx));
    for j = rcv
        h = rxMs(rxId == p.id & rxUe == j);
        if ~isempty(h)
            L = min(h) - p.genMs; cause = 0;
        else
            L = NaN; cause = lossCause(tx, cand, txUe, txMs, j, p.src);
        end
        pr.src(end + 1) = p.src; pr.rx(end + 1) = j; pr.type(end + 1) = ti; pr.distM(end + 1) = d(j);
        pr.latMs(end + 1) = L; pr.onTime(end + 1) = ~isnan(L) && L <= p.pdbMs; pr.cause(end + 1) = cause;
    end
end
S.pairs = pr;

% ---- per UE -------------------------------------------------------------------------------
rows = cell(N, 1);
for u = 1:N
    busy = r.rssiDbm(u, :, :) > THRES_RSSI_CBR_DBM;
    meas = ~isnan(r.rssiDbm(u, :, :));
    cbrT = nan(1, r.nSlots);
    for n = CBR_WINDOW_SLOTS:r.nSlots
        w = n - CBR_WINDOW_SLOTS + 1:n;
        m = meas(1, w, :); b = busy(1, w, :);
        if any(m(:)), cbrT(n) = sum(b(:) & m(:)) / sum(m(:)); end
    end
    asRx = pr.rx == u; asTx = pr.src == u;
    lc = arrayfun(@(k) nnz(asRx & pr.cause == k), 1:4);
    rows{u} = {u, nnz([r.pkt.src] == u & strcmp({r.pkt.type}, 'cam')), ...
        nnz([r.pkt.src] == u & strcmp({r.pkt.type}, 'evt')), nnz(txUe == u), ...
        share(pr.onTime(asRx & pr.type == 1)), pctl(pr.latMs(asRx & pr.type == 1), 50), pctl(pr.latMs(asRx & pr.type == 1), 95), ...
        share(pr.onTime(asRx & pr.type == 2)), pctl(pr.latMs(asRx & pr.type == 2), 50), pctl(pr.latMs(asRx & pr.type == 2), 95), ...
        share(pr.onTime(asTx)), lc(1), lc(2), lc(3), lc(4), mean(cbrT, 'omitnan'), pctl(cbrT, 95), ...
        mean(r.agc(u, :), 'omitnan'), 100 * mean(r.clip(u, :))};
    S.cbrTimeline(u, :) = cbrT;
end
S.perUe = cell2table(vertcat(rows{:}), 'VariableNames', {'ue', 'camGen', 'evtGen', 'psschTx', ...
    'camOnTimeRx', 'camP50Ms', 'camP95Ms', 'evtOnTimeRx', 'evtP50Ms', 'evtP95Ms', 'ownOnTimeAtNbrs', ...
    'lostNotSent', 'lostHalfDuplex', 'lostCollision', 'lostRadio', 'cbrMean', 'cbrP95', 'agcGainDb', 'clipPct'});

% ---- per flow -----------------------------------------------------------------------------
fr = cell(2, 1);
pq = cfg.pqiTable();
for ti = 1:2
    m = pr.type == ti;
    lat = pr.latMs(m); on = pr.onTime(m);
    kp = find(strcmp({r.pkt.type}, types{ti}), 1);
    pdbMs = NaN;
    if ~isempty(kp), pdbMs = r.pkt(kp).pdbMs; end
    lc = arrayfun(@(k) nnz(m & pr.cause == k), 1:4);
    onShare = share(on);
    need = 1 - pq([pq.PQI] == pqiOf(ti)).PER;      % TS 23.287 Table 5.4.4-1, this flow's own PQI
    if isnan(onShare)
        verdict = 'N/A';
    elseif onShare >= need
        verdict = 'PASS';
    else
        verdict = 'FAIL';
    end
    fr{ti} = {types{ti}, pqiOf(ti), need, pdbMs, nnz(m), nnz(on), nnz(~isnan(lat) & ~on), nnz(isnan(lat)), onShare, ...
        lc(1), lc(2), lc(3), lc(4), pctl(lat, 50), pctl(lat, 95), verdict};
end
S.flow = cell2table(vertcat(fr{:}), 'VariableNames', {'flow', 'pqi', 'onTimeNeeded', 'pdbMs', 'pairs', 'onTime', 'late', 'lost', ...
    'onTimeShare', 'lostNotSent', 'lostHalfDuplex', 'lostCollision', 'lostRadio', 'p50Ms', 'p95Ms', 'verdict'});
end

function c = lossCause(tx, cand, txUe, txMs, j, src)
if isempty(cand), c = 1; return; end
deaf = arrayfun(@(k) any(txUe == j & txMs == txMs(k)), cand);
if all(deaf), c = 2; return; end
for k = cand(~deaf)
    o = find(txMs == txMs(k) & txUe ~= src & txUe ~= j);
    for q = o
        if tx(q).startSubch < tx(k).startSubch + tx(k).LsubCH && tx(k).startSubch < tx(q).startSubch + tx(q).LsubCH
            c = 3; return;
        end
    end
end
c = 4;
end

function v = share(x)
if isempty(x), v = NaN; else, v = mean(x); end
end

function v = pctl(x, p)
x = x(~isnan(x));
if isempty(x), v = NaN; else, v = prctile(x, p); end
end
