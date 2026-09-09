function kpi = kpiReport(resolved, nGenerated, nSlots, scen, nTransmissions, rxDistM, rxOk, nRlf)
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
kpi.withinPdb    = mean(latencyMs <= scen.traffic.pdbMs);

% Throughput: delivered payload over wall-clock time. Payload only -- MAC subheaders and
% padding are overhead, not goodput, and counting them makes a bigger PDU look like a faster
% link.
runMs = nSlots * msPerSlot;
kpi.goodputKbps  = kpi.nDelivered * scen.traffic.sizeBytes * 8 / runMs;
kpi.perUeKbps    = kpi.goodputKbps / scen.nUe;
% Transmissions spent per delivered packet: the efficiency figure blind retransmission moves.
kpi.txPerDelivery = nTransmissions / max(1, kpi.nDelivered);
kpi.nTransmissions = nTransmissions;

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
end

function v = pct(x, p)
if isempty(x), v = NaN; return; end
s = sort(x);
v = s(max(1, ceil(p / 100 * numel(s))));
end

function v = maxOrNaN(x)
if isempty(x), v = NaN; else, v = max(x); end
end
