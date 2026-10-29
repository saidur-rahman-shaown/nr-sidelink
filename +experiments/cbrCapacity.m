function out = cbrCapacity(s, f)
%cbrCapacity Experiment 6: channel busy ratio against the capacity a UE still has to transmit.
%Spec:   TS 38.215 5.1.25 (CBR) and 5.1.26 (CR) as measured in harness.sls by phy.ts38215.cbr/.cr;
%        TS 38.214 8.1.6 (CR limit at the CBR range) with the pool's SL-CBR-LevelsConfig and
%        sl-CR-Limit (scen.pool.cbrRangeUpperBounds / crLimitByLevel).
%Inputs: s  optional, experiments.settings();  f  optional, experiments.fieldConfig()
%Outputs: out  struct: .files, .table (per load point: CBR, CR, remaining capacity, reliability,
%              collisions, congestion drops), .poolKbps, .crLimit
%TWO "REMAINING CAPACITIES", BOTH SHOWN
%  regulatory   what clause 8.1.6 still LETS this UE send: (CR_limit(CBR) - CR_own) of the pool's
%               sub-channel-slots, converted at the MCS's bytes per sub-channel. This is the
%               curve the question asks for -- a staircase in CBR, because the limit is a table.
%  physical     what is still IDLE: (1 - CBR) of the pool. Not a permission, but the ceiling any
%               additional transmission competes for.
%Load is swept by UE count and generation period together, so the measured CBR spans the
%range rather than clustering at one value.
%Figures (plots/experiments/cbr_capacity/):
%   cbr_vs_remaining_capacity.png   theory staircase, measured points, binned median
%   reliability_vs_cbr.png          on-time ratio, collision rate and latency against CBR
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(f), f = experiments.fieldConfig(); end
outDir = fullfile(s.plotRoot, 'cbr_capacity');
v = viz();
quick = strcmp(s.scale, 'quick');
nSlots = 5000; if quick, nSlots = 2600; end   % > the 1000 ms CR window, which must fill first
nList = [20 40 80]; pList = [100 50 20];
if quick, nList = [20 60]; pList = [100 20]; end

base = rmfield(f, {'durationS', 'rangeM'});
base.densityPerKm2 = [];
base.flows = struct('pqi', 58, 'periodMs', 100, 'sizeBytes', 300, 'lcid', 4, 'nPackets', inf, ...
    'pdbMsOverride', [], 'arrival', 'periodic');
cf = {}; lbl = {};
for n = nList
    for p = pList
        c = base; c.nUe = n; c.flows.periodMs = p; c.prsvpTxMs = p;
        cf{end + 1} = c; lbl{end + 1} = sprintf('%d UE, %d ms', n, p); %#ok<AGROW>
    end
end
% The per-UE (CBR, CR) samples are needed, not just summaries, so this sweep keeps them.
jobs = cf; seeds = s.seeds; nJ = numel(jobs) * numel(seeds);
res = cell(1, nJ);
if s.useParallel && isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end
if s.useParallel
    parfor j = 1:nJ
        res{j} = runCbr(jobs{ceil(j / numel(seeds))}, seeds(mod(j - 1, numel(seeds)) + 1), nSlots, f.rangeM);
    end
else
    for j = 1:nJ
        res{j} = runCbr(jobs{ceil(j / numel(seeds))}, seeds(mod(j - 1, numel(seeds)) + 1), nSlots, f.rangeM);
    end
end

sc = fieldScenario(base);
bounds = sc.pool.cbrRangeUpperBounds; lim = sc.pool.crLimitByLevel;
bytesPerSubch = sc.tbsBytesByLsubCH(end) / sc.numSubchannel;
poolKbps = sc.numSubchannel * 1000 * 2^sc.mu * bytesPerSubch * 8 / 1000;

% ---- figure 1 ---------------------------------------------------------------------
[fig, ax] = newFig(1000, 500);
cbrAll = []; crAll = [];
for j = 1:nJ
    cbrAll = [cbrAll res{j}.cbr(:)']; crAll = [crAll res{j}.cr(:)']; %#ok<AGROW>
end
ok = ~isnan(cbrAll) & ~isnan(crAll);
cbrAll = cbrAll(ok); crAll = crAll(ok);
level = arrayfun(@(x) phy.ts38214.cbrRangeIndex(x, bounds), cbrAll);
remAll = max(0, lim(level) - crAll) * poolKbps;
pick = 1:max(1, floor(numel(cbrAll) / 4000)):numel(cbrAll);
scatter(ax, cbrAll(pick), remAll(pick) / 1000, 8, v.cat(1, :), 'filled', 'MarkerFaceAlpha', 0.15);
x = linspace(0, 1, 1001);
lvl = arrayfun(@(q) phy.ts38214.cbrRangeIndex(q, bounds), x);
plot(ax, x, lim(lvl) * poolKbps / 1000, '-', 'Color', v.ink, 'LineWidth', 2);
plot(ax, x, (1 - x) * poolKbps / 1000, '--', 'Color', v.cat(3, :));
eb = 0:0.02:1; med = nan(1, numel(eb) - 1);
for k = 1:numel(eb) - 1
    m = cbrAll >= eb(k) & cbrAll < eb(k + 1);
    if nnz(m) >= 30, med(k) = median(remAll(m)); end
end
plot(ax, eb(1:end - 1) + 0.01, med / 1000, 'o', 'Color', v.cat(2, :), 'MarkerFaceColor', v.cat(2, :), 'MarkerSize', 6);
for b = bounds(1:end - 1), xline(ax, b, ':', 'Color', v.muted); end
xlabel(ax, 'CBR measured by the UE'); ylabel(ax, 'remaining capacity for this UE (Mbit/s)');
legend(ax, {'measured (UE, 10 ms sample)', 'CR limit x pool, own CR = 0 (sl-CR-Limit staircase)', ...
    'idle share of the pool, (1 - CBR) x pool', 'measured, binned median'}, 'Location', 'northeast', 'Box', 'off');
title(ax, sprintf(['Remaining capacity vs CBR: pool %.1f Mbit/s at MCS %d; CR limits %s at CBR bounds %s'], ...
    poolKbps / 1000, base.mcs, mat2str(lim), mat2str(bounds)), 'FontWeight', 'normal');
xlim(ax, [0 1]);
files{1} = saveFig(fig, outDir, 'cbr_vs_remaining_capacity');

% ---- figure 2 ---------------------------------------------------------------------
rows = {};
for c = 1:numel(cf)
    rr = res((c - 1) * numel(seeds) + (1:numel(seeds)));
    cb = mean(cellfun(@(r) mean(r.cbr(:), 'omitnan'), rr));
    crm = mean(cellfun(@(r) mean(r.cr(:), 'omitnan'), rr));
    on = mean(cell2mat(cellfun(@(r) r.onTime, rr, 'UniformOutput', false)));
    lat = cell2mat(cellfun(@(r) r.lat, rr, 'UniformOutput', false));
    rem = max(0, lim(phy.ts38214.cbrRangeIndex(cb, bounds)) - crm) * poolKbps;
    rows(end + 1, :) = {lbl{c}, cf{c}.nUe, cf{c}.flows.periodMs, cb, crm, rem / 1000, (1 - cb) * poolKbps / 1000, ...
        on, prctile(lat, 95), mean(cellfun(@(r) r.collisionRate, rr)), sum(cellfun(@(r) r.nCongDrop, rr)), ...
        cf{c}.nUe * 300 * 8 / cf{c}.flows.periodMs}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'load', 'nUe', 'periodMs', 'cbr', 'crOwn', 'remainingRegMbps', ...
    'remainingIdleMbps', 'onTime', 'p95LatMs', 'collisionRate', 'congestionDrops', 'offeredKbps'});
T = sortrows(T, 'cbr');
[fig, t] = newFig(1200, 420, 1, 3);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, T.cbr, T.onTime, '-o', 'Color', v.cat(1, :), 'MarkerFaceColor', v.cat(1, :));
yline(ax, 0.9, ':', '1 - PER', 'Color', v.muted); xlabel(ax, 'mean CBR'); ylabel(ax, 'pairs within PDB (300 m)');
title(ax, 'Reliability', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, T.cbr, T.collisionRate, '-o', 'Color', v.cat(8, :), 'MarkerFaceColor', v.cat(8, :));
xlabel(ax, 'mean CBR'); ylabel(ax, 'collided share of TX'); title(ax, 'Collisions', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, T.cbr, T.p95LatMs, '-o', 'Color', v.cat(2, :), 'MarkerFaceColor', v.cat(2, :));
yline(ax, 100, ':', 'PDB', 'Color', v.status.bad);
xlabel(ax, 'mean CBR'); ylabel(ax, 'p95 per-link latency (ms)'); title(ax, 'Latency tail', 'FontWeight', 'normal');
title(t, 'Operating envelope against channel load (CAM PQI 58, 300 B, P_{rsvp} = period)', 'FontWeight', 'normal');
files{2} = saveFig(fig, outDir, 'reliability_vs_cbr');

out.files = files; out.table = T; out.poolKbps = poolKbps; out.crLimit = struct('bounds', bounds, 'limit', lim);
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'cbrCapacity.mat'), 'out');
disp(T);
end

function r = runCbr(c, seed, nSlots, rangeM)
c.seed = seed; c.dropSeed = seed + 1000;
scen = fieldScenario(c);
[kpi, L, ~, scen, res] = runLogged(scen, nSlots);
% Both windows must be full before a sample means anything: CBR's 100 ms and CR's past half of
% 1000 ms. Earlier samples divide by a window that is partly before the run began.
warm = L.t >= max(scen.cbrWindowSlots, scen.crPastSlots);
r.cbr = L.cbr(:, warm); r.cr = L.cr(:, warm);
S = summarizeRun(kpi, L, res, scen, rangeM);
r.onTime = S.flow(1).linkOnTime; r.lat = S.flow(1).linkLatMs;
r.collisionRate = S.collisionRate; r.nCongDrop = L.nCongDrop;
end
