function out = rlcSegmentation(s)
%rlcSegmentation Experiment 5b: what RLC segmentation costs in reliability and latency.
%Spec:   none -- a study over the FULL STACK (+stack/ through harness.field.run): real SDAP, PDCP,
%        RLC UM (TS 38.322 5.2.2: segmentation at TX, reassembly with t-Reassembly at RX), MAC
%        multiplexing, the waveform, TDL-D fading and RMa path loss. The SLS cannot do this: it has
%        no RLC and refuses an SDU larger than one transport block (scenarioInit:sduTooLarge).
%Inputs: s  optional, experiments.settings()
%Outputs: out  .files, .table (per SDU size, distance, T2 policy: segments per SDU, PDB reliability,
%              latency percentiles)
%Scenario: two UEs 60 km/h each in convoy (separation constant; Doppler speed |v1|+|v2| = 120 km/h,
%the BLER table's key), UE1 -> UE2 broadcast CAM-like flow (PQI 58, 100 ms PDB, every 100 ms) of
%SDU size B. The stored pool's largest TB at MCS 7 is 560 B (5 sub-channels, PSFCH in every slot),
%so B > ~550 B must be segmented, one segment per grant, and in UM the SDU is lost if ANY segment
%is. Each further segment needs its own Mode-2 selection inside the remaining PDB.
%Figures (plots/experiments/rlc_segmentation/):
%   segmentation.png   PDB reliability, segments per SDU and latency against SDU size
if nargin < 1 || isempty(s), s = experiments.settings(); end
outDir = fullfile(s.plotRoot, 'rlc_segmentation');
v = viz();
quick = strcmp(s.scale, 'quick');
sizes = [200 500 800 1200 1600 2400]; dists = [150 450]; caps = [Inf 20];
durMs = 3000;
if quick, sizes = [300 1200]; dists = 150; caps = Inf; durMs = 800; end
[S, D, C] = ndgrid(sizes, dists, caps);
jobs = [S(:) D(:) C(:)];
res = cell(1, size(jobs, 1));
if s.useParallel
    if isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end
    parfor j = 1:size(jobs, 1)
        res{j} = runSeg(jobs(j, 1), jobs(j, 2), jobs(j, 3), durMs, s.seeds(1));
    end
else
    for j = 1:size(jobs, 1)
        res{j} = runSeg(jobs(j, 1), jobs(j, 2), jobs(j, 3), durMs, s.seeds(1));
    end
end
T = struct2table([res{:}]);

[fig, t] = newFig(1300, 430, 1, 3);
axs = [nexttile(t) nexttile(t) nexttile(t)];
for a = axs, hold(a, 'on'); grid(a, 'on'); end
k = 0; lg = {};
for d = dists
    for c = caps
        k = k + 1;
        m = T.dM == d & T.t2CapMs == c;
        col = v.cat(k, :);
        plot(axs(1), T.sduBytes(m), T.onTime(m), '-o', 'Color', col, 'MarkerFaceColor', col);
        plot(axs(2), T.sduBytes(m), T.newTxPerSdu(m), '-o', 'Color', col, 'MarkerFaceColor', col);
        plot(axs(3), T.sduBytes(m), T.p50Ms(m), '-o', 'Color', col, 'MarkerFaceColor', col);
        plot(axs(3), T.sduBytes(m), T.p95Ms(m), '--', 'Color', col);
        lg{end + 1} = sprintf('%g m, T2 %s', d, ifelse(isinf(c), '= PDB', sprintf('cap %g ms', c))); %#ok<AGROW>
    end
end
tbsMax = res{1}.tbsMaxBytes;
for a = axs, xline(a, tbsMax, ':', sprintf('max TBS %d B', tbsMax), 'Color', v.muted); end
yline(axs(1), 0.9, ':', '1 - PER', 'Color', v.muted); yline(axs(3), 100, ':', 'PDB', 'Color', v.status.bad);
ylabel(axs(1), 'SDUs delivered within PDB'); ylabel(axs(2), 'new transmissions (segments) per SDU');
ylabel(axs(3), 'latency (ms): p50 solid, p95 dashed'); ylim(axs(1), [0 1.02]);
for a = axs, xlabel(a, 'application SDU size (bytes)'); end
legend(axs(1), lg, 'Location', 'southwest', 'Box', 'off');
title(t, 'RLC UM segmentation, full stack + waveform, UE1 -> UE2, MCS 7, TDL-D 120 km/h', 'FontWeight', 'normal');
files{1} = saveFig(fig, outDir, 'segmentation');

out.files = files; out.table = T;
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'rlcSegmentation.mat'), 'out');
disp(T);
end

function r = runSeg(sduBytes, dM, t2Cap, durMs, seed)
c = fieldConfig();                       % the repo's field configuration (top-level fieldConfig.m)
c.ue.n = 2;
c.ue.x = [0 dM]; c.ue.y = [0 0];
c.ue.vMps = [60 60] / 3.6;                % convoy: constant separation, double-mobility Doppler
c.ue.l2Id = hex2dec('100000') + (1:2);
c.cam.sizeBytes = sduBytes;
c.denm.count = 0;                         % no events
c.uni.from = 1; c.uni.to = 2; c.uni.startMs = 1e9;     % unicast session never starts
c.impl.t2MaxMs = t2Cap;
c.sim.durationMs = durMs; c.sim.seed = seed;
o = harness.field.run(c);
mine = [o.pkt.src] == 1 & strcmp({o.pkt.type}, 'cam') & [o.pkt.genMs] + [o.pkt.pdbMs] < durMs;
pk = o.pkt(mine);
lat = nan(1, numel(pk));
for k = 1:numel(pk)
    h = o.rx([o.rx.id] == pk(k).id & [o.rx.rxUe] == 2);
    if ~isempty(h), lat(k) = min([h.rxMs]) - pk(k).genMs; end
end
pdb = [pk.pdbMs];
tx1 = o.txLog([o.txLog.ue] == 1);
r.sduBytes = sduBytes; r.dM = dM; r.t2CapMs = t2Cap;
r.nSdu = numel(pk);
r.onTime = mean(lat <= pdb);
r.p50Ms = median(lat, 'omitnan'); r.p95Ms = prctile(lat, 95);
r.newTxPerSdu = nnz(~[tx1.isRetx]) / max(1, nnz([o.pkt.src] == 1 & strcmp({o.pkt.type}, 'cam')));
r.tbsMaxBytes = o.ues(1).g.tbsBytesByLsubCH(end);
g = o.ues(1).g; op = experiments.settings().op;
assert(g.mu == op.mu && g.numSubchannel == op.numSubchannel && g.subchSizeRb == op.subchSizeRb, ...
    'rlcSegmentation: stored pool is %d x %d PRB at mu %d -- off the operating point', g.numSubchannel, g.subchSizeRb, g.mu);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
