function [kpi, ue, scen] = runSim(c)
%runSim Run the scenario in simConfig and plot latency and throughput.
%Inputs: c  optional -- a config struct. Omit it to use simConfig()
%Outputs: kpi   the KPI struct from harness.kpiReport, including kpi.byFlow
%         ue    final per-UE state, for inspection
%         scen  the resolved scenario, including every DERIVED quantity
%
%   k = runSim();                       % edit simConfig.m, then run this
%   c = simConfig(); c.link.spacingM = 400; k = runSim(c);    % or override inline
%
%The figures are the point: a KPI struct tells you the mean, and the mean of a delivered-only
%latency distribution is the statistic that hides every interesting failure. The CDF against
%the PDB shows the tail, which is what a delay budget is actually about.

if nargin < 1
    c = simConfig();
end

scen = harness.sls.scenarioFromConfig(c);

nSlots = c.sim.nSlots;
if isempty(nSlots)
    nSlots = autoLength(scen);
end

[kpi, ue] = harness.sls.runScenario(scen, nSlots);

% ---- report ---------------------------------------------------------------
msPerSlot = 1 / 2^scen.mu;
fprintf('\n=== %s, %d UE, %d transmitting, %.0f m spacing, %s, %.1f s ===\n', ...
    scen.castLabel, scen.nUe, nnz(scen.txUeMask), scen.spacingM, ...
    upper(scen.channelModel), nSlots * msPerSlot / 1000);
fprintf('  T1 = %d slots (T_proc,1 at mu=%d) | decode margin = %d slots | MCS %d | P_rsvp_TX %g ms\n', ...
    phy.ts38214.procTimeSelection(scen.mu), scen.mu, scen.decodeMarginSlots, ...
    scen.policy.mcs, scen.policy.prsvpTxMs);

% Offered load against what one periodic grant can actually carry. A UE holding one selected
% grant gets one transport block per reservation period, so this ratio -- not the radio link --
% is what decides whether the tight flows can be served at all. Printed every run because an
% overloaded reservation and a bad channel produce the same PDB expiries in the KPI table, and
% nothing else here distinguishes them.
offeredBps = sum(arrayfun(@(f) f.sizeBytes * 1000 / f.periodMs, scen.flows));
grantBps   = scen.maxTbsBytes * 1000 / scen.policy.prsvpTxMs;
mark = '';
if offeredBps > grantBps
    mark = '   <-- OVERLOADED: shorten c.policy.prsvpTxMs';
end
fprintf('  offered %.0f B/s per UE | one grant carries %.0f B/s (%d B every %g ms)%s\n', ...
    offeredBps, grantBps, scen.maxTbsBytes, scen.policy.prsvpTxMs, mark);

fprintf('  generated %d | delivered %d | PDB-expired %d | max-retx %d | still in flight %d\n', ...
    kpi.nGenerated, kpi.nDelivered, kpi.nExpired, kpi.nMaxTx, kpi.nInFlight);

% ---- per flow, which is how the traffic was configured --------------------
fprintf('\n  %-6s %-5s %-6s %-9s %8s %8s %7s %7s %7s %7s %8s\n', ...
    'LCID', 'PQI', 'prio', 'PDB', 'deliv', 'expired', 'p50', 'p90', 'p99', 'max', 'kbps');
for f = 1:numel(kpi.byFlow)
    b = kpi.byFlow(f);
    fprintf('  %-6d %-5d %-6d %-9s %8d %8d %7.1f %7.1f %7.1f %7.1f %8.1f\n', ...
        b.lcid, b.pqi, b.prio, sprintf('%g ms', b.pdbMs), b.nDelivered, b.nExpired, ...
        b.latencyP50Ms, b.latencyP90Ms, b.latencyP99Ms, b.latencyMaxMs, b.goodputKbps);
end

fprintf('\n  aggregate latency  mean %.1f ms | p50 %.1f | p90 %.1f | p99 %.1f | within own PDB %.1f%%\n', ...
    kpi.latencyMeanMs, kpi.latencyP50Ms, kpi.latencyP90Ms, kpi.latencyP99Ms, 100 * kpi.withinPdb);
fprintf('  goodput  %.1f kbps total | %.1f kbps per UE | %.2f transmissions per delivery\n', ...
    kpi.goodputKbps, kpi.perUeKbps, kpi.txPerDelivery);
fprintf('  link PRR %.3f over %d pairs | CBR %.3f | RLF %d | congestion drops %d\n', ...
    kpi.prrLink, kpi.nPairs, kpi.cbrMean, kpi.nRlf, kpi.nCongestionDrop);

if c.sim.plot
    harness.plotKpi(kpi, scen, c);
end
end

% =========================================================================
function nSlots = autoLength(scen)
%autoLength Slots enough to generate every flow's quota and then let the last packet resolve.
%A count-based experiment ("600 packets from each generator") has a natural length and asking
%the user to convert it into slots by hand is how a run ends with packets still in flight --
%which are excluded from every ratio, so the result looks fine and is short.
%
%The drain is one full PDB past the last generation, plus slack. That is sufficient rather than
%approximate: after the last arrival every remaining packet is resolved within its own PDB,
%because +sap/lchExpire retires anything the deadline passes whether or not it was ever sent.
if any(~isfinite([scen.flows.nPackets]))
    error('runSim:unboundedTraffic', ['runSim: c.sim.nSlots is [] (auto), but flow(s) %s generate ', ...
        'indefinitely (nPackets = inf). Give every flow a finite nPackets, or set c.sim.nSlots.'], ...
        mat2str(find(~isfinite([scen.flows.nPackets]))));
end
nTxUe   = max(1, nnz(scen.txUeMask));
lastGen = 0;
for f = 1:numel(scen.flows)
    fl = scen.flows(f);
    % The last UE's phase offset, from harness.sls.ueInit's flowOffsets stagger.
    maxOffset = max(arrayfun(@(u) mod((u - 1) * numel(scen.flows) + (f - 1), fl.periodSlots), 1:nTxUe));
    lastGen = max(lastGen, maxOffset + (fl.nPackets - 1) * fl.periodSlots);
end
drainSlots = max([scen.flows.pdbMs]) * scen.slotsPerMs + scen.decodeMarginSlots + 20;
nSlots = lastGen + drainSlots + 1;
end
