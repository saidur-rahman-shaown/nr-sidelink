function test_ch5GenericFunctions()
%test_ch5GenericFunctions Example scenarios and visualisation for the TS 38.211
%chapter 5 generic MATLAB (5G Toolbox) functions catalogued in
%+phy/+lib/genericFunctions.m: nrPRBS (Sec 5.2.1), nrSymbolModulate (Sec 5.1),
%nrLowPAPRS (Sec 5.2.2).
%
%   No +phy/+lib/ wrapper exists yet, so this calls the toolbox functions
%   directly -- lives here rather than in +phy/+ts38211/ because that package is
%   normative and .claude/hooks/guard-norm.sh denies any toolbox call written
%   there. Purpose is to see all three functions working and looking right
%   before any wrapper signature gets written, not a wrapper round-trip test.
%
%   Plots saved to: +test/+unit/+phy/+ts38211/output/
%       goldSeq_example.png
%       modMap_constellations.png
%       lowPaprSeq_example.png

outDir = fullfile(fileparts(mfilename('fullpath')), 'output');
if ~isfolder(outDir), mkdir(outDir); end

%% ---- Sec 5.2.1: PRBS / Gold sequence ----------------------------------
cinit = 12345;
n = 200;
seq = nrPRBS(cinit, n);
assert(numel(seq) == n, 'nrPRBS: length mismatch');
assert(all(ismember(double(seq), [0 1])), 'nrPRBS: output must be binary');
balance = mean(double(seq));
fprintf('goldSeq demo: cinit=%d, n=%d, fraction of 1s = %.3f (expect ~0.5)\n', cinit, n, balance);

fig1 = figure('Visible', 'off', 'Position', [100 100 900 220]);
stem(0:n-1, double(seq), 'Marker', 'none');
xlim([0 n-1]); ylim([-0.2 1.2]);
xlabel('n'); ylabel('c(n)');
title(sprintf('Gold/PRBS sequence, c_{init} = %d (TS 38.211 Sec 5.2.1)', cinit));
exportgraphics(fig1, fullfile(outDir, 'goldSeq_example.png'), 'Resolution', 130);
close(fig1);

%% ---- Sec 5.1: modulation mapper, visualised as constellations ---------
schemes = {'pi/2-BPSK', 'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM'};
bitsPerSymbol = [1, 1, 2, 4, 6, 8];
nSym = 2000;

fig2 = figure('Visible', 'off', 'Position', [100 100 1200 750]);
for i = 1:numel(schemes)
    bits = randi([0 1], nSym * bitsPerSymbol(i), 1);
    symOut = nrSymbolModulate(bits, schemes{i});
    avgPow = mean(abs(symOut).^2);
    assert(abs(avgPow - 1) < 0.05, sprintf('%s: average power %.4f far from 1', schemes{i}, avgPow));

    subplot(2, 3, i);
    plot(real(symOut), imag(symOut), '.', 'MarkerSize', 4);
    axis equal; grid on;
    xlim([-1.6 1.6]); ylim([-1.6 1.6]);
    title(sprintf('%s (avg power %.3f)', schemes{i}, avgPow));
    xlabel('I'); ylabel('Q');
end
sgtitle('Modulation mapper constellations (TS 38.211 Sec 5.1)');
exportgraphics(fig2, fullfile(outDir, 'modMap_constellations.png'), 'Resolution', 130);
close(fig2);

%% ---- Sec 5.2.2: low-PAPR sequences -------------------------------------
seqShort = nrLowPAPRS(0, 0, 0, 12);   % length < 36 branch
seqLong  = nrLowPAPRS(0, 0, 0, 36);   % length >= 36 branch (Zadoff-Chu-rooted)
assert(max(abs(abs(seqShort) - 1)) < 1e-10, 'short low-PAPR sequence not constant modulus');
assert(max(abs(abs(seqLong)  - 1)) < 1e-10, 'long low-PAPR sequence not constant modulus');

fig3 = figure('Visible', 'off', 'Position', [100 100 900 700]);
subplot(2, 2, 1); stem(0:11, abs(seqShort)); ylim([0 1.5]); title('|seq|, m=12'); xlabel('k');
subplot(2, 2, 2); stem(0:11, angle(seqShort)); title('angle(seq), m=12'); xlabel('k'); ylabel('rad');
subplot(2, 2, 3); stem(0:35, abs(seqLong)); ylim([0 1.5]); title('|seq|, m=36 (ZC-rooted)'); xlabel('k');
subplot(2, 2, 4); stem(0:35, angle(seqLong)); title('angle(seq), m=36'); xlabel('k'); ylabel('rad');
sgtitle('Low-PAPR sequences (TS 38.211 Sec 5.2.2)');
exportgraphics(fig3, fullfile(outDir, 'lowPaprSeq_example.png'), 'Resolution', 130);
close(fig3);

fprintf('test_ch5GenericFunctions: PASS (plots in %s)\n', outDir);
end
