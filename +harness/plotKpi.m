function figs = plotKpi(kpi, scen, c)
%plotKpi Latency CDF and throughput, the two figures the KPI struct cannot show.
%Inputs: kpi   from harness.kpiReport
%        scen  the resolved scenario
%        c     the config, for .sim.plotDir
%Outputs: figs  the figure handles
%
%LATENCY IS SHOWN AS A CDF AGAINST THE PDB, NOT AS A MEAN
%----------------------------------------------------------
%The mean of a delivered-only latency distribution improves when the slow packets stop being
%delivered at all, so it moves the wrong way exactly when things get worse. The CDF shows the
%tail and the PDB line shows what the tail has to beat. Packets that never arrived are not on
%this plot at all -- their count is in the title, because a CDF of survivors alone is the same
%trap in picture form.

msPerSlot = 1 / 2^scen.mu;
runMs = numel(kpi.latencyMs) * 0 + double(kpi.nGenerated > 0);  %#ok<NASGU>
figs = gobjects(1, 2);

% ---- 1. latency CDF -------------------------------------------------------
figs(1) = figure('Name', 'Latency', 'Position', [100 100 760 460]);
if isempty(kpi.latencyMs)
    text(0.5, 0.5, 'no packets delivered', 'HorizontalAlignment', 'center');
else
    x = sort(kpi.latencyMs);
    y = (1:numel(x)) / numel(x);
    stairs(x, y, 'LineWidth', 1.8); hold on; grid on;
    xline(scen.traffic.pdbMs, '--', sprintf('PDB = %g ms', scen.traffic.pdbMs), ...
        'LineWidth', 1.4, 'LabelVerticalAlignment', 'bottom');
    for pp = [0.5 0.9 0.99]
        yline(pp, ':', sprintf('p%g', pp * 100), 'Color', [0.5 0.5 0.5]);
    end
    xlabel('end-to-end latency (ms), measured from packet generation');
    ylabel('cumulative fraction of DELIVERED packets');
    ylim([0 1.02]);
    title(sprintf('Latency CDF  |  %s, %d UE, %.0f m  |  %d delivered, %d expired, %d in flight', ...
        scen.castLabel, scen.nUe, scen.spacingM, kpi.nDelivered, kpi.nExpired, kpi.nInFlight));
end

% ---- 2. throughput and where the packets went -----------------------------
figs(2) = figure('Name', 'Throughput', 'Position', [140 140 760 460]);
subplot(1, 2, 1);
bar([kpi.goodputKbps, kpi.perUeKbps]);
set(gca, 'XTickLabel', {'aggregate', 'per UE'});
ylabel('goodput (kbps), payload only');
grid on;
title(sprintf('%.1f kbps total', kpi.goodputKbps));

subplot(1, 2, 2);
% Every generated packet lands in exactly one of these. Plotting the outcome split next to the
% throughput is deliberate: a high goodput with a large expired count is a different system
% from the same goodput with none, and the number alone cannot tell them apart.
counts = [kpi.nDelivered, kpi.nExpired, kpi.nCongestionDrop, kpi.nInFlight];
bar(counts);
set(gca, 'XTickLabel', {'delivered', 'PDB expired', 'cong. drop', 'in flight'});
ylabel('packets');
grid on;
title(sprintf('%d generated  |  link PRR %.3f', kpi.nGenerated, kpi.prrLink));

if ~isempty(c.sim.plotDir)
    if ~exist(c.sim.plotDir, 'dir'), mkdir(c.sim.plotDir); end
    exportgraphics(figs(1), fullfile(c.sim.plotDir, 'latency.png'), 'Resolution', 150);
    exportgraphics(figs(2), fullfile(c.sim.plotDir, 'throughput.png'), 'Resolution', 150);
    fprintf('  figures written to %s\n', c.sim.plotDir);
end
end
