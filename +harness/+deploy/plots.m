function files = plots(r, S, outDir)
%plots Figures of a waveform-level deployment run (harness.deploy.run + ueStats).
%Inputs: r  from harness.deploy.run;  S  from harness.deploy.ueStats;  outDir  char
%Outputs: files  cellstr of PNGs written:
%   geometry.png            trajectories over the run, each UE coloured by what it receives on time
%   per_ue_reliability.png  per UE: CAM and event on-time share as a receiver, 90 % target
%   loss_causes_per_ue.png  per UE: lost copies by cause (not sent / half duplex / collision / radio)
%   latency_cdf.png         per flow, every (packet, receiver) pair, losses included, PDB marked
%   prr_vs_distance.png     on-time share vs TX-RX distance, per flow
%   cbr.png                 CBR from the received waveform's S-RSSI: over time, and per UE
%   received_spectrum.png   one received slot holding overlapping transmissions: the spectrum
%                           the receiver's ADC saw, with each transmitter's allocation marked --
%                           PA in-band emission is visible where no one transmitted
%   agc_clip.png            AGC gain distribution and ADC clipping per UE
if ~isfolder(outDir), mkdir(outDir); end
col = [42 120 214; 235 104 52; 27 175 122; 237 161 0; 232 123 164; 0 131 0; 98 80 214; 227 73 72] / 255;
bad = col(8, :); muted = [0.32 0.32 0.31];
c = r.c; N = numel(r.ues); pr = S.pairs; T = S.perUe;
files = {};

% ---- geometry & trajectories --------------------------------------------------------------
[f, ax] = fig(700, 640);
tt = 0:0.05:c.sim.durationMs / 1000;
for k = 1:numel(tt)
    p = harness.deploy.positions(r.drop, tt(k), c.field.sizeM);
    plot(ax, p(:, 1), p(:, 2), '.', 'Color', [0.8 0.8 0.8], 'MarkerSize', 4);
end
pEnd = harness.deploy.positions(r.drop, tt(end), c.field.sizeM);
scatter(ax, pEnd(:, 1), pEnd(:, 2), 70, T.camOnTimeRx, 'filled', 'MarkerEdgeColor', 'w');
for u = 1:N, text(ax, pEnd(u, 1) + 6, pEnd(u, 2), num2str(u), 'FontSize', 7, 'Color', muted); end
colormap(ax, parula); cb = colorbar(ax); cb.Label.String = 'CAM received on time (as receiver)';
axis(ax, 'equal'); xlim(ax, [0 c.field.sizeM(1)]); ylim(ax, [0 c.field.sizeM(2)]);
xlabel(ax, 'x (m)'); ylabel(ax, 'y (m)');
title(ax, sprintf('%d moving UEs (%g-%g km/h), %.1f s; grey = trajectories', N, c.ue.speedKmh, ...
    c.sim.durationMs / 1000), 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'geometry');

% ---- per-UE reliability -------------------------------------------------------------------
[f, ax] = fig(1100, 420);
b = bar(ax, T.ue, [T.camOnTimeRx T.evtOnTimeRx], 0.85, 'EdgeColor', 'none');
b(1).FaceColor = col(1, :); b(2).FaceColor = col(2, :);
yline(ax, 0.9, ':', '1 - PER', 'Color', muted);
badUe = T.ue(T.camOnTimeRx < 0.9 | T.evtOnTimeRx < 0.9);
for u = badUe', xline(ax, u, '-', 'Color', [bad 0.25], 'LineWidth', 6); end
ylim(ax, [max(0, min([T.camOnTimeRx; T.evtOnTimeRx], [], 'omitnan') - 0.05) 1.01]);
xlabel(ax, 'UE'); ylabel(ax, 'pairs received within PDB');
legend(ax, {'CAM (PQI 58, 100 ms)', 'event (PQI 56, 20 ms)'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
title(ax, sprintf('Per-UE reception within PDB (red band: below 90 %% for at least one flow, %d UEs)', numel(badUe)), 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'per_ue_reliability');

% ---- loss causes per UE -------------------------------------------------------------------
[f, ax] = fig(1100, 420);
b = bar(ax, T.ue, [T.lostNotSent T.lostHalfDuplex T.lostCollision T.lostRadio], 0.85, 'stacked', 'EdgeColor', 'w');
causeCol = col([4 7 8 1], :);
for q = 1:4, b(q).FaceColor = causeCol(q, :); end
xlabel(ax, 'UE (as receiver)'); ylabel(ax, 'lost (packet, receiver) pairs');
legend(ax, {'not sent', 'half duplex', 'collision', 'radio (path loss, fading, hardware)'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
title(ax, 'Why each UE lost what it lost', 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'loss_causes_per_ue');

% ---- latency CDF --------------------------------------------------------------------------
[f, t] = fig(1100, 420, 1, 2);
names = {'CAM (PQI 58)', 'event (PQI 56)'};
for ti = 1:2
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    m = pr.type == ti; lat = sort(pr.latMs(m & ~isnan(pr.latMs)));
    plot(ax, lat, (1:numel(lat)) / nnz(m), '-', 'Color', col(ti, :), 'LineWidth', 2);
    pdbMs = S.flow.pdbMs(ti);
    xline(ax, pdbMs, ':', 'PDB', 'Color', bad, 'LineWidth', 1.5); yline(ax, 0.9, ':', '1 - PER', 'Color', muted);
    xlim(ax, [0 1.3 * pdbMs]); ylim(ax, [0 1.02]);
    xlabel(ax, 'latency (ms)'); ylabel(ax, 'fraction of pairs');
    title(ax, sprintf('%s: %.1f %% on time of %d pairs (%s)', names{ti}, 100 * S.flow.onTimeShare(ti), ...
        S.flow.pairs(ti), S.flow.verdict{ti}), 'FontWeight', 'normal');
end
files{end + 1} = save_(f, outDir, 'latency_cdf');

% ---- PRR vs distance ----------------------------------------------------------------------
[f, ax] = fig(820, 420);
e = 0:50:c.sim.rangeM; ctr = e(1:end - 1) + 25;
for ti = 1:2
    v = nan(1, numel(ctr));
    for k = 1:numel(ctr)
        m = pr.type == ti & pr.distM >= e(k) & pr.distM < e(k + 1);
        if nnz(m) >= 10, v(k) = mean(pr.onTime(m)); end
    end
    plot(ax, ctr, v, '-o', 'Color', col(ti, :), 'MarkerFaceColor', col(ti, :), 'LineWidth', 2);
end
yline(ax, 0.9, ':', '1 - PER', 'Color', muted); ylim(ax, [0 1.02]);
xlabel(ax, 'TX-RX distance at generation (m)'); ylabel(ax, 'pairs within PDB');
legend(ax, names, 'Location', 'southwest', 'Box', 'off');
title(ax, 'On-time reception vs distance (waveform level, all losses counted)', 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'prr_vs_distance');

% ---- CBR ----------------------------------------------------------------------------------
[f, t] = fig(1100, 420, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
ts = (1:r.nSlots) * r.g.slotMs / 1000;
cb = S.cbrTimeline;
fill(ax, [ts fliplr(ts)], [min(cb, [], 1, 'omitnan') fliplr(max(cb, [], 1, 'omitnan'))], col(1, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(ax, ts, mean(cb, 1, 'omitnan'), '-', 'Color', col(1, :), 'LineWidth', 2);
xlabel(ax, 'time (s)'); ylabel(ax, 'CBR'); title(ax, 'CBR from received S-RSSI (mean, min-max over UEs)', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
bar(ax, T.ue, T.cbrMean, 0.8, 'FaceColor', col(1, :), 'EdgeColor', 'none');
xlabel(ax, 'UE'); ylabel(ax, 'mean CBR'); title(ax, 'Per-UE mean CBR', 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'cbr');

% ---- received spectrum of one overlapped slot -------------------------------------------
if ~isempty(r.example) && ~isempty(r.example.y)
    g = r.g; ex = r.example;
    Gs = phy.lib.ofdmDemod(ex.y, g.nSubcarriers, g.mu, mod(ex.slot, 10 * 2^g.mu));
    psd = 10 * log10(mean(abs(Gs(:, g.firstSymbol + (0:g.ld - 1) + 1)).^2, 2) + eps);
    [f, ax] = fig(1000, 440);
    prb = (0:g.nSubcarriers - 1) / 12;
    plot(ax, prb, psd - max(psd), '-', 'Color', col(1, :), 'LineWidth', 1);
    txAt = r.txLog([r.txLog.ms] == ex.slot * g.slotMs);
    for q = 1:numel(txAt)
        lo = g.subchStartRb(txAt(q).startSubch + 1); hi = lo + txAt(q).LsubCH * g.subchSizeRb;
        patch(ax, [lo hi hi lo], [-80 -80 5 5], col(2 + mod(q, 5), :), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
        text(ax, (lo + hi) / 2, 2, sprintf('UE %d', txAt(q).ue), 'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    xlabel(ax, 'PRB'); ylabel(ax, 'received power per subcarrier, dB rel. peak');
    ylim(ax, [-80 6]);
    title(ax, sprintf('UE %d, slot %d: %d overlapping arrivals at %s dBm; shaded = allocations', ex.ue, ex.slot, ...
        size(ex.arrivals, 1), mat2str(round(ex.arrivals(:, 3)'))), 'FontWeight', 'normal');
    files{end + 1} = save_(f, outDir, 'received_spectrum');
end

% ---- AGC & clipping -----------------------------------------------------------------------
[f, t] = fig(1100, 400, 1, 2);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
a = r.agc(~isnan(r.agc));
histogram(ax, a, 40, 'FaceColor', col(3, :), 'EdgeColor', 'w');
xlabel(ax, 'AGC gain before the ADC (dB)'); ylabel(ax, 'slots'); title(ax, 'AGC gain: the near-far spread', 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
bar(ax, T.ue, T.clipPct, 0.8, 'FaceColor', bad, 'EdgeColor', 'none');
xlabel(ax, 'UE'); ylabel(ax, 'ADC samples clipped (%)'); title(ax, 'Clipping: later symbols stronger than the AGC symbol', 'FontWeight', 'normal');
files{end + 1} = save_(f, outDir, 'agc_clip');
end

function [f, ax] = fig(w, h, nr, nc)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 w h]);
set(f, 'DefaultAxesFontSize', 11, 'DefaultAxesBox', 'off', 'DefaultAxesTickDir', 'out');
if nargin > 2
    ax = tiledlayout(f, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');
else
    ax = axes(f); hold(ax, 'on'); grid(ax, 'on');
end
end

function file = save_(f, outDir, name)
file = fullfile(outDir, [name '.png']);
exportgraphics(f, file, 'Resolution', 150, 'BackgroundColor', 'white');
close(f);
end
