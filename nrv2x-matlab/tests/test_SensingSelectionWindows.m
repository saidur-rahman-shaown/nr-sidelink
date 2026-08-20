function test_SensingSelectionWindows()
%test_SensingSelectionWindows Sensing/selection windows + booked resources.
%SPEC: TS 38.214 8.1.4 steps 1-2 (windows), step 6 (exclusion)
%
%   Five UEs on the RMa channel graph, with VARIED reservation periods and
%   priorities, and REALISTIC V2X delay budgets (PDB 10-20 ms, per the
%   safety-class PQIs):
%     UE1: P = 100 ms, prio 3, PDB 20 ms   UE2: P = 200 ms, prio 2, PDB 20 ms
%     UE3: P = 100 ms, prio 5, PDB 20 ms   UE4: P =  50 ms, prio 1, PDB 10 ms
%   UE5 (P = 100 ms, prio 3, PDB 20 ms) triggers at n = 600: candidate
%   window [n+5, n+40] — only 36 slots. With T_scal = 20 ms every sensed
%   period satisfies P_rsvp >= T_scal, so Q = 1: each SCI projects exactly
%   ONCE. A short PDB therefore sees only reservations whose single
%   projection lands inside the narrow window; traffic starts are staged
%   so each UE has such an occurrence in the sensing window:
%     P=100/200 UEs -> occurrence in [405,440] books at +200 (q=1 for
%       P=100; via the own-side j=1 shift for P=200's +400 projection)
%     P=50 UE      -> occurrence in [505,540] books at +100
%   TERMINOLOGY: the green region is the 8.1.4 CANDIDATE RESOURCE WINDOW
%   [n+T1, n+T2], with T2 derived from the remaining PDB. It is NOT the
%   RRC IE sl-SelectionWindowList (n1/n5/n10/n20 x 2^mu) — that IE is
%   only T2min, the per-priority LOWER bound on T2, drawn as a tick at
%   n+T2min (with PDB 20 ms and n20, T2 = T2min = 40: the tick sits on
%   the window edge).
%   The plot shows the sensing window with each UE's SCIs, the candidate
%   resource window, available S_A, and booked cells coloured/labelled
%   per reserving UE (L2 ID, P, prio). Sub-channel k = unit band [k, k+1).
%   Saves: tests/output/sensing_selection_windows.png

cfg  = defaultPreconfig();
% allow the 50 ms periodicity (step-5 hypothetical set + SCI field range)
cfg.sl_ResourceReservePeriodList_ms = [0 50 100 200 500 1000];
nSim = 1400;
nUE  = 5;
n5   = 600;                                    % UE5's trigger slot
trafficStart = [400 400 200 300 n5];           % staged so projections land
prioU = [  3   2   5   1   3];                 % L1 priorities (1 = highest)
PU    = [100 200 100  50 100];                 % reservation periods, ms
pdbU  = [ 20  20  20  10  20];                 % realistic V2X safety PDBs

% ---- build UEs + channel graph (nodes = UEs, edges = RMa links) ------
ues = cell(1, nUE);
g = ChannelGraph(RandStream('mt19937ar', 'Seed', 99));
posn = [ 150   0;                              % transmitters around UE5
          75 130;
         -90 110;
        -160 -40;
           0   0];                             % UE5 (observer) at origin
for u = 1:nUE
    ues{u} = SidelinkUE(u, cfg, nSim, 40 + u);
    ues{u}.configureTraffic(prioU(u), PU(u), 2, pdbU(u));
    ues{u}.mac.hasDataFcn = @(n) n >= trafficStart(u); %#ok<*NASGU>
    g.addNode(u, ues{u}.L2ID, posn(u, :));
end
% every pairwise link must be sensable (above the -110 dBm threshold)
A = g.adjacencyRSRP();
assert(all(A(~isnan(A)) > -110), 'all links must exceed the sensing threshold');

% ---- run the harness (two-phase, half-duplex, per-edge RSRP) ---------
for n = 0:n5 + 40
    txs = cell(1, nUE);
    for u = 1:nUE
        txs{u} = ues{u}.txPhase(n);
    end
    for u = 1:nUE
        rx = struct([]);
        for v = 1:nUE
            if v ~= u && ~isempty(txs{v})
                rx = [rx, asRx(txs{v}, ues{v}.L2ID, g.linkRSRP(v, u))]; %#ok<AGROW>
            end
        end
        ues{u}.rxPhase(n, rx);
    end
end
ue5 = ues{5};
assert(~isempty(ue5.mac.grant), 'UE5 must have selected a grant at n=600');

% ---- re-run the 8.1.4 procedure exactly as UE5's MAC invoked it ------
req = struct('n', n5, 'LsubCH', 2, 'prioTx', prioU(5), ...
    'remainingPDB_ms', pdbU(5), 'PrsvpTx_ms', PU(5), ...
    'Cresel', ue5.mac.grant.Cresel);
[S_A, M_total, ~, S_tot] = selectCandidateResources(req, cfg, ue5.slotMap, ue5.db);

exclIdx  = ~ismember(S_tot, S_A, 'rows');
assert(nnz(exclIdx) > 0, 'the four SPS UEs must exclude something');
assert(size(S_A, 1) + nnz(exclIdx) == M_total, 'S_A + excluded = M_total');

% ---- attribute each booked resource to the SCI that booked it --------
T0slots = cfg.sl_SensingWindow_ms * cfg.slotsPerMs;
[Tproc0, Tproc1] = procTimeTable(cfg.mu);
recs = ue5.db.recordsInAbsWindow(n5 - T0slots, n5 - Tproc0);
assert(~isempty(recs), 'sensing window must contain the transmitters'' SCIs');
sensedL2 = unique([recs.srcL2]);
assert(numel(sensedL2) >= 4, ...
    'UE5 must have heard all four transmitters, heard %d', numel(sensedL2));

T2 = round(req.remainingPDB_ms * cfg.slotsPerMs);
bookedBy = zeros(size(S_tot, 1), 1);           % L2 ID per candidate (0 = free)
for r = recs
    hit = condCMask(S_tot, r, req, cfg, ue5.slotMap, n5, T2);
    bookedBy(hit & bookedBy == 0) = r.srcL2;
end
assert(all(bookedBy(exclIdx) > 0), 'every excluded resource must have a booker');
assert(all(bookedBy(~exclIdx) == 0), 'available candidates carry no booking');
bookers = unique(bookedBy(exclIdx))';
assert(numel(bookers) >= 3, ...
    'expect bookings from >=3 distinct UEs, got %d', numel(bookers));

% projection-spacing invariant: for a booker with period P, every shift
% applied by cond (c) — sensed q*P'_rx and own j*P'_tx(=200) — is a
% multiple of gcd(P'_rx, 200), so its booked slots collapse to <= 3
% residues (<= #resources per occurrence) modulo that gcd.
absOfAll = ue5.slotMap.logical2abs;
for u = [1 3 4]                                % P = 100, 100, 50 ms
    b = ues{u}.L2ID;
    slots_b = absOfAll(S_tot(bookedBy == b & exclIdx, 1));
    if isempty(slots_b), continue; end
    Pp = prsvpToLogical(PU(u), ue5.slotMap);   % 200, 200, 100 logical slots
    res = unique(mod(slots_b, gcd(Pp, 200)));
    assert(numel(res) <= 3, ...
        'UE%d (P=%d ms): booked slots must repeat at the projection spacing', ...
        u, PU(u));
end
% with T_scal = 20 ms, every sensed reservation has P_rsvp >= T_scal, so
% Q = 1 throughout: no sensed SCI may book more slots than its own
% resource count (<= 3 per occurrence) times the own-side j shifts that
% land in the 36-slot window (at most 1, since P'_tx = 200 > window).
for b = bookers
    slots_b = unique(absOfAll(S_tot(bookedBy == b & exclIdx, 1)));
    assert(numel(slots_b) <= 3, ...
        'Q=1 regime: booker L2 %d may occupy at most 3 slots, got %d', ...
        b, numel(slots_b));
end

% ---- plot -------------------------------------------------------------
outDir = fullfile(fileparts(mfilename('fullpath')), 'output');
if ~isfolder(outDir), mkdir(outDir); end
fig = figure('Visible', 'off', 'Position', [40 40 1400 560]);
hold on;

nSub = cfg.sl_NumSubchannel_r16;
senseLo = n5 - T0slots;  senseHi = n5 - Tproc0;      % [lo, hi)
selLo   = n5 + Tproc1;   selHi   = n5 + T2;          % [lo, hi]

% window shading (sub-channel k = unit band [k, k+1), axis starts at 0)
patch([senseLo senseHi senseHi senseLo], [0 0 nSub nSub], ...
    [0.82 0.90 1.00], 'EdgeColor', 'none', 'FaceAlpha', 0.55);
patch([selLo selHi+1 selHi+1 selLo], [0 0 nSub nSub], ...
    [0.87 1.00 0.87], 'EdgeColor', 'none', 'FaceAlpha', 0.55);

txColors = lines(4);                           % one colour per transmitter
l2ofTx = arrayfun(@(u) ues{u}.L2ID, 1:4);

% sensed SCIs in the sensing window, coloured per transmitter
for r = recs
    u = find(l2ofTx == r.srcL2, 1);
    rectangle('Position', [r.abs, r.startSub, 1, r.L], ...
        'FaceColor', txColors(u, :), 'EdgeColor', 'none');
end

% candidates: available (green dots at band centres) vs excluded (tint)
absOf = ue5.slotMap.logical2abs;
plot(absOf(S_A(:, 1)) + 0.5, S_A(:, 2) + 0.5, 's', ...
    'Color', [0.30 0.75 0.30], 'MarkerSize', 3, ...
    'MarkerFaceColor', [0.30 0.75 0.30]);
% Excluded CANDIDATES (light tint): each candidate is LsubCH tall, and it
% is excluded on ANY overlap with a reservation — so the tinted footprint
% is the reservation dilated by LsubCH-1 sub-channels. That widening is
% exclusion semantics (8.1.4 step 6c), not a wider reservation.
for k = find(exclIdx)'
    u = find(l2ofTx == bookedBy(k), 1);
    a = absOf(S_tot(k, 1));
    patch([a a+1 a+1 a], ...
        S_tot(k, 2) + [0 0 req.LsubCH req.LsubCH], ...
        txColors(u, :), 'FaceAlpha', 0.30, 'EdgeColor', 'none');
end
% Projected RESERVATIONS (solid, exact per-resource width): where each
% sensed resource — the SCI's slot AND its TRIV-chained resources, each
% at ITS OWN sub-channels — will actually recur inside the window.
% UE2's P=200 ms recurrence lands beyond the window (its candidates are
% excluded via UE5's own C_resel repetition): tint but no solid block.
for r = recs
    PpRx = prsvpToLogical(r.Prsvp, ue5.slotMap);
    ent = [double(r.log), r.startSub];
    if ~isempty(r.trivLog), ent = [ent; r.trivLog]; end     %#ok<AGROW>
    u = find(l2ofTx == r.srcL2, 1);
    for e = 1:size(ent, 1)
        for q = 1:3
            occLog = ent(e, 1) + q * PpRx;
            if occLog > ue5.slotMap.nLogical, break; end
            occAbs = absOfAll(occLog);
            if occAbs >= selLo && occAbs <= selHi
                rectangle('Position', [occAbs, ent(e, 2), 1, r.L], ...
                    'FaceColor', txColors(u, :), 'EdgeColor', 'k', ...
                    'LineWidth', 0.4);
            end
        end
    end
end

% markers and window captions
xline(n5, 'k-', sprintf('n = %d (trigger)', n5), 'LabelVerticalAlignment', 'bottom');
xline(senseHi, 'k:');
xline(selLo, 'k:');
% T2min from sl-SelectionWindowList (n20 -> 40 slots @ mu=1): the RRC IE
% is only the LOWER bound on T2, not the window itself
T2min = cfg.sl_SelectionWindowList_slots(prioU(5));
xline(n5 + T2min, 'k--', sprintf('n+T2min (%d, sl-SelectionWindow n20)', T2min), ...
    'FontSize', 8, 'LabelVerticalAlignment', 'middle');
text(senseLo + 5, nSub + 0.28, sprintf('sensing window [n-%d, n-%d)', ...
    T0slots, Tproc0), 'FontSize', 10);
text(selHi + 12, nSub + 0.28, sprintf(['candidate resource window ' ...
    '[n+T1, n+T2] = [n+%d, n+%d]  (T2 from PDB %d ms)'], ...
    Tproc1, T2, pdbU(5)), 'FontSize', 10, 'HorizontalAlignment', 'right');

% legend via proxy handles: per-UE colours + the three cell types
hProxy = gobjects(1, 7);
for u = 1:4
    hProxy(u) = patch(nan, nan, txColors(u, :), 'EdgeColor', 'none');
end
hProxy(5) = patch(nan, nan, [0.35 0.35 0.35], 'EdgeColor', 'k');
hProxy(6) = patch(nan, nan, [0.35 0.35 0.35], 'FaceAlpha', 0.30, ...
    'EdgeColor', 'none');
hProxy(7) = plot(nan, nan, 's', 'Color', [0.30 0.75 0.30], ...
    'MarkerFaceColor', [0.30 0.75 0.30]);
legNames = [arrayfun(@(u) sprintf('UE%d (P=%d ms, prio %d)', ...
    u, PU(u), prioU(u)), 1:4, 'UniformOutput', false), ...
    {'projected reservation (exact)', ...
     'excluded candidate (overlap)', 'available candidate (S_A)'}];
legend(hProxy, legNames, 'Location', 'southoutside', ...
    'Orientation', 'horizontal', 'NumColumns', 4, 'FontSize', 8);

xlim([senseLo - 10, selHi + 14]);
ylim([0, nSub + 0.6]);                         % sub-channel axis floor at 0
yticks(0:nSub);                                % band EDGES: band [k, k+1) = sub-channel k
xlabel('absolute slot (0.5 ms each)');
ylabel('sub-channel index (band [k, k+1) = sub-channel k)');
title(sprintf(['UE %d needs L_{subCH} = %d contiguous sub-channels — ' ...
    'Mode 2 sensing at trigger slot n=%d: ' ...
    '%d/%d candidates available, %d excluded by %d UEs'], ...
    ue5.ID, req.LsubCH, n5, size(S_A, 1), M_total, nnz(exclIdx), numel(bookers)));
exportgraphics(fig, fullfile(outDir, 'sensing_selection_windows.png'), ...
    'Resolution', 130);
close(fig);

fprintf(['test_SensingSelectionWindows: PASS (5 UEs, %d booked by %d UEs; ' ...
    'plot: tests/output/sensing_selection_windows.png)\n'], ...
    nnz(exclIdx), numel(bookers));
end

% ---- helpers ----------------------------------------------------------
function rx = asRx(tx, srcL2, rsrp_dBm)
rx = struct('startSub', tx.startSub, 'LsubCH', tx.LsubCH, ...
    'prio', tx.prio, 'Prsvp_ms', tx.Prsvp_ms, ...
    'rsrp_dBm', rsrp_dBm, 'trivLog', tx.trivLog, 'srcL2Id', srcL2);
end
