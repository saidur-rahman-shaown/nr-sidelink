function r = runField(outDir)
%runField Run the waveform-level field scenario defined in fieldConfig.m, print its report and
%save its figures.
%   r = runField();               % figures to plots/field/
%   r = runField('plots/mine');   % or anywhere else
%   Edit fieldConfig.m for positions, traffic, channel and UE latency policy; edit the stored
%   preconfiguration (+cfg/configs/preconfig_example.json) for anything 3GPP-configured.
if nargin < 1, outDir = fullfile('plots', 'field'); end
c = fieldConfig();
t0 = tic;
r = harness.field.run(c);
fprintf('\n(%.0f s of wall clock for %.1f s of air time)\n', toc(t0), r.c.sim.durationMs / 1000);
r.summary = harness.field.report(r);
files = harness.field.plotField(r, outDir);
fprintf('\nFigures: %s\n', strjoin(files, ', '));
end
