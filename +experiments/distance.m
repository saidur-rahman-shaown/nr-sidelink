function out = distance(s)
%distance Experiment 5: throughput, reliability and latency against distance, for every MCS,
%with and without HARQ.
%Spec:   none -- two complementary studies:
%   LINK LEVEL (every MCS 0..27): the measured BLER curves of experiments.linkCurves read through
%     the RMa LOS budget at 23 dBm over the 50-PRB channel. Gives the throughput-distance family,
%     the best-MCS envelope (ideal link adaptation), and each MCS's range.
%   SYSTEM LEVEL (table MCS 4, 7, 11, 20): harness.sls with one transmitter and one receiver at
%     each distance, a 300 B packet every 50 ms (PQI 58, 100 ms PDB) and the reservation period
%     matched to it. Three HARQ modes: none (1 TX), blind (2 TX, broadcast), PSFCH feedback
%     (unicast). Gives latency and PDB-reliability vs distance through the whole MAC.
%Inputs: s  optional, experiments.settings()
%Outputs: out  .files, .rangeTable (per MCS: range at PRR >= 0.9 per mode), .envelope, .sls
%Figures (plots/experiments/distance/):
%   throughput_vs_distance_all_mcs.png   one curve per MCS (sequential colour), envelope bold
%   best_mcs_vs_distance.png             the MCS that maximises throughput at each distance
%   range_per_mcs.png                    distance at which PRR falls below 0.9, per mode
%   sls_prr_latency_vs_distance.png      PDB reliability and latency vs distance, HARQ modes
%   sls_tx_per_delivery.png              channel cost of each HARQ mode vs distance
if nargin < 1, s = experiments.settings(); end
outDir = fullfile(s.plotRoot, 'distance');
v = viz();
quick = strcmp(s.scale, 'quick');
lk = experiments.linkCurves();
slotMs = 0.5;
nRb = lk.meta.NRB;
assert(nRb == s.op.numSubchannel * s.op.subchSizeRb && lk.meta.mu == s.op.mu, ...
    'distance: link curves measured at %d PRB -- off the operating point', nRb);
d = 10:5:1500;
snrD = linkBudget(d, nRb, s);
scenU = harness.sls.scenarioInit(2, 1, 'unicast');
nM = numel(lk.mcs);
modes = {'none', 'blind1', 'feedback'};
modeLbl = {'no HARQ (1 TX)', 'blind retx (2 TX)', 'PSFCH HARQ (<=3 TX)'};

% ---- link level: every MCS ------------------------------------------------------
Tall = zeros(nM, numel(d), 3); P = zeros(nM, numel(d), 3);
for m = 1:nM
    tbU = harness.lls.linkConfig(lk.mcs(m), lk.meta.LsubCH, scenU).trblklen;
    for k = 1:3
        tb = []; if k == 3, tb = tbU; end
        [Tall(m, :, k), P(m, :, k)] = linkThroughput(lk.curve{m}, snrD, modes{k}, slotMs, tb);
    end
end
cm = interp1(linspace(0, 1, size(v.seq, 1)), v.seq, linspace(0.25, 1, nM));
[f, t] = newFig(1300, 440, 1, 3);
for k = 1:3
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    for m = 1:nM
        plot(ax, d, Tall(m, :, k), '-', 'Color', cm(m, :), 'LineWidth', 1.2);
    end
    [env, best] = max(Tall(:, :, k), [], 1);
    plot(ax, d, env, '-', 'Color', v.cat(2, :), 'LineWidth', 2.5);
    envelope.(modes{k}) = struct('d', d, 'T', env, 'bestMcs', lk.mcs(best));
    xlabel(ax, 'distance (m)'); ylabel(ax, 'throughput (Mbit/s)'); xlim(ax, [0 1200]);
    title(ax, modeLbl{k}, 'FontWeight', 'normal');
end
colormap(ax, cm); cb = colorbar(ax); clim(ax, [lk.mcs(1) lk.mcs(end)]); cb.Label.String = 'I_{MCS}';
legend(ax, findobj(ax, 'Color', v.cat(2, :)), {'best MCS (envelope)'}, 'Location', 'northeast', 'Box', 'off');
title(t, sprintf('Full-buffer throughput vs distance, every MCS (%s, %g km/h, %d PRB, RMa LOS, 23 dBm)', ...
    lk.meta.channel, lk.meta.speedKmh, nRb), 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'throughput_vs_distance_all_mcs');

[f, ax] = newFig(900, 420);
for k = 1:3
    stairs(ax, d, envelope.(modes{k}).bestMcs, '-', 'Color', v.cat(k, :));
end
xlabel(ax, 'distance (m)'); ylabel(ax, 'throughput-maximising I_{MCS}'); xlim(ax, [0 1200]);
legend(ax, modeLbl, 'Location', 'northeast', 'Box', 'off');
title(ax, 'Ideal link adaptation: best MCS against distance', 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'best_mcs_vs_distance');

rng90 = zeros(nM, 3);
for m = 1:nM
    for k = 1:3
        ok = find(P(m, :, k) >= 0.9);
        if isempty(ok), rng90(m, k) = 0; else, rng90(m, k) = d(ok(end)); end
    end
end
[f, ax] = newFig(1000, 420);
b = bar(ax, lk.mcs, rng90, 1, 'EdgeColor', 'w', 'LineWidth', 1);
for k = 1:3, b(k).FaceColor = v.cat(k, :); end
xlabel(ax, 'I_{MCS}'); ylabel(ax, 'range at PRR >= 0.9 (m)');
legend(ax, modeLbl, 'Location', 'northeast', 'Box', 'off');
title(ax, 'Range per MCS (link level: last distance where the TB decodes with >= 90%)', 'FontWeight', 'normal');
files{3} = saveFig(f, outDir, 'range_per_mcs');
rangeTable = array2table([lk.mcs(:) rng90 max(Tall(:, :, 1), [], 2)], 'VariableNames', ...
    {'mcs', 'rangeNoHarqM', 'rangeBlindM', 'rangeFeedbackM', 'maxNoHarqMbps'});

% ---- system level: HARQ modes, latency and PDB reliability ----------------------
dS = 100:100:1200; if quick, dS = [100 500 900]; end
mS = [4 7 11 20]; if quick, mS = 7; end
nSlots = 8000; if quick, nSlots = 2400; end
jobs = {};
for a = 1:numel(mS)
    for k = 1:3
        for q = 1:numel(dS)
            for sd = s.seeds
                jobs{end + 1} = {dS(q), modes{k}, mS(a), sd}; %#ok<AGROW>
            end
        end
    end
end
res = cell(1, numel(jobs));
if s.useParallel
    if isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end
    parfor j = 1:numel(jobs)
        jb = jobs{j};
        res{j} = lineRun(jb{1}, jb{2}, jb{3}, jb{4}, nSlots);
    end
else
    for j = 1:numel(jobs)
        jb = jobs{j};
        res{j} = lineRun(jb{1}, jb{2}, jb{3}, jb{4}, nSlots);
    end
end
R = [res{:}];
[f, t] = newFig(1300, 760, 2, numel(mS));
rowsS = {};
for a = 1:numel(mS)
    axP = nexttile(t, a); hold(axP, 'on'); grid(axP, 'on');
    axL = nexttile(t, a + numel(mS)); hold(axL, 'on'); grid(axL, 'on');
    for k = 1:3
        on = nan(1, numel(dS)); p50 = on; p95 = on; tpd = on;
        for q = 1:numel(dS)
            sel = R([R.mcs] == mS(a) & strcmp({R.mode}, modes{k}) & [R.d] == dS(q));
            o = [sel.onTime]; l = [sel.latMs];
            on(q) = mean(o);
            if ~isempty(l), p50(q) = median(l); p95(q) = prctile(l, 95); end
            tpd(q) = mean([sel.txPerDelivery]);
            rowsS(end + 1, :) = {mS(a), modes{k}, dS(q), on(q), p50(q), p95(q), tpd(q), numel(o), all([sel.infeasible])}; %#ok<AGROW>
        end
        plot(axP, dS, on, '-o', 'Color', v.cat(k, :), 'MarkerFaceColor', v.cat(k, :), 'MarkerSize', 4);
        plot(axL, dS, p50, '-o', 'Color', v.cat(k, :), 'MarkerFaceColor', v.cat(k, :), 'MarkerSize', 4);
        plot(axL, dS, p95, '--', 'Color', v.cat(k, :));
    end
    yline(axP, 0.9, ':', '1 - PER (PQI 56/57/59)', 'Color', v.muted);
    yline(axL, 100, ':', 'PDB', 'Color', v.status.bad);
    ylim(axP, [0 1.02]); ylim(axL, [0 105]);
    title(axP, sprintf('MCS %d', mS(a)), 'FontWeight', 'normal');
    xlabel(axL, 'distance (m)');
    if a == 1
        ylabel(axP, 'packets delivered within PDB'); ylabel(axL, 'latency (ms): p50 solid, p95 dashed');
    end
end
legend(axP, modeLbl, 'Location', 'southwest', 'Box', 'off');
title(t, 'System level, 1 TX -> 1 RX: PDB reliability and latency vs distance, by HARQ mode', 'FontWeight', 'normal');
files{4} = saveFig(f, outDir, 'sls_prr_latency_vs_distance');
slsT = cell2table(rowsS, 'VariableNames', {'mcs', 'mode', 'dM', 'onTime', 'p50Ms', 'p95Ms', 'txPerDelivery', 'n', 'infeasible'});

[f, ax] = newFig(900, 420);
for k = 1:3
    sel = strcmp(slsT.mode, modes{k}) & slsT.mcs == 7;
    plot(ax, slsT.dM(sel), slsT.txPerDelivery(sel), '-o', 'Color', v.cat(k, :), ...
        'MarkerFaceColor', v.cat(k, :), 'MarkerSize', 4);
end
xlabel(ax, 'distance (m)'); ylabel(ax, 'transmissions per delivered packet');
legend(ax, modeLbl, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Channel cost of reliability, MCS 7: what each delivery spends', 'FontWeight', 'normal');
files{5} = saveFig(f, outDir, 'sls_tx_per_delivery');

out.files = files; out.rangeTable = rangeTable; out.envelope = envelope; out.sls = slsT;
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'distance.mat'), 'out');
disp(rangeTable);
disp(slsT(slsT.mcs == 7, :));
end
