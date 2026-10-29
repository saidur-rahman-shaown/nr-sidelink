function files = plotField(r, outDir)
%plotField Save the figures of one field run as PNGs in outDir (created if absent).
%Spec:   none -- a harness view of harness.field.run's output. Every number plotted comes from
%        r (the application-level packet/delivery records, the transmit log, the config); nothing
%        is read from inside a UE.
%Inputs: r       struct from harness.field.run
%        outDir  char -- folder for the PNGs, e.g. 'plots/field'
%Outputs: files  1 x F cellstr -- the files written:
%          geometry_field.png     static UEs (all speeds 0): the field, the UEs, every link drawn
%                                 and coloured by its SNR, the unicast pair, the DENM source
%          geometry_road.png      moving UEs: the road at t = 0 and t = end, lanes, paths, links
%          geometry_spacetime.png moving UEs only: position along the road vs time
%          prr_vs_distance.png    broadcast PRR of every directed link against its distance
%          collisions.png         collided vs clean outcomes, the capture effect vs SIR, per UE
%          link_snr.png           per-link SNR matrix at t = 0 (path loss only)
%          latency_cdf.png        per-flow latency CDF against each flow's PDB
%          latency_timeline.png   every delivered copy's latency vs its generation time
%          resource_grid.png      PSSCH occupancy: time x sub-channel, coloured by UE

if ~exist(outDir, 'dir'), mkdir(outDir); end
c = r.c;
N = numel(c.ue.x);
T = c.sim.durationMs / 1000;
col = lines(N);
files = {};
FLOWS = {'cam', 'denm', 'uni'};
FLOW_NAME = {'CAM (PQI 58, broadcast)', 'DENM (PQI 56, broadcast)', 'Unicast (PQI 23)'};

% ---- geometry -------------------------------------------------------------------------------
if all(c.ue.vMps == 0)
    f = newFig(760, 700);
    hold on;
    sz = c.field.sizeM;
    rectangle('Position', [0 0 sz], 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5, 'FaceColor', [0.96 0.97 0.93]);
    snrLim = [min(r.linkSnrDb(:), [], 'omitnan'), max(r.linkSnrDb(:), [], 'omitnan')];
    cmap = parula(256);
    for i = 1:N
        for j = i + 1:N
            v = (min(r.linkSnrDb(i, j), r.linkSnrDb(j, i)) - snrLim(1)) / max(diff(snrLim), eps);
            cc = cmap(1 + round(v * 255), :);
            plot([c.ue.x(i) c.ue.x(j)], [c.ue.y(i) c.ue.y(j)], '-', 'Color', cc, 'LineWidth', 2.5);
            text(mean([c.ue.x(i) c.ue.x(j)]), mean([c.ue.y(i) c.ue.y(j)]), ...
                sprintf('%.0f m\n%.1f dB', hypot(c.ue.x(i) - c.ue.x(j), c.ue.y(i) - c.ue.y(j)), r.linkSnrDb(i, j)), ...
                'FontSize', 7, 'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1 0.7]);
        end
    end
    plot(c.ue.x([c.uni.from c.uni.to]), c.ue.y([c.uni.from c.uni.to]), 'k--', 'LineWidth', 1.5);
    for u = 1:N
        plot(c.ue.x(u), c.ue.y(u), 'o', 'MarkerSize', 14, 'MarkerFaceColor', col(u, :), 'MarkerEdgeColor', 'k');
        text(c.ue.x(u) + 30, c.ue.y(u) + 45, sprintf('UE%d', u), 'FontWeight', 'bold');
    end
    plot(c.ue.x(c.denm.ueIdx), c.ue.y(c.denm.ueIdx), 'rp', 'MarkerSize', 22, 'LineWidth', 1.5);
    colormap(cmap); clim(snrLim); cb = colorbar; cb.Label.String = 'link SNR per RE, 10-PRB PSSCH (dB)';
    axis equal; xlim([-50 sz(1) + 50]); ylim([-50 sz(2) + 50]);
    xlabel('x (m)'); ylabel('y (m)');
    title({sprintf('%d static UEs, random drop (seed %d) in a %g x %g m field', N, c.ue.placementSeed, sz), ...
        sprintf('red star = DENM source UE%d; dashed = unicast UE%d -> UE%d', c.denm.ueIdx, c.uni.from, c.uni.to)});
    files{end + 1} = save1(f, outDir, 'geometry_field.png');
else
    % ---- geometry: the road at the start and the end --------------------------------------------
    f = newFig(1100, 420);
    x0 = c.ue.x; x1 = c.ue.x + c.ue.vMps * T; y = c.ue.y;
    xl = [min([x0 x1]) - 60, max([x0 x1]) + 60];
    hold on;
    fill([xl fliplr(xl)], [-2 -2 5.5 5.5], [0.85 0.85 0.85], 'EdgeColor', 'none');
    plot(xl, [1.75 1.75], 'w--', 'LineWidth', 1.5);
    for i = 1:N
        for j = i + 1:N
            plot([x0(i) x0(j)], [y(i) y(j)], ':', 'Color', [0.5 0.5 0.5]);
        end
    end
    for u = 1:N
        plot(x0(u), y(u), 'o', 'MarkerSize', 11, 'MarkerFaceColor', col(u, :), 'MarkerEdgeColor', 'k');
        plot(x1(u), y(u), '^', 'MarkerSize', 9, 'MarkerFaceColor', col(u, :), 'MarkerEdgeColor', 'k');
        plot([x0(u), x1(u)], [y(u) y(u)] + 0.6, '-', 'Color', col(u, :), 'LineWidth', 2);   % path over the run
        text(x0(u), y(u) - 1.1, sprintf('UE%d  %.0f km/h', u, abs(c.ue.vMps(u)) * 3.6), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end
    plot(x0(c.denm.ueIdx) + c.ue.vMps(c.denm.ueIdx) * c.denm.startMs / 1000, y(c.denm.ueIdx), 'rp', ...
        'MarkerSize', 16, 'MarkerFaceColor', 'r');
    xlim(xl); ylim([-2.5 6]);
    xlabel('position along the road (m)'); ylabel('lateral (m)');
    text(xl(1) + 5, -1.8, 'lane 0', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
    text(xl(1) + 5, 4.6, 'lane 1 (3.5 m)', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
    title(sprintf(['UE geometry: o at t = 0, \\Delta at t = %.1f s (bar = path travelled), ' ...
        'red star = DENM trigger (UE%d, t = %d ms); dotted = links at t = 0'], T, c.denm.ueIdx, c.denm.startMs));
    files{end + 1} = save1(f, outDir, 'geometry_road.png');

    % ---- geometry: space-time -------------------------------------------------------------------
    f = newFig(800, 500);
    t = linspace(0, T, 100);
    hold on;
    for u = 1:N
        plot(t * 1000, c.ue.x(u) + c.ue.vMps(u) * t, 'LineWidth', 2, 'Color', col(u, :));
    end
    xline(c.denm.startMs, 'r--', 'DENM trigger');
    xlabel('time (ms)'); ylabel('position along the road (m)');
    legend(arrayfun(@(u) sprintf('UE%d', u), 1:N, 'UniformOutput', false), 'Location', 'best');
    title('UE trajectories (UE5 oncoming): the distances, and so the path losses, change every slot');
    grid on;
    files{end + 1} = save1(f, outDir, 'geometry_spacetime.png');
end

% ---- link SNR -----------------------------------------------------------------------------
f = newFig(560, 480);
imagesc(r.linkSnrDb); axis square; colorbar;
colormap(parula);
for i = 1:N
    for j = 1:N
        if i ~= j
            text(j, i, sprintf('%.1f', r.linkSnrDb(i, j)), 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
end
set(gca, 'XTick', 1:N, 'YTick', 1:N);
xlabel('receiver UE'); ylabel('transmitter UE');
title({'SNR per RE at t = 0 (dB)', '10-PRB PSSCH, 23 dBm, RMa LOS, no fading'});
files{end + 1} = save1(f, outDir, 'link_snr.png');

% ---- latency: CDF and timeline ------------------------------------------------------------
lat = cell(1, 3); gen = cell(1, 3); pdb = zeros(1, 3);
for k = 1:3
    P = r.pkt(strcmp({r.pkt.type}, FLOWS{k}));
    if isempty(P), continue; end
    pdb(k) = P(1).pdbMs;
    for p = P
        hit = r.rx([r.rx.id] == p.id);
        for h = hit
            lat{k}(end + 1) = h.rxMs - p.genMs;
            gen{k}(end + 1) = p.genMs;
        end
    end
end
f = newFig(800, 500);
hold on;
fc = [0 0.45 0.74; 0.85 0.33 0.1; 0.47 0.67 0.19];
for k = 1:3
    if isempty(lat{k}), continue; end
    v = sort(lat{k});
    stairs([0 v], [0 (1:numel(v)) / numel(v)], 'LineWidth', 2, 'Color', fc(k, :));
end
for k = 1:3
    if pdb(k) > 0, xline(pdb(k), '--', sprintf('PDB %d ms', pdb(k)), 'Color', fc(k, :)); end
end
xlabel('application-to-application latency (ms)'); ylabel('CDF of delivered copies');
legend(FLOW_NAME(~cellfun(@isempty, lat)), 'Location', 'southeast');
title(sprintf('Latency per flow (T2 cap: %s)', capLabel(c)));
grid on; xlim([0 max(pdb) * 1.1]);
files{end + 1} = save1(f, outDir, 'latency_cdf.png');

f = newFig(900, 450);
hold on;
for k = 1:3
    if ~isempty(lat{k}), plot(gen{k}, lat{k}, '.', 'MarkerSize', 12, 'Color', fc(k, :)); end
end
for k = 1:3
    if pdb(k) > 0, yline(pdb(k), '--', 'Color', fc(k, :)); end
end
xline(c.denm.startMs, 'r:', 'DENM trigger');
xlabel('generation time (ms)'); ylabel('latency (ms)');
legend(FLOW_NAME(~cellfun(@isempty, lat)), 'Location', 'northwest');
title('Latency of every delivered copy; dashed = that flow''s PDB');
grid on;
files{end + 1} = save1(f, outDir, 'latency_timeline.png');

% ---- resource occupancy: the whole run, and a zoom on the DENM event ------------------------
% Each PSSCH is a vertical bar over its sub-channels at its slot. Bars have a fixed on-screen
% width -- a 0.5 ms slot is a sliver at this scale -- so position, not width, is the information.
f = newFig(1200, 700);
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact');
zoom = c.denm.startMs + [-20 140];
for panel = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for q = r.txLog
        xc = q.ms + r.ues(1).g.slotMs / 2;
        cc = col(q.ue, :);
        if q.isRetx, cc = 1 - 0.45 * (1 - cc); end
        plot(ax, [xc xc], [q.startSubch, q.startSubch + q.LsubCH] + [0.05 -0.05], '-', ...
            'Color', cc, 'LineWidth', 2 + 3 * (panel == 2));
    end
    for e = harness.field.collisions(r).events
        lo = min(e.startSubch); hi = max(e.startSubch + e.LsubCH);
        plot(ax, e.ms + r.ues(1).g.slotMs / 2, hi + 0.12, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 5 + 2 * (panel == 2));
        if panel == 2, plot(ax, e.ms + r.ues(1).g.slotMs / 2 + [0 0], [lo hi], 'r-', 'LineWidth', 0.75); end
    end
    hs = gobjects(1, N);
    for u = 1:N, hs(u) = plot(ax, nan, nan, '-', 'Color', col(u, :), 'LineWidth', 4); end
    xline(ax, c.denm.startMs, 'r:', 'DENM trigger');
    ylim(ax, [0 r.ues(1).g.numSubchannel + 0.3]); set(ax, 'YTick', 0:r.ues(1).g.numSubchannel);
    ylabel(ax, 'sub-channel'); grid(ax, 'on');
    if panel == 1
        xlim(ax, [0 c.sim.durationMs]);
        title(ax, 'PSSCH occupancy, whole run (bright = initial transmission, pale = retransmission, red \\nabla = collision)');
        legend(ax, hs, arrayfun(@(u) sprintf('UE%d', u), 1:N, 'UniformOutput', false), 'Location', 'eastoutside');
    else
        xlim(ax, zoom);
        title(ax, sprintf('Zoom %d-%d ms: the DENM burst from UE%d; bars at the same time on the same sub-channels are collisions', ...
            zoom(1), zoom(2), c.denm.ueIdx));
        legend(ax, hs, arrayfun(@(u) sprintf('UE%d', u), 1:N, 'UniformOutput', false), 'Location', 'eastoutside');
    end
end
xlabel(tl, 'time (ms)');
files{end + 1} = save1(f, outDir, 'resource_grid.png');

% ---- PRR per directed link vs distance (broadcast copies: CAM + DENM) ------------------------
f = newFig(760, 460);
hold on;
pts = zeros(0, 4);                                   % [d prr i j]
for i = 1:N
    for j = setdiff(1:N, i)
        P = r.pkt([r.pkt.src] == i & [r.pkt.dst] == 0 & [r.pkt.genMs] + [r.pkt.pdbMs] <= c.sim.durationMs);
        if isempty(P), continue; end
        got = 0;
        for p = P
            h = r.rx([r.rx.id] == p.id & [r.rx.rxUe] == j);
            got = got + (~isempty(h) && h(1).rxMs - p.genMs <= p.pdbMs);
        end
        pts(end + 1, :) = [hypot(c.ue.x(i) - c.ue.x(j), c.ue.y(i) - c.ue.y(j)), got / numel(P), i, j]; %#ok<AGROW>
    end
end
scatter(pts(:, 1), pts(:, 2), 70, arrayfun(@(q) r.linkSnrDb(pts(q, 3), pts(q, 4)), 1:size(pts, 1))', 'filled', ...
    'MarkerEdgeColor', 'k');
for q = 1:size(pts, 1)
    up = pts(q, 3) < pts(q, 4);                        % i->j above the point, j->i below: same distance
    text(pts(q, 1) + 12, pts(q, 2) + 0.035 * (2 * up - 1), sprintf('%d\\rightarrow%d', pts(q, 3), pts(q, 4)), 'FontSize', 8);
end
cb = colorbar; cb.Label.String = 'link SNR per RE, 10-PRB PSSCH (dB)';
xlabel('link distance (m)'); ylabel('broadcast PRR within PDB');
ylim([-0.05 1.05]); grid on;
title('Every directed link: CAM + DENM copies delivered on time / sent');
files{end + 1} = save1(f, outDir, 'prr_vs_distance.png');

% ---- collisions -----------------------------------------------------------------------------
k = harness.field.collisions(r);
f = newFig(1350, 430);
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
ax = nexttile(tl);
frac = k.outcome ./ max(sum(k.outcome, 2), 1);
b = bar(ax, frac, 'stacked');
oc = [0.2 0.65 0.3; 0.95 0.7 0.1; 0.85 0.2 0.2; 0.6 0.6 0.6];
for q = 1:4, b(q).FaceColor = oc(q, :); end
set(ax, 'XTickLabel', {sprintf('clean (%d)', sum(k.outcome(1, :))), sprintf('collided (%d)', sum(k.outcome(2, :)))});
ylabel(ax, 'fraction of (initial transmission, other UE) pairs');
legend(ax, {'TB decoded', 'SCI only', 'missed', 'deaf (half duplex)'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, sprintf('%d of %d PSSCH collided (%.1f%%)', k.nCollided, k.nTx, 100 * k.nCollided / max(k.nTx, 1)));
ax = nexttile(tl); hold(ax, 'on');
if ~isempty(k.capture)
    ok = k.capture(:, 3) == 1;
    scatter(ax, k.capture(ok, 1), k.capture(ok, 2), 40, oc(1, :), 'filled');
    scatter(ax, k.capture(~ok, 1), k.capture(~ok, 2), 40, oc(3, :), 'x', 'LineWidth', 1.5);
    xline(ax, 0, 'k:');
    legend(ax, {'decoded through the collision', 'lost'}, 'Location', 'southoutside');
end
xlabel(ax, 'SIR at the receiver: wanted - strongest interferer (dB)'); ylabel(ax, 'wanted link SNR (dB)');
title(ax, 'Capture effect: who survives a collision'); grid(ax, 'on');
ax = nexttile(tl);
bar(ax, k.byUe);
xlabel(ax, 'transmitting UE'); ylabel(ax, 'PSSCH transmissions');
legend(ax, {'sent', 'collided', 'slot shared (half duplex)'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
title(ax, 'Per UE'); grid(ax, 'on');
files{end + 1} = save1(f, outDir, 'collisions.png');
end

% =========================================================================================
function f = newFig(w, h)
f = figure('Visible', 'off', 'Position', [100 100 w h], 'Color', 'w');
end

function file = save1(f, outDir, name)
file = fullfile(outDir, name);
exportgraphics(f, file, 'Resolution', 150);
close(f);
end

function s = capLabel(c)
if isfield(c, 'impl') && isfield(c.impl, 't2MaxMs') && isfinite(c.impl.t2MaxMs)
    s = sprintf('%g ms', c.impl.t2MaxMs);
else
    s = 'none, T2 = remaining PDB';
end
end
