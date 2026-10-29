function out = throughputMcs(s, mcsList)
%throughputMcs Experiment 3: link throughput of chosen MCS under realistic channel conditions.
%Spec:   none -- a link-level study. BLER is MEASURED (experiments.linkCurves: the real PSSCH chain,
%        TDL-D fading, DM-RS channel estimation, ZF, LDPC, HARQ soft combining), then mapped to
%        throughput per HARQ mode (linkThroughput) and to distance through the RMa LOS budget
%        (linkBudget). Nothing here reads harness.phyabs.blerTable, whose MCS rows do not include
%        5, 6 or 27.
%Inputs: s        optional, experiments.settings()
%        mcsList  optional, default [5 6 11 27]
%Outputs: out  struct: .files, .table (per MCS and condition: peak rate, SNR for 10% BLER,
%              max throughput, range at PRR >= 0.9), .conditions
%Three operating conditions, each a separately measured curve set:
%   A  highway: 120 km/h Doppler speed (two cars at 60 km/h), 2 DM-RS symbols  (linkCurves.mat)
%   B  highway with the high-speed DM-RS pattern: 120 km/h, 4 DM-RS symbols    (_dmrs4)
%   C  urban: 30 km/h, 2 DM-RS symbols                                          (_v30)
%The allocation is the whole 20 MHz ITS channel: 5 sub-channels x 10 PRB = 50 PRB at 30 kHz.
%"Throughput" is the full-buffer rate of ONE link that transmits in every slot -- an upper bound
%Mode 2 does not reach (half duplex, sl-TxPercentage, the CR limit at the measured CBR); the
%field and CBR experiments give what a UE actually gets in a shared pool.
%Figures (plots/experiments/throughput_mcs/):
%   bler_vs_snr.png           first and third attempt, every condition
%   throughput_vs_snr.png     three HARQ modes, condition A
%   throughput_vs_distance.png  HARQ feedback mode, each condition
%   throughput_conditions.png   peak achieved rate per MCS per condition
if nargin < 1 || isempty(s), s = experiments.settings(); end
if nargin < 2, mcsList = [5 6 11 27]; end
outDir = fullfile(s.plotRoot, 'throughput_mcs');
v = viz();
cond = struct('tag', {'', 'dmrs4', 'v30'}, ...
    'label', {'A: 120 km/h, 2 DM-RS', 'B: 120 km/h, 4 DM-RS', 'C: 30 km/h, 2 DM-RS'});
lk = cell(1, numel(cond));
have = false(1, numel(cond));
for q = 1:numel(cond)
    fn = fullfile(s.dataRoot, ['linkCurves' ifelse(isempty(cond(q).tag), '', ['_' cond(q).tag]) '.mat']);
    if isfile(fn)
        x = load(fn, 'lk'); lk{q} = x.lk; have(q) = all(ismember(mcsList, x.lk.mcs));
    end
end
if ~have(1)
    lk{1} = experiments.linkCurves(struct('mcs', mcsList)); have(1) = true;
end
cond = cond(have); lk = lk(have);
op = s.op;
assert(lk{1}.meta.NRB == op.numSubchannel * op.subchSizeRb && lk{1}.meta.mu == op.mu, ...
    'throughputMcs: link curves measured at %d PRB, mu %d -- off the operating point', lk{1}.meta.NRB, lk{1}.meta.mu);

nC = numel(cond); nM = numel(mcsList);
slotMs = 0.5;
nRb = lk{1}.meta.NRB;
scenU = harness.sls.scenarioInit(2, 1, 'unicast');
tbsPsfch = arrayfun(@(m) harness.lls.linkConfig(m, lk{1}.meta.LsubCH, scenU).trblklen, mcsList);

% ---- BLER vs SNR --------------------------------------------------------------
[f, t] = newFig(1250, 420, 1, nC);
for q = 1:nC
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on'); set(ax, 'YScale', 'log');
    for m = 1:nM
        c = getCurve(lk{q}, mcsList(m));
        semilogy(ax, c.snrDb, max(c.bler(:, 1), 1e-3), '-', 'Color', v.cat(m, :));
        semilogy(ax, c.snrDb, max(c.bler(:, end), 1e-3), '--', 'Color', v.cat(m, :));
    end
    yline(ax, 0.1, ':', 'Color', v.muted);
    ylim(ax, [1e-3 1.1]); xlabel(ax, 'SNR per RE (dB)'); ylabel(ax, 'BLER (floored at 1e-3 for display)');
    title(ax, cond(q).label, 'FontWeight', 'normal');
end
legend(ax, [compose('MCS %d, 1st TX', mcsList(:)); compose('MCS %d, after 3 TX', mcsList(:))], ...
    'Location', 'eastoutside', 'Box', 'off');
title(t, sprintf('Measured PSSCH BLER, TDL-D %g ns, %d PRB, DM-RS-estimated channel, ZF, LDPC', ...
    lk{1}.meta.delaySpreadNs, nRb), 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'bler_vs_snr');

% ---- throughput vs SNR, three HARQ modes, condition A -------------------------
modes = {'none', 'blind1', 'feedback'};
modeLbl = {'no HARQ (1 TX)', 'blind retx (2 TX, broadcast)', 'PSFCH HARQ (<=3 TX, unicast)'};
snr = -10:0.25:40;
[f, t] = newFig(1250, 420, 1, 3);
for k = 1:3
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    for m = 1:nM
        tb = []; if strcmp(modes{k}, 'feedback'), tb = tbsPsfch(m); end
        T = linkThroughput(getCurve(lk{1}, mcsList(m)), snr, modes{k}, slotMs, tb);
        plot(ax, snr, T, '-', 'Color', v.cat(m, :));
    end
    xlabel(ax, 'SNR per RE (dB)'); ylabel(ax, 'throughput (Mbit/s, every slot)');
    title(ax, modeLbl{k}, 'FontWeight', 'normal');
end
legend(ax, compose('MCS %d', mcsList(:)), 'Location', 'northwest', 'Box', 'off');
title(t, [cond(1).label ' — full-buffer link throughput, 50 PRB'], 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'throughput_vs_snr');

% ---- throughput vs distance ---------------------------------------------------
d = 10:5:1200;
snrD = linkBudget(d, nRb, s);
[f, t] = newFig(1250, 420, 1, nC);
rows = {};
for q = 1:nC
    ax = nexttile(t); hold(ax, 'on'); grid(ax, 'on');
    for m = 1:nM
        c = getCurve(lk{q}, mcsList(m));
        [T, prr] = linkThroughput(c, snrD, 'feedback', slotMs, tbsPsfch(m));
        plot(ax, d, T, '-', 'Color', v.cat(m, :));
        T1 = linkThroughput(c, snr, 'none', slotMs);
        i10 = find(interp1(c.snrDb, c.bler(:, 1), snr, 'linear', 1) <= 0.1, 1);
        snr10 = NaN; if ~isempty(i10), snr10 = snr(i10); end
        rng = max([0 d(prr >= 0.9)]);
        rows(end + 1, :) = {cond(q).label, mcsList(m), c.modScheme, c.R, c.trblklen, ...
            c.trblklen / slotMs / 1e3, max(T1), snr10, ...
            max(T), rng, c.bler(end, 1)}; %#ok<AGROW>
    end
    xlabel(ax, 'distance (m), RMa LOS, 23 dBm'); ylabel(ax, 'throughput (Mbit/s)');
    title(ax, cond(q).label, 'FontWeight', 'normal');
end
legend(ax, compose('MCS %d', mcsList(:)), 'Location', 'northeast', 'Box', 'off');
title(t, 'Throughput vs distance, PSFCH HARQ (<=3 TX), full buffer', 'FontWeight', 'normal');
files{3} = saveFig(f, outDir, 'throughput_vs_distance');
T = cell2table(rows, 'VariableNames', {'condition', 'mcs', 'mod', 'R', 'tbsBits', 'peakMbps', ...
    'maxNoHarqMbps', 'snrBler10pct', 'maxFeedbackMbps', 'rangePrr90M', 'blerFloor1stTx'});

% ---- condition comparison -----------------------------------------------------
[f, ax] = newFig(900, 420);
M = nan(nM, nC);
for q = 1:nC
    for m = 1:nM
        M(m, q) = T.maxNoHarqMbps(strcmp(T.condition, cond(q).label) & T.mcs == mcsList(m));
    end
end
b = bar(ax, M, 0.8, 'EdgeColor', 'w', 'LineWidth', 1.5);
for q = 1:nC, b(q).FaceColor = v.cat(q, :); end
peak = arrayfun(@(m) getCurve(lk{1}, m).trblklen / slotMs / 1e3, mcsList);
plot(ax, (1:nM), peak, '_', 'Color', v.ink, 'MarkerSize', 30, 'LineWidth', 2);
set(ax, 'XTick', 1:nM, 'XTickLabel', compose('MCS %d', mcsList(:)));
ylabel(ax, 'best achieved rate, no HARQ (Mbit/s)');
legend(ax, [{cond.label} {'error-free peak (TBS / slot)'}], 'Location', 'northwest', 'Box', 'off');
title(ax, 'What the channel lets each MCS reach (any SNR)', 'FontWeight', 'normal');
files{4} = saveFig(f, outDir, 'throughput_conditions');

out.files = files; out.table = T; out.conditions = {cond.label};
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'throughputMcs.mat'), 'out');
disp(T);
end

function c = getCurve(lk, mcs)
c = lk.curve{lk.mcs == mcs};
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
