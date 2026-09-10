function [grid, info] = psschTx(grid, carrier, cfg, mapCfg, sci2Bits, tbBits, txp)
%psschTx PSSCH transmit chain: SCI-2 and SL-SCH onto the grid, DM-RS first.
%Spec:   TS 38.212 V16.15.0 clause 8.4.2-8.4.4 (SCI-2 coding), clause 8.2.1 (multiplexing, via
%        sci12Multiplex), clauses 6.2.1-6.2.6 (SL-SCH coding, via slSchEncode); then TS 38.211
%        V16.10.0 clause 8.3.1 (scrambling and modulation, via slPSSCH) and clause 8.4.1.1
%        (DM-RS) / 8.3.1.4 (RE mapping, via the index functions).
%Inputs: grid      nSubcarriers-by-nSymbols complex matrix to write into
%        carrier   scalar struct, slCarrierConfig
%        cfg       scalar struct from phy.ts38211.slPSSCHConfig (NID, MbitSCI2, modScheme, ...)
%        mapCfg    scalar struct for phy.ts38211.slPSSCHIndices: .startPRB .NRB .ld
%                  .dmrsSymbols .pscchRE (and .Msymb1, filled in here)
%        sci2Bits  A-by-1 column -- from sci2aPack or sci2bPack
%        tbBits    trblklen-by-1 column -- the SL-SCH transport block
%        txp       scalar struct: .Gsci2 (G^SCI2 from phy.ts38212.sci2OutputLength), .R, .rv,
%                  .Qm, .modScheme, .nlayers
%Outputs: grid  the input with DM-RS, SCI-2 and data written
%         info  scalar struct: .Gsci2 .Gslsch .Msymb1 .dataInd .dmrsInd .nDataRE
%
%MAPPING ORDER IS DM-RS, THEN SCI-2, THEN DATA -- AND IT IS ASSERTED
%--------------------------------------------------------------------
%+phy/+chan/CLAUDE.md calls this out as the most expensive failure mode in the project: getting
%it wrong "leaves everything working at high SNR and failing subtly at low SNR", and would not
%surface until a system-level run. The order is structural here rather than incidental: DM-RS
%is written first and its REs are excluded from the data index list by slPSSCHIndices, and
%slPSSCHIndices returns the SCI-2 rows before the data rows so the concatenation from
%sci12Multiplex lands in that order by construction.
%
%THE PSSCH REGION EXCLUDES THE PSCCH REs, IT DOES NOT OVERWRITE THEM
%--------------------------------------------------------------------
%mapCfg.pscchRE carries the PSCCH's own [k l] pairs (data and its DM-RS) and slPSSCHIndices
%maps around them. The SL-SCH is rate-matched to whatever is left -- which is why G^SL-SCH is
%computed from the index list below rather than from the nominal allocation size. Rate matching
%to the nominal size and then writing over the PSCCH destroys the control channel of the very
%transmission that carries it.

Msymb1        = txp.Gsci2 / 2;                  % SCI-2 is always QPSK, clause 8.3.1
mapCfg.Msymb1 = Msymb1;
if mod(txp.Gsci2, 2) ~= 0
    error('chan:psschTx:oddGsci2', 'psschTx: G^SCI2 must be even (QPSK), got %d', txp.Gsci2);
end

dataInd = phy.ts38211.slPSSCHIndices(carrier, mapCfg);
nTotal  = size(dataInd, 1);
nDataRE = nTotal - Msymb1;
if nDataRE <= 0
    error('chan:psschTx:noRoomForData', 'psschTx: the SCI-2 needs %d of the %d available REs, leaving none for data', Msymb1, nTotal);
end
Gslsch = nDataRE * txp.Qm;

gSci2  = phy.ts38212.sci2ChainEncode(sci2Bits, txp.Gsci2);
gSlSch = phy.ts38212.slSchEncode(tbBits, txp.R, Gslsch, txp.rv, txp.modScheme, txp.nlayers);
g      = phy.ts38212.sci12Multiplex(gSci2, gSlSch, txp.nlayers, 2);

% NL = 1 places no placeholder bits: clause 8.2.1's "x" positions exist only in the NL=2
% branch, which sci12Multiplex explicitly does not implement.
placeholderMask = false(numel(g), 1);
d = phy.ts38211.slPSSCH(carrier, cfg, g, placeholderMask);

% ---- DM-RS first ---------------------------------------------------------
dmrsInd = phy.ts38211.slPSSCHDMRSIndices(mapCfg.startPRB, mapCfg.NRB, mapCfg.dmrsSymbols);
nPerSym = 6 * mapCfg.NRB;
for s = 1:numel(mapCfg.dmrsSymbols)
    l    = mapCfg.dmrsSymbols(s);
    r    = phy.ts38211.slPSSCHDMRS(cfg.NID, l, cfg.nsf, cfg.NsymbSlot, nPerSym);
    rows = (s - 1) * nPerSym + (1:nPerSym);
    grid(sub2ind(size(grid), dmrsInd(rows, 1) + 1, dmrsInd(rows, 2) + 1)) = r;
end

% ---- then SCI-2, then data, in the single ordered index list -------------
grid(sub2ind(size(grid), dataInd(:, 1) + 1, dataInd(:, 2) + 1)) = d;

info = struct('Gsci2', txp.Gsci2, 'Gslsch', Gslsch, 'Msymb1', Msymb1, ...
    'dataInd', dataInd, 'dmrsInd', dmrsInd, 'nDataRE', nDataRE);
end
