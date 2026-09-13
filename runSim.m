function [kpi, ue, scen] = runSim(c)
%runSim Run the scenario in simConfig and plot latency and throughput.
%Inputs: c  optional -- a config struct. Omit it to use simConfig()
%Outputs: kpi   the KPI struct from harness.kpiReport
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
[kpi, ue] = harness.sls.runScenario(scen, c.sim.nSlots);

% ---- report ---------------------------------------------------------------
msPerSlot = 1 / 2^scen.mu;
fprintf('\n=== %s, %d UE, %d transmitting, %.0f m spacing, %.1f s ===\n', ...
    scen.castLabel, scen.nUe, nnz(scen.txUeMask), scen.spacingM, c.sim.nSlots * msPerSlot / 1000);
fprintf('  T1 = %d slots (T_proc,1 at mu=%d) | decode margin = %d slots | PDB = %g ms\n', ...
    phy.ts38214.procTimeSelection(scen.mu), scen.mu, scen.decodeMarginSlots, scen.traffic.pdbMs);
fprintf('  generated %d | delivered %d | PDB-expired %d | still in flight %d\n', ...
    kpi.nGenerated, kpi.nDelivered, kpi.nExpired, kpi.nInFlight);
fprintf('  latency  mean %.1f ms | p50 %.1f | p90 %.1f | p99 %.1f | max %.1f | within PDB %.1f%%\n', ...
    kpi.latencyMeanMs, kpi.latencyP50Ms, kpi.latencyP90Ms, kpi.latencyP99Ms, kpi.latencyMaxMs, 100 * kpi.withinPdb);
fprintf('  goodput  %.1f kbps total | %.1f kbps per UE | %.2f transmissions per delivery\n', ...
    kpi.goodputKbps, kpi.perUeKbps, kpi.txPerDelivery);
fprintf('  link PRR %.3f over %d pairs | CBR %.3f | RLF %d | congestion drops %d\n', ...
    kpi.prrLink, kpi.nPairs, kpi.cbrMean, kpi.nRlf, kpi.nCongestionDrop);

if c.sim.plot
    harness.plotKpi(kpi, scen, c);
end
end
