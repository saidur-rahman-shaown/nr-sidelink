function S = summarizeRun(kpi, L, resolved, scen, rangeM)
%summarizeRun Reduce one logged SLS run to the numbers every experiment reports.
%Outputs: S  struct:
%   .flow(f)   per flow: .lcid .pqi .pdbMs .arrival
%              .pktLatMs     packet-level latencies (first delivery to ANY receiver), delivered only
%              .pktOnTime    per resolved packet: delivered within PDB (lost/expired = false)
%              .linkLatMs    per-link latencies, received pairs only
%              .linkOnTime   per (packet, receiver within rangeM): received within PDB
%              .linkDistM    distance of each of those pairs
%              .rxBitsOnTime .pairBits .obsSec  bits delivered on time to intended receivers, bits
%                            offered to them, and the observation window (s): broadcast throughput
%              .accessMs     generation -> first transmission, delivered packets
%   .collisionRate .sameStartRate .cbrMean .cbrP95 .crMean .nSel .selPerUePerS
%   .txPerDelivery .goodputKbps .nRlf .nReeval .nPreempt .nCongDrop .prrLinkByDist (struct)
%   .rx collided/clean PRR: .prrClean .prrCollided
codes = sap.outcomeCodes();
msPerSlot = 1 / 2^scen.mu;
P = linkPackets(L, resolved, scen, rangeM);
for f = 1:scen.nFlow
    fl = scen.flows(f);
    mine = resolved([resolved.lcid] == fl.lcid);
    keep = double([mine.tGenSlot]) + fl.pdbMs / msPerSlot < L.nSlots;
    mine = mine(keep);
    del = [mine.outcome] == codes.delivered;
    lat = double([mine.tRxSlot] - [mine.tGenSlot]) * msPerSlot;
    S.flow(f).lcid = fl.lcid; S.flow(f).pqi = fl.pqi; S.flow(f).pdbMs = fl.pdbMs;
    S.flow(f).arrival = fl.arrival;
    S.flow(f).pktLatMs = lat(del);
    S.flow(f).pktOnTime = del & lat <= fl.pdbMs;
    S.flow(f).accessMs = double([mine(del).tTxSlot] - [mine(del).tGenSlot]) * msPerSlot;
    sel = P.lcid == fl.lcid;
    S.flow(f).linkOnTime = P.onTime(sel);
    S.flow(f).linkDistM = P.distM(sel);
    S.flow(f).linkCause = P.cause(sel);
    % Broadcast throughput: bits that reached an intended receiver within the PDB, over the window
    % whose packets were all decided (packets generated within one PDB of the end are excluded).
    S.flow(f).sizeBytes = fl.sizeBytes;
    S.flow(f).rxBitsOnTime = nnz(P.onTime(sel)) * fl.sizeBytes * 8;
    S.flow(f).pairBits = nnz(sel) * fl.sizeBytes * 8;
    S.flow(f).obsSec = (L.nSlots * msPerSlot - fl.pdbMs) / 1000;
    l = P.latMs(sel);
    S.flow(f).linkLatMs = l(~isnan(l));
end
a = L.air;
S.collisionRate = mean([a.collided]);
S.sameStartRate = mean([a.sameStart]);
S.cbrMean = mean(L.cbr(:), 'omitnan');
S.cbrP95 = prctile(L.cbr(:), 95);
S.crMean = mean(L.cr(:), 'omitnan');
S.nSel = numel(L.sel);
S.selPerUePerS = numel(L.sel) / scen.nUe / (L.nSlots * msPerSlot / 1000);
S.txPerDelivery = kpi.txPerDelivery;
S.goodputKbps = kpi.goodputKbps;
S.nTx = numel(a);
S.nRlf = L.nRlf; S.nReeval = L.nReeval; S.nPreempt = L.nPreempt; S.nCongDrop = L.nCongDrop;
% PRR of a decode attempt split by whether its transmission collided: what a collision costs.
if ~isempty(L.rx.ok)
    col = [a(L.rx.air).collided];
    S.prrClean = mean(L.rx.ok(~col));
    S.prrCollided = mean(L.rx.ok(col));
else
    S.prrClean = NaN; S.prrCollided = NaN;
end
S.nUe = scen.nUe;
end
