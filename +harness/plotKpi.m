function figs = plotKpi(kpi, scen, c)
%plotKpi Latency CDF, throughput and per-packet latency -- the figures the KPI struct cannot show.
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

figs = gobjects(1, 3);
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

% ---- 3. per-packet latency against WHEN the packet was generated -----------
% The CDF says how the flow behaved; it cannot say when. Every packet is one point on its
% flow's line, in generation order, so a run's time structure is visible: a grant whose phase
% happens to sit late in the budget shows as a plateau, a reselection as a step, and a stretch
% of expiries as a gap in the line with its packets marked on the deadline. Five expiries
% scattered through a run and five consecutive are the same number in the KPI table and
% completely different faults, and this is the figure that separates them.
figs(3) = figure('Name', 'Per-packet latency', 'Position', [180 180 980 480]);
hold on; grid on;
h = gobjects(1, 0);
lbl = {};
codes = sap.outcomeCodes();
for f = 1:nFlow
    b = kpi.byFlow(f);
    if isempty(b.pktTGenMs)
        continue;
    end
    tSec = b.pktTGenMs / 1000;
    % NaN at every packet that was never delivered, so the line BREAKS there rather than
    % interpolating across the gap. A line drawn straight through a stretch of losses reads as
    % normal service, which is the one thing that stretch was not.
    h(end + 1) = plot(tSec, b.pktLatencyMs, '-', 'LineWidth', 1.0, 'Color', co(f, :)); %#ok<AGROW>
    lbl{end + 1} = sprintf('LCID %d (PQI %d): %d delivered', b.lcid, b.pqi, b.nDelivered); %#ok<AGROW>
    % Lost packets have no latency, so they are drawn ON their own deadline -- the latency they
    % would have had to beat and did not. Plotting them at zero, or omitting them, are the two
    % ways to make a loss look like a success.
    lost = b.pktOutcome ~= codes.delivered;
    if any(lost)
        plot(tSec(lost), repmat(b.pdbMs, 1, nnz(lost)), 'x', 'Color', co(f, :), ...
            'MarkerSize', 9, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
    yline(b.pdbMs, '--', sprintf('PDB %g ms (LCID %d)', b.pdbMs, b.lcid), 'Color', co(f, :), ...
        'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
end
xlabel('packet generation time (s)');
ylabel('end-to-end latency (ms);  x on the PDB line = never delivered');
if ~isempty(h)
    legend(h, lbl, 'Location', 'best', 'Interpreter', 'none');
end
title(sprintf('Per-packet latency  |  %s, %d UE, %.0f m, %s  |  %d expired, %d max-retx', ...
    scen.castLabel, scen.nUe, scen.spacingM, upper(scen.channelModel), ...
    kpi.nExpired, kpi.nMaxTx));

if ~isempty(c.sim.plotDir)
    if ~exist(c.sim.plotDir, 'dir'), mkdir(c.sim.plotDir); end
    exportgraphics(figs(1), fullfile(c.sim.plotDir, 'latency.png'), 'Resolution', 150);
    exportgraphics(figs(2), fullfile(c.sim.plotDir, 'throughput.png'), 'Resolution', 150);
    exportgraphics(figs(3), fullfile(c.sim.plotDir, 'latencyPerPacket.png'), 'Resolution', 150);
    fprintf('  figures written to %s\n', c.sim.plotDir);
end
end
