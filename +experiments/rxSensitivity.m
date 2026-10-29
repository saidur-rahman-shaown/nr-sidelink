function out = rxSensitivity(s)
%rxSensitivity Experiment 3b: received power against receiver sensitivity, and the range it gives.
%Spec:   none -- a derivation from MEASURED curves. Sensitivity here is the received signal power,
%        integrated over the occupied allocation, at which the PSSCH transport block survives
%        LDPC decoding AND passes its CRC (TS 38.212 7.2.1, 24-bit CRC24A) with probability
%        >= 90 % (BLER <= 10 %) -- the operating point of the PQI 56/57/59 PER of 10 %. It is read
%        off experiments.linkCurves (real chain, TDL-D, DM-RS channel estimation), not computed
%        from a Shannon bound.
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct: .files, .table (per MCS and attempt: required SNR per RE, sensitivity for a
%              50-PRB and a 10-PRB allocation, range under RMa LOS and under free space)
%The arithmetic, stated once:
%   noise per RE      N_RE  = -174 dBm/Hz + 10 log10(30 kHz) + NF          (= -120.2 dBm at NF 9 dB)
%   sensitivity       S     = SNR_req + N_RE + 10 log10(12 x N_PRB)         (dBm, over the allocation)
%   received power    P_RX  = P_CMAX - PL(d)                                (the whole TX power lands
%                                                                            on the allocation)
%   range             largest d with P_RX(d) >= S
%Because the transmitter spreads a fixed 23 dBm over its allocation, the SNR per RE is
%P_CMAX - PL - 10 log10(12 N_PRB) - N_RE: a narrower allocation is MORE robust at the same
%distance, by 10 log10(50/10) = 7 dB for 10 PRB against 50.
%Figures (plots/experiments/rx_sensitivity/):
%   rx_power_vs_distance.png   P_RX(d), RMa LOS (and free space, dashed), sensitivity lines
%   sensitivity_per_mcs.png    sensitivity of every MCS, 1st transmission and after HARQ
if nargin < 1 || isempty(s), s = experiments.settings(); end
outDir = fullfile(s.plotRoot, 'rx_sensitivity');
v = viz();
lk = experiments.linkCurves();
op = s.op; r = s.radio;
nPrbMeas = lk.meta.NRB;
assert(nPrbMeas == op.numSubchannel * op.subchSizeRb, 'rxSensitivity: curves off the operating point');
SCS_HZ = 30e3; SC_PER_RB = 12; BLER_TARGET = 0.1;
nRe = rf.noiseFloorDbm(SCS_HZ, r.noiseFigureDb);
d = 10:5:3000;
plR = harness.chanmodel.pathlossModel('rma', struct('fcHz', r.fcHz, 'losMode', 'los', 'hTxM', r.hAntM, 'hRxM', r.hAntM));
rxRma = r.pCmaxDbm - arrayfun(@(x) harness.chanmodel.pathloss(plR, x), d);
rxFs  = r.pCmaxDbm - 20 * log10(4 * pi * d * r.fcHz / 299792458);

rows = {};
for m = 1:numel(lk.mcs)
    c = lk.curve{m};
    for a = 1:size(c.bler, 2)
        snrReq = firstCross(c.snrDb, c.bler(:, a), BLER_TARGET);
        s50 = snrReq + nRe + 10 * log10(SC_PER_RB * 50);
        s10 = snrReq + nRe + 10 * log10(SC_PER_RB * 10);
        rows(end + 1, :) = {lk.mcs(m), c.modScheme, c.R, a, snrReq, s50, s10, ...
            rangeAt(d, rxRma, s50), rangeAt(d, rxFs, s50), rangeAt(d, rxRma, s10), rangeAt(d, rxFs, s10)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'mcs', 'mod', 'R', 'nTx', 'snrReqDb', 'sens50PrbDbm', ...
    'sens10PrbDbm', 'rangeRma50M', 'rangeFs50M', 'rangeRma10M', 'rangeFs10M'});

% ---- figure 1: received power vs distance with sensitivity lines --------------
show = [0 5 7 11 20 27];
[f, ax] = newFig(1000, 520);
h = plot(ax, d, rxRma, '-', 'Color', v.ink, 'LineWidth', 2.5);
h(2) = plot(ax, d, rxFs, '--', 'Color', v.muted, 'LineWidth', 1.5);
lbl = {'P_{RX}, RMa LOS (used in this study)', 'P_{RX}, free space (reference)'};
for k = 1:numel(show)
    row = T(T.mcs == show(k) & T.nTx == 1, :);
    if isnan(row.sens50PrbDbm), continue; end
    h(end + 1) = plot(ax, d([1 end]), row.sens50PrbDbm * [1 1], '-', 'Color', v.cat(k, :), 'LineWidth', 1.5); %#ok<AGROW>
    lbl{end + 1} = sprintf('sensitivity MCS %d: %.1f dBm (RMa range %d m)', show(k), row.sens50PrbDbm, row.rangeRma50M); %#ok<AGROW>
end
noise50 = nRe + 10 * log10(SC_PER_RB * 50);
h(end + 1) = plot(ax, d([1 end]), noise50 * [1 1], ':', 'Color', v.status.bad, 'LineWidth', 1.5);
lbl{end + 1} = sprintf('thermal noise over 50 PRB: %.1f dBm', noise50);
legend(ax, h, lbl, 'Location', 'southwest', 'Box', 'off', 'FontSize', 9);
set(ax, 'XScale', 'log'); xlim(ax, [10 3000]); ylim(ax, [-130 -20]);
xlabel(ax, 'TX-RX distance (m)'); ylabel(ax, 'received signal power over 50 PRB (dBm)');
title(ax, sprintf(['Received power vs sensitivity (LDPC + CRC pass >= 90%%, first transmission), ' ...
    '23 dBm, %s %g km/h'], lk.meta.channel, lk.meta.speedKmh), 'FontWeight', 'normal');
files{1} = saveFig(f, outDir, 'rx_power_vs_distance');

% ---- figure 2: sensitivity of every MCS -------------------------------------------
[f, ax] = newFig(1000, 440);
for a = 1:3
    sub = T(T.nTx == a, :);
    plot(ax, sub.mcs, sub.sens50PrbDbm, '-o', 'Color', v.cat(a, :), 'MarkerFaceColor', v.cat(a, :), 'MarkerSize', 4);
end
xlabel(ax, 'I_{MCS}'); ylabel(ax, 'sensitivity over 50 PRB (dBm)');
legend(ax, {'1st transmission', 'after 2 (soft-combined)', 'after 3 (soft-combined)'}, 'Location', 'northwest', 'Box', 'off');
title(ax, 'Receiver sensitivity per MCS (missing points: 10 % BLER never reached, error floor)', 'FontWeight', 'normal');
files{2} = saveFig(f, outDir, 'sensitivity_per_mcs');

out.files = files; out.table = T; out.noisePerReDbm = nRe;
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'rxSensitivity.mat'), 'out');
writetable(T, fullfile(s.dataRoot, 'rxSensitivity.csv'));
disp(T(T.nTx == 1, :));
end

function x = firstCross(snr, bler, target)
%firstCross The lowest SNR from which BLER stays at or below target (linear interpolation).
%"Stays" matters: a 40-trial point can dip below target by chance in the waterfall's noise.
ok = bler(:) <= target;
k = find(~ok, 1, 'last');
if isempty(k), x = snr(1); return; end
if k == numel(snr), x = NaN; return; end   % never reaches target: an error floor
x = interp1(bler(k:k + 1), snr(k:k + 1), target);
end

function r = rangeAt(d, rx, sens)
if isnan(sens), r = 0; return; end
ok = find(rx >= sens);
if isempty(ok), r = 0; else, r = d(ok(end)); end
end
