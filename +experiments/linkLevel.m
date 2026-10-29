function out = linkLevel(s)
%linkLevel Study Part B: one link, real PHY -- RMa link budget, SNR per distance, range, throughput and
%latency for MCS 5, 6, 11, 27 at 0, 10, 20, 30 mph.
%Spec:   none -- built on MEASURED BLER (experiments.measureSpeeds: the normative PSCCH/PSSCH chains,
%        OFDM, TDL-D fading with an independent realisation per transport block, DM-RS channel
%        estimation, ZF, LDPC, HARQ soft combining). Nothing here is a Shannon formula.
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct: .link, .snrTable, .range (per MCS x speed), .throughput, .latency
%THE LINK BUDGET (settings().link)
%     SNR(d) = 23 dBm + G - PL_RMa(d) - 10 log10(12 x 50 PRB) - N_RE,   N_RE = kT0 x 30 kHz x NF
%  PL_RMa: TR 38.901 RMa LOS at 5.9 GHz, antennas 3 m at both ends (agricultural machinery, cab
%  roof); G = 3 + 3 dBi; NF = 9 dB (TR 37.885 V15.3.0 Table 6.1.1-1). Nothing is fitted: the range
%  each MCS reaches follows from these values and the measured BLER.
%LATENCY AT LINK LEVEL
%  One Mode-2 link with no other users: the packet arrives at n, the first transmission is drawn
%  uniformly in [n + T1, n + T2] (T1 = 5 slots, T2 = PDB - 3 slots), one chained blind
%  retransmission uniformly within TRIV's 31-slot reach and before T2. Attempt k succeeds with the
%  measured soft-combined BLER. Latency = arrival -> the slot of the first successful transmission
%  + 1 slot on the air + 2 slots to receive (settings().op, "THE LATENCY PIPELINE"), so it lies
%  in [4 ms, PDB]. The PDBs are those of the broadcast PQIs 55, 56, 57, 58 (TS 23.287 Table 5.4.4-1).
%Figures (plots/study/B_link/): B1_snr_vs_distance, B2_bler_by_speed, B3_range, B4_throughput,
%  B5_latency, B6_prr, B7_speed_effect
if nargin < 1 || isempty(s), s = experiments.settings(); end
outDir = fullfile('plots', 'study', 'B_link');
v = viz();
mph = [0 10 20 30];
focus = [5 6 11 27];
allM = [1 2 3 5 6 7 11 27];
slotMs = 0.5; spm = 2; T1 = 5; TRIV = 31; NPRB = 50;
PIPE = s.op.txSlots + s.op.rxProcSlots;             % 1 slot on the air + 2 to receive
fc = s.radio.fcHz; NF = s.radio.noiseFigureDb; P = s.op.pCmaxDbm;
nRe = rf.noiseFloorDbm(30e3, NF);
lkS = s.link;
plM = harness.chanmodel.pathlossModel(lkS.plModel, struct('fcHz', fc, 'losMode', lkS.losMode, ...
    'hTxM', lkS.antennaHeightM, 'hRxM', lkS.antennaHeightM));         % gain applied below, explicitly
G = lkS.antennaGainDb;
plDb = @(d) harness.chanmodel.pathloss(plM, d);
dBp = 2 * pi * lkS.antennaHeightM^2 * fc / 299792458;              % RMa breakpoint distance
lk = cell(1, numel(mph));
for k = 1:numel(mph)
    x = load(fullfile(s.dataRoot, sprintf('linkCurves_v%02dmph.mat', mph(k))), 'lk'); lk{k} = x.lk;
end
cur = @(k, m) lk{k}.curve{lk{k}.mcs == m};
req = @(c, a) firstCross(c.snrDb, c.bler(:, a), 0.1);

% ---- the link budget -------------------------------------------------------------------------
kRef = find(mph == 20);
snrReq5 = req(cur(kRef, 5), 1);
snrAt = @(d) P + G - plDb(d) - 10 * log10(12 * NPRB) - nRe;   % per-RE SNR over 50 PRB
fprintf('link: RMa LOS, h = %g m, G = %g dB, NF = %g dB; SNR at 1500 m = %.2f dB, MCS 5 needs %.2f dB (20 mph)\n', ...
    lkS.antennaHeightM, G, NF, snrAt(1500), snrReq5);
link = struct('plModel', lkS.plModel, 'antennaHeightM', lkS.antennaHeightM, 'antennaGainDb', G, ...
    'noiseFigureDb', NF, 'breakpointM', dBp, 'snrAt1500Db', snrAt(1500), 'mcs5ReqDb', snrReq5);

% ---- B1: SNR vs distance -------------------------------------------------------------------
d = 10:10:3000;
[f, ax] = newFig(900, 440);
plot(ax, d, snrAt(d), '-', 'Color', v.ink, 'LineWidth', 2);
for q = 1:numel(focus)
    r = req(cur(kRef, focus(q)), 1);
    % Labels on the left, alternately above and below the line: MCS 5 and 6 need almost the same SNR.
    va = {'bottom', 'top', 'top', 'top'}; ha = {'left', 'left', 'center', 'center'};
    if ~isnan(r), yline(ax, r, ':', sprintf('MCS %d needs %.1f dB', focus(q), r), 'Color', v.cat(q, :), 'LineWidth', 1.5, ...
            'LabelHorizontalAlignment', ha{q}, 'LabelVerticalAlignment', va{q}); end
end
dd = [100 250 500 750 1000 1250 1500 1750 2000 2500];
plot(ax, dd, snrAt(dd), 'o', 'Color', v.ink, 'MarkerFaceColor', v.cat(1, :));
xline(ax, dBp, '--', sprintf('RMa breakpoint %.0f m', dBp), 'Color', v.muted, 'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'left');
xline(ax, 1500, ':', '1500 m', 'Color', v.ink);
set(ax, 'XScale', 'log'); xlim(ax, [10 3000]);
xlabel(ax, 'distance (m)'); ylabel(ax, 'SNR per resource element over 50 PRB (dB)');
title(ax, {sprintf('Link budget: 23 dBm, TR 38.901 RMa LOS at 5.9 GHz, antennas %g m, %g + %g dBi, NF %g dB', ...
    lkS.antennaHeightM, lkS.antennaGainDbi, lkS.antennaGainDbi, NF), ...
    'dotted lines: SNR each MCS needs for 10 % BLER on the first transmission (20 mph)'}, 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'B1_snr_vs_distance');
out.snrTable = table(dd', plDb(dd)', snrAt(dd)', P + G - plDb(dd)', 'VariableNames', {'distanceM', 'pathLossDb', 'snrPerReDb', 'rxPowerDbm'});

% ---- B2: BLER by speed ---------------------------------------------------------------------
[f, t] = newFig(1250, 420, 1, numel(focus));
for q = 1:numel(focus)
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on'); set(ax, 'YScale', 'log');
    for k = 1:numel(mph)
        c = cur(k, focus(q));
        plot(ax, c.snrDb, max(c.bler(:, 1), 1e-3), '-', 'Color', v.cat(k, :), 'LineWidth', 1.8);
    end
    yline(ax, 0.1, ':', 'Color', v.muted); ylim(ax, [1e-3 1.1]); xlim(ax, [-10 40]);
    xlabel(ax, 'SNR per RE (dB)'); title(ax, sprintf('MCS %d', focus(q)), 'FontWeight', 'normal');
    if q == 1, ylabel(ax, 'BLER, first transmission'); end
end
legend(ax, compose('%d mph', mph(:)), 'Location', 'southwest', 'Box', 'off');
title(t, 'Measured BLER (real PSSCH chain, TDL-D, DM-RS channel estimation) at four speeds', 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'B2_bler_by_speed');

% ---- B3: range per MCS and speed -------------------------------------------------------------
R = zeros(numel(allM), numel(mph)); R3 = R;
for k = 1:numel(mph)
    for m = 1:numel(allM)
        c = cur(k, allM(m));
        R(m, k) = rangeFor(req(c, 1), snrAt, d);
        R3(m, k) = rangeFor(req(c, size(c.bler, 2)), snrAt, d);
    end
end
[f, ax] = newFig(1000, 440);
b = bar(ax, categorical(compose('MCS %d', allM(:)), compose('MCS %d', allM(:))), R, 0.85, 'EdgeColor', 'w');
for k = 1:numel(mph), b(k).FaceColor = v.cat(k, :); end
ylabel(ax, 'range: BLER <= 10 % on the first transmission (m)');
legend(ax, compose('%d mph', mph(:)), 'Location', 'northeast', 'Box', 'off');
title(ax, 'How far each MCS reaches, by speed (50 PRB, RMa LOS, 3 m antennas, 3 + 3 dBi)', 'FontWeight', 'normal');
files{3} = saveFig(f, outDir, 'B3_range');
out.range = array2table([allM(:) R R3], 'VariableNames', [{'mcs'}, compose('firstTx_%dmph', mph), compose('after3Tx_%dmph', mph)]);

% ---- B4: throughput vs distance --------------------------------------------------------------
[f, t] = newFig(1250, 760, 2, 2);
thr = struct();
for k = 1:numel(mph)
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    for q = 1:numel(focus)
        c = cur(k, focus(q));
        T = linkThroughput(c, snrAt(d), 'none', slotMs);
        plot(ax, d, T, '-', 'Color', v.cat(q, :), 'LineWidth', 2);
        thr.(sprintf('mcs%d_%dmph', focus(q), mph(k))) = T;
    end
    xlim(ax, [0 3000]); xlabel(ax, 'distance (m)'); ylabel(ax, 'throughput (Mbit/s)');
    title(ax, sprintf('%d mph', mph(k)), 'FontWeight', 'normal');
end
legend(ax, compose('MCS %d', focus(:)), 'Location', 'northeast', 'Box', 'off');
title(t, 'Link throughput against distance: one link using every slot, 50 PRB, first transmission', 'FontWeight', 'normal');
files{4} = saveFig(f, outDir, 'B4_throughput');
out.throughput = thr; out.distanceM = d;

% ---- B5/B6: latency and reliability vs distance, per PDB ---------------------------------------
pqT = cfg.pqiTable();
bcPqi = [55 56 57 58];                               % broadcast PQIs with PDB <= 100 ms
bcRow = arrayfun(@(q) cfg.pqiLookup(pqT, q), bcPqi);
pdbs = [bcRow.PDB_ms];                               % 10, 20, 25, 100 ms
dL = 50:50:3000;
rs = RandStream('mt19937ar', 'Seed', 1);
NMC = 4000;
lat = struct();
[f5, t5] = newFig(1300, 1150, numel(pdbs), numel(mph));
[f6, t6] = newFig(1300, 1150, numel(pdbs), numel(mph));
for p = 1:numel(pdbs)
    T2 = pdbs(p) * spm - PIPE;
    for k = 1:numel(mph)
        a5 = nexttile(t5); hold(a5, 'on'); grid(a5, 'on');
        a6 = nexttile(t6); hold(a6, 'on'); grid(a6, 'on');
        for q = 1:numel(focus)
            c = cur(k, focus(q));
            mL = nan(size(dL)); p95 = mL; prr = mL;
            for di = 1:numel(dL)
                b1 = blerAt(c, 1, snrAt(dL(di))); b2 = blerAt(c, 2, snrAt(dL(di)));
                t1 = T1 + floor(rand(rs, NMC, 1) * (T2 - T1 + 1));
                room = min(TRIV, T2 - t1);
                t2 = t1 + 1 + floor(rand(rs, NMC, 1) .* max(room, 0));
                ok1 = rand(rs, NMC, 1) >= b1;
                ok2 = ~ok1 & room > 0 & rand(rs, NMC, 1) < (b1 - b2) / max(b1, eps);
                L = nan(NMC, 1); L(ok1) = (t1(ok1) + PIPE) * slotMs; L(ok2) = (t2(ok2) + PIPE) * slotMs;
                prr(di) = mean(~isnan(L));
                if any(~isnan(L)), mL(di) = mean(L, 'omitnan'); p95(di) = prctile(L(~isnan(L)), 95); end
            end
            % Latency is drawn only where at least half the packets arrive: beyond that the few
            % successes make a noisy, misleading average (reliability has its own figure).
            show = prr >= 0.5;
            mPlot = mL; mPlot(~show) = NaN; pPlot = p95; pPlot(~show) = NaN;
            hM(q) = plot(a5, dL, mPlot, '-', 'Color', v.cat(q, :), 'LineWidth', 1.8); %#ok<AGROW>
            plot(a5, dL, pPlot, ':', 'Color', v.cat(q, :), 'LineWidth', 1.2);
            plot(a6, dL, prr, '-', 'Color', v.cat(q, :), 'LineWidth', 1.8);
            lat.(sprintf('pdb%d_mcs%d_%dmph', pdbs(p), focus(q), mph(k))) = struct('meanMs', mL, 'p95Ms', p95, 'prr', prr);
        end
        yline(a5, pdbs(p), '-', 'Color', v.status.bad); ylim(a5, [0 pdbs(p) * 1.05]); xlim(a5, [0 3000]);
        yline(a5, (T1 + PIPE) * slotMs, ':', 'Color', v.muted);
        yline(a6, 1 - bcRow(p).PER, ':', sprintf('1 - PER = %g %%', 100 * (1 - bcRow(p).PER)), 'Color', v.muted, ...
            'LabelHorizontalAlignment', 'left', 'FontSize', 8);
        ylim(a6, [0 1.02]); xlim(a6, [0 3000]);
        title(a5, sprintf('PQI %d: PDB %d ms, %d mph', bcPqi(p), pdbs(p), mph(k)), 'FontWeight', 'normal');
        title(a6, sprintf('PQI %d: PDB %d ms, %d mph', bcPqi(p), pdbs(p), mph(k)), 'FontWeight', 'normal');
        if p == numel(pdbs), xlabel(a5, 'distance (m)'); xlabel(a6, 'distance (m)'); end
        if k == 1, ylabel(a5, 'latency (ms)'); ylabel(a6, 'delivered within PDB'); end
    end
end
hP = plot(a5, NaN, NaN, ':', 'Color', v.ink, 'LineWidth', 1.2);
legend(a5, [hM hP], [compose('MCS %d (solid: mean)', focus(:)); {'dotted: p95'}], 'Location', 'eastoutside', 'Box', 'off');
legend(a6, compose('MCS %d', focus(:)), 'Location', 'southwest', 'Box', 'off');
title(t5, {'Link-level latency vs distance: one link, TX slot in [n + 5, n + PDB - 3 slots], 1 blind retx, + 1 slot on air + 2 slots to receive', 'solid mean, dotted p95, drawn where >= 50 % arrive; grey dotted = minimum 4 ms'}, 'FontWeight', 'normal');
title(t6, 'Link-level reliability: share delivered within the PDB, against each PQI''s own target 1 - PER (dotted)', 'FontWeight', 'normal');
files{5} = saveFig(f5, outDir, 'B5_latency');
files{6} = saveFig(f6, outDir, 'B6_prr');
out.latency = lat; out.latencyDistanceM = dL;

% ---- B7: speed effect at a glance ----------------------------------------------------------------
[f, t] = newFig(1150, 420, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
for q = 1:numel(focus)
    plot(ax, mph, R(allM == focus(q), :), '-o', 'Color', v.cat(q, :), 'MarkerFaceColor', v.cat(q, :), 'LineWidth', 2);
end
xlabel(ax, 'speed (mph)'); ylabel(ax, 'range, first transmission (m)'); set(ax, 'XTick', mph);
legend(ax, compose('MCS %d', focus(:)), 'Location', 'best', 'Box', 'off');
title(ax, 'Range against speed', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
d0 = 500;
for q = 1:numel(focus)
    Tq = arrayfun(@(k) linkThroughput(cur(k, focus(q)), snrAt(d0), 'none', slotMs), 1:numel(mph));
    plot(ax, mph, Tq, '-o', 'Color', v.cat(q, :), 'MarkerFaceColor', v.cat(q, :), 'LineWidth', 2);
end
xlabel(ax, 'speed (mph)'); ylabel(ax, sprintf('throughput at %d m (Mbit/s)', d0)); set(ax, 'XTick', mph);
title(ax, sprintf('Throughput at %d m against speed', d0), 'FontWeight', 'normal');
files{7} = saveFig(f, outDir, 'B7_speed_effect');

out.link = link; out.files = files;
d2 = fullfile('plots', 'study', 'data'); if ~isfolder(d2), mkdir(d2); end
save(fullfile(d2, 'linkLevel.mat'), 'out');
disp(out.snrTable); disp(out.range);
end

function x = firstCross(snr, bler, target)
ok = bler(:) <= target;
k = find(~ok, 1, 'last');
if isempty(k), x = snr(1); return; end
if k == numel(snr), x = NaN; return; end
x = interp1(bler(k:k + 1), snr(k:k + 1), target);
end

function r = rangeFor(snrReq, snrAt, d)
if isnan(snrReq), r = 0; return; end
ok = find(snrAt(d) >= snrReq);
if isempty(ok), r = 0; else, r = d(ok(end)); end
end

function b = blerAt(c, a, snr)
a = min(a, size(c.bler, 2));
if snr <= c.snrDb(1), b = c.bler(1, a);
elseif snr >= c.snrDb(end), b = c.bler(end, a);
else, b = interp1(c.snrDb, c.bler(:, a), snr);
end
end
