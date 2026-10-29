function out = slotStructure(s)
%slotStructure Experiment 1a: what the sidelink slots look like, resource element by element.
%Spec:   none itself. Every grid here is built by the normative chains, not drawn by hand:
%        S-SSB by phy.chan.psbchTx (TS 38.211 8.4.1-8.4.3, TS 38.212 8.1), the data slot by
%        stack.phySlotTx (PSCCH 38.211 8.3.2, PSSCH + SCI-2 8.3.1, AGC copy 8.2.1) and PSFCH by
%        stack.psfchGridAdd (38.211 8.3.4, 38.213 16.3); the pool timeline by
%        phy.ts38214.poolSlotMap (38.214 clause 8 preamble) with phy.ts38213.sSsbSlotIndex.
%        Each resource element is then CLASSIFIED from the index lists those functions return,
%        so the picture is the transmitter's actual mapping.
%Inputs: s  optional, experiments.settings()
%Outputs: out  struct: .files (figure paths), .symbolTable (role of each symbol per slot type),
%              .numbers (RE counts, TBS per L_subCH, S-SSB/pool slot counts)
%Figures (plots/experiments/slot_structure/):
%   ssb_slot_grid.png     the S-SSB slot over the 50-PRB BWP, plus the 11-PRB block zoomed
%   data_slot_psfch.png   two PSSCH transmissions + one PSFCH in a PSFCH-bearing slot
%   data_slot_nopsfch.png the same transmissions in a slot without a PSFCH occasion
%   pool_timeline.png     one 160 ms S-SSB period: S-SSB, reserved and pool slots
if nargin < 1, s = experiments.settings(); end
outDir = fullfile(s.plotRoot, 'slot_structure');
v = viz();

% ---------------------------------------------------------------- S-SSB slot
NSYMB_SSB = 13;                 % normal CP: 13 S-SSB symbols, then the guard (38.211 8.4.1)
NID1 = 17; NID2 = 0;
cfgB = phy.ts38211.slPSBCHConfig(NID1 + 336 * NID2, NSYMB_SSB);
mib = double(phy.ts38212.mibSlPack(struct('tddConfig', zeros(12, 1), 'inCoverage', 0, ...
    'directFrameNumber', 0, 'slotIndex', 0, 'reservedBits', zeros(2, 1))));
block = complex(zeros(132, NSYMB_SSB));
[block, infoB] = phy.chan.psbchTx(block, struct(), cfgB, mib(:), NID1, NID2);

o  = cfg.loadConfig('+cfg/configs/preconfig_example.json', [55 70 89]);
g  = stack.poolGeometry(o, 7);
nSc = g.nSubcarriers;
ROLE = {'empty', 'S-PSS', 'S-SSS', 'PSBCH', 'PSBCH DM-RS', 'AGC (copy)', 'PSCCH', ...
    'PSCCH DM-RS', 'SCI-2', 'PSSCH data', 'PSSCH DM-RS', 'PSFCH', 'guard / gap'};
cmap = [1 1 1; v.cat(7, :); v.cat(5, :); v.cat(1, :); v.cat(8, :); 0.80 0.80 0.80; ...
    v.cat(2, :); v.cat(8, :); v.cat(4, :); v.cat(1, :); v.cat(8, :); v.cat(3, :); 0.55 0.55 0.55];
% Role codes: the value stored per RE; ROLE{code + 1} names it and cmap(code + 1, :) colours it.
C = struct('empty', 0, 'spss', 1, 'ssss', 2, 'psbch', 3, 'psbchDmrs', 4, 'agc', 5, 'pscch', 6, ...
    'pscchDmrs', 7, 'sci2', 8, 'data', 9, 'psschDmrs', 10, 'psfch', 11, 'guard', 12);

ssbStart = 12 * floor((nSc / 12 - 11) / 2);           % 11 PRBs, centred in the BWP (illustrative)
roleSsb = zeros(nSc, 14);
roleSsb = paint(roleSsb, infoB.dataInd, C.psbch, ssbStart);
roleSsb = paint(roleSsb, infoB.dmrsInd, C.psbchDmrs, ssbStart);
roleSsb = paint(roleSsb, infoB.spssInd, C.spss, ssbStart);
roleSsb = paint(roleSsb, infoB.sssInd, C.ssss, ssbStart);
roleSsb(ssbStart + (1:132), 14) = C.guard;            % symbol 13: guard
nonzero = any(abs(block) > 0, 2);
assert(any(nonzero), 'slotStructure: psbchTx wrote nothing');

[f, t] = newFig(1100, 520, 1, 2);
ax = nexttile(t); drawRoles(ax, roleSsb, cmap, ROLE, sprintf('S-SSB slot, %d-PRB BWP', nSc / 12));
ax = nexttile(t); drawRoles(ax, roleSsb(ssbStart + (1:132), :), cmap, ROLE, ...
    'S-SS/PSBCH block (11 PRB = 132 subcarriers), zoomed');
legendRoles(ax, cmap, ROLE, unique(roleSsb(:))');
files{1} = saveFig(f, outDir, 'ssb_slot_grid');

% ------------------------------------------------------- data slot, PSFCH on
[roleP, nb] = dataSlotRoles(g, C);
f = drawDataSlot(roleP, cmap, ROLE, C, 'Data slot, PSFCH period 1: UE A sub-ch 0-1, UE B sub-ch 3');
files{2} = saveFig(f, outDir, 'data_slot_psfch');

% ------------------------------------------------------ data slot, PSFCH off
o2 = o;
o2.preconfig.sl_PreconfigFreqInfoList_r16(1).sl_BWP_List_r16(1).sl_BWP_PoolConfigCommon_r16 ...
    .sl_TxPoolSelectedNormal_r16(1).sl_ResourcePool_r16.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16 = 0;   % sl0
g0 = stack.poolGeometry(o2, 7);
[role0, nb0] = dataSlotRoles(g0, C);
f = drawDataSlot(role0, cmap, ROLE, C, 'Data slot, no PSFCH occasion (period 0)');
files{3} = saveFig(f, outDir, 'data_slot_nopsfch');

% ------------------------------------------------------------- pool timeline
mu = g.mu;
slotsPerPeriod = 160 * 2^mu;                          % the 16-frame S-SSB period
Nperiod = 2; Noffset = 0; Ninterval = 160;            % sl-NumSSB-WithinPeriod etc. (illustrative)
ssbIdx = arrayfun(@(i) phy.ts38213.sSsbSlotIndex(Noffset, Ninterval, i, Nperiod), 0:Nperiod - 1);
nDfn = 10240 * 2^mu;
ssbMask = false(1, nDfn);
for p = 0:nDfn / slotsPerPeriod - 1
    ssbMask(p * slotsPerPeriod + ssbIdx + 1) = true;
end
[physOfLogical, logicalOfPhys, TmaxPrime] = phy.ts38214.poolSlotMap(mu, ssbMask, false(1, nDfn), true(1, 10));
kind = ones(1, nDfn);                                 % 1 pool
kind(ssbMask) = 2;                                    % 2 S-SSB
kind(~ssbMask & logicalOfPhys < 0) = 3;               % 3 reserved (clause 8 mod rule)
nShow = slotsPerPeriod;
[f, t] = newFig(1100, 360, 2, 1);
ax = nexttile(t);
kcm = [v.cat(1, :); v.cat(7, :); v.cat(4, :)];
image(ax, 0:nShow - 1, 1, kind(1:nShow)); colormap(ax, kcm); clim(ax, [0.5 3.5]);
set(ax, 'YTick', [], 'TickDir', 'out'); xlabel(ax, sprintf('physical slot (mu = %d, 0.5 ms each)', mu));
title(ax, sprintf(['One 160 ms S-SSB period: %d S-SSB slots (purple) excluded from the pool; ' ...
    'T''_{max} = %d pool slots per 10.24 s'], Nperiod, TmaxPrime), 'FontWeight', 'normal');
ax = nexttile(t);
z = 0:39;
image(ax, z, 1, kind(z + 1)); colormap(ax, kcm); clim(ax, [0.5 3.5]);
set(ax, 'YTick', []);
for k = z
    lbl = 'S-SSB';
    if kind(k + 1) == 1, lbl = sprintf('L%d', logicalOfPhys(k + 1)); end
    text(ax, k, 1, lbl, 'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', 'w', 'Rotation', 90);
end
xlabel(ax, 'first 40 physical slots; Lk = logical pool slot index k (what every clause-8 window counts in)');
files{4} = saveFig(f, outDir, 'pool_timeline');

% ------------------------------------------------------------------ numbers
types = {'S-SSB', roleSsb; 'data, PSFCH', roleP; 'data, no PSFCH', role0};
T = cell(14, 4);
for l = 0:13
    T{l + 1, 1} = l;
    for q = 1:3
        r = types{q, 2};
        col = r(:, l + 1);
        T{l + 1, q + 1} = strjoin(ROLE(unique(col(col > 0))' + 1), ' + ');
        if isempty(T{l + 1, q + 1}), T{l + 1, q + 1} = '-'; end
    end
end
out.symbolTable = cell2table(T, 'VariableNames', {'symbol', 'S_SSB', 'data_PSFCH', 'data_noPSFCH'});
out.numbers = struct('psbchE', infoB.E, 'psbchDataRE', infoB.nDataRE, ...
    'tbsBytesByLsubCH_psfch', g.tbsBytesByLsubCH, 'tbsBytesByLsubCH_nopsfch', g0.tbsBytesByLsubCH, ...
    'reCounts_psfch', nb, 'reCounts_nopsfch', nb0, 'ssbSlotsPerPeriod', Nperiod, ...
    'poolSlotsPerDfn', TmaxPrime, 'slotsPerDfn', nDfn, 'ldPsfch', g.ld, 'ldNoPsfch', g0.ld, ...
    'dmrsSymbolsPsfch', g.dmrsSymbols, 'dmrsSymbolsNoPsfch', g0.dmrsSymbols, 'nRbBwp', g.nRbBwp, ...
    'physOfLogicalFirst', physOfLogical(1:10));
out.files = files;
disp(out.symbolTable);
fprintf('TBS bytes by L_subCH at MCS 7: with PSFCH %s, without %s\n', ...
    mat2str(g.tbsBytesByLsubCH), mat2str(g0.tbsBytesByLsubCH));
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end
save(fullfile(s.dataRoot, 'slotStructure.mat'), 'out');
end

% =========================================================================
function [role, counts] = dataSlotRoles(g, C)
%dataSlotRoles Build one slot the way stack.txSlot does -- two UEs' PSSCH, plus a PSFCH when the
%pool has PSFCH -- and label every RE by which channel's index list put it there.
role = zeros(g.nSubcarriers, 14);
tx = struct('start', {0, 3}, 'L', {2, 1}, 'prio', {3, 6});
for k = 1:numel(tx)
    L = tx(k).L;
    sci1a = struct('priority', tx(k).prio, ...
        'friv', phy.ts38212.frivEncode(0, 0, L, g.numSubchannel, g.maxNumPerReserve), ...
        'triv', phy.ts38212.trivEncode(1, 0, 0, g.maxNumPerReserve), ...
        'reservationPeriodIndex', 0, 'dmrsPatternIndex', g.dmrsPatternIndex, 'sci2Format', 'A', ...
        'betaOffsetIndex', g.betaOffsetIndex, 'numDmrsPort', 0, 'mcs', g.mcs, ...
        'additionalMcsTableIndex', 0, 'psfchOverhead', 0);
    sci2 = struct('harqProcessNumber', 0, 'ndi', 0, 'rv', 0, 'sourceID', k, ...
        'destinationID', 255, 'harqFeedbackEnabled', 0, 'castType', 0, 'csiRequest', 0);
    tb = false(8 * g.tbsBytesByLsubCH(L), 1);
    [~, ~, info] = stack.phySlotTx(g, tx(k).start, L, 0, sci1a, sci2, tb, 0, NaN);
    role = paint(role, info.pscch.dataInd, C.pscch, 0);
    role = paint(role, info.pscch.dmrsInd, C.pscchDmrs, 0);
    sciRe = info.pssch.dataInd(1:info.pssch.Msymb1, :);
    datRe = info.pssch.dataInd(info.pssch.Msymb1 + 1:end, :);
    role = paint(role, datRe, C.data, 0);
    role = paint(role, sciRe, C.sci2, 0);
    role = paint(role, info.pssch.dmrsInd, C.psschDmrs, 0);
    sc = 12 * g.subchStartRb(tx(k).start + 1) + (1:12 * L * g.subchSizeRb);
    % Columns are l + 1. AGC is l = firstSymbol - 1 (slAgcSymbol); the guard is the last
    % sidelink symbol, l = sl-StartSymbol + sl-LengthSymbols - 1.
    role(sc, g.firstSymbol - 1 + 1) = C.agc;
    role(sc, g.slStartSymbol + g.slLengthSymbols - 1 + 1) = C.guard;
    if g.psfchPeriod > 0
        role(sc, g.psfchSymbol - 2 + 1) = C.guard;     % the gap symbol before PSFCH (38.214 8.1.2.1)
    end
end
if g.psfchPeriod > 0
    grid = stack.psfchGridAdd(complex(zeros(g.nSubcarriers, 14)), g, 0, g.psfchRbAbs(1), 0, 1);
    [kk, ll] = find(abs(grid) > 0);
    role(sub2ind(size(role), kk, ll)) = C.psfch;       % l' - 1 (its AGC copy) and l'
end
counts = struct();
names = {'pscch', 'pscchDmrs', 'sci2', 'data', 'psschDmrs', 'psfch'};
for q = 1:numel(names)
    counts.(names{q}) = nnz(role == C.(names{q}));
end
end

function f = drawDataSlot(role, cmap, ROLE, C, ttl)
%drawDataSlot A PRB-level overview (DM-RS combs marked, since 6 of 12 subcarriers cannot be
%drawn at that scale without aliasing) and an RE-level zoom across UE A's PSCCH edge.
[f, t] = newFig(1250, 600, 1, 2);
t.TileSpacing = 'loose';
nPrb = size(role, 1) / 12;
coarse = zeros(nPrb, 14);
hasDmrs = false(nPrb, 14);
dm = [C.psbchDmrs C.pscchDmrs C.psschDmrs];
for p = 1:nPrb
    blk = role((p - 1) * 12 + (1:12), :);
    for l = 1:14
        col = blk(:, l);
        hasDmrs(p, l) = any(ismember(col, dm));
        rest = col(~ismember(col, dm) & col > 0);
        if ~isempty(rest), coarse(p, l) = mode(rest);
        elseif hasDmrs(p, l), coarse(p, l) = col(find(col > 0, 1)); end
    end
end
ax = nexttile(t);
image(ax, 0:13, (0:nPrb - 1) + 0.5, coarse + 1); colormap(ax, cmap); clim(ax, [0.5 size(cmap, 1) + 0.5]);
set(ax, 'YDir', 'normal', 'XTick', 0:13, 'TickDir', 'out', 'Layer', 'top'); hold(ax, 'on');
[pp, ll] = find(hasDmrs & coarse ~= C.psschDmrs & coarse ~= C.pscchDmrs);
plot(ax, ll - 1, pp - 0.5, '.', 'Color', cmap(C.psschDmrs + 1, :), 'MarkerSize', 7);
for x = 0.5:1:12.5, xline(ax, x, 'Color', [1 1 1], 'LineWidth', 0.5); end
xlabel(ax, 'OFDM symbol l'); ylabel(ax, 'PRB'); ylim(ax, [0 nPrb]);
title(ax, {ttl, 'per PRB; red dots = DM-RS comb in that PRB'}, 'FontWeight', 'normal');
ax = nexttile(t);
rows = 7 * 12 + 1:13 * 12;                       % PRB 7..12: PSCCH edge at PRB 10 of UE A
image(ax, 0:13, (rows - 1) / 12, role(rows, :) + 1); colormap(ax, cmap); clim(ax, [0.5 size(cmap, 1) + 0.5]);
set(ax, 'YDir', 'normal', 'XTick', 0:13, 'TickDir', 'out', 'Layer', 'top'); hold(ax, 'on');
for x = 0.5:1:12.5, xline(ax, x, 'Color', [1 1 1], 'LineWidth', 0.5); end
yline(ax, 10, '--', 'PSCCH edge', 'Color', [0.3 0.3 0.3], 'LabelHorizontalAlignment', 'left');
xlabel(ax, 'OFDM symbol l'); ylabel(ax, 'PRB (subcarrier resolution)');
title(ax, {'RE-level zoom, PRB 7-12', 'white at l = 1-2 above PRB 10: unmapped, see note'}, 'FontWeight', 'normal');
legendRoles(ax, cmap, ROLE, unique(role(:))');
end

function role = paint(role, ind, val, scOffset)
if isempty(ind), return; end
role(sub2ind(size(role), ind(:, 1) + 1 + scOffset, ind(:, 2) + 1)) = val;
end

function drawRoles(ax, role, cmap, ROLE, ttl) %#ok<INUSD>
image(ax, 0:13, (0:size(role, 1) - 1) / 12, role + 1);
colormap(ax, cmap); clim(ax, [0.5 size(cmap, 1) + 0.5]);
set(ax, 'YDir', 'normal', 'XTick', 0:13, 'TickDir', 'out', 'Layer', 'top');
xlabel(ax, 'OFDM symbol l'); ylabel(ax, 'PRB');
title(ax, ttl, 'FontWeight', 'normal');
hold(ax, 'on');
for x = 0.5:1:12.5, xline(ax, x, 'Color', [1 1 1], 'LineWidth', 0.5); end
end

function legendRoles(ax, cmap, ROLE, present)
present = present(present > 0);
h = gobjects(1, numel(present));
for q = 1:numel(present)
    h(q) = patch(ax, NaN, NaN, cmap(present(q) + 1, :), 'EdgeColor', 'none');
end
legend(ax, h, ROLE(present + 1), 'Location', 'eastoutside', 'Box', 'off');
end
