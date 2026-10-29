function out = twoUeLatency(opt)
%twoUeLatency Two UEs, one flow, N packets, through the FULL stack and RF at waveform level: the
%latency of every packet as a line, a box and a CDF.
%   r = runTwoUe();                                          % the entry point: see twoUeConfig.m
%   out = experiments.twoUeLatency(struct('distM', 1200));   % or override fields directly
%Spec:   none -- an experiment, run on harness.deploy.run: every packet goes application -> SDAP ->
%        PDCP -> RLC -> MAC -> PHY (+stack/) -> IQ at 30.72 Msps -> the transmitter's hardware
%        (rf.txHardware: DAC, IQ imbalance, phase noise, carrier error, PA at 23 dBm) -> the channel
%        (path loss, TDL-D fading in continuous time, propagation delay, thermal noise) -> the
%        receiver's hardware (rf.rxHardware: LO error, AGC, ADC) -> PHY decode -> MAC -> RLC ->
%        PDCP -> SDAP -> application. Nothing is abstracted (.claude/rules/full-stack-simulation.md).
%        Latency = delivery slot - generation + 1 slot on the air + 2 slots to receive, with the
%        stack's selection window ending at T2 = PDB - 3 slots (stack.defaults.decodeMarginSlots = 2).
%        The stack's MAC runs sensing-based SPS when .prsvpTxMs > 0 (stack.defaults.prsvpTxMs):
%        one grant reused every P_rsvp_TX, counter, keep probability, reservation in SCI-1A.
%Inputs: opt  optional struct, every field optional (defaults in brackets):
%           .pqi        [56]    must be mapped to an SLRB in the stored preconfiguration
%                               (+cfg/configs/preconfig_example.json: broadcast 56 and 58)
%           .periodMs   [100]   generation period (10 Hz)
%           .sizeBytes  [300]
%           .nPackets   [1000]
%           .distM      [100]   TX-RX distance; both UEs static
%           .mcs        [11]
%           .speedMph   [20]    Doppler speed of the link (the TDL-D channel's), mph
%           .seed       [5]
%           .link       struct: .plModel ['rma'] .losMode ['los'] .antennaHeightM [3]
%                       .antennaGainDb [6] (TX + RX) .noiseFigureDb [9] (TR 37.885 Table 6.1.1-1)
%           .tReorderingMs [10] PDCP t-Reordering at the receiver (TS 38.331 9.1.1.5, UE choice)
%           .delaySpreadNs [100]
%           .hw         [rf.hwDefaults()]  transmitter/receiver hardware impairments
%           .nWorkers   [2]
%           .prsvpTxMs  [100]   P_rsvp_TX: 100 = SPS (as a production UE runs periodic traffic),
%                               0 = a new selection per packet
%           .probResourceKeep [[]]  sl-ProbResourceKeep, one of {0 0.2 0.4 0.6 0.8}: the chance an
%                               SPS grant keeps its resources when its counter expires; [] = the
%                               stored preconfiguration's (0.8, SAE J3161)
%Outputs: out  struct: .latMs (1 x N, ms, NaN if lost, in order of generation), .onTime, .stats,
%         .file (the figure), .run (harness.deploy.run's result, without the UE structs)
%Figure: plots/experiments/twoUe/twoUe_fullstack_pqi<PQI>_n<N>_<D>m.png
d = struct('pqi', 56, 'periodMs', 100, 'sizeBytes', 300, 'nPackets', 1000, 'distM', 100, 'mcs', 11, ...
    'speedMph', 20, 'seed', 5, 'tReorderingMs', 10, 'delaySpreadNs', 100, 'nWorkers', 2, 'prsvpTxMs', 100, 'probResourceKeep', []);
d.link = struct('plModel', 'rma', 'losMode', 'los', 'antennaHeightM', 3, 'antennaGainDb', 6, 'noiseFigureDb', 9);
d.hw = rf.hwDefaults();
if nargin < 1, opt = struct(); end
fn = fieldnames(d);
for k = 1:numel(fn)
    if ~isfield(opt, fn{k}), opt.(fn{k}) = d.(fn{k}); end
end
lf = fieldnames(d.link);
for k = 1:numel(lf)
    if ~isfield(opt.link, lf{k}), opt.link.(lf{k}) = d.link.(lf{k}); end
end
s = experiments.settings();
row = cfg.pqiLookup(cfg.pqiTable(), opt.pqi);

% ---- the deployment: UE 1 transmits, UE 2 receives, both static -------------------------------
c = deployConfig();
c.ue.densityPerKm2 = []; c.ue.n = 2;
c.ue.xy = [0 0; opt.distM 0];
c.field.sizeM = [opt.distM + 1, 1];
c.ue.dropSeed = opt.seed + 1000;
c.cam = struct('pqi', opt.pqi, 'pfi', 1, 'periodMs', opt.periodMs, 'sizeBytes', opt.sizeBytes, 'txUe', 1);
c.evt.pqi = opt.pqi; c.evt.meanMs = Inf;                 % no event traffic
c.radio.plModel = opt.link.plModel; c.radio.losMode = opt.link.losMode;
c.radio.hAntM = opt.link.antennaHeightM; c.radio.antennaGainDb = opt.link.antennaGainDb;
c.radio.fading = 'TDL-D'; c.radio.delaySpreadNs = opt.delaySpreadNs;
c.radio.dopplerKmh = opt.speedMph * 1.609344;
c.hw = opt.hw; c.hw.rx.noiseFigureDb = opt.link.noiseFigureDb;
c.impl.mcs = opt.mcs;
c.impl.decodeMarginSlots = s.op.rxProcSlots;             % T2 = PDB - 3 slots
c.impl.tReorderingMs = opt.tReorderingMs;
c.impl.prsvpTxMs = opt.prsvpTxMs;
c.impl.probResourceKeep = opt.probResourceKeep;
c.sim.nPackets = opt.nPackets; c.sim.durationMs = [];
c.sim.seed = opt.seed; c.sim.nWorkers = opt.nWorkers;
c.sim.rangeM = opt.distM + 1;
c.sim.outDir = fullfile(s.plotRoot, 'twoUe');
r = harness.deploy.run(c);

% ---- per-packet latency at the receiving application --------------------------------------------
slotMs = 1 / 2^s.op.mu;
pipeMs = (s.op.txSlots + s.op.rxProcSlots) * slotMs;     % 1 slot on the air + 2 to receive
P = r.pkt([r.pkt.src] == 1 & strcmp({r.pkt.type}, 'cam'));
[~, o] = sort([P.genMs]); P = P(o);
X = r.rx([r.rx.rxUe] == 2);
lat = nan(1, numel(P));
for k = 1:numel(P)
    hit = [X.id] == P(k).id;
    if any(hit), lat(k) = min([X(hit).rxMs]) - P(k).genMs + pipeMs; end
end
onT = lat <= row.PDB_ms;                                  % NaN (lost) compares false

% ---- numbers -------------------------------------------------------------------------------
ok = ~isnan(lat);
lt = linkText(c);
st = struct('nPackets', numel(lat), 'min', min(lat(ok)), 'p50', prctile(lat(ok), 50), ...
    'mean', mean(lat(ok)), 'p95', prctile(lat(ok), 95), 'p99', prctile(lat(ok), 99), ...
    'max', max(lat(ok)), 'nOverPdb', nnz(ok & ~onT), 'nLost', nnz(~ok), 'pdbMs', row.PDB_ms, ...
    'per', row.PER, 'onTimeShare', mean(onT), 'link', lt);
s1 = r.ues(1).stats;
fprintf('UE 1 MAC: %d selections, %d SPS periods (%d unused), kept %d, released %d, %d transmissions\n', ...
    s1.selections, s1.spsPeriods, s1.spsUnusedPeriods, s1.spsKept, s1.spsReleased, s1.transmissions);
fprintf('UE 1 congestion / re-evaluation: CBR %.2f, %d dropped by the CR limit, %d re-evaluated, %d pre-empted, %d replaced, %d unreplaceable\n', ...
    r.ues(1).cbrLast, s1.ccDropped, s1.reevalFlagged, s1.preemptFlagged, s1.replaced, s1.replaceFailed);
st.selections = s1.selections; st.spsPeriods = s1.spsPeriods;
st.probResourceKeep = r.ues(1).g.probResourceKeep;     % what the UE actually ran with
fprintf(['FULL STACK | P_rsvp %g ms | PQI %d (PDB %g ms, PER %g): %d packets, %g m | latency min %.1f, p50 %.1f, mean %.2f, ' ...
    'p95 %.1f, p99 %.1f, max %.1f ms | over PDB %d, lost %d, on time %.2f %%\n'], opt.prsvpTxMs, opt.pqi, row.PDB_ms, ...
    row.PER, st.nPackets, opt.distM, st.min, st.p50, st.mean, st.p95, st.p99, st.max, st.nOverPdb, ...
    st.nLost, 100 * st.onTimeShare);

% ---- figure: line, box, CDF ------------------------------------------------------------------
v = viz();
col = v.cat(1, :);
floorMs = (phy.ts38214.procTimeSelection(s.op.mu) + s.op.txSlots + s.op.rxProcSlots) * slotMs;
yl = [0 row.PDB_ms * 1.1];
[f, t] = newFig(1350, 430, 1, 3);

ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
plot(ax, 1:numel(lat), lat, '-', 'Color', col, 'LineWidth', 0.8);
if any(~ok), plot(ax, find(~ok), row.PDB_ms * ones(1, nnz(~ok)), 'x', 'Color', v.status.bad); end
refLines(ax, row.PDB_ms, floorMs, v, 'horizontal');
xlim(ax, [1 max(2, numel(lat))]); ylim(ax, yl);
xlabel(ax, 'packet (in order of generation)'); ylabel(ax, 'latency (ms)');
title(ax, 'Latency of every packet (x = lost)', 'FontWeight', 'normal');

ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
boxchart(ax, ones(nnz(ok), 1), lat(ok)', 'BoxFaceColor', col, 'MarkerColor', col, 'BoxWidth', 0.5);
refLines(ax, row.PDB_ms, floorMs, v, 'horizontal');
set(ax, 'XTick', 1, 'XTickLabel', sprintf('PQI %d', opt.pqi)); xlim(ax, [0.4 1.6]); ylim(ax, yl);
ylabel(ax, 'latency (ms)');
title(ax, sprintf('Distribution: median %.1f ms, IQR %.1f-%.1f ms', st.p50, prctile(lat(ok), 25), ...
    prctile(lat(ok), 75)), 'FontWeight', 'normal');

ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
x = sort(lat(ok));
stairs(ax, [x(1) x], [0 (1:numel(x)) / numel(lat)], '-', 'Color', col, 'LineWidth', 2);
refLines(ax, row.PDB_ms, floorMs, v, 'vertical');
yline(ax, 1 - row.PER, ':', sprintf('target 1 - PER = %g %%', 100 * (1 - row.PER)), 'Color', v.muted, ...
    'LabelHorizontalAlignment', 'left');
xlim(ax, yl); ylim(ax, [0 1.02]);
xlabel(ax, 'latency (ms)'); ylabel(ax, 'share of packets delivered within x');
title(ax, sprintf('CDF: p95 %.1f ms, p99 %.1f ms, max %.1f ms', st.p95, st.p99, st.max), 'FontWeight', 'normal');

title(t, {sprintf(['Full stack, waveform level: two UEs %g m apart, PQI %d (PDB %g ms), %d packets of %d B ' ...
    'every %g ms, MCS %d, %s'], opt.distM, opt.pqi, row.PDB_ms, st.nPackets, ...
    opt.sizeBytes, opt.periodMs, opt.mcs, rsvText(opt.prsvpTxMs, st)), ...
    sprintf('%s; %d over the PDB, %d lost', lt, st.nOverPdb, st.nLost)}, 'FontWeight', 'normal');
tag = sprintf('twoUe_fullstack_pqi%d_rsvp%d_n%d_%dm', opt.pqi, opt.prsvpTxMs, st.nPackets, round(opt.distM));
if opt.prsvpTxMs > 0
    tag = sprintf('%s_keep%02d', tag, round(10 * st.probResourceKeep));   % keep 0.8 -> _keep08
end
out.file = saveFig(f, c.sim.outDir, tag);
out.latMs = lat; out.onTime = onT; out.stats = st; out.opt = opt;
out.run = rmfield(r, 'ues');
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, [tag '.mat']), 'out', '-v7.3');
end

function t = rsvText(prsvpMs, st)
if prsvpMs > 0
    t = sprintf('SPS P_{rsvp} %g ms, keep %.1f (%d selections)', prsvpMs, st.probResourceKeep, st.selections);
else
    t = sprintf('one selection per packet (%d)', st.selections);
end
end

function t = linkText(c)
%linkText The channel and hardware the run was configured with.
t = upper(c.radio.plModel);
if strcmpi(c.radio.plModel, 'rma'), t = [t ' ' upper(c.radio.losMode)]; end
t = sprintf('%s, antennas %g m, gain %g dB, NF %g dB, TDL-D at %.1f km/h, PA %g dBm', t, c.radio.hAntM, ...
    c.radio.antennaGainDb, c.hw.rx.noiseFigureDb, c.radio.dopplerKmh, c.hw.tx.pOutDbm);
end

function refLines(ax, pdbMs, floorMs, v, orient)
%refLines The PDB (the deadline) and the 4 ms floor (T1 + 3 slots), labelled, on either axis.
if strcmp(orient, 'horizontal')
    yline(ax, pdbMs, '-', 'PDB', 'Color', v.status.bad, 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
    yline(ax, floorMs, ':', sprintf('floor %.0f ms', floorMs), 'Color', v.muted, 'LabelHorizontalAlignment', 'left');
else
    xline(ax, pdbMs, '-', 'PDB', 'Color', v.status.bad, 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
    xline(ax, floorMs, ':', sprintf('floor %.0f ms', floorMs), 'Color', v.muted, 'LabelVerticalAlignment', 'bottom');
end
end
