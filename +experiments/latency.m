function out = latency(s)
%latency Experiment 2: end-to-end latency against the PDB, and what moves it.
%Spec:   none -- a system-level study over harness.sls (Mode 2, sensing-based selection, the
%        measured TDL-D BLER table). Latency is application generation -> first successful decode
%        at a receiver; judged per (packet, receiver within range) pair against the packet's own
%        PDB at its PQI's PER (pdbVerdict), and also per packet (first decode anywhere).
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct: .files, .verdict (baseline table), .tables (one per factor), .decomp
%Scenario: Poisson drop in 500 m x 500 m, every UE broadcasting CAM (PQI 58: 100 ms, periodic
%100 ms, 300 B) and event messages (PQI 56: 20 ms PDB, Poisson, mean 500 ms, 250 B), MCS 7,
%P_rsvp_TX 100 ms, one blind retransmission. Intended receivers: within 300 m.
%Figures (plots/experiments/latency/):
%   latency_cdf.png          baseline per-link latency CDF per flow, losses included (the curve
%                            tops out at the on-time ratio), PDB marked
%   latency_decomposition.png  where the time goes: waiting for the resource vs air + decode
%   latency_vs_load.png      p50/p95 and on-time ratio vs UE count
%   latency_vs_prsvp.png     ... vs reservation period
%   latency_vs_retx.png      ... vs blind retransmissions
%   latency_vs_mcs.png       ... vs MCS (table MCS only)
if nargin < 1, s = experiments.settings(); end
outDir = fullfile(s.plotRoot, 'latency');
v = viz();
quick = strcmp(s.scale, 'quick');
nSlots = 6000; if quick, nSlots = 1600; end
rangeM = 300;
base = struct('nUe', 40);

% ---- baseline ---------------------------------------------------------------
R0 = sweep({base}, nSlots, s, rangeM);
[f, t] = newFig(1150, 430, 1, 2);
verdict = [];
for fi = 1:numel(R0{1}.flow)
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    fl = R0{1}.flow(fi);
    lat = pooled(R0, fi, 'linkLatMs');
    on  = pooled(R0, fi, 'linkOnTime');
    nPairs = numel(on);
    xs = sort(lat);
    plot(ax, xs, (1:numel(xs)) / nPairs, '-', 'Color', v.cat(1, :));
    pl = sort(pooled(R0, fi, 'pktLatMs'));
    pn = numel(pooled(R0, fi, 'pktOnTime'));
    plot(ax, pl, (1:numel(pl)) / pn, '--', 'Color', v.cat(2, :));
    xline(ax, fl.pdbMs, ':', sprintf('PDB %g ms', fl.pdbMs), 'Color', v.status.bad, 'LineWidth', 1.5);
    yline(ax, 1 - cfg.pqiLookup(cfg.pqiTable(), fl.pqi).PER, ':', '1 - PER', 'Color', v.muted);
    vd = pdbVerdict(on, fl.pqi, sprintf('PQI %d per-link', fl.pqi));
    vp = pdbVerdict(pooled(R0, fi, 'pktOnTime'), fl.pqi, sprintf('PQI %d per-packet', fl.pqi));
    verdict = [verdict vd vp]; %#ok<AGROW>
    xlabel(ax, 'latency (ms)'); ylabel(ax, 'fraction of pairs / packets');
    ylim(ax, [0 1.02]); xlim(ax, [0 max(fl.pdbMs * 1.4, 5)]);
    legend(ax, {sprintf('per link, %d pairs (%s)', nPairs, vd.verdict), ...
        sprintf('per packet, any receiver (%s)', vp.verdict)}, 'Location', 'southeast', 'Box', 'off');
    title(ax, sprintf('PQI %d, %s, PDB %g ms: %.1f%% of pairs on time', fl.pqi, fl.arrival, ...
        fl.pdbMs, 100 * vd.achieved), 'FontWeight', 'normal');
end
title(t, sprintf('Baseline: %d UEs / 0.25 km^2, MCS 7, P_{rsvp} 100 ms, 1 blind retx (%d seeds)', ...
    base.nUe, numel(s.seeds)), 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'latency_cdf');

% ---- decomposition ------------------------------------------------------------
[f, ax] = newFig(700, 420);
nF = numel(R0{1}.flow);
acc = zeros(1, nF); air = zeros(1, nF); lbl = cell(1, nF);
for fi = 1:nF
    a = pooled(R0, fi, 'accessMs'); l = pooled(R0, fi, 'pktLatMs');
    acc(fi) = median(a); air(fi) = max(0, median(l) - median(a));
    lbl{fi} = sprintf('PQI %d (%s)', R0{1}.flow(fi).pqi, R0{1}.flow(fi).arrival);
end
b = barh(ax, [acc' air'], 'stacked', 'BarWidth', 0.5, 'EdgeColor', 'w', 'LineWidth', 2);
b(1).FaceColor = v.cat(1, :); b(2).FaceColor = v.cat(3, :);
set(ax, 'YTick', 1:nF, 'YTickLabel', lbl);
xlabel(ax, 'median per-packet latency (ms)');
legend(ax, {'generation -> first transmission (selection window)', 'first TX -> decoded (retx, HARQ)'}, ...
    'Location', 'southoutside', 'Box', 'off');
title(ax, {'Where the latency goes', 'SLS: a TB decodes in the slot it is sent; T2 stops decodeMargin short of the PDB'}, 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'latency_decomposition');
decomp = table(lbl', acc', air', 'VariableNames', {'flow', 'accessMedMs', 'airMedMs'});

% ---- factors ------------------------------------------------------------------
nList = [10 20 40 80 120]; if quick, nList = [10 40]; end
cf = arrayfun(@(n) setfield(base, 'nUe', n), nList, 'UniformOutput', false); %#ok<SFLD>
[files{3}, tables.load] = factorFigure(nList, 'UEs in the 500 m x 500 m field', ...
    sweep(cf, nSlots, s, rangeM), 'Latency vs load', outDir, 'latency_vs_load');

pList = [20 50 100];
cf = arrayfun(@(p) setfield(base, 'prsvpTxMs', p), pList, 'UniformOutput', false); %#ok<SFLD>
[files{4}, tables.prsvp] = factorFigure(pList, 'P_{rsvp,TX} (ms)', sweep(cf, nSlots, s, rangeM), ...
    'Latency vs reservation period (40 UEs)', outDir, 'latency_vs_prsvp');

rList = [0 1 2];
cf = arrayfun(@(r) setfield(base, 'numRetx', r), rList, 'UniformOutput', false); %#ok<SFLD>
[files{5}, tables.retx] = factorFigure(rList, 'blind retransmissions per TB', sweep(cf, nSlots, s, rangeM), ...
    'Latency vs blind retransmissions (40 UEs)', outDir, 'latency_vs_retx');

mList = [4 7 11];
cf = arrayfun(@(m) setfield(base, 'mcs', m), mList, 'UniformOutput', false); %#ok<SFLD>
[files{6}, tables.mcs] = factorFigure(mList, 'I_{MCS}', sweep(cf, nSlots, s, rangeM), ...
    'Latency vs MCS (40 UEs)', outDir, 'latency_vs_mcs');

out.files = files;
out.verdict = struct2table(rmfield(verdict, 'ci95'));
out.tables = tables;
out.decomp = decomp;
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'latency.mat'), 'out');
disp(out.verdict); disp(decomp);
fn = fieldnames(tables);
for k = 1:numel(fn), fprintf('\n-- %s\n', fn{k}); disp(tables.(fn{k})); end
end
