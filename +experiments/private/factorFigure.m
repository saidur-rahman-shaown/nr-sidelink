function [file, T] = factorFigure(x, xLabel, R, ttl, outDir, name, xTickLabels)
%factorFigure One factor's effect on every flow: per-link latency percentiles and on-time ratio.
%Inputs: x       1 x C numeric -- the factor's values (plotted positions)
%        xLabel  char
%        R       C x nSeed cell of summarizeRun structs (from sweep)
%        ttl     char -- figure title
%        outDir, name  where to save
%        xTickLabels   optional cellstr
%Outputs: file  the PNG
%         T     table: one row per (x, flow) -- p50/p95/p99 per-link latency, on-time ratio,
%               target 1-PER, verdict, collision rate, CBR
%Left panel: p50 (solid) and p95 (dashed) per-link latency, with each flow's PDB as a dotted line
%in the flow's colour. Right panel: the fraction of (packet, receiver) pairs delivered within the
%PDB, against 1 - PER -- the one number the PDB/PER pair is judged on.
v = viz();
C = numel(x);
nF = numel(R{1, 1}.flow);
[f, t] = newFig(1150, 430, 1, 2);
axL = nexttile(t); hold(axL, 'on'); grid(axL, 'on');
axR = nexttile(t); hold(axR, 'on'); grid(axR, 'on');
rows = {};
hL = gobjects(1, nF); names = cell(1, nF);
for fi = 1:nF
    p50 = nan(1, C); p95 = nan(1, C); ot = nan(1, C); lo = nan(1, C); hi = nan(1, C);
    fl = R{1, 1}.flow(fi);
    for c = 1:C
        lat = pooled(R(c, :), fi, 'linkLatMs');
        on  = pooled(R(c, :), fi, 'linkOnTime');
        if ~isempty(lat), p50(c) = median(lat); p95(c) = prctile(lat, 95); end
        vd = pdbVerdict(on, fl.pqi, '');
        ot(c) = vd.achieved; lo(c) = vd.ci95(1); hi(c) = vd.ci95(2);
        rows(end + 1, :) = {x(c), fl.pqi, fl.pdbMs, fl.arrival, p50(c), p95(c), ...
            prctile(lat, 99), vd.achieved, vd.target, vd.verdict, ...
            mean(cellfun(@(r) r.collisionRate, R(c, :))), mean(cellfun(@(r) r.cbrMean, R(c, :)))}; %#ok<AGROW>
    end
    col = v.cat(fi, :);
    hL(fi) = plot(axL, x, p50, '-o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 5);
    plot(axL, x, p95, '--s', 'Color', col, 'MarkerSize', 5);
    yline(axL, fl.pdbMs, ':', 'Color', col, 'LineWidth', 1.5);
    names{fi} = sprintf('PQI %d (%s, PDB %g ms)', fl.pqi, fl.arrival, fl.pdbMs);
    errorbar(axR, x, ot, ot - lo, hi - ot, '-o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 5);
    % A PDB violation (on-time share below 1 - PER) is ringed in red so it cannot be missed.
    bad = ot < 1 - cfg.pqiLookup(cfg.pqiTable(), fl.pqi).PER;
    plot(axR, x(bad), ot(bad), 'o', 'Color', v.status.bad, 'MarkerSize', 14, 'LineWidth', 2.5);
    plot(axL, x(bad), p95(bad), 'x', 'Color', v.status.bad, 'MarkerSize', 12, 'LineWidth', 2.5);
    yline(axR, 1 - cfg.pqiLookup(cfg.pqiTable(), fl.pqi).PER, ':', 'Color', col, 'LineWidth', 1.5);
end
xlabel(axL, xLabel); ylabel(axL, 'per-link latency (ms)  — p50 solid, p95 dashed');
legend(axL, hL, names, 'Location', 'northoutside', 'Box', 'off');
xlabel(axR, xLabel); ylabel(axR, 'pairs delivered within PDB  (dotted: 1 - PER target)');
ylim(axR, [max(0, min(ylim(axR))) 1.01]);
text(axR, 0.02, 0.04, 'red ring = PDB VIOLATED (on-time < 1 - PER)', 'Units', 'normalized', 'Color', v.status.bad, 'FontSize', 9);
if nargin >= 7 && ~isempty(xTickLabels)
    set([axL axR], 'XTick', x, 'XTickLabel', xTickLabels);
end
title(t, ttl, 'FontWeight', 'normal');
file = saveFig(f, outDir, name);
T = cell2table(rows, 'VariableNames', {'x', 'pqi', 'pdbMs', 'arrival', 'p50Ms', 'p95Ms', 'p99Ms', ...
    'onTime', 'target', 'verdict', 'collisionRate', 'cbr'});
end
