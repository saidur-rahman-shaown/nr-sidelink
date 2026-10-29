function r = runTwoUe(c)
%runTwoUe Run the two-UE latency experiment configured in twoUeConfig.m.
%   r = runTwoUe();                  % edit twoUeConfig.m first
%   c = twoUeConfig(); c.distM = 1200; c.mcs = 5; r = runTwoUe(c);   % or change it here
%Prints min / median / mean / p95 / p99 / max latency, packets over the PDB and lost, and saves the
%line + box + CDF figure to plots/experiments/twoUe/ (the file name carries PQI, N and the distance) and
%the per-packet latencies to plots/experiments/data/.
if nargin < 1, c = twoUeConfig(); end
t0 = tic;
r = experiments.twoUeLatency(c);     % full stack, waveform level (harness.deploy.run)
fprintf('channel: %s\nfigure:  %s\n(%.0f s)\n', r.stats.link, r.file, toc(t0));
end
