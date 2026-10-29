function P = linkPackets(L, resolved, scen, rangeM)
%linkPackets Every (packet, intended receiver) pair, with its per-link latency or its loss.
%Spec:   none -- a KPI definition. This is the per-link packet reception ratio of 3GPP V2X
%        evaluations: of the receivers within range of the transmitter, which received each
%        packet, and how late.
%Inputs: L         runLogged's log
%        resolved  runLogged's resolved contexts (every packet generated that reached an outcome)
%        scen      the scenario (positions, numerology)
%        rangeM    real -- receivers farther than this are not counted as intended receivers
%Outputs: P  struct of equal-length row vectors, one entry per pair:
%            .txUe .rxUe .pktId .lcid .pdbMs .distM .tGenSlot
%            .latMs   delivery at that receiver minus generation, ms: first decoding slot + the
%                     1 + 2 slot TX/RX pipeline (settings().op); NaN if never decoded
%            .onTime  decoded within the packet's own PDB
%            .cause   0 delivered on time; for a pair that was not: 1 NOT SENT (no transmission of the
%                     packet -- expired at the source), 2 HALF DUPLEX (the receiver was transmitting
%                     in every slot the packet was sent), 3 COLLISION (at least one of its
%                     transmissions shared slot and sub-channel with another), 4 RADIO (heard, clean,
%                     not decoded: range / fading), 5 LATE (decoded after the PDB)
%
%WHY THIS, AND NOT kpi.latencyMs
%-------------------------------
%harness.kpiReport closes a packet on its FIRST delivery to ANY receiver -- one latency per
%packet. That is the right definition for a unicast and a weak one for broadcast safety
%traffic, where every neighbour must hear it: a CAM decoded by the nearest UE and missed by the
%one about to collide is a success in kpi.prr and a failure here. Half-duplex misses count as
%losses here too, because the receiver did not get the packet, whatever the reason.
%
%Packets generated within one PDB of the end of the run are excluded: their outcome at some
%receivers is not yet decided, and counting them as lost would bias the ratio down.

msPerSlot = 1 / 2^scen.mu;
% The SLS decodes a TB in the slot it is sent; the delivery is txSlots + rxProcSlots later (the
% transmission slot, then two to receive it; the TB is built during T1: experiments.settings,
% "THE LATENCY PIPELINE").
op = experiments.settings().op;
pipeSlots = op.txSlots + op.rxProcSlots;
nUe = scen.nUe;
if isempty(resolved)
    P = emptyP(); return;
end
maxPkt = max([resolved.pktId]);
first = inf(nUe * maxPkt, nUe);              % first decode slot, (tx,pkt) x rx

% Which air entries carried each (tx, packet), and who listened to each air entry.
carried = cell(nUe * maxPkt, 1);
for q = 1:numel(L.air)
    for pk = L.air(q).pktIds(:)'
        if pk <= maxPkt
            key = (L.air(q).ue - 1) * maxPkt + pk;
            carried{key}(end + 1) = q;
        end
    end
end
heard = sparse(double(L.rx.air), double(L.rx.rxUe), true, max(1, numel(L.air)), nUe);
okIdx = find(L.rx.ok);
for q = okIdx
    a = L.air(L.rx.air(q));
    i = L.rx.txUe(q); j = L.rx.rxUe(q);
    for p = a.pktIds(:)'
        if p <= maxPkt
            key = (i - 1) * maxPkt + p;
            first(key, j) = min(first(key, j), L.rx.slot(q));
        end
    end
end

tx  = [resolved.srcL2Id];                  % srcL2Id == UE index in the SLS
pid = [resolved.pktId];
tg  = double([resolved.tGenSlot]);
pdb = double([resolved.pdbMs]);
lc  = [resolved.lcid];
keep = tg + pdb / msPerSlot < L.nSlots;
tx = tx(keep); pid = pid(keep); tg = tg(keep); pdb = pdb(keep); lc = lc(keep);

D = sqrt((scen.posXY(:, 1) - scen.posXY(:, 1)').^2 + (scen.posXY(:, 2) - scen.posXY(:, 2)').^2);
P = emptyP();
for k = 1:numel(tx)
    rcv = find(D(tx(k), :) <= rangeM);
    rcv(rcv == tx(k)) = [];
    if isempty(rcv), continue; end
    f = first((tx(k) - 1) * maxPkt + pid(k), rcv);
    lat = (f - tg(k) + pipeSlots) * msPerSlot;
    lat(~isfinite(lat)) = NaN;
    n = numel(rcv);
    P.txUe = [P.txUe repmat(tx(k), 1, n)];
    P.rxUe = [P.rxUe rcv];
    P.pktId = [P.pktId repmat(pid(k), 1, n)];
    P.lcid = [P.lcid repmat(lc(k), 1, n)];
    P.pdbMs = [P.pdbMs repmat(pdb(k), 1, n)];
    P.distM = [P.distM D(tx(k), rcv)];
    P.tGenSlot = [P.tGenSlot repmat(tg(k), 1, n)];
    P.latMs = [P.latMs lat];
    cs = zeros(1, n);
    aq = carried{(tx(k) - 1) * maxPkt + pid(k)};
    for r = 1:n
        if ~isnan(lat(r)) && lat(r) <= pdb(k), continue; end
        if ~isnan(lat(r)), cs(r) = 5;
        elseif isempty(aq), cs(r) = 1;
        elseif ~any(heard(aq, rcv(r))), cs(r) = 2;
        elseif any([L.air(aq).collided]), cs(r) = 3;
        else, cs(r) = 4;
        end
    end
    P.cause = [P.cause cs];
end
P.onTime = P.latMs <= P.pdbMs;               % NaN compares false: a lost packet is not on time
end

function P = emptyP()
P = struct('txUe', zeros(1, 0), 'rxUe', zeros(1, 0), 'pktId', zeros(1, 0), 'lcid', zeros(1, 0), ...
    'pdbMs', zeros(1, 0), 'distM', zeros(1, 0), 'tGenSlot', zeros(1, 0), 'latMs', zeros(1, 0), ...
    'onTime', false(1, 0), 'cause', zeros(1, 0));
end
