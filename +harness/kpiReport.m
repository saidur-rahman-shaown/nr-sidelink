function kpi = kpiReport(resolved, nGenerated, nSlots, scen, nTransmissions, rxDistM, rxOk, nRlf, nReeval, nPreempt, nCongDrop, cbrByUe)
%kpiReport Latency, reliability and throughput from resolved packet contexts.
%Spec:   none -- KPI definitions. They are the reason the tree exists, so each one states what
%        it counts and, where it matters, what it deliberately does not.
%Inputs: resolved        1 x n struct array of terminal +sap/ contexts
%        nGenerated      integer -- packets created by +app/, whatever became of them
%        nSlots          integer -- physical slots executed
%        scen            the scenario, for the numerology and payload size
%        nTransmissions  integer -- transport blocks put on the air, including retransmissions
%        rxDistM         1 x nPair real -- transmitter-receiver separation for every pair where
%                        the receiver could hear at all (half-duplex slots excluded: a UE that
%                        was transmitting did not fail to receive, it was never a link)
%        rxOk            1 x nPair logical -- whether that pair's transport block decoded
%        nRlf            integer -- radio link failures indicated, TS 38.321 clause 5.22.1.3.3.
%                        Nonzero means links were dying, which every other KPI here averages
%                        away: a dead link stops generating failures once its traffic stops
%Outputs: kpi  scalar struct, documented per field below
%
%LATENCY IS REPORTED AS A DISTRIBUTION, NOT A MEAN
%--------------------------------------------------
%The mean of a delivered-only latency distribution hides every interesting failure: it improves
%when the slow packets stop being delivered at all. Percentiles and the fraction meeting the
%PDB are what carry information, so those are what this returns. The mean is included only
%because it is asked for, never quoted alone.
%
%A PDB-EXPIRED PACKET IS A LOSS
%-------------------------------
%It is counted in nLost, never in latency. Scoring it as a slow success inflates throughput and
%stretches the tail with samples that should not exist -- both in the flattering direction,
%with nothing else in the run to contradict them.
%
%STILL IN FLIGHT IS NEITHER
%---------------------------
%Packets unresolved when the run stopped are reported separately and excluded from every ratio.
%Folding them into the denominator understates reliability; dropping them silently overstates
%it. Reported, so the reader can judge whether the run was long enough.

codes = sap.outcomeCodes();
msPerSlot = 1 / 2^scen.mu;

outcomes  = [resolved.outcome];
delivered = resolved(outcomes == codes.delivered);
expiredN  = nnz(outcomes == codes.pdbExpired);
maxTxN    = nnz(outcomes == codes.maxTx);
droppedN  = nnz(outcomes == codes.dropped);

latencySlots = double([delivered.tRxSlot] - [delivered.tGenSlot]);
latencyMs    = latencySlots * msPerSlot;
accessMs     = double([delivered.tTxSlot] - [delivered.tMacSlot]) * msPerSlot;

kpi.nGenerated   = nGenerated;
kpi.nDelivered   = numel(delivered);
kpi.nExpired     = expiredN;
% The outcome breakdown must be complete, or a bucket nobody counts becomes a bucket nobody
% notices. maxTx is sl-MaxTransNum spent without an acknowledgement -- a loss with a different
% cause from a spent PDB, and one that only exists once feedback does.
kpi.nMaxTx       = maxTxN;
kpi.nDropped     = droppedN;
kpi.nResolved    = numel(resolved);
kpi.nInFlight    = nGenerated - numel(resolved);
kpi.prr          = kpi.nDelivered / max(1, kpi.nResolved);
assert(kpi.nDelivered + expiredN + maxTxN + droppedN == kpi.nResolved, ...
    'kpiReport: the outcome buckets must account for every resolved packet -- %d + %d + %d + %d vs %d', ...
    kpi.nDelivered, expiredN, maxTxN, droppedN, kpi.nResolved);
kpi.latencyMs    = latencyMs;
kpi.latencyMeanMs = mean(latencyMs);
kpi.latencyP50Ms = pct(latencyMs, 50);
kpi.latencyP90Ms = pct(latencyMs, 90);
kpi.latencyP99Ms = pct(latencyMs, 99);
kpi.latencyMaxMs = maxOrNaN(latencyMs);
kpi.accessMeanMs = mean(accessMs);
% Against EACH PACKET'S OWN PDB, read off the context rather than off the scenario. With
% several flows there is no single scenario-wide PDB, and using one flow's would score another
% flow's packets against a budget that was never theirs.
kpi.withinPdb    = mean(latencyMs <= double([delivered.pdbMs]));

% Throughput: delivered payload over wall-clock time. Payload only -- MAC subheaders and
% padding are overhead, not goodput, and counting them makes a bigger PDU look like a faster
% link.
runMs = nSlots * msPerSlot;
kpi.goodputKbps  = sum(double([delivered.sizeBytes])) * 8 / runMs;
kpi.perUeKbps    = kpi.goodputKbps / scen.nUe;
% Transmissions spent per delivered packet: the efficiency figure blind retransmission moves.
kpi.txPerDelivery = nTransmissions / max(1, kpi.nDelivered);
kpi.nTransmissions = nTransmissions;

% ---- per FLOW ------------------------------------------------------------
% One row per logical channel, because a flow is what an application owns: an aggregate that
% mixes a 20 ms safety message with a 500 ms status update reports a latency distribution that
% describes neither. Every flow is scored against ITS OWN PDB. The rows come from the scenario,
% not from the packets, so a flow that delivered nothing still appears -- as a row of zeros,
% which is the result, rather than by vanishing from the table.
kpi.byFlow = repmat(flowKpiTemplate(), 1, numel(scen.flows));
for f = 1:numel(scen.flows)
    fl   = scen.flows(f);
    mine = [resolved.lcid] == fl.lcid;
    dOk  = mine & outcomes == codes.delivered;
    lat  = double([resolved(dOk).tRxSlot] - [resolved(dOk).tGenSlot]) * msPerSlot;
    kpi.byFlow(f).lcid        = fl.lcid;
    kpi.byFlow(f).pqi         = fl.pqi;
    kpi.byFlow(f).prio        = fl.prio;
    kpi.byFlow(f).pdbMs       = fl.pdbMs;
    kpi.byFlow(f).periodMs    = fl.periodMs;
    kpi.byFlow(f).sizeBytes   = fl.sizeBytes;
    kpi.byFlow(f).nDelivered  = nnz(dOk);
    kpi.byFlow(f).nExpired    = nnz(mine & outcomes == codes.pdbExpired);
    kpi.byFlow(f).nMaxTx      = nnz(mine & outcomes == codes.maxTx);
    kpi.byFlow(f).nDropped    = nnz(mine & outcomes == codes.dropped);
    kpi.byFlow(f).nResolved   = nnz(mine);
    kpi.byFlow(f).latencyMs   = lat;
    kpi.byFlow(f).latencyMeanMs = mean(lat);
    kpi.byFlow(f).latencyP50Ms  = pct(lat, 50);
    kpi.byFlow(f).latencyP90Ms  = pct(lat, 90);
    kpi.byFlow(f).latencyP99Ms  = pct(lat, 99);
    kpi.byFlow(f).latencyMaxMs  = maxOrNaN(lat);
    kpi.byFlow(f).withinPdb   = mean(lat <= fl.pdbMs);
    kpi.byFlow(f).goodputKbps = nnz(dOk) * fl.sizeBytes * 8 / runMs;
    kpi.byFlow(f).prr         = nnz(dOk) / max(1, nnz(mine));
    % PER-PACKET SERIES, in generation order. The percentiles above say how the flow behaved;
    % this says WHEN. A handful of expiries scattered at random is a different fault from the
    % same handful in one burst, and no summary statistic separates them -- so every resolved
    % packet of this flow is kept here with its generation time, its latency (NaN when it was
    % never delivered, because a lost packet has no latency) and its outcome code.
    my   = resolved(mine);
    [tg, ord] = sort(double([my.tGenSlot]));
    my   = my(ord);
    lost = [my.outcome] ~= codes.delivered;
    lat  = double([my.tRxSlot] - [my.tGenSlot]) * msPerSlot;
    lat(lost) = NaN;
    kpi.byFlow(f).pktTGenMs    = tg * msPerSlot;
    kpi.byFlow(f).pktLatencyMs = lat;
    kpi.byFlow(f).pktOutcome   = [my.outcome];
end
assert(sum([kpi.byFlow.nResolved]) == kpi.nResolved, ...
    'kpiReport: every resolved packet must belong to exactly one flow -- %d across flows vs %d resolved', ...
    sum([kpi.byFlow.nResolved]), kpi.nResolved);

% ---- PRR versus distance, the per-LINK statistic -------------------------
% kpi.prr above is PACKET-level: a packet counts as delivered if ANY receiver decoded it. That
% is what closes a latency figure -- a packet has one latency, not one per listener -- but it is
% the weakest possible reliability statement and in a dense scenario it reads 1.0 regardless of
% the channel, because the nearest neighbour always decodes. Reliability in V2X is a per-LINK
% quantity: of all the receivers that could have heard a transmission, what fraction did. The
% two are different numbers and both are reported, never conflated.
edges = [0 50 100 150 200 300 400 600 800 1200 inf];
kpi.prrDistEdgesM = edges;
kpi.prrByDistance = nan(1, numel(edges) - 1);
kpi.pairsByDistance = zeros(1, numel(edges) - 1);
for b = 1:numel(edges) - 1
    in = rxDistM >= edges(b) & rxDistM < edges(b + 1);
    kpi.pairsByDistance(b) = nnz(in);
    if any(in)
        kpi.prrByDistance(b) = mean(rxOk(in));
    end
end
kpi.prrLink = mean(rxOk);
kpi.nPairs  = numel(rxOk);
kpi.nRlf    = nRlf;
% Clause 5.22.1.2a activity. Reported because both numbers are load indicators that no other
% KPI shows: re-evaluation rises when the pool is churning under the UE's feet before it has
% committed, pre-emption when higher-priority traffic is taking committed resources away. Zero
% for both in a quiet pool is expected; zero in a congested one means the checks are not wired.
kpi.nReeval  = nReeval;
kpi.nPreempt = nPreempt;
% Congestion drops are counted SEPARATELY and never folded into the loss count. A packet the UE
% chose not to send is a different thing from one the channel destroyed, and the two are
% indistinguishable in a PRR figure alone -- so a congestion-control policy that throttles hard
% would otherwise read as a bad radio link.
kpi.nCongestionDrop = nCongDrop;
kpi.cbrMean = mean(cbrByUe);
kpi.cbrMax  = max(cbrByUe);
end

function v = pct(x, p)
if isempty(x), v = NaN; return; end
s = sort(x);
v = s(max(1, ceil(p / 100 * numel(s))));
end

function v = maxOrNaN(x)
if isempty(x), v = NaN; else, v = max(x); end
end

function t = flowKpiTemplate()
t = struct('lcid', 0, 'pqi', 0, 'prio', 0, 'pdbMs', 0, 'periodMs', 0, 'sizeBytes', 0, ...
    'nDelivered', 0, 'nExpired', 0, 'nMaxTx', 0, 'nDropped', 0, 'nResolved', 0, ...
    'latencyMs', zeros(1, 0), 'latencyMeanMs', NaN, 'latencyP50Ms', NaN, 'latencyP90Ms', NaN, ...
    'latencyP99Ms', NaN, 'latencyMaxMs', NaN, 'withinPdb', NaN, 'goodputKbps', 0, 'prr', NaN, ...
    'pktTGenMs', zeros(1, 0), 'pktLatencyMs', zeros(1, 0), 'pktOutcome', zeros(1, 0));
end
