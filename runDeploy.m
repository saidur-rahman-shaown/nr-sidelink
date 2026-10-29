function [r, S] = runDeploy(c)
%runDeploy Run the continuous-time, waveform-level deployment in deployConfig.m: print per-flow and
%per-UE statistics, write figures to c.sim.outDir, save the results.
%   [r, S] = runDeploy();                         % edit deployConfig.m first
%   c = deployConfig(); c.sim.durationMs = 500; [r, S] = runDeploy(c);
%See +harness/CLAUDE.md ("+deploy/") for what is modelled and what is not.
if nargin < 1, c = deployConfig(); end
t0 = tic;
r = harness.deploy.run(c);
fprintf('\n=== deployment: %d UEs (%.0f /km^2), %.1f s air, %.0f s wall ===\n', numel(r.ues), ...
    r.drop.lambdaPerKm2, r.c.sim.durationMs / 1000, toc(t0));
S = harness.deploy.ueStats(r);
disp(S.flow);
disp(S.perUe);
k = harness.field.collisions(r);
fprintf('PSSCH transmissions %d, collided %d (%.1f %%), PSCCH-on-PSCCH %d\n', k.nTx, k.nCollided, ...
    100 * k.nCollided / max(1, k.nTx), k.nSameStart);
S.collisions = k;
files = harness.deploy.plots(r, S, c.sim.outDir);
fprintf('Figures: %s\n', strjoin(files, ', '));
rs = rmfield(r, 'ues');
save(fullfile(c.sim.outDir, 'deploy.mat'), 'rs', 'S', '-v7.3');
end
