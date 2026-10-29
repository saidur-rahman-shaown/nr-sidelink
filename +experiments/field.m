function out = field(s, f)
%field Experiment 4: N UEs dropped as a Poisson point process in a field, each sending periodic
%and event-driven traffic, for t seconds: collisions, CBR, latency at one target UE, PDB verdict.
%Spec:   none -- a system-level run of harness.sls (Mode 2: sensing, SCI reservations, re-evaluation,
%        pre-emption, congestion control; measured TDL-D BLER table), observed through runLogged.
%Inputs: s  optional, experiments.settings()
%        f  optional, experiments.fieldConfig() -- field size, density, duration, traffic, policy
%Outputs: out  struct: .files, .verdict (per flow, per-link and per-packet, plus target UE),
%              .collisions, .cbr, .target, .drop
%The TARGET is the UE nearest the field centre. Its latency is reported both ways: packets it
%RECEIVES from every UE within range (what its applications see), and packets it SENDS, measured
%at every neighbour within range.
%Figures (plots/experiments/field/):
%   geometry.png            the drop, the target, its range, per-UE on-time ratio of what it sent
%   cbr_collisions_time.png CBR (mean and spread over UEs) and collision rate over time
%   resource_grid.png       200 ms of pool occupancy, collisions marked
%   collisions.png          what a collision costs: PRR clean vs collided, vs distance
%   target_latency.png      latency CDFs at/from the target, per flow, PDB marked
%   prr_vs_distance.png     per-link PDB reliability vs distance, per flow
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(f), f = experiments.fieldConfig(); end
outDir = fullfile(s.plotRoot, 'field');
v = viz();
if strcmp(s.scale, 'quick'), f.durationS = min(f.durationS, 2); end
[scen, ~, drop] = fieldScenario(f);
msPerSlot = 1 / 2^scen.mu;
nSlots = round(f.durationS * 1000 / msPerSlot);
[~, tgt] = min(sum((drop.xy - f.sizeM / 2).^2, 2));
t0 = tic;
[kpi, L, ~, scen, res] = runLogged(scen, nSlots, struct('sampleEverySlots', 20));
fprintf('field: %d UEs, %.1f s air in %.0f s wall\n', drop.N, f.durationS, toc(t0));
S = summarizeRun(kpi, L, res, scen, f.rangeM);
P = linkPackets(L, res, scen, f.rangeM);
nF = scen.nFlow;
flowLbl = arrayfun(@(x) sprintf('PQI %d %s (PDB %g ms)', x.pqi, x.arrival, x.pdbMs), scen.flows, 'UniformOutput', false);

% ---- geometry -----------------------------------------------------------------
[fig, ax] = newFig(640, 600);
onByUe = nan(1, drop.N);
for i = 1:drop.N
    m = P.txUe == i; if any(m), onByUe(i) = mean(P.onTime(m)); end
end
th = linspace(0, 2 * pi, 200);
plot(ax, drop.xy(tgt, 1) + f.rangeM * cos(th), drop.xy(tgt, 2) + f.rangeM * sin(th), ':', 'Color', v.muted);
scatter(ax, drop.xy(:, 1), drop.xy(:, 2), 60, onByUe, 'filled', 'MarkerEdgeColor', 'w');
plot(ax, drop.xy(tgt, 1), drop.xy(tgt, 2), 'p', 'MarkerSize', 18, 'MarkerFaceColor', v.cat(2, :), 'MarkerEdgeColor', v.ink);
colormap(ax, v.seq(60:end, :)); cb = colorbar(ax); cb.Label.String = 'pairs within PDB, packets this UE sent';
axis(ax, 'equal'); xlim(ax, [0 f.sizeM(1)]); ylim(ax, [0 f.sizeM(2)]);
xlabel(ax, 'x (m)'); ylabel(ax, 'y (m)');
title(ax, sprintf('%d UEs (PPP, %.0f /km^2), target UE %d (star), range %g m', drop.N, drop.lambda, tgt, f.rangeM), ...
    'FontWeight', 'normal');
files{1} = saveFig(fig, outDir, 'geometry');

% ---- CBR and collisions over time ----------------------------------------------
tS = (L.t + 1) * msPerSlot / 1000;
win = 200;                                      % 100 ms windows for the collision rate
slotsA = [L.air.slot]; colA = [L.air.collided];
edges = 0:win:nSlots;
colRate = nan(1, numel(edges) - 1); txPerMs = colRate;
for k = 1:numel(edges) - 1
    in = slotsA >= edges(k) & slotsA < edges(k + 1);
    if any(in), colRate(k) = mean(colA(in)); end
    txPerMs(k) = nnz(in) / (win * msPerSlot);
end
[fig, t] = newFig(1100, 560, 2, 1);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
lo = min(L.cbr, [], 1); hi = max(L.cbr, [], 1);
fill(ax, [tS fliplr(tS)], [lo fliplr(hi)], v.cat(1, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(ax, tS, mean(L.cbr, 1, 'omitnan'), '-', 'Color', v.cat(1, :));
plot(ax, tS, L.cbr(tgt, :), '-', 'Color', v.cat(2, :), 'LineWidth', 1.2);
ylabel(ax, 'CBR'); legend(ax, {'min-max over UEs', 'mean', sprintf('target UE %d', tgt)}, 'Location', 'northwest', 'Box', 'off');
title(ax, sprintf('Channel busy ratio (100 ms window, S-RSSI > %g dBm): mean %.3f, p95 %.3f', ...
    scen.pool.threshSRssiCbrDbm, S.cbrMean, S.cbrP95), 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
tc = edges(1:end - 1) * msPerSlot / 1000 + win * msPerSlot / 2000;
plot(ax, tc, colRate, '-', 'Color', v.cat(8, :));
ylabel(ax, 'collided share of PSSCH TX'); xlabel(ax, 'time (s)');
title(ax, sprintf(['Resource collisions (same slot, >= 1 shared sub-channel): %.1f%% of %d transmissions; ' ...
    '%.1f%% PSCCH-on-PSCCH'], 100 * S.collisionRate, S.nTx, 100 * S.sameStartRate), 'FontWeight', 'normal');
files{2} = saveFig(fig, outDir, 'cbr_collisions_time');

% ---- resource grid ----------------------------------------------------------------
w0 = max(0, nSlots - 400 - 1); w1 = w0 + 400;
[fig, ax] = newFig(1150, 430);
inW = find(slotsA >= w0 & slotsA < w1);
for k = inW
    a = L.air(k);
    c = v.cat(1 + mod(a.ue - 1, 8), :);
    rectangle(ax, 'Position', [(a.slot - w0) * msPerSlot, a.startSubch, msPerSlot, a.LsubCH], ...
        'FaceColor', [c 0.55], 'EdgeColor', 'none');
    if a.collided
        plot(ax, (a.slot - w0 + 0.5) * msPerSlot, a.startSubch + a.LsubCH / 2, 'v', 'Color', v.status.bad, ...
            'MarkerFaceColor', v.status.bad, 'MarkerSize', 5);
    end
end
xlim(ax, [0 400 * msPerSlot]); ylim(ax, [0 scen.numSubchannel]);
xlabel(ax, sprintf('time (ms) from t = %.2f s', w0 * msPerSlot / 1000)); ylabel(ax, 'sub-channel');
title(ax, 'Pool occupancy, last 200 ms: one colour per UE (cycled), red triangle = collided', 'FontWeight', 'normal');
files{3} = saveFig(fig, outDir, 'resource_grid');

% ---- what a collision costs ----------------------------------------------------------
[fig, t] = newFig(1100, 420, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
b = bar(ax, [S.prrClean S.prrCollided], 0.5, 'FaceColor', 'flat', 'EdgeColor', 'none');
b.CData = [v.cat(1, :); v.cat(8, :)];
set(ax, 'XTick', 1:2, 'XTickLabel', {'clean TX', 'collided TX'}); ylim(ax, [0 1]);
ylabel(ax, 'decode probability per (TX, listening RX)');
title(ax, 'Capture: collided transmissions still decode at near receivers', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
dEd = 0:50:750; dc = dEd(1:end - 1) + 25;
col = [L.air(L.rx.air).collided];
for q = 0:1
    pr = nan(1, numel(dc));
    for k = 1:numel(dc)
        m = L.rx.distM >= dEd(k) & L.rx.distM < dEd(k + 1) & col == q;
        if nnz(m) >= 20, pr(k) = mean(L.rx.ok(m)); end
    end
    plot(ax, dc, pr, '-o', 'Color', v.cat(1 + 7 * q, :), 'MarkerFaceColor', v.cat(1 + 7 * q, :), 'MarkerSize', 4);
end
legend(ax, {'clean', 'collided'}, 'Location', 'southwest', 'Box', 'off');
xlabel(ax, 'TX-RX distance (m)'); ylabel(ax, 'decode probability'); ylim(ax, [0 1.02]);
title(ax, 'Collisions cost the far receivers', 'FontWeight', 'normal');
files{4} = saveFig(fig, outDir, 'collisions');

% ---- target latency ------------------------------------------------------------------
[fig, t] = newFig(1150, 430, 1, nF);
verdict = [];
for fi = 1:nF
    fl = scen.flows(fi);
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    sets = {P.rxUe == tgt & P.lcid == fl.lcid, P.txUe == tgt & P.lcid == fl.lcid};
    lbl = {sprintf('received BY UE %d', tgt), sprintf('sent BY UE %d', tgt)};
    for q = 1:2
        m = sets{q};
        x = sort(P.latMs(m & ~isnan(P.latMs)));
        if nnz(m) > 0
            plot(ax, x, (1:numel(x)) / nnz(m), '-', 'Color', v.cat(q, :));
        end
        vd = pdbVerdict(P.onTime(m), fl.pqi, sprintf('target %s, PQI %d', lbl{q}, fl.pqi));
        verdict = [verdict vd]; %#ok<AGROW>
        lbl{q} = sprintf('%s: %d pairs, %.1f%% on time (%s)', lbl{q}, nnz(m), 100 * vd.achieved, vd.verdict);
    end
    xline(ax, fl.pdbMs, ':', 'PDB', 'Color', v.status.bad, 'LineWidth', 1.5);
    yline(ax, 1 - cfg.pqiLookup(cfg.pqiTable(), fl.pqi).PER, ':', '1 - PER', 'Color', v.muted);
    xlim(ax, [0 fl.pdbMs * 1.3]); ylim(ax, [0 1.02]);
    xlabel(ax, 'latency (ms)'); ylabel(ax, 'fraction of (packet, receiver) pairs');
    legend(ax, lbl, 'Location', 'southeast', 'Box', 'off');
    title(ax, flowLbl{fi}, 'FontWeight', 'normal');
end
title(t, sprintf('Latency at and from target UE %d (losses keep the CDF below 1)', tgt), 'FontWeight', 'normal');
files{5} = saveFig(fig, outDir, 'target_latency');

% ---- per-link PDB reliability vs distance, whole field ------------------------------
[fig, ax] = newFig(900, 420);
for fi = 1:nF
    pr = nan(1, numel(dc));
    for k = 1:numel(dc)
        m = P.lcid == scen.flows(fi).lcid & P.distM >= dEd(k) & P.distM < dEd(k + 1);
        if nnz(m) >= 20, pr(k) = mean(P.onTime(m)); end
    end
    plot(ax, dc, pr, '-o', 'Color', v.cat(fi, :), 'MarkerFaceColor', v.cat(fi, :), 'MarkerSize', 4);
    vd = pdbVerdict(P.onTime(P.lcid == scen.flows(fi).lcid), scen.flows(fi).pqi, ['all links, ' flowLbl{fi}]);
    vp = pdbVerdict(S.flow(fi).pktOnTime, scen.flows(fi).pqi, ['per packet, ' flowLbl{fi}]);
    verdict = [verdict vd vp]; %#ok<AGROW>
end
yline(ax, 0.9, ':', '1 - PER', 'Color', v.muted);
xlabel(ax, 'TX-RX distance (m)'); ylabel(ax, 'pairs delivered within PDB'); ylim(ax, [0 1.02]);
xline(ax, f.rangeM, '--', 'intended range', 'Color', v.muted);
legend(ax, flowLbl, 'Location', 'southwest', 'Box', 'off');
title(ax, 'Packet reception within PDB vs distance (half-duplex and collision losses included)', 'FontWeight', 'normal');
files{6} = saveFig(fig, outDir, 'prr_vs_distance');

out.files = files;
out.verdict = struct2table(rmfield(verdict, 'ci95'));
out.collisions = struct('rate', S.collisionRate, 'sameStart', S.sameStartRate, 'nTx', S.nTx, ...
    'prrClean', S.prrClean, 'prrCollided', S.prrCollided);
out.cbr = struct('mean', S.cbrMean, 'p95', S.cbrP95, 'crMean', S.crMean);
out.target = struct('ue', tgt, 'xy', drop.xy(tgt, :));
out.drop = drop; out.summary = rmfield(S, 'flow'); out.config = f;
out.counts = struct('nReeval', L.nReeval, 'nPreempt', L.nPreempt, 'nCongDrop', L.nCongDrop, 'nRlf', L.nRlf, ...
    'selPerUePerS', S.selPerUePerS, 'goodputKbps', S.goodputKbps, 'txPerDelivery', S.txPerDelivery);
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'field.mat'), 'out');
disp(out.verdict); disp(out.collisions); disp(out.cbr); disp(out.counts);
end
