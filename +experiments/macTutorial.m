function out = macTutorial(s)
%macTutorial Study Part A: the Mode-2 MAC procedures, one picture at a time.
%Spec:   TS 38.214 V16.17.0 clause 8.1.4 (sensing, candidate set S_A, exclusion, escalation), 8.1.5
%        (TRIV/FRIV chained resources), Tables 8.1.4-1/-2 (T_proc,0 / T_proc,1); TS 38.321 clause
%        5.22.1.1 (SPS counter, sl-ProbResourceKeep). Every step below calls the repo's verified
%        implementation of that clause (phy.ts38214.sensingDbRecord, candidateSet,
%        phy.rx.policy.resourcePickChained, mac.creselCounterRange); nothing is redrawn by hand.
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct of the numbers each figure shows
%Window policy used throughout (UE implementation, inside the spec's bounds):
%   T1 = T_proc,1 = 5 slots at mu = 1 -- the largest T1 the spec allows at this numerology;
%   T2 = PDB - 3 slots                -- the transmission slot itself, then 2 slots for the receiver
%                                        to decode, all inside the PDB (settings().op: txSlots = 1,
%                                        rxProcSlots = 2). Latency = (TX slot - arrival) + 3 slots,
%                                        so the minimum is T1 + 3 slots = 4 ms and the maximum is
%                                        the PDB itself.
%PQIs: broadcast may use only the Non-GBR rows of TS 23.287 Table 5.4.4-1, PQI 55..59 (NOTE 1).
%Figures (plots/study/A_mac/):
%   A1_window_timeline.png     where sensing, processing, selection and the deadline sit in time
%   A2_latency_bounds.png      the minimum, mean and maximum latency the procedure allows, per PDB
%   A3_sensed_scis.png         decoded SCIs in the sensing window: widths, periods, chained resources
%   A4_exclusion.png           their reservations projected into the selection window; what survives
%   A5_threshold.png           how S_A grows as the RSRP threshold rises (the escalation rule)
%   A6_sps_reservation.png     the selected resource repeating every period (SPS)
%   A7_sps_in_action.png       SPS in a running system-level simulation, every UE's resource over time
%   A8_event_selection.png     an aperiodic (event) selection: one-shot, nothing announced in advance
%   A9_per_packet_latency.png  1000 packets of every broadcast PQI on an empty channel: each one's
%                              latency against its PDB (none may exceed it)
if nargin < 1 || isempty(s), s = experiments.settings(); end
outDir = fullfile('plots', 'study', 'A_mac');
v = viz();
mu = 1; slotMs = 0.5; spm = 2;                       % slots per ms at mu = 1
T1 = phy.ts38214.procTimeSelection(mu);              % T_proc,1 = 5 slots
Tp0 = phy.ts38214.procTimeSensing(mu);               % T_proc,0
T0ms = 100;                                          % sl-SensingWindow
PIPE = s.op.txSlots + s.op.rxProcSlots;              % transmission slot + 2 to receive = 3 (TB built during T1)
NSUB = s.op.numSubchannel;
TRIV_REACH = 31;                                     % TS 38.214 8.1.5: chained resources 1..31 slots
pqi = cfg.pqiTable();
bc = pqi(~[pqi.unicastOnly]);                         % broadcast: PQI 55..59 (Table 5.4.4-1 NOTE 1)

% ===================== A1: the window timeline ============================================
PDB = 100;
[f, ax] = newFig(1100, 330);
bands = { -T0ms, -Tp0 * slotMs, 'sensing window T_0 = 100 ms (decoded SCIs recorded)', v.cat(1, :); ...
    -Tp0 * slotMs, 0, '', [0.6 0.6 0.6]; ...
    0, T1 * slotMs, 'T_1 = T_{proc,1}', v.cat(4, :); ...
    T1 * slotMs, PDB - PIPE * slotMs, 'selection window [n+T_1, n+T_2], T_2 = PDB - 3 slots', v.cat(3, :); ...
    PDB - PIPE * slotMs, PDB, '', v.cat(8, :)};
for k = 1:size(bands, 1)
    patch(ax, [bands{k, 1} bands{k, 2} bands{k, 2} bands{k, 1}], [0 0 1 1], bands{k, 4}, 'FaceAlpha', 0.35, 'EdgeColor', 'none');
    if ~isempty(bands{k, 3})
        text(ax, mean([bands{k, 1:2}]), 0.5, bands{k, 3}, 'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end
xline(ax, 0, '-', 'packet arrives (n)', 'LineWidth', 2, 'LabelVerticalAlignment', 'top');
xline(ax, PDB, '-', 'PDB deadline', 'Color', v.status.bad, 'LineWidth', 2, 'LabelVerticalAlignment', 'top');
text(ax, PDB - 0.5, 1.15, 'last TX slot (1) + reception (2)', 'FontSize', 8, 'HorizontalAlignment', 'right');
text(ax, -0.5, -0.15, sprintf('T_{proc,0} = %d slot', Tp0), 'FontSize', 8, 'HorizontalAlignment', 'right');
plot(ax, [40 40 + TRIV_REACH * slotMs], [0.85 0.85], '-', 'Color', v.ink, 'LineWidth', 2);
text(ax, 40 + TRIV_REACH * slotMs / 2, 0.92, 'chained retx: within 31 slots of the first TX', 'HorizontalAlignment', 'center', 'FontSize', 8);
xlim(ax, [-110 110]); ylim(ax, [-0.3 1.3]); set(ax, 'YTick', []);
xlabel(ax, 'time relative to the packet''s arrival (ms), PDB = 100 ms, \mu = 1 (0.5 ms slots)');
title(ax, sprintf('When a Mode-2 UE senses, selects and must deliver (T_1 = %d slots = %.1f ms)', T1, T1 * slotMs), 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'A1_window_timeline');

% ===================== A2: the latency the procedure allows ================================
% Delivered latency = (TX slot - arrival) + PIPE slots; the TX slot is drawn in [T1, T2].
T2s  = [bc.PDB_ms] * spm - PIPE;                      % last TX slot offset per PQI
pdbs = [bc.PDB_ms];
lo   = (T1 + PIPE) * slotMs * ones(size(pdbs));       % earliest delivery: 4 ms
hi   = (T2s + PIPE) * slotMs;                         % latest delivery: exactly the PDB
mid  = ((T1 + T2s) / 2 + PIPE) * slotMs;              % mean of a uniform draw
[f, ax] = newFig(900, 440);
[ps, ord] = sort(pdbs);
fill(ax, [ps fliplr(ps)], [lo(ord) fliplr(hi(ord))], v.cat(1, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
plot(ax, ps, lo(ord), '-o', 'Color', v.cat(3, :), 'MarkerFaceColor', v.cat(3, :));
plot(ax, ps, mid(ord), '-o', 'Color', v.cat(1, :), 'MarkerFaceColor', v.cat(1, :));
plot(ax, ps, hi(ord), '-o', 'Color', v.cat(8, :), 'MarkerFaceColor', v.cat(8, :));
for q = 1:numel(bc)
    text(ax, pdbs(q) * 1.06, mid(q), sprintf('PQI %d', bc(q).PQI), 'FontSize', 9);
end
set(ax, 'XScale', 'log', 'YScale', 'log', 'XTick', unique(ps));
xlabel(ax, 'packet delay budget (ms)'); ylabel(ax, 'delivered latency (ms)');
legend(ax, {'range the procedure allows', sprintf('minimum: T_1 + 3 slots = %.1f ms', (T1 + PIPE) * slotMs), ...
    'mean of a uniform draw', 'maximum: T_2 + 3 slots = PDB'}, 'Location', 'northwest', 'Box', 'off');
title(ax, {'Latency a Mode-2 UE can deliver for each broadcast PQI (TS 23.287 Table 5.4.4-1, Non-GBR)', ...
    'TX slot drawn in [n + T_1, n + PDB - 3 slots], then 1 slot on the air and 2 slots to receive'}, 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'A2_latency_bounds');
rows = {};
for q = 1:numel(bc)
    rows(end + 1, :) = {bc(q).PQI, bc(q).priority, bc(q).PDB_ms, bc(q).PER, T1, T2s(q), lo(q), mid(q), hi(q)}; %#ok<AGROW>
end
out.latencyBounds = cell2table(rows, 'VariableNames', {'pqi', 'priority', 'pdbMs', 'per', 'T1slots', 'T2slots', 'minMs', 'meanMs', 'maxMs'});

% ===================== A3: what one UE sensed ==============================================
n = 400;                                              % the selection trigger, logical slot
nb = struct('name', {'A', 'B', 'C', 'D', 'E', 'F'}, ...
    'L', {1, 2, 3, 1, 4, 2}, 'x', {0, 1, 2, 4, 1, 3}, 'periodMs', {100, 100, 50, 100, 100, 20}, ...
    'prio', {6, 6, 6, 3, 6, 6}, 'rsrp', {-95, -85, -100, -118, -105, -90}, ...
    'lastRx', {n - 180, n - 150, n - 90, n - 120, n - 60, n - 10}, 'chainOff', {4, 10, 6, 12, 0, 3}, ...
    'chainX', {3, 3, 0, 1, 0, 0});
db = phy.ts38214.sensingDbInit();
recs = zeros(0, 7);                                   % [slot x L rsrp chainSlot chainX nbIdx]
for k = 1:numel(nb)
    P = nb(k).periodMs * spm;
    for t = nb(k).lastRx:-P:n - T0ms * spm
        nRes = 1 + (nb(k).chainOff > 0);
        db = phy.ts38214.sensingDbRecord(db, t, nb(k).x, nb(k).L, nb(k).prio, nb(k).rsrp, true, ...
            nb(k).periodMs, nRes, nb(k).chainOff, 0, nb(k).chainX, 0);
        recs(end + 1, :) = [t nb(k).x nb(k).L nb(k).rsrp t + nb(k).chainOff nb(k).chainX k]; %#ok<AGROW>
    end
end
ownTx = n - 70;                                       % the UE itself transmitted here: half duplex
db = phy.ts38214.sensingDbMarkUnmonitored(db, ownTx);
[f, ax] = newFig(1100, 430);
cm = v.seq; colormap(ax, cm); rlo = -125; rhi = -80;
for r = 1:size(recs, 1)
    c = cm(max(1, min(256, round(1 + 255 * (recs(r, 4) - rlo) / (rhi - rlo)))), :);
    rectangle(ax, 'Position', [(recs(r, 1) - n) * slotMs, recs(r, 2), slotMs * 1.6, recs(r, 3)], 'FaceColor', c, 'EdgeColor', v.ink);
    text(ax, (recs(r, 1) - n) * slotMs - 0.6, recs(r, 2) + recs(r, 3) / 2, nb(recs(r, 7)).name, 'FontSize', 10, ...
        'Color', v.ink, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    if nb(recs(r, 7)).chainOff > 0
        rectangle(ax, 'Position', [(recs(r, 5) - n) * slotMs, recs(r, 6), slotMs * 1.6, recs(r, 3)], 'EdgeColor', c, 'LineStyle', '--', 'LineWidth', 1.2);
        plot(ax, [(recs(r, 1) - n) * slotMs + 0.8, (recs(r, 5) - n) * slotMs + 0.8], [recs(r, 2) + recs(r, 3) / 2, recs(r, 6) + recs(r, 3) / 2], ':', 'Color', c);
    end
end
xline(ax, (ownTx - n) * slotMs, '-', 'own TX: not sensed', 'Color', v.status.bad, 'LineWidth', 2, 'LabelOrientation', 'horizontal');
clim(ax, [rlo rhi]); cb = colorbar(ax); cb.Label.String = 'SL-RSRP per RE (dBm)';
xlim(ax, [-T0ms 2]); ylim(ax, [0 NSUB]); set(ax, 'YTick', 0:NSUB);
xlabel(ax, 'time before the trigger n (ms): the 100 ms sensing window'); ylabel(ax, 'sub-channel');
title(ax, {'What the UE decoded: each block is one SCI (height = its L_{subCH}), dashed = its chained retransmission (TRIV/FRIV)', ...
    'A, B, D, E reserve every 100 ms; C every 50 ms; F every 20 ms; D was heard below the threshold'}, 'FontWeight', 'normal');
files{3} = saveFig(f, outDir, 'A3_sensed_scis');
out.neighbours = struct2table(rmfield(nb, {'chainOff', 'chainX'}));

% ===================== A4: exclusion in the selection window ===============================
myL = 2; PDBsps = 100;
req = struct('n', n, 'T1', T1, 'T2', PDBsps * spm - PIPE, 'remainingPdbSlots', PDBsps * spm - PIPE, ...
    'LsubCH', myL, 'prioTx', 6, 'prsvpTxMs', 100, 'Cresel', 10);
thr = repmat(-110, 1, 64);
TMAXP = 10240 * spm;
[cy, cx, surv, Mt, nEsc, thrOff] = phy.ts38214.candidateSet(req, NSUB, T0ms, mu, db, thr, 0.2, [20 50 100], 20, TMAXP, 20);
[f, ax] = newFig(1100, 420);
for k = 1:numel(cy)
    c = v.cat(1, :); if ~surv(k), c = [0.86 0.86 0.86]; end
    rectangle(ax, 'Position', [(cy(k) - n) * slotMs, cx(k) + 0.05, slotMs, 0.9], 'FaceColor', c, 'EdgeColor', 'none');
end
draws = [0.37 0.61];
[ps, px] = phy.rx.policy.resourcePickChained(cy, cx, surv, draws, 2, 0);
for k = 1:numel(ps)
    rectangle(ax, 'Position', [(ps(k) - n) * slotMs, px(k), slotMs, myL], 'EdgeColor', v.cat(2, :), 'LineWidth', 2.5);
end
% Each neighbour's reservations projected into the window, as the spec projects them (period P
% repeated; F, heard within its last period, projected every 20 ms) -- outlined and labelled, so each
% grey exclusion can be traced to who caused it.
for k = 1:numel(nb)
    if nb(k).rsrp < -110, continue; end               % below the threshold: excludes nothing
    P = nb(k).periodMs * spm;
    for tt = nb(k).lastRx + P:P:n + req.T2
        if tt < n + T1, continue; end
        rectangle(ax, 'Position', [(tt - n) * slotMs, nb(k).x, slotMs, nb(k).L], 'EdgeColor', v.cat(8, :), 'LineWidth', 1.2, 'LineStyle', '--');
        text(ax, (tt - n) * slotMs + 0.7, nb(k).x + nb(k).L - 0.2, nb(k).name, 'FontSize', 8, 'Color', v.cat(8, :), 'FontWeight', 'bold');
    end
end
xlim(ax, [0 PDBsps]); ylim(ax, [0 NSUB]); set(ax, 'YTick', 0:NSUB);
xlabel(ax, 'time after the trigger (ms): selection window [n + T_1, n + T_2]'); ylabel(ax, 'start sub-channel of a candidate');
h = [patch(ax, NaN, NaN, v.cat(1, :)), patch(ax, NaN, NaN, [0.86 0.86 0.86]), plot(ax, NaN, NaN, '--', 'Color', v.cat(8, :)), plot(ax, NaN, NaN, '-', 'Color', v.cat(2, :), 'LineWidth', 2.5)];
legend(ax, h, {'candidate in S_A', 'excluded', 'a neighbour''s projected reservation (letter)', 'selected (first TX + chained retx)'}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
title(ax, {sprintf('Own UE needs L_{subCH} = %d: M_{total} = %d candidates, %d survive (%.0f %%), %d threshold raises', ...
    myL, Mt, nnz(surv), 100 * nnz(surv) / Mt, nEsc), ...
    'A candidate is excluded where it would overlap a projected reservation; D (heard below the threshold) excludes nothing'}, 'FontWeight', 'normal');
files{4} = saveFig(f, outDir, 'A4_exclusion');
out.exclusion = struct('Mtotal', Mt, 'nSA', nnz(surv), 'nEscalations', nEsc, 'thresholdOffsetDb', thrOff, ...
    'pickSlots', ps - n, 'pickSubch', px);

% ===================== A5: the threshold and escalation ===================================
ths = -140:2.5:-60; share = zeros(size(ths));
for k = 1:numel(ths)
    [~, ~, sv, M] = phy.ts38214.candidateSet(req, NSUB, T0ms, mu, db, repmat(ths(k), 1, 64), 1e-3, [20 50 100], 20, TMAXP, 1);
    share(k) = nnz(sv) / M;
end
[f, ax] = newFig(900, 420);
plot(ax, ths, 100 * share, '-', 'Color', v.cat(1, :), 'LineWidth', 2);
yline(ax, 20, ':', 'sl-TxPercentage = 20 %: S_A must reach this', 'Color', v.muted);
xline(ax, -110, '--', 'configured threshold', 'Color', v.cat(2, :));
for r = unique(recs(:, 4))'
    xline(ax, r, ':', 'Color', [0.7 0.7 0.7]);
end
xlabel(ax, 'RSRP threshold (dBm per RE); grey lines = the neighbours'' RSRP');
ylabel(ax, 'candidates surviving (%)');
title(ax, 'Each neighbour stops being excluded once the threshold passes its RSRP; if S_A < 20 %, the UE raises the threshold 3 dB at a time', 'FontWeight', 'normal');
files{5} = saveFig(f, outDir, 'A5_threshold');

% ===================== A6: semi-persistent reservation ====================================
[loC, hiC] = mac.creselCounterRange(100);
counter = round((loC + hiC) / 2);
[f, ax] = newFig(1100, 330);
for kP = 0:counter - 1
    for k = 1:numel(ps)
        tt = (ps(k) - n) * slotMs + kP * 100;
        rectangle(ax, 'Position', [tt, px(k), 4, myL], 'FaceColor', [v.cat(2, :) 0.6 - 0.3 * (k > 1)], 'EdgeColor', 'none');
    end
end
xline(ax, (ps(1) - n) * slotMs + counter * 100, '--', 'counter expires: keep (p = sl-ProbResourceKeep) or reselect', ...
    'Color', v.status.bad, 'LabelOrientation', 'horizontal');
xlim(ax, [0 (counter + 1.5) * 100]); ylim(ax, [0 NSUB]);
xlabel(ax, 'time after selection (ms)'); ylabel(ax, 'sub-channel');
title(ax, sprintf(['SPS for periodic traffic: the same resource every P_{rsvp} = 100 ms for SL\\_RESOURCE\\_RESELECTION\\_COUNTER ' ...
    '= %d periods (drawn in [%d, %d]); every SCI announces the next one'], counter, loC, hiC), 'FontWeight', 'normal');
files{6} = saveFig(f, outDir, 'A6_sps_reservation');

% ===================== A7: SPS in a running simulation =====================================
fl = struct('pqi', 58, 'periodMs', 100, 'sizeBytes', 190, 'lcid', 4, 'nPackets', inf, 'pdbMsOverride', [], 'arrival', 'periodic');
[scen, ~, drop] = fieldScenario(struct('nUe', 10, 'sizeM', [300 300], 'flows', fl, 'seed', 3, 'dropSeed', 4));
[~, L] = runLogged(scen, 6000);
[f, t] = newFig(1150, 560, 2, 1);
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
for k = 1:numel(L.air)
    a = L.air(k);
    rectangle(ax, 'Position', [a.slot * slotMs, a.startSubch, 4, a.LsubCH], 'FaceColor', v.cat(1 + mod(a.ue - 1, 8), :), 'EdgeColor', 'none');
end
for k = 1:numel(L.sel)
    plot(ax, L.sel(k).slot * slotMs, NSUB + 0.2, 'v', 'Color', v.cat(1 + mod(L.sel(k).ue - 1, 8), :), 'MarkerFaceColor', v.cat(1 + mod(L.sel(k).ue - 1, 8), :));
end
xlim(ax, [0 1500]); ylim(ax, [0 NSUB + 0.5]); xlabel(ax, 'time (ms)'); ylabel(ax, 'sub-channel');
title(ax, sprintf('%d UEs, CAM every 100 ms, sensing-based SPS: each colour keeps its resource; triangles = (re)selections', drop.N), 'FontWeight', 'normal');
ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
life = [];
for u = 1:drop.N
    ts = [L.sel([L.sel.ue] == u).slot] * slotMs;
    life = [life diff(ts)]; %#ok<AGROW>
end
histogram(ax, life, 0:100:2000, 'FaceColor', v.cat(3, :), 'EdgeColor', 'w');
xlabel(ax, 'time between a UE''s (re)selections (ms)'); ylabel(ax, 'count');
title(ax, sprintf('How long a grant lives: median %.0f ms (counter %d-%d periods, then kept with p = %.1f)', median(life), loC, hiC, scen.pool.slProbResourceKeep), 'FontWeight', 'normal');
files{7} = saveFig(f, outDir, 'A7_sps_in_action');
out.sps = struct('grantLifeMedianMs', median(life), 'nSel', numel(L.sel), 'collisionRate', mean([L.air.collided]));

% ===================== A8: event (aperiodic) selection ====================================
pdbE = unique([bc.PDB_ms]); pdbE = pdbE(pdbE <= 100);     % PQI 55, 56, 57, 58: 10, 20, 25, 100 ms
[f, t] = newFig(1150, 500, numel(pdbE), 1);
evRows = {};
for q = 1:numel(pdbE)
    T2 = pdbE(q) * spm - PIPE;
    reqE = struct('n', n, 'T1', T1, 'T2', T2, 'remainingPdbSlots', T2, 'LsubCH', myL, 'prioTx', 3, 'prsvpTxMs', 0, 'Cresel', 1);
    [ey, ex, es, eM, eEsc] = phy.ts38214.candidateSet(reqE, NSUB, T0ms, mu, db, thr, 0.2, [20 50 100], 20, TMAXP, 20);
    [eps_, epx] = phy.rx.policy.resourcePickChained(ey, ex, es, [0.5 0.5], 2, 0);
    ax = nexttile(t); hold(ax, 'on');
    for k = 1:numel(ey)
        c = v.cat(1, :); if ~es(k), c = [0.86 0.86 0.86]; end
        rectangle(ax, 'Position', [(ey(k) - n) * slotMs, ex(k) + 0.05, slotMs, 0.9], 'FaceColor', c, 'EdgeColor', 'none');
    end
    for k = 1:numel(eps_)
        rectangle(ax, 'Position', [(eps_(k) - n) * slotMs, epx(k), slotMs, myL], 'EdgeColor', v.cat(2, :), 'LineWidth', 2);
    end
    xline(ax, pdbE(q), '-', 'Color', v.status.bad, 'LineWidth', 1.5);
    xlim(ax, [0 101]); ylim(ax, [0 NSUB]); set(ax, 'YTick', []);
    ylabel(ax, sprintf('PDB %g', pdbE(q)));
    evRows(end + 1, :) = {pdbE(q), T1 * slotMs, T2 * slotMs, (T1 + PIPE) * slotMs, ((T1 + T2) / 2 + PIPE) * slotMs, ...
        (T2 + PIPE) * slotMs, eM, nnz(es), eEsc}; %#ok<AGROW>
end
xlabel(ax, 'time after the event (ms)');
title(t, {'Event traffic: a one-shot (aperiodic, P_{rsvp} = 0) selection in [n + 5, n + PDB - 3 slots] on the same sensing history', ...
    'Nothing is announced before the first transmission, so neighbours cannot avoid it; only its chained retransmission is protected'}, 'FontWeight', 'normal');
files{8} = saveFig(f, outDir, 'A8_event_selection');
out.event = cell2table(evRows, 'VariableNames', {'pdbMs', 'windowStartMs', 'windowEndMs', 'minLatMs', 'meanLatMs', 'maxLatMs', 'Mtotal', 'nSA', 'nEscalations'});

% ===================== A9: every packet within its PDB, on an empty channel =====================
out.perPacket = perPacketNoLoad(s, bc, outDir, v);
files{9} = out.perPacket.file;

out.files = files;
d = fullfile('plots', 'study', 'data'); if ~isfolder(d), mkdir(d); end
save(fullfile(d, 'macTutorial.mat'), 'out');
disp(out.latencyBounds); disp(out.exclusion); disp(out.sps); disp(out.event); disp(out.perPacket.table);
end

function R = perPacketNoLoad(s, bc, outDir, v)
%perPacketNoLoad 1000 packets of each broadcast PQI from one UE to one receiver 100 m away, nothing
%else on the channel. Each PQI keeps its own traffic shape: the lane-change PQIs (55, 57) are events
%(Poisson), the platooning and sensor-sharing PQIs (56, 58, 59) are periodic. The full SLS runs it
%(sensing, SPS, reselection on the PDB, blind retransmission), and every latency carries the
%3-slot TX/RX pipeline. A packet that is never delivered, or delivered after its PDB, is a violation.
N_PKT = 1000;
nB = numel(bc);
arrival = repmat({'periodic'}, 1, nB); arrival(ismember([bc.PQI], [55 57])) = {'poisson'};
periodMs = 100 * ones(1, nB); periodMs([bc.PQI] == 59) = 500;
sizeB = 200 * ones(1, nB); sizeB([bc.PQI] == 58) = 300;
jobs = cell(1, nB);
for q = 1:nB
    fl = struct('pqi', bc(q).PQI, 'periodMs', periodMs(q), 'sizeBytes', sizeB(q), 'lcid', 4, ...
        'nPackets', N_PKT, 'pdbMsOverride', [], 'arrival', arrival{q});
    % Long enough for N_PKT arrivals (Poisson: 30 % margin) and their PDB to close.
    nSlots = ceil((N_PKT * periodMs(q) * 1.3 + 2 * bc(q).PDB_ms) * 2^s.op.mu);
    jobs{q} = {fl, nSlots};
end
res = cell(1, nB);
if s.useParallel
    if isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end
    parfor q = 1:nB
        res{q} = oneLink(jobs{q}{1}, jobs{q}{2});
    end
else
    for q = 1:nB, res{q} = oneLink(jobs{q}{1}, jobs{q}{2}); end
end
[f, t] = newFig(1250, 640, 2, nB);
rows = {};
for q = 1:nB
    P = res{q};
    [~, o] = sort(P.tGenSlot);                        % in order of arrival
    lat = P.latMs(o); onT = P.onTime(o); cs = P.cause(o); pdb = bc(q).PDB_ms;
    nViol = nnz(~onT);
    ax = nexttile(t, q); hold(ax, 'on'); grid(ax, 'on');
    plot(ax, 1:numel(lat), lat, '.', 'Color', v.cat(q, :), 'MarkerSize', 5);
    yline(ax, pdb, '-', 'PDB', 'Color', v.status.bad, 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
    yline(ax, 4, ':', 'min 4 ms', 'Color', v.muted, 'LabelHorizontalAlignment', 'left');
    if nViol > 0, plot(ax, find(~onT), pdb * ones(1, nViol), 'x', 'Color', v.status.bad); end
    ylim(ax, [0 pdb * 1.12]); xlim(ax, [0 numel(lat) + 1]);
    xlabel(ax, 'packet'); if q == 1, ylabel(ax, 'latency (ms)'); end
    title(ax, sprintf('PQI %d: PDB %g ms, %s', bc(q).PQI, pdb, arrival{q}), 'FontWeight', 'normal');
    ax = nexttile(t, nB + q); hold(ax, 'on'); grid(ax, 'on');
    histogram(ax, lat, linspace(0, pdb, 26), 'FaceColor', v.cat(q, :), 'EdgeColor', 'w');
    xline(ax, pdb, '-', 'Color', v.status.bad, 'LineWidth', 1.5);
    xlabel(ax, 'latency (ms)'); if q == 1, ylabel(ax, 'packets'); end
    title(ax, {sprintf('max %.1f ms', max(lat)), sprintf('%d of %d over the PDB', nViol, numel(lat))}, 'FontWeight', 'normal');
    rows(end + 1, :) = {bc(q).PQI, pdb, bc(q).PER, arrival{q}, periodMs(q), numel(lat), min(lat), mean(lat, 'omitnan'), ...
        max(lat), nViol, nnz(cs == 1)}; %#ok<AGROW>
end
title(t, {'Every packet on an empty channel: 1000 per broadcast PQI, one transmitter, one receiver at 100 m', ...
    'latency = TX slot - arrival + 1 slot on the air + 2 slots to receive; red = the PDB'}, 'FontWeight', 'normal');
R.file = saveFig(f, outDir, 'A9_per_packet_latency');
R.table = cell2table(rows, 'VariableNames', {'pqi', 'pdbMs', 'per', 'arrival', 'periodOrMeanMs', 'nPackets', ...
    'minMs', 'meanMs', 'maxMs', 'nOverPdb', 'nNotSent'});
end

function P = oneLink(fl, nSlots)
[scen, ~, ~] = fieldScenario(struct('nUe', 2, 'sizeM', [100 100], 'flows', fl, 'mcs', 11, ...
    'txUeIds', 1, 'seed', 5, 'dropSeed', 6));
scen.posXY = [0 0; 100 0];
[~, L, ~, scen, res] = runLogged(scen, nSlots);
P = linkPackets(L, res, scen, 1000);
end
