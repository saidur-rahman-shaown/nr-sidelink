function out = systemLevel(s)
%systemLevel Study Part C: many UEs in a 1 km x 1 km field -- throughput, latency, collisions and
%failures per PQI, each judged against its own PER, for several UE densities.
%Spec:   none -- harness.sls (sensing-based SPS, SCI reservations, re-evaluation/pre-emption, CBR/CR,
%        the real MAC receive path) with the PHY read from tables MEASURED at 20 mph
%        (20 mph) and the calibrated free-space link of Part B (experiments.linkLevel).
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct: .flows (the traffic, stated before deployment), .table (per density x flow),
%              .files
%TRAFFIC (every UE runs all five; broadcast may use only the Non-GBR PQIs 55..59, TS 23.287
%Table 5.4.4-1 NOTE 1, and each is judged against its own PER):
%   Sensor information sharing    PQI 58: PDB 100 ms, PER 1e-2 -> 99 %;    300 B every 100 ms
%   Platooning informative exch.  PQI 56: PDB 20 ms,  PER 1e-1 -> 90 %;    200 B every 100 ms
%   Platooning, report to RSU     PQI 59: PDB 500 ms, PER 1e-1 -> 90 %;    200 B every 500 ms
%   Cooperative lane change       PQI 55: PDB 10 ms,  PER 1e-4 -> 99.99 %; 200 B, Poisson 500 ms
%   Cooperative lane change, low  PQI 57: PDB 25 ms,  PER 1e-1 -> 90 %;    200 B, Poisson 1000 ms
%   MCS 11, P_rsvp 100 ms, 1 blind retransmission, T1 = 5 slots, T2 = PDB - 3 slots; latency adds
%   the 1 + 2 slot TX/RX pipeline (settings().op). Intended receivers: every UE within 500 m.
%Figures (plots/study/C_system/): C1_deployment, C2_reliability, C3_latency, C4_throughput,
%   C5_collisions, C6_failures, C7_reliability_vs_distance
if nargin < 1 || isempty(s), s = experiments.settings(); end
outDir = fullfile('plots', 'study', 'C_system');
v = viz();
quick = strcmp(s.scale, 'quick');
dens = [5 10 15 20 30 40 50 75 100]; if quick, dens = [10 50]; end
nSlots = 10000; if quick, nSlots = 1600; end
rangeM = 500;
flows = struct('pqi', {58, 56, 59, 55, 57}, 'periodMs', {100, 100, 500, 500, 1000}, ...
    'sizeBytes', {300, 200, 200, 200, 200}, 'lcid', {4, 5, 6, 7, 8}, 'nPackets', {inf, inf, inf, inf, inf}, ...
    'pdbMsOverride', {[], [], [], [], []}, 'arrival', {'periodic', 'periodic', 'periodic', 'poisson', 'poisson'});
names = {'Sensor sharing (PQI 58)', 'Platooning info (PQI 56)', 'Report to RSU (PQI 59)', ...
    'Lane change (PQI 55)', 'Lane change, low (PQI 57)'};
pq = cfg.pqiTable();
ft = arrayfun(@(f) cfg.pqiLookup(pq, f.pqi), flows);
out.flows = table(names', [flows.pqi]', [ft.PDB_ms]', [ft.PER]', 1 - [ft.PER]', [ft.priority]', {flows.arrival}', ...
    [flows.periodMs]', [flows.sizeBytes]', [flows.sizeBytes]' * 8 ./ [flows.periodMs]', ...
    'VariableNames', {'flow', 'pqi', 'pdbMs', 'per', 'target', 'priority', 'arrival', 'periodOrMeanMs', 'sizeBytes', 'offeredKbpsPerUe'});
base = struct('sizeM', [1000 1000], 'mcs', 11, 'prsvpTxMs', 100, 'numRetx', 1, 'flows', flows, ...
    'castType', 'broadcast', 'pool', struct(), 'policy', struct());
cfgs = arrayfun(@(dn) setfield(base, 'densityPerKm2', dn), dens, 'UniformOutput', false); %#ok<SFLD>
R = sweep(cfgs, nSlots, s, rangeM);

% ---- C1: how the UEs are distributed, and one sample drop (experiments.deployment) ---------------
[files{1}, out.drops] = experiments.deployment(s, dens, rangeM, base);

% ---- per density x flow numbers ----------------------------------------------------------------
rows = {};
nF = numel(flows);
onT = zeros(numel(dens), nF); p50 = onT; p95 = onT; good = zeros(numel(dens), 1); col = good; cbr = good;
btRx = zeros(numel(dens), nF); btIdeal = btRx;          % broadcast throughput, Mbit/s in the field
causes = zeros(numel(dens), nF, 5);
for k = 1:numel(dens)
    Rk = R(k, :);
    col(k) = mean(cellfun(@(r) r.collisionRate, Rk)); cbr(k) = mean(cellfun(@(r) r.cbrMean, Rk));
    nUe = mean(cellfun(@(r) r.nUe, Rk));
    good(k) = mean(cellfun(@(r) r.goodputKbps, Rk));
    for fi = 1:nF
        btRx(k, fi)    = mean(cellfun(@(r) r.flow(fi).rxBitsOnTime / r.flow(fi).obsSec, Rk)) / 1e6;
        btIdeal(k, fi) = mean(cellfun(@(r) r.flow(fi).pairBits / r.flow(fi).obsSec, Rk)) / 1e6;
    end
    for fi = 1:nF
        on = pooled(Rk, fi, 'linkOnTime'); lat = pooled(Rk, fi, 'linkLatMs'); cs = pooled(Rk, fi, 'linkCause');
        vd = pdbVerdict(on, flows(fi).pqi, names{fi});
        onT(k, fi) = vd.achieved; p50(k, fi) = pct(lat, 50); p95(k, fi) = pct(lat, 95);
        causes(k, fi, :) = arrayfun(@(c) nnz(cs == c), 1:5);
        rows(end + 1, :) = {dens(k), round(nUe), names{fi}, flows(fi).pqi, ft(fi).PDB_ms, ft(fi).PER, numel(on), ...
            vd.achieved, vd.target, vd.verdict, p50(k, fi), p95(k, fi), col(k), cbr(k), good(k) / max(nUe, 1)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'densityPerKm2', 'nUe', 'flow', 'pqi', 'pdbMs', 'per', 'pairs', ...
    'onTime', 'target', 'verdict', 'p50Ms', 'p95Ms', 'collisionRate', 'cbr', 'goodputKbpsPerUe'});

% ---- C2: reliability vs density, against each flow's own target ---------------------------------
[f, ax] = newFig(950, 460);
hL = gobjects(1, nF);
for fi = 1:nF
    hL(fi) = plot(ax, dens, onT(:, fi), '-o', 'Color', v.cat(fi, :), 'MarkerFaceColor', v.cat(fi, :), 'LineWidth', 2);
    bad = onT(:, fi) < 1 - ft(fi).PER;
    plot(ax, dens(bad), onT(bad, fi), 'o', 'Color', v.status.bad, 'MarkerSize', 14, 'LineWidth', 2.5);
end
% One line per distinct target, labelled with every PQI that shares it (56, 57, 59 are all 90 %).
tg = unique(1 - [ft.PER]);
hAlign = {'left', 'center'};                % alternate, so near-equal targets (99 / 99.99 %) do not overprint
for q = 1:numel(tg)
    who = [flows(abs((1 - [ft.PER]) - tg(q)) < 1e-12).pqi];
    yline(ax, tg(q), ':', sprintf('target %g %% (PQI %s)', 100 * tg(q), strjoin(string(who), ', ')), ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 1.5, 'LabelHorizontalAlignment', hAlign{1 + mod(q, 2)}, ...
        'LabelVerticalAlignment', 'bottom');
end
xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'pairs delivered within the flow''s PDB (receivers <= 500 m)');
legend(ax, hL, names, 'Location', 'southwest', 'Box', 'off'); ylim(ax, [max(0, min(onT(:)) - 0.05) 1.005]);
title(ax, {'Reliability against density, each flow against its own target 1 - PER', 'red ring = target violated'}, 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'C2_reliability');

% ---- C3: latency vs density -------------------------------------------------------------------------
[f, t] = newFig(1750, 400, 1, nF);
for fi = 1:nF
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    plot(ax, dens, p50(:, fi), '-o', 'Color', v.cat(fi, :), 'MarkerFaceColor', v.cat(fi, :), 'LineWidth', 2);
    plot(ax, dens, p95(:, fi), '--s', 'Color', v.cat(fi, :), 'LineWidth', 1.5);
    yline(ax, ft(fi).PDB_ms, '-', 'PDB', 'Color', v.status.bad);
    yline(ax, 4, ':', 'minimum 4 ms', 'Color', v.muted);
    ylim(ax, [0 ft(fi).PDB_ms * 1.1]); xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'latency (ms)');
    title(ax, {names{fi}, 'p50 solid, p95 dashed'}, 'FontWeight', 'normal');
end
files{3} = saveFig(f, outDir, 'C3_latency');

% ---- C4: broadcast throughput with sensing running ---------------------------------------------
% Broadcast has no single receiver, so throughput is counted at the RECEIVERS: every (packet,
% intended receiver within 500 m) copy delivered within its PDB adds the packet's bits. The ideal is
% every copy delivered. Per UE = field total / N, i.e. what an average UE receives on time.
nU = arrayfun(@(k) mean(cellfun(@(r) r.nUe, R(k, :))), 1:numel(dens));
[f, t] = newFig(1250, 430, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, dens, sum(btIdeal, 2), '--', 'Color', v.muted, 'LineWidth', 1.5);
plot(ax, dens, sum(btRx, 2), '-o', 'Color', v.cat(1, :), 'MarkerFaceColor', v.cat(1, :), 'LineWidth', 2);
xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'Mbit/s received on time, whole field');
legend(ax, {'ideal: every intended receiver gets every packet', 'delivered within the PDB'}, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Aggregate broadcast throughput', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
bh = bar(ax, 1:numel(dens), 1000 * btRx ./ nU(:), 0.7, 'stacked', 'EdgeColor', 'w');
for fi = 1:nF, bh(fi).FaceColor = v.cat(fi, :); end
plot(ax, 1:numel(dens), 1000 * sum(btIdeal, 2) ./ nU(:), 'k--o', 'LineWidth', 1.2, 'MarkerSize', 4);
set(ax, 'XTick', 1:numel(dens), 'XTickLabel', compose('%d', dens(:)));
xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'kbit/s received on time, per UE');
legend(ax, [names, {'ideal'}], 'Location', 'northwest', 'Box', 'off', 'FontSize', 8);
title(ax, 'What one UE receives on time, by flow', 'FontWeight', 'normal');
title(t, sprintf('Broadcast throughput with sensing-based SPS running (each UE sends %.0f kbit/s)', sum(out.flows.offeredKbpsPerUe)), 'FontWeight', 'normal');
files{4} = saveFig(f, outDir, 'C4_throughput');
out.broadcast = table(dens(:), nU(:), sum(btIdeal, 2), sum(btRx, 2), 1000 * sum(btRx, 2) ./ nU(:), ...
    sum(btRx, 2) ./ sum(btIdeal, 2), 'VariableNames', {'densityPerKm2', 'nUe', 'idealMbps', 'deliveredMbps', ...
    'perUeKbps', 'efficiency'});

% ---- C5: collisions and CBR -------------------------------------------------------------------------
[f, ax] = newFig(900, 420);
yyaxis_free(ax, dens, col, cbr, v);
files{5} = saveFig(f, outDir, 'C5_collisions');

% ---- C6: failure breakdown -------------------------------------------------------------------------
[f, t] = newFig(1850, 420, 1, nF);
lbl = {'not sent (expired at source)', 'half duplex', 'collision', 'radio (range / fading)', 'late (after PDB)'};
cc = v.cat([4 7 8 1 5], :);
for fi = 1:nF
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    C = squeeze(causes(:, fi, :));
    if isvector(C), C = C(:)'; end
    tot = arrayfun(@(k) numel(pooled(R(k, :), fi, 'linkOnTime')), 1:numel(dens))';
    b = bar(ax, 1:numel(dens), 100 * C ./ tot, 0.7, 'stacked', 'EdgeColor', 'w');
    for q = 1:5, b(q).FaceColor = cc(q, :); end
    yline(ax, 100 * ft(fi).PER, ':', 'PER budget', 'Color', v.ink);
    set(ax, 'XTick', 1:numel(dens), 'XTickLabel', compose('%d', dens(:)));
    xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'pairs failed (%)');
    title(ax, names{fi}, 'FontWeight', 'normal');
end
legend(ax, lbl, 'Location', 'eastoutside', 'Box', 'off');
title(t, 'Why pairs failed, against each flow''s PER budget', 'FontWeight', 'normal');
files{6} = saveFig(f, outDir, 'C6_failures');

% ---- C7: reliability vs distance ---------------------------------------------------------------------
[f, t] = newFig(1750, 400, 1, nF);
e = 0:50:rangeM; ctr = e(1:end - 1) + 25;
for fi = 1:nF
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    shown = find(ismember(dens, [10 20 50 100]));
    for jj = 1:numel(shown)
        k = shown(jj);
        on = pooled(R(k, :), fi, 'linkOnTime'); dd = pooled(R(k, :), fi, 'linkDistM');
        vv = arrayfun(@(b) mean(on(dd >= e(b) & dd < e(b + 1))), 1:numel(ctr));
        plot(ax, ctr, vv, '-o', 'Color', v.cat(jj, :), 'MarkerSize', 4, 'LineWidth', 1.6);
    end
    yline(ax, 1 - ft(fi).PER, ':', 'target', 'Color', v.muted);
    xlabel(ax, 'TX-RX distance (m)'); ylabel(ax, 'within PDB'); ylim(ax, [0.5 1.005]);
    title(ax, names{fi}, 'FontWeight', 'normal');
end
legend(ax, compose('%d /km^2', dens(ismember(dens, [10 20 50 100]))'), 'Location', 'southwest', 'Box', 'off');
files{7} = saveFig(f, outDir, 'C7_reliability_vs_distance');

out.table = T; out.files = files; out.causes = causes; out.densities = dens;
d = fullfile('plots', 'study', 'data'); if ~isfolder(d), mkdir(d); end
save(fullfile(d, 'systemLevel.mat'), 'out');
disp(out.flows); disp(out.drops); disp(out.broadcast); disp(T);
end

function yyaxis_free(ax, dens, col, cbr, v)
%Two measures on one axis would need two scales; both are fractions in [0, 1], so they share one.
plot(ax, dens, col, '-o', 'Color', v.cat(8, :), 'MarkerFaceColor', v.cat(8, :), 'LineWidth', 2);
plot(ax, dens, cbr, '-s', 'Color', v.cat(1, :), 'MarkerFaceColor', v.cat(1, :), 'LineWidth', 2);
xlabel(ax, 'UE density (per km^2)'); ylabel(ax, 'fraction');
legend(ax, {'collided share of transmissions', 'mean CBR'}, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Collisions and channel load against density', 'FontWeight', 'normal');
end

function v = pct(x, p)
if isempty(x), v = NaN; else, v = prctile(x, p); end
end
