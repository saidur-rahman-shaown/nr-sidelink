function [file, drops] = deployment(s, dens, rangeM, base)
%deployment Study Part C, figure C1: how the UEs are distributed, and one sample drop.
%Spec:   none. The drop is experiments' private fieldScenario: a homogeneous Poisson point process
%        (PPP) of intensity lambda per km^2 -- N ~ Poisson(lambda x area), then N positions
%        independently uniform over the field. Each seed is an independent drop (dropSeed =
%        seed + 1000, as private/sweep sets it).
%Inputs: all optional -- s (experiments.settings()), dens (UE/km^2), rangeM (intended-receiver
%        range), base (the systemLevel scenario override struct; only .sizeM and the drop matter)
%Outputs: file   the saved figure; drops  table: N per seed and mean neighbours within rangeM
%The neighbour count is compared with 2000 simulated drops of the same field rather than with
%Poisson(lambda*pi*r^2): with a 500 m range in a 1 km field most UEs are near an edge, so the
%edge-free Poisson count overstates the neighbours of a typical UE by more than half.
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(dens), dens = [5 10 15 20 30 40 50 75 100]; end
if nargin < 3 || isempty(rangeM), rangeM = 500; end
if nargin < 4 || isempty(base), base = struct('sizeM', [1000 1000]); end
v = viz();
outDir = fullfile('plots', 'study', 'C_system');
SAMPLE = 30;                                            % the density shown as the sample drop
kS = find(dens == SAMPLE, 1); if isempty(kS), kS = ceil(numel(dens) / 2); end
nByDrop = zeros(numel(dens), numel(s.seeds)); nbr = cell(1, numel(dens));
for k = 1:numel(dens)
    for q = 1:numel(s.seeds)
        dq = dropOf(base, dens(k), s.seeds(q));
        nByDrop(k, q) = dq.N;
        D = hypot(dq.xy(:, 1) - dq.xy(:, 1)', dq.xy(:, 2) - dq.xy(:, 2)');
        nbr{k} = [nbr{k}; sum(D <= rangeM, 2) - 1]; %#ok<AGROW>
    end
end
% Reference: the same PPP in the same field, 2000 drops, edges included.
rs = RandStream('mt19937ar', 'Seed', 1);
ref = [];
lam = dens(kS) * prod(base.sizeM) / 1e6;
for t = 1:2000
    N = poissrnd(lam);
    if N < 2, continue; end
    xy = [rand(rs, N, 1) * base.sizeM(1), rand(rs, N, 1) * base.sizeM(2)];
    D = hypot(xy(:, 1) - xy(:, 1)', xy(:, 2) - xy(:, 2)');
    ref = [ref; sum(D <= rangeM, 2) - 1]; %#ok<AGROW>
end
[f, t] = newFig(1250, 470, 1, 2);
ax = nexttile(t); hold(ax, 'on');
dS = dropOf(base, dens(kS), s.seeds(1));
[~, ctr] = min(hypot(dS.xy(:, 1) - base.sizeM(1) / 2, dS.xy(:, 2) - base.sizeM(2) / 2));
inR = hypot(dS.xy(:, 1) - dS.xy(ctr, 1), dS.xy(:, 2) - dS.xy(ctr, 2)) <= rangeM;
th = linspace(0, 2 * pi, 200);
fill(ax, dS.xy(ctr, 1) + rangeM * cos(th), dS.xy(ctr, 2) + rangeM * sin(th), v.cat(1, :), 'FaceAlpha', 0.08, 'EdgeColor', v.cat(1, :));
plot(ax, dS.xy(~inR, 1), dS.xy(~inR, 2), 'o', 'Color', v.muted, 'MarkerSize', 5);
plot(ax, dS.xy(inR, 1), dS.xy(inR, 2), 'o', 'Color', v.cat(1, :), 'MarkerFaceColor', v.cat(1, :), 'MarkerSize', 5);
plot(ax, dS.xy(ctr, 1), dS.xy(ctr, 2), 'p', 'Color', v.status.bad, 'MarkerFaceColor', v.status.bad, 'MarkerSize', 14);
axis(ax, 'equal'); xlim(ax, [0 base.sizeM(1)]); ylim(ax, [0 base.sizeM(2)]); box(ax, 'on');
xlabel(ax, 'x (m)'); ylabel(ax, 'y (m)');
title(ax, {sprintf('Sample drop: %d UE/km^2, N = %d (seed %d)', dens(kS), dS.N, s.seeds(1)), ...
    sprintf('star: one transmitter; filled: its %d intended receivers within %d m', nnz(inR) - 1, rangeM)}, 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
x = nbr{kS};
edges = -0.5:1:max([x; ref]) + 0.5;
histogram(ax, x, edges, 'Normalization', 'probability', 'FaceColor', v.cat(1, :), 'EdgeColor', 'w');
hr = histcounts(ref, edges, 'Normalization', 'probability');
plot(ax, edges(1:end - 1) + 0.5, hr, '-', 'Color', v.status.bad, 'LineWidth', 2);
xline(ax, dens(kS) * pi * (rangeM / 1000)^2, ':', sprintf('no edges: \\lambda\\pi r^2 = %.1f', dens(kS) * pi * (rangeM / 1000)^2), ...
    'Color', v.muted, 'LabelVerticalAlignment', 'top');
xlabel(ax, sprintf('neighbours within %d m', rangeM)); ylabel(ax, 'share of UEs');
legend(ax, {sprintf('the %d study drops (mean %.1f)', numel(s.seeds), mean(x)), ...
    sprintf('PPP in this field, 2000 drops (mean %.1f)', mean(ref))}, 'Location', 'northwest', 'Box', 'off');
title(ax, {sprintf('Neighbours per UE at %d UE/km^2', dens(kS)), 'a UE near the field edge has fewer'}, 'FontWeight', 'normal');
title(t, 'UE positions: a Poisson point process in 1 km x 1 km, a new independent drop per seed', 'FontWeight', 'normal');
file = saveFig(f, outDir, 'C1_deployment');
drops = array2table([dens(:) dens(:) * prod(base.sizeM) / 1e6 nByDrop cellfun(@mean, nbr)'], 'VariableNames', ...
    [{'densityPerKm2', 'expectedN'}, compose('N_seed%d', s.seeds), {'meanNeighbours'}]);
end

function d = dropOf(base, dens, seed)
fc = base; fc.densityPerKm2 = dens; fc.seed = seed; fc.dropSeed = seed + 1000;
if ~isfield(fc, 'mcs'), fc.mcs = 11; end
[~, ~, d] = fieldScenario(fc);
end
