function [grid, info] = pscchTx(grid, carrier, cfg, sci1aBits)
%pscchTx PSCCH transmit chain: SCI-1A bits to resource elements on the grid.
%Spec:   TS 38.212 V16.15.0 clause 8.3.2-8.3.4 (CRC, polar, rate match, via sci1aChainEncode)
%        then TS 38.211 V16.10.0 clause 8.3.2 (scrambling and QPSK, via slPSCCH), clause
%        8.3.2.2 (DM-RS, via slPSCCHDMRS) and clause 8.3.2.3 (RE mapping, via the two index
%        functions).
%Inputs: grid       nSubcarriers-by-nSymbols complex matrix -- the slot grid to write into.
%                   Taken and returned rather than created here, because a slot carries PSCCH
%                   and PSSCH together and only the caller knows the full grid size
%        carrier    scalar struct, slCarrierConfig
%        cfg        scalar struct from phy.ts38211.slPSCCHConfig
%        sci1aBits  A-by-1 column of 0/1 -- the output of phy.ts38212.sci1aPack
%Outputs: grid  the input with the PSCCH data and DM-RS REs written
%         info  scalar struct: .E (coded bit count), .dataInd, .dmrsInd ([k l] pairs), .nDataRE
%
%THE RATE-MATCHED LENGTH IS DERIVED FROM THE ALLOCATION, NOT PASSED IN
%----------------------------------------------------------------------
%E = 2 x (number of PSCCH data REs), because clause 8.3.2 fixes PSCCH at QPSK and the data REs
%are whatever the allocation leaves after the DM-RS. Passing E in from outside would let a
%caller rate-match to a length the allocation cannot carry, and the symptom is REs left
%unwritten at the end of the mapping -- which decodes as noise and looks like a channel
%problem. +phy/+chan/CLAUDE.md makes the same argument for the SCI-2 resource size.

dataInd = phy.ts38211.slPSCCHIndices(carrier, cfg);
dmrsInd = phy.ts38211.slPSCCHDMRSIndices(cfg.startPRB, cfg.NRB, cfg.symbols);

nDataRE = size(dataInd, 1);
E       = 2 * nDataRE;                          % QPSK, clause 8.3.2

coded = phy.ts38212.sci1aChainEncode(sci1aBits, E);
d     = phy.ts38211.slPSCCH(carrier, cfg, coded);

grid(sub2ind(size(grid), dataInd(:, 1) + 1, dataInd(:, 2) + 1)) = d;

% DM-RS is generated per symbol: its cinit walks with l, so one call per symbol and never one
% long sequence sliced up.
nPerSym = 3 * cfg.NRB;
for s = 1:numel(cfg.symbols)
    l = cfg.symbols(s);
    r = phy.ts38211.slPSCCHDMRS(cfg.DMRS_NID, l, cfg.nsf, cfg.NsymbSlot, cfg.NRB);
    rows = (s - 1) * nPerSym + (1:nPerSym);
    grid(sub2ind(size(grid), dmrsInd(rows, 1) + 1, dmrsInd(rows, 2) + 1)) = r;
end

info = struct('E', E, 'nDataRE', nDataRE, 'dataInd', dataInd, 'dmrsInd', dmrsInd);
end
