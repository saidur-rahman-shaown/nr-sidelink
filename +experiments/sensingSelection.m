function out = sensingSelection(s, f)
%sensingSelection Experiment 1b: what a UE senses, what survives exclusion, and what it selects.
%Spec:   none itself. The sensing database is the one the SLS filled from DECODED SCI-1A
%        (phy.ts38214.sensingDbRecord fed by trivDecode/frivDecode); S_A is
%        phy.ts38214.candidateSet (TS 38.214 8.1.4 steps 1-7); the pick is
%        phy.rx.policy.resourcePickChained -- the same calls slotStep's macPhase makes.
%Inputs: s  optional, experiments.settings()
%        f  optional field overrides (experiments/private/fieldScenario), default 40 UEs in
%           500 m x 500 m, CAM + Poisson events, broadcast, MCS 7, P_rsvp_TX 100 ms
%Outputs: out  struct: .files, .snapshot (target UE, M_total, |S_A|, escalations, threshold),
%              .selStats (access-offset percentiles, L_subCH counts, reselections/UE/s),
%              .loadSweep (|S_A|/M_total and escalations vs UE count)
%Figures (plots/experiments/sensing_selection/):
%   sensing_window.png      decoded SCIs in the target UE's sensing window, coloured by RSRP
%   candidate_set.png       the selection window: excluded vs surviving resources, the pick
%   selection_stats.png     access offset distribution, L_subCH, selections over time
%   sa_vs_load.png          |S_A|/M_total and threshold escalations against UE density
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2, f = struct(); end
outDir = fullfile(s.plotRoot, 'sensing_selection');
v = viz();
quick = strcmp(s.scale, 'quick');
nSlots = 3000; if quick, nSlots = 1200; end
snapAt = nSlots - 200;

% ----------------------------------------------------------- the main run
[scen, ~, drop] = fieldScenario(f);
ctr = sum((drop.xy - mean(drop.xy)).^2, 2);
[~, tgt] = min(ctr);                               % the UE nearest the field centre
[kpi, L, ~, scen] = runLogged(scen, nSlots, struct('snapshotSlot', snapAt, 'snapshotUe', tgt));
snap = L.snapshot;
mu = scen.mu; msPerSlot = 1 / 2^mu;
db = snap.db; n = snap.nLog;
T0 = scen.pool.sensingWindowMs * 2^mu;

% ---- figure 1: the sensing window -------------------------------------------
[fig, ax] = newFig(1000, 420);
in = db.slot >= n - T0 & db.slot < n;
rs = db.rsrp(in); y0 = db.startSubch(in); Ls = db.lSubch(in); xs = db.slot(in);
cm = v.seq; colormap(ax, cm);
lo = floor(min([rs; -110])); hi = ceil(max([rs; -60]));
for k = 1:numel(rs)
    c = cm(max(1, min(256, round(1 + 255 * (rs(k) - lo) / (hi - lo)))), :);
    rectangle(ax, 'Position', [(xs(k) - n) * msPerSlot, y0(k), msPerSlot, Ls(k)], ...
        'FaceColor', c, 'EdgeColor', 'none');
end
um = db.unmonitoredSlot(db.unmonitoredSlot >= n - T0 & db.unmonitoredSlot < n);
for k = 1:numel(um)
    xline(ax, (um(k) - n) * msPerSlot, '-', 'Color', v.status.bad, 'LineWidth', 1.5);
end
clim(ax, [lo hi]); cb = colorbar(ax); cb.Label.String = 'SL-RSRP of decoded SCI (dBm)';
xlim(ax, [-T0 * msPerSlot 0]); ylim(ax, [0 scen.numSubchannel]);
xlabel(ax, 'time relative to the selection trigger n (ms)'); ylabel(ax, 'sub-channel');
title(ax, sprintf(['UE %d sensing window (T_0 = %g ms): %d SCIs decoded, %d own-TX slots ' ...
    'unmonitored (red)'], tgt, scen.pool.sensingWindowMs, numel(rs), numel(um)), 'FontWeight', 'normal');
files{1} = saveFig(fig, outDir, 'sensing_window');

% ---- figure 2: candidate set at the snapshot ---------------------------------
pdbMs = 100; prio = scen.prioByUe(tgt);
% Sized exactly as slotStep's macPhase sizes a grant: the load arriving in one reservation period.
pduBytes = scen.macOverheadFixedBytes;
for k = 1:scen.nFlow
    pduBytes = pduBytes + ceil(scen.policy.prsvpTxMs / scen.flows(k).periodMs) * ...
        (scen.macOverheadPerSduBytes + scen.flows(k).sizeBytes);
end
pduBytes = min(pduBytes, scen.maxTbsBytes);
remPhys = pdbMs * 2^mu - scen.decodeMarginSlots;
[lo2, hi2] = mac.creselCounterRange(scen.policy.prsvpTxMs);
cresel = mac.cresel(round((lo2 + hi2) / 2), true);
req = phy.rx.policy.selectionRequest(n, mu, remPhys, prio, cresel, scen.policy, pduBytes);
[candY, candX, survivor, Mtotal, nEsc, thrOff] = phy.ts38214.candidateSet(req, scen.numSubchannel, ...
    scen.pool.sensingWindowMs, mu, db, scen.pool.thresholdListDbm, scen.pool.txPercentage, ...
    scen.pool.allowedPeriodsMs, scen.pool.T2minRaw, scen.TmaxPrime, scen.policy.maxEscalations);
rsS = RandStream('mt19937ar', 'Seed', 5);
minGap = phy.rx.policy.minResourceGapSlots(n, scen.slPsfchPeriod, scen.minTimeGapPsfch, scen.policy.psfchProcSlots);
[pick, pickX] = phy.rx.policy.resourcePickChained(candY, candX, survivor, rand(rsS, 1, scen.maxNumPerReserve), ...
    scen.maxNumPerReserve, minGap);
[fig, ax] = newFig(1000, 420);
W = req.LsubCH;
for k = 1:numel(candY)
    c = v.cat(1, :); if ~survivor(k), c = [0.86 0.86 0.86]; end
    rectangle(ax, 'Position', [(candY(k) - n) * msPerSlot, candX(k) + 0.05, msPerSlot, 0.9], ...
        'FaceColor', c, 'EdgeColor', 'none');
end
for k = 1:numel(pick)
    rectangle(ax, 'Position', [(pick(k) - n) * msPerSlot, pickX(k), msPerSlot, W], ...
        'EdgeColor', v.cat(2, :), 'LineWidth', 2.5);
end
xlabel(ax, 'time after trigger n (ms): the selection window [n+T_1, n+T_2]');
ylabel(ax, 'start sub-channel x of a candidate R_{x,y}');
ylim(ax, [0 scen.numSubchannel]);
h = [patch(ax, NaN, NaN, v.cat(1, :)), patch(ax, NaN, NaN, [0.86 0.86 0.86]), ...
    plot(ax, NaN, NaN, '-', 'Color', v.cat(2, :), 'LineWidth', 2.5)];
legend(ax, h, {'in S_A', 'excluded (reserved, RSRP above threshold)', 'selected (anchor + chained)'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
title(ax, sprintf(['Candidate set, UE %d, L_{subCH} = %d, prio %d: M_{total} = %d, |S_A| = %d ' ...
    '(%.0f%%), %d escalations (+%d dB)'], tgt, W, prio, Mtotal, nnz(survivor), ...
    100 * nnz(survivor) / Mtotal, nEsc, thrOff), 'FontWeight', 'normal');
files{2} = saveFig(fig, outDir, 'candidate_set');

% ---- figure 3: selection statistics over the whole run -----------------------
sel = L.sel;
off = [sel.offsetSlots] * msPerSlot;
[fig, t] = newFig(1200, 420, 1, 3);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
histogram(ax, off, 0:2.5:100, 'FaceColor', v.cat(1, :), 'EdgeColor', 'w');
xline(ax, phy.ts38214.procTimeSelection(mu) * msPerSlot, '--', 'T_1', 'Color', v.muted);
xlabel(ax, 'first resource - selection slot (ms)'); ylabel(ax, 'selections');
title(ax, sprintf('Access offset: median %.1f ms, p95 %.1f ms', median(off), prctile(off, 95)), 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
Lc = histcounts([sel.LsubCH], 0.5:1:scen.numSubchannel + 0.5);
bar(ax, 1:scen.numSubchannel, Lc, 0.6, 'FaceColor', v.cat(3, :), 'EdgeColor', 'none');
xlabel(ax, 'L_{subCH} selected'); ylabel(ax, 'selections');
title(ax, 'Allocation width', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, [sel.slot] * msPerSlot / 1000, [sel.ue], '.', 'Color', v.cat(1, :), 'MarkerSize', 8);
xlabel(ax, 'time (s)'); ylabel(ax, 'UE'); ylim(ax, [0 scen.nUe + 1]);
title(ax, sprintf('(Re)selections: %.1f per UE per s', numel(sel) / scen.nUe / (nSlots * msPerSlot / 1000)), ...
    'FontWeight', 'normal');
files{3} = saveFig(fig, outDir, 'selection_stats');

% ---- figure 4: |S_A| / M_total versus load -----------------------------------
nList = [10 20 40 80 120]; if quick, nList = [10 40]; end
sa = cell(1, numel(nList)); esc = cell(1, numel(nList)); cbr = zeros(1, numel(nList));
for q = 1:numel(nList)
    fq = f; fq.nUe = nList(q);
    sq = fieldScenario(fq);
    nRun = 1200; if quick, nRun = 600; end
    [~, Lq, ueq, sq] = runLogged(sq, nRun);
    nq = harness.sls.slotToLogical(sq, nRun - 1);
    reqq = phy.rx.policy.selectionRequest(nq, mu, remPhys, prio, cresel, sq.policy, pduBytes);
    for i = 1:sq.nUe
        [~, ~, sv, Mt, ne] = phy.ts38214.candidateSet(reqq, sq.numSubchannel, sq.pool.sensingWindowMs, ...
            mu, ueq(i).db, sq.pool.thresholdListDbm, sq.pool.txPercentage, sq.pool.allowedPeriodsMs, ...
            sq.pool.T2minRaw, sq.TmaxPrime, sq.policy.maxEscalations);
        sa{q}(i) = nnz(sv) / Mt;   %#ok<AGROW>
        esc{q}(i) = ne;            %#ok<AGROW>
    end
    cbr(q) = mean(Lq.cbr(:, end), 'omitnan');
end
[fig, t] = newFig(1000, 400, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
grp = repelem(1:numel(nList), cellfun(@numel, sa));
boxchart(ax, grp, [sa{:}], 'BoxFaceColor', v.cat(1, :), 'MarkerColor', v.cat(1, :));
yline(ax, scen.pool.txPercentage, '--', 'sl-TxPercentage floor', 'Color', v.muted);
set(ax, 'XTick', 1:numel(nList), 'XTickLabel', compose('%d UE\nCBR %.2f', nList(:), cbr(:)));
ylabel(ax, '|S_A| / M_{total}'); title(ax, 'Share of the window that survives exclusion', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
boxchart(ax, grp, [esc{:}], 'BoxFaceColor', v.cat(2, :), 'MarkerColor', v.cat(2, :));
set(ax, 'XTick', 1:numel(nList), 'XTickLabel', compose('%d UE', nList(:)));
ylabel(ax, '3 dB escalation rounds'); title(ax, 'Threshold escalations needed to reach X%', 'FontWeight', 'normal');
files{4} = saveFig(fig, outDir, 'sa_vs_load');

out.files = files;
out.snapshot = struct('ue', tgt, 'nLog', n, 'nSci', numel(rs), 'nUnmonitored', numel(um), ...
    'Mtotal', Mtotal, 'nSA', nnz(survivor), 'nEscalations', nEsc, 'thresholdOffsetDb', thrOff, ...
    'LsubCH', W, 'T1', req.T1, 'T2', req.T2, 'pickSlots', pick - n, 'pickSubch', pickX);
out.selStats = struct('nSel', numel(sel), 'offsetP50Ms', median(off), 'offsetP95Ms', prctile(off, 95), ...
    'LsubCHCounts', Lc, 'perUePerS', numel(sel) / scen.nUe / (nSlots * msPerSlot / 1000));
out.loadSweep = struct('nUe', nList, 'saMedian', cellfun(@median, sa), 'escMedian', cellfun(@median, esc), 'cbr', cbr);
out.kpi = rmfield(kpi, {'latencyMs', 'byFlow'});
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'sensingSelection.mat'), 'out');
disp(out.snapshot); disp(out.selStats); disp(out.loadSweep);
end
