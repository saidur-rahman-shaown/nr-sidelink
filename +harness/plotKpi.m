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
%
%ONE CURVE PER FLOW, NOT ONE FOR THE RUN
%----------------------------------------
%A flow is what an application owns, and each has its own PDB. Pooling a 20 ms safety flow with
%a 500 ms status flow produces a distribution describing neither, and a single PDB line that is
%wrong for both. So every flow gets its own curve and its own dashed deadline in its own
%colour; the aggregate is drawn only when there is exactly one flow, where the two coincide.

figs = gobjects(1, 2);
nFlow = numel(kpi.byFlow);
co = lines(max(nFlow, 3));

% ---- 1. latency CDF, one curve per flow -----------------------------------
figs(1) = figure('Name', 'Latency', 'Position', [100 100 820 480]);
if isempty(kpi.latencyMs)
    text(0.5, 0.5, 'no packets delivered', 'HorizontalAlignment', 'center');
else
    hold on; grid on;
    h = gobjects(1, 0);
    lbl = {};
    for f = 1:nFlow
        b = kpi.byFlow(f);
        if isempty(b.latencyMs)
            continue;                 % a flow that delivered nothing has no curve to draw
        end
        x = sort(b.latencyMs);
        y = (1:numel(x)) / numel(x);
        h(end + 1) = stairs(x, y, 'LineWidth', 1.8, 'Color', co(f, :)); %#ok<AGROW>
        lbl{end + 1} = sprintf('LCID %d (PQI %d, %g ms PDB): %d delivered, %.0f%% in PDB', ...
            b.lcid, b.pqi, b.pdbMs, b.nDelivered, 100 * b.withinPdb); %#ok<AGROW>
        % Each flow's own deadline, in that flow's own colour. Drawn per flow rather than once
        % because with mixed PQIs there is no single PDB the run can be scored against.
        xline(b.pdbMs, '--', sprintf('%g ms', b.pdbMs), 'Color', co(f, :), ...
            'LineWidth', 1.2, 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    end
    for pp = [0.5 0.9 0.99]
        yline(pp, ':', sprintf('p%g', pp * 100), 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    end
    xlabel('end-to-end latency (ms), measured from packet generation');
    ylabel('cumulative fraction of that flow''s DELIVERED packets');
    ylim([0 1.02]);
    if ~isempty(h)
        legend(h, lbl, 'Location', 'southeast', 'Interpreter', 'none');
    end
    title(sprintf('Latency CDF  |  %s, %d UE, %.0f m, %s  |  %d delivered, %d expired, %d in flight', ...
        scen.castLabel, scen.nUe, scen.spacingM, upper(scen.channelModel), ...
        kpi.nDelivered, kpi.nExpired, kpi.nInFlight));
end

% ---- 2. throughput and where the packets went, per flow -------------------
figs(2) = figure('Name', 'Throughput', 'Position', [140 140 900 480]);
names = arrayfun(@(b) sprintf('LCID %d', b.lcid), kpi.byFlow, 'UniformOutput', false);

subplot(1, 2, 1);
bar(categorical(names, names), [kpi.byFlow.goodputKbps]);
ylabel('goodput (kbps), payload only');
grid on;
title(sprintf('%.1f kbps total, %.1f per UE', kpi.goodputKbps, kpi.perUeKbps));

subplot(1, 2, 2);
% Every generated packet lands in exactly one of these. Plotting the outcome split next to the
% throughput is deliberate: a high goodput with a large expired count is a different system
% from the same goodput with none, and the number alone cannot tell them apart. Stacked per
% flow, because one starved flow inside a healthy aggregate is invisible in a single bar.
split = [[kpi.byFlow.nDelivered]; [kpi.byFlow.nExpired]; ...
         [kpi.byFlow.nMaxTx]; [kpi.byFlow.nDropped]]';
bar(categorical(names, names), split, 'stacked');
legend({'delivered', 'PDB expired', 'max retx', 'dropped'}, 'Location', 'best');
ylabel('packets');
grid on;
title(sprintf('%d generated, %d in flight  |  link PRR %.3f', ...
    kpi.nGenerated, kpi.nInFlight, kpi.prrLink));

if ~isempty(c.sim.plotDir)
    if ~exist(c.sim.plotDir, 'dir'), mkdir(c.sim.plotDir); end
    exportgraphics(figs(1), fullfile(c.sim.plotDir, 'latency.png'), 'Resolution', 150);
    exportgraphics(figs(2), fullfile(c.sim.plotDir, 'throughput.png'), 'Resolution', 150);
    fprintf('  figures written to %s\n', c.sim.plotDir);
end
end
