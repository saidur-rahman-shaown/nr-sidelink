function out = measureSpeeds(s)
%measureSpeeds Measure link-level BLER (PSSCH, 3 HARQ attempts, and PSCCH) at 0/10/20/30 mph for the
%study's MCS set, and register each speed's table for the SLS (harness.phyabs.blerTableFor).
%Speeds are the Doppler speed of the link: one vehicle moving at that speed relative to the other.
if nargin < 1 || isempty(s), s = experiments.settings(); end
MPH_TO_KMH = 1.609344;
mph = [0 10 20 30];
mcs = [1 2 3 5 6 7 11 27];
out = struct();
for k = 1:numel(mph)
    tag = sprintf('v%02dmph', mph(k));
    lk = experiments.linkCurves(struct('mcs', mcs, 'focusMcs', [5 6 11 27], ...
        'speedKmh', mph(k) * MPH_TO_KMH, 'tag', tag, 'refresh', true));
    out.(tag) = exportBlerTable(lk, 'tdld');
    fprintf('measureSpeeds: %d mph -> %s\n', mph(k), out.(tag));
end
end
