function out = runAll(s, only)
%runAll Run every experiment, in dependency order, and export one summary for the report.
%   experiments.runAll()                          % full scale, all experiments (~1.5 h, 10 cores)
%   s = experiments.settings(); s.scale = 'quick'; experiments.runAll(s)   % smoke test
%   experiments.runAll([], {'latency', 'field'})  % a subset, by name
%Figures: <s.plotRoot>/<experiment>/*.png.  Data: <s.dataRoot>/<experiment>.mat, summary.json.
%
%   slotStructure     1a  S-SSB slot, data slot with/without PSFCH, pool timeline
%   sensingSelection  1b  sensing window, candidate set S_A, selection statistics, S_A vs load
%   linkCurves            LLS BLER, every MCS (cached; ~25 min), plus the 4-DM-RS and 30 km/h sets
%   rxSensitivity     3b  received power vs LDPC+CRC sensitivity per MCS, range
%   throughputMcs     3   MCS 5/6/11/27 throughput vs SNR and distance, three channel conditions
%   distance          5   throughput vs distance for every MCS; SLS PRR/latency vs distance, HARQ
%   rlcSegmentation   5b  full-stack SDU size sweep through RLC UM segmentation
%   latency           2   latency vs PDB: baseline, load, P_rsvp, retx, MCS
%   field             4   Poisson field, CAM + events: collisions, CBR, target-UE latency, verdict
%   eventStrategy     4b  best strategy for event-driven data
%   cbrCapacity       6   CBR vs remaining capacity, operating envelope
if nargin < 1 || isempty(s), s = experiments.settings(); end
all = {'slotStructure', 'sensingSelection', 'linkCurves', 'rxSensitivity', 'throughputMcs', 'distance', ...
    'rlcSegmentation', 'latency', 'field', 'eventStrategy', 'cbrCapacity'};
if nargin < 2 || isempty(only), only = all; end
out = struct();
t0 = tic;
for k = 1:numel(all)
    name = all{k};
    if ~ismember(name, only), continue; end
    t1 = tic;
    fprintf('\n==================== %s ====================\n', name);
    switch name
        case 'linkCurves'
            experiments.linkCurves();
            if ~strcmp(s.scale, 'quick')
                experiments.linkCurves(struct('mcs', [5 6 11 27], 'nDmrs', 4, 'tag', 'dmrs4'));
                experiments.linkCurves(struct('mcs', [5 6 11 27], 'speedKmh', 30, 'tag', 'v30'));
            end
        otherwise
            out.(name) = experiments.(name)(s);
    end
    fprintf('[%s done in %.0f s, %.0f s total]\n', name, toc(t1), toc(t0));
end
experiments.exportSummary(s);
end
