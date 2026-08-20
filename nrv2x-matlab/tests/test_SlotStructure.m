function test_SlotStructure()
%test_SlotStructure Where PSCCH, PSSCH, their DM-RS, AGC and guard sit.
%SPEC: TS 38.211 clause 8 (sidelink slot structure)
%
%   Builds one slot with the 5G Toolbox PHY chain (SidelinkPHYEntity /
%   NRSidelinkResourcePool), classifies every resource element, asserts
%   the structure, and saves a labelled plot:
%       tests/output/slot_structure.png
%
%   Expected layout (start symbol 0, 14 symbols, PSCCH n2/10 PRB):
%     sym 0        AGC        (copy of symbol 1 for receiver gain settling)
%     sym 1..2     PSCCH + its DM-RS (freq: sl-FreqResourcePSCCH PRBs),
%                  PSSCH on the remaining subcarriers
%     sym 1..12    PSSCH + PSSCH DM-RS (SCI-2 multiplexed near the front)
%     sym 13       guard      (empty, TX/RX turnaround)

phy = SidelinkPHYEntity();                    % 20 MHz / 30 kHz defaults
[~, txData] = phy.transmitSlot();
grid = txData.ResourceGrid;                   % K x 14 complex
[K, nSym] = size(grid);

startSym = phy.Pool.sl_StartSymbol_r16;       % 0-based
lenSym   = phy.Pool.sl_LengthSymbols_r16;
agcCol   = startSym + 1;                      % 1-based column of AGC symbol
guardCol = startSym + lenSym;                 % 1-based column of guard symbol

% ---- classify every RE ------------------------------------------------
% 0 empty | 1 AGC | 2 PSCCH | 3 PSCCH-DMRS | 4 PSSCH | 5 PSSCH-DMRS | 6 guard
cat = zeros(K, nSym);
cat(txData.PSSCH.PSSCHIndices + 1)     = 4;
cat(txData.PSSCH.PSSCHDMRSIndices + 1) = 5;
cat(txData.PSCCH.PSCCHIndices + 1)     = 2;
cat(txData.PSCCH.PSCCHDMRSIndices + 1) = 3;
cat(grid(:, agcCol) ~= 0, agcCol)      = 1;
cat(:, guardCol)                       = 6 * (grid(:, guardCol) ~= 0) + 6;
cat(:, guardCol)                       = 6;   % label the guard column

% ---- structural assertions -------------------------------------------
pscchCols = unique(ceil((txData.PSCCH.PSCCHIndices + 1) / K))';
psschCols = unique(ceil((txData.PSSCH.PSSCHIndices + 1) / K))';

assert(all(grid(:, guardCol) == 0), 'guard symbol must be empty');
assert(isequal(grid(:, agcCol), grid(:, agcCol + 1)), ...
    'AGC symbol must be a copy of the first data symbol');
assert(numel(pscchCols) >= 2 && numel(pscchCols) <= 3, ...
    'PSCCH spans sl-TimeResourcePSCCH in {2,3} symbols, got %d', numel(pscchCols));
assert(min(pscchCols) == agcCol + 1, 'PSCCH starts right after the AGC symbol');
assert(~ismember(agcCol, psschCols) && ~ismember(guardCol, psschCols), ...
    'PSSCH must not map onto the AGC or guard symbols');
assert(nnz(cat == 3) > 0 && nnz(cat == 5) > 0, 'both DM-RS sets must be present');
assert(max(psschCols) == guardCol - 1, 'PSSCH runs up to the symbol before guard');
% PSCCH frequency footprint = sl-FreqResourcePSCCH PRBs (12 REs each,
% data + DMRS interleave within those PRBs)
pscchRows = unique(mod(txData.PSCCH.PSCCHIndices, K)) + 1;
dmrsRows  = unique(mod(txData.PSCCH.PSCCHDMRSIndices, K)) + 1;
assert(mod(numel(union(pscchRows, dmrsRows)), 12) == 0, ...
    'PSCCH+DMRS footprint must be a whole number of PRBs');

% ---- plot -------------------------------------------------------------
outDir = fullfile(fileparts(mfilename('fullpath')), 'output');
if ~isfolder(outDir), mkdir(outDir); end

fig = figure('Visible', 'off', 'Position', [100 100 900 620]);
cmap = [0.94 0.94 0.94;   % 0 empty
        0.85 0.65 0.13;   % 1 AGC
        0.84 0.16 0.16;   % 2 PSCCH
        1.00 0.55 0.55;   % 3 PSCCH DM-RS
        0.13 0.35 0.75;   % 4 PSSCH
        0.45 0.70 1.00;   % 5 PSSCH DM-RS
        0.35 0.35 0.35];  % 6 guard
imagesc(0:nSym-1, 0:K-1, cat);
colormap(fig, cmap);  clim([-0.5 6.5]);
axis xy;
cb = colorbar('Ticks', 0:6, 'TickLabels', ...
    {'empty', 'AGC', 'PSCCH', 'PSCCH DM-RS', 'PSSCH', 'PSSCH DM-RS', 'guard'});
cb.Label.String = 'resource element role';
xlabel('OFDM symbol in slot');
ylabel('subcarrier');
% sub-channel boundaries (10 PRB = 120 subcarriers)
scSize = 12 * phy.Pool.sl_SubchannelSize_r16;
for y = scSize:scSize:K-1
    yline(y - 0.5, 'k:', 'Alpha', 0.6);
end
title(sprintf(['Sidelink slot structure — %d PRB, SCS %d kHz\n' ...
    'PSCCH %d symbols, PSSCH up to symbol %d, TBS %d bits'], ...
    K/12, phy.Pool.SCSCarrier.SubcarrierSpacing, numel(pscchCols), ...
    guardCol - 2, phy.TBS));
exportgraphics(fig, fullfile(outDir, 'slot_structure.png'), 'Resolution', 130);
close(fig);

fprintf('test_SlotStructure: PASS (plot: tests/output/slot_structure.png)\n');
end
