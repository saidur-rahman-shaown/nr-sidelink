function out = waveDeploy(s, variants)
%waveDeploy Experiment 7: the multi-UE deployment at waveform level, under real hardware, and what
%the system-level abstraction gets right and wrong about interference.
%Spec:   none -- runs harness.deploy (continuous time, summed IQ, Communications Toolbox hardware
%        models, per-link TDL fading, propagation delay and timing/frequency errors), on the same
%        drop and traffic, in up to three variants, and calibrates the SLS's SINR formula against
%        the waveform decoder (harness.deploy.abstractionCheck).
%Inputs: s         optional, experiments.settings()
%        variants  optional cellstr from {'real', 'ideal', 'noReorder'} (default all three):
%                    real       rf.hwDefaults: PA compression, IQ imbalance, phase noise, +/-0.1 ppm,
%                               +/-0.25 us timing, 10-bit ADC with AGC
%                    ideal      rf.hwIdeal: every impairment off (thermal noise kept)
%                    noReorder  real hardware, receivers without the PDCP t-Reordering hold
%Outputs: out  struct per variant: .flow, .perUe (tables), .collisions, .abstraction
%Figures: plots/experiments/wave_deploy/<variant>/ (harness.deploy.plots) and, at the top level,
%   variant_comparison.png      on-time share per flow and loss causes, per variant
%   abstraction_check.png       observed vs SLS-predicted TB decode against SINR, clean vs collided
%A 2 s, ~31-UE run takes ~30-40 min on 6 workers; each variant is one run.
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(variants), variants = {'real', 'ideal', 'noReorder'}; end
outRoot = fullfile(s.plotRoot, 'wave_deploy');
v = viz();
base = deployConfig();
if strcmp(s.scale, 'quick')
    base.ue.densityPerKm2 = []; base.ue.n = 8; base.sim.durationMs = 200;
end
base.sim.nWorkers = s.nWorkers;
for q = 1:numel(variants)
    c = base;
    switch variants{q}
        case 'real'
        case 'ideal',     c.hw = rf.hwIdeal();
        case 'noReorder', c.impl.tReorderingMs = 0;
        otherwise, error('experiments:waveDeploy:variant', 'unknown variant %s', variants{q});
    end
    c.sim.outDir = fullfile(outRoot, variants{q});
    matFile = fullfile(c.sim.outDir, 'deploy.mat');
    if isfile(matFile) && ~strcmp(s.scale, 'quick')
        x = load(matFile); rs = x.rs; S = x.S;
        fprintf('waveDeploy: using saved %s\n', matFile);
    else
        [r, S] = runDeploy(c);
        rs = rmfield(r, 'ues');
    end
    A = harness.deploy.abstractionCheck(rs);
    out.(variants{q}) = struct('flow', S.flow, 'perUe', S.perUe, 'collisions', S.collisions, ...
        'abstraction', A, 'N', rs.drop.N, 'durationMs', c.sim.durationMs);
end

% ---- variant comparison --------------------------------------------------------------------
names = fieldnames(out);
[f, t] = newFig(1150, 430, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
M = zeros(numel(names), 2);
for q = 1:numel(names), M(q, :) = out.(names{q}).flow.onTimeShare'; end
b = bar(ax, M, 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
b(1).FaceColor = v.cat(1, :); b(2).FaceColor = v.cat(2, :);
yline(ax, 0.9, ':', '1 - PER', 'Color', v.muted);
set(ax, 'XTick', 1:numel(names), 'XTickLabel', names);
ylabel(ax, 'pairs within PDB'); legend(ax, {'CAM', 'event'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
ylim(ax, [max(0, min(M(:)) - 0.1) 1.01]);
title(ax, 'Reliability within PDB, per variant', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
L = zeros(numel(names), 5);
for q = 1:numel(names)
    F = out.(names{q}).flow;
    L(q, :) = [sum(F.late) sum(F.lostNotSent) sum(F.lostHalfDuplex) sum(F.lostCollision) sum(F.lostRadio)];
end
b = bar(ax, L, 0.8, 'stacked', 'EdgeColor', 'w');
cc = v.cat([5 4 7 8 1], :);
for q = 1:5, b(q).FaceColor = cc(q, :); end
set(ax, 'XTick', 1:numel(names), 'XTickLabel', names);
ylabel(ax, 'pairs not on time');
legend(ax, {'late (delivered after PDB)', 'not sent', 'half duplex', 'collision', 'radio + hardware'}, ...
    'Location', 'southoutside', 'NumColumns', 3, 'Box', 'off');
title(ax, 'Why packets missed the PDB', 'FontWeight', 'normal');
files{1} = saveFig(f, outRoot, 'variant_comparison');

% ---- abstraction check -----------------------------------------------------------------------
[f, t] = newFig(1150, 430, 1, numel(names));
for q = 1:numel(names)
    A = out.(names{q}).abstraction;
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    plot(ax, A.curve.sinrDb, A.curve.pTb, '-', 'Color', v.ink, 'LineWidth', 1.5);
    for colF = 0:1
        B = A.bins(A.bins.collided == colF, :);
        plot(ax, B.sinrDb, B.obsTb, 'o', 'Color', v.cat(1 + 7 * colF, :), 'MarkerFaceColor', v.cat(1 + 7 * colF, :), 'MarkerSize', 6);
    end
    xlim(ax, [-10 30]); ylim(ax, [0 1.02]);
    xlabel(ax, 'SINR by the SLS formula (dB)'); ylabel(ax, 'TB decoded, first transmission');
    title(ax, sprintf('%s: waveform needs %+.2f dB vs formula', names{q}, A.gapDb), 'FontWeight', 'normal');
end
legend(ax, {'SLS prediction (measured tables)', 'waveform, clean', 'waveform, collided'}, 'Location', 'southeast', 'Box', 'off');
title(t, 'Does the SLS interference formula predict the summed-waveform decoder?', 'FontWeight', 'normal');
files{2} = saveFig(f, outRoot, 'abstraction_check');

out.files = files;
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'waveDeploy.mat'), 'out');
for q = 1:numel(names)
    fprintf('\n-- %s: %d UEs, SINR gap %+.2f dB\n', names{q}, out.(names{q}).N, out.(names{q}).abstraction.gapDb);
    disp(out.(names{q}).flow);
end
end
