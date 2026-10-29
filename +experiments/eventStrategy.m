function out = eventStrategy(s, f)
%eventStrategy Experiment 4b: the best way to send event-driven (Poisson) data alongside CAMs.
%Spec:   none -- a policy comparison over harness.sls. Every strategy is a UE-implementation
%        choice the specs leave open (TS 38.214 8.1.4's T2, the number of reserved resources,
%        P_rsvp_TX, MCS) or a pool switch (sl-PreemptionEnable, sl-SelectionWindow); nothing
%        normative changes between rows.
%Inputs: s  optional, experiments.settings();  f  optional, experiments.fieldConfig()
%Outputs: out  struct: .files, .table (one row per strategy and density), .best (per density),
%              .rate (event-rate sensitivity table)
%RANKING: event pairs delivered within the 20 ms PDB, among strategies that keep the CAM flow at
%or above its own 1 - PER. A strategy that buys event reliability by breaking CAM is not a win.
%Figures (plots/experiments/event_strategy/):
%   strategies.png        event and CAM on-time ratio per strategy, two densities, best marked
%   strategy_costs.png    collision rate, CBR and transmissions per delivery per strategy
%   event_rate.png        baseline vs best strategy as the event rate rises
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(f), f = experiments.fieldConfig(); end
outDir = fullfile(s.plotRoot, 'event_strategy');
v = viz();
quick = strcmp(s.scale, 'quick');
nSlots = 5000; if quick, nSlots = 1600; end
base = rmfield(f, {'durationS', 'rangeM'});
rangeM = f.rangeM;

S = { ...
    'baseline (P_{rsvp} 100, T2 = PDB, 1 retx)', struct(); ...
    'no blind retx',                  struct('numRetx', 0); ...
    '2 blind retx (n3)',              struct('numRetx', 2); ...
    'P_{rsvp} 50 ms',                 struct('prsvpTxMs', 50); ...
    'P_{rsvp} 20 ms',                 struct('prsvpTxMs', 20); ...
    'T2 cap = P_{rsvp} (100 ms)',     struct('policy', struct('t2MaxMs', 100)); ...
    'T2min 5 ms + T2 cap 10 ms',      struct('policy', struct('t2MaxMs', 10), 'pool', struct('selectionWindowRaw', 5)); ...
    'pre-emption disabled',           struct('pool', struct('preemptionEnable', '')); ...
    'MCS 11 (narrower TB)',           struct('mcs', 11); ...
    'grant sized for CAM only',       struct('policy', struct('sizeEventFlows', false)); ...
    'CAM-only grant + T2 cap 10 ms',  struct('policy', struct('sizeEventFlows', false, 't2MaxMs', 10), ...
                                          'pool', struct('selectionWindowRaw', 5))};
if quick, S = S([1 2 5 7], :); end
% Nominal and twice nominal. Slot cost grows ~N^2 in the SLS, so 3x (120 UEs) x 9 strategies x 3
% seeds was ~2 h on 6 workers; 2x keeps the question (does the ranking hold under load?) at a third.
dens = [f.densityPerKm2, 2 * f.densityPerKm2]; if quick, dens = f.densityPerKm2; end

rows = {};
R = cell(numel(dens), 1);
for di = 1:numel(dens)
    cf = cell(1, size(S, 1));
    for k = 1:size(S, 1)
        c = base; c.densityPerKm2 = dens(di);
        ov = S{k, 2}; fn = fieldnames(ov);
        for q = 1:numel(fn), c.(fn{q}) = ov.(fn{q}); end
        cf{k} = c;
    end
    R{di} = sweep(cf, nSlots, s, rangeM);
    for k = 1:size(S, 1)
        Rk = R{di}(k, :);
        ev = pdbVerdict(pooled(Rk, 2, 'linkOnTime'), base.flows(2).pqi, '');
        ca = pdbVerdict(pooled(Rk, 1, 'linkOnTime'), base.flows(1).pqi, '');
        lat = pooled(Rk, 2, 'linkLatMs');
        rows(end + 1, :) = {dens(di), round(mean(cellfun(@(r) r.nUe, Rk))), S{k, 1}, ev.achieved, ...
            ev.verdict, prctile(lat, 95), ca.achieved, ca.verdict, prctile(pooled(Rk, 1, 'linkLatMs'), 95), ...
            mean(cellfun(@(r) r.collisionRate, Rk)), mean(cellfun(@(r) r.cbrMean, Rk)), ...
            mean(cellfun(@(r) r.txPerDelivery, Rk)), mean(cellfun(@(r) r.selPerUePerS, Rk))}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'densityPerKm2', 'nUe', 'strategy', 'eventOnTime', 'eventVerdict', ...
    'eventP95Ms', 'camOnTime', 'camVerdict', 'camP95Ms', 'collisionRate', 'cbr', 'txPerDelivery', 'selPerUePerS'});

best = cell(1, numel(dens));
for di = 1:numel(dens)
    m = T.densityPerKm2 == dens(di) & T.camOnTime >= 0.9;
    if ~any(m), m = T.densityPerKm2 == dens(di); end
    sub = T(m, :);
    [~, i] = max(sub.eventOnTime - 1e-3 * sub.collisionRate);
    best{di} = sub.strategy{i};
end

% ---- figure: strategies -----------------------------------------------------------
nS = size(S, 1);
[fig, t] = newFig(1300, 120 + 48 * nS, 1, numel(dens));
for di = 1:numel(dens)
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    sub = T(T.densityPerKm2 == dens(di), :);
    b = barh(ax, [sub.eventOnTime sub.camOnTime], 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
    b(1).FaceColor = v.cat(2, :); b(2).FaceColor = v.cat(1, :);
    xline(ax, 0.9, ':', '1 - PER', 'Color', v.muted, 'LabelVerticalAlignment', 'bottom');
    lbls = sub.strategy;
    ib = find(strcmp(lbls, best{di}));
    lbls{ib} = ['\bf' lbls{ib} ' (best)'];
    set(ax, 'YTick', 1:nS, 'YTickLabel', lbls, 'YDir', 'reverse');
    xlim(ax, [max(0, min([sub.eventOnTime; sub.camOnTime]) - 0.05) 1]);
    xlabel(ax, 'pairs delivered within PDB (receivers within 300 m)');
    title(ax, sprintf('%g UE/km^2 (~%d UEs)', dens(di), sub.nUe(1)), 'FontWeight', 'normal');
    if di == numel(dens)
        legend(ax, {'event (PQI 56, Poisson, 20 ms)', 'CAM (PQI 58, 100 ms)'}, 'Location', 'southoutside', 'Box', 'off');
    end
end
title(t, 'Strategy for event-driven data: reliability within PDB', 'FontWeight', 'normal');
files{1} = saveFig(fig, outDir, 'strategies');

% ---- figure: costs ----------------------------------------------------------------
[fig, t] = newFig(1300, 120 + 48 * nS, 1, 3);
metrics = {'collisionRate', 'collided share of TX'; 'cbr', 'mean CBR'; 'txPerDelivery', 'TX per delivered packet'};
for k = 1:3
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    M = zeros(nS, numel(dens));
    for di = 1:numel(dens)
        M(:, di) = T.(metrics{k, 1})(T.densityPerKm2 == dens(di));
    end
    b = barh(ax, M, 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
    for di = 1:numel(dens), b(di).FaceColor = v.cat(di + 2, :); end
    set(ax, 'YTick', 1:nS, 'YDir', 'reverse');
    if k == 1, set(ax, 'YTickLabel', S(:, 1)); else, set(ax, 'YTickLabel', {}); end
    xlabel(ax, metrics{k, 2});
end
legend(ax, compose('%g UE/km^2', dens(:)), 'Location', 'southoutside', 'Box', 'off');
title(t, 'What each strategy costs the channel', 'FontWeight', 'normal');
files{2} = saveFig(fig, outDir, 'strategy_costs');

% ---- event-rate sensitivity: baseline vs the best (nominal density) ---------------
rates = [100 250 500 2000]; if quick, rates = [100 500]; end
bestOv = S{strcmp(S(:, 1), best{1}), 2};
cf = {};
for k = 1:2
    for r = rates
        c = base; c.flows(2).periodMs = r;
        if k == 2
            fn = fieldnames(bestOv);
            for q = 1:numel(fn), c.(fn{q}) = bestOv.(fn{q}); end
        end
        cf{end + 1} = c; %#ok<AGROW>
    end
end
Rr = sweep(cf, nSlots, s, rangeM);
[fig, ax] = newFig(900, 420);
rr = {};
for k = 1:2
    on = zeros(1, numel(rates)); ca = on;
    for q = 1:numel(rates)
        j = (k - 1) * numel(rates) + q;
        on(q) = mean(pooled(Rr(j, :), 2, 'linkOnTime'));
        ca(q) = mean(pooled(Rr(j, :), 1, 'linkOnTime'));
        rr(end + 1, :) = {ifelse(k == 1, 'baseline', best{1}), rates(q), on(q), ca(q), ...
            mean(cellfun(@(r) r.cbrMean, Rr(j, :)))}; %#ok<AGROW>
    end
    plot(ax, rates, on, '-o', 'Color', v.cat(2 * k - 1, :), 'MarkerFaceColor', v.cat(2 * k - 1, :));
    plot(ax, rates, ca, '--s', 'Color', v.cat(2 * k - 1, :));
end
set(ax, 'XScale', 'log', 'XTick', rates);
yline(ax, 0.9, ':', '1 - PER', 'Color', v.muted);
xlabel(ax, 'mean event inter-arrival per UE (ms, Poisson)'); ylabel(ax, 'pairs within PDB');
legend(ax, {'baseline: event', 'baseline: CAM', ['best: event'], ['best: CAM']}, 'Location', 'southeast', 'Box', 'off');
title(ax, sprintf('Event-rate sensitivity (best at nominal density: %s)', strrep(best{1}, '_', '\_')), 'FontWeight', 'normal');
files{3} = saveFig(fig, outDir, 'event_rate');

out.files = files; out.table = T; out.best = best;
out.rate = cell2table(rr, 'VariableNames', {'strategy', 'eventMeanMs', 'eventOnTime', 'camOnTime', 'cbr'});
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'eventStrategy.mat'), 'out');
disp(T); disp(out.rate);
fprintf('BEST: %s\n', strjoin(best, ' | '));
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
