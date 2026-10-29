function out = runStudy(s, parts)
%runStudy The three-part study, in dependency order.
%   experiments.runStudy()                   % everything (~2-3 h on 6 workers)
%   experiments.runStudy([], {'B', 'C'})     % a subset
%   measure  link-level BLER at 0/10/20/30 mph for MCS 1,2,3,5,6,7,11,27 (experiments.measureSpeeds);
%            skipped when the four curve sets already exist
%   B        link level: RMa link budget (settings().link), SNR per distance, range, throughput,
%            latency per PDB, speed effect (experiments.linkLevel).
%   A        MAC procedures: spec bounds, sensing, exclusion, SPS, event selection
%            (experiments.macTutorial)
%   C        system level: 1 km x 1 km field, densities 10..100 /km^2, three PQIs
%            (experiments.systemLevel)
%Figures: plots/study/{A_mac, B_link, C_system}/. Data: plots/study/data/.
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2 || isempty(parts), parts = {'measure', 'B', 'A', 'C'}; end
out = struct();
have = all(arrayfun(@(m) isfile(fullfile(s.dataRoot, sprintf('linkCurves_v%02dmph.mat', m))), [0 10 20 30]));
if ismember('measure', parts) && ~have
    experiments.measureSpeeds(s);
end
if ismember('B', parts), out.B = experiments.linkLevel(s); end
if ismember('A', parts), out.A = experiments.macTutorial(s); end
if ismember('C', parts), out.C = experiments.systemLevel(s); end
end
