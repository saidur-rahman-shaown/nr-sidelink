function [blockGrid, info] = psbchTx(blockGrid, carrier, cfg, mibBits, NID1, NID2)
%psbchTx S-SS/PSBCH block: sync sequences, PSBCH DM-RS and the coded MIB-SL onto the block grid.
%Spec:   TS 38.212 V16.15.0 clause 8.1 (SL-BCH coding, via slBchEncode) and TS 38.211 V16.10.0
%        clause 8.4.2 (S-PSS/S-SSS), 8.4.3 (PSBCH DM-RS) and 8.4.1 (scrambling, modulation and
%        mapping, via slPSBCH and the index functions).
%Inputs: blockGrid  132-by-Nsymb complex matrix -- the S-SS/PSBCH block's OWN grid. Every index
%                   function in this chain returns [k l] relative to the block's origin, not to
%                   the carrier, so the block is assembled standalone and placed by the caller
%        carrier    scalar struct, slCarrierConfig
%        cfg        scalar struct from phy.ts38211.slPSBCHConfig (NIDSL, Nsymb)
%        mibBits    32-by-1 column -- the output of phy.ts38212.mibSlPack
%        NID1       integer, 0..335 -- N_ID,1^SL
%        NID2       integer, 0 or 1 -- N_ID,2^SL
%Outputs: blockGrid  the input with S-PSS, S-SSS, PSBCH DM-RS and PSBCH written
%         info       scalar struct: .E .dataInd .dmrsInd .spssInd .sssInd .nDataRE
%
%THE CODEWORD LENGTH IS DERIVED FROM THE ALLOCATION, NOT FROM A LABEL
%---------------------------------------------------------------------
%E is computed as 2 x (PSBCH data REs) -- QPSK, clause 8.4.1 -- and the cyclic-prefix label is
%then derived from the S-SSB symbol count rather than passed in. The codeword must fill exactly
%those REs, so the allocation is the authoritative source and the label is a consequence of it.
%
%This ordering is deliberate and has already earned itself. phy.ts38212.slBchEncode's two
%labels were inverted (normal returned 1386 where clause 8.1 and TS 38.331's RRC field
%definition give 1782), and the assertion below is what caught it: a length taken from a label
%disagreed with a length taken from the grid. The defect had survived because slBchEncode's own
%unit test asserted the same inversion -- code and test agreeing with each other, which
%+test/CLAUDE.md names as proving self-consistency rather than correctness. slBchEncode and its
%test were corrected on 2026-09-11; the assertion stays, because it is the only check here that
%compares two independent facts rather than one fact with itself.
dataInd = phy.ts38211.slPSBCHIndices(cfg.Nsymb);
dmrsInd = phy.ts38211.slPSBCHDMRSIndices(cfg.Nsymb);
spssInd = phy.ts38211.slSPSSIndices();
sssInd  = phy.ts38211.slSSSSIndices();

nDataRE = size(dataInd, 1);
E       = 2 * nDataRE;                       % PSBCH is QPSK, clause 8.4.1

% The cyclic prefix follows from the S-SSB symbol count: TS 38.211 clause 8.4.3.1 gives
% N_symb^S-SSB = 13 for normal and 11 for extended.
switch cfg.Nsymb
    case 13
        cyclicPrefix = 'normal';
    case 11
        cyclicPrefix = 'extended';
    otherwise
        error('chan:psbchTx:badNsymb', 'psbchTx: N_symb^S-SSB must be 13 (normal CP) or 11 (extended), got %d', cfg.Nsymb);
end
coded = phy.ts38212.slBchEncode(mibBits, cyclicPrefix);
% The check that caught the inversion: a length from the label against a length from the grid.
assert(numel(coded) == E, ...
    'chan:psbchTx:codewordLength: slBchEncode returned %d bits for ''%s'' but the %d-RE PSBCH allocation needs %d -- the two disagree; see this function''s header', ...
    numel(coded), cyclicPrefix, nDataRE, E);

d = phy.ts38211.slPSBCH(carrier, cfg, coded);

% ---- sync sequences ------------------------------------------------------
% S-PSS is the SAME 127-value sequence placed once in each of two symbols -- a repetition for
% robustness, not one 254-long sequence. slSPSSIndices' header says so explicitly, and reading
% it as continuous puts the second half of a longer sequence in symbol 2.
spss = phy.ts38211.slSPSS(NID2);
sss  = phy.ts38211.slSSSS(NID1, NID2);
blockGrid(sub2ind(size(blockGrid), spssInd(:, 1) + 1, spssInd(:, 2) + 1)) = [spss; spss];
blockGrid(sub2ind(size(blockGrid), sssInd(:, 1) + 1,  sssInd(:, 2) + 1))  = [sss; sss];

% ---- PSBCH DM-RS, then PSBCH ---------------------------------------------
r = phy.ts38211.slPSBCHDMRS(cfg.NIDSL, cfg.Nsymb);
blockGrid(sub2ind(size(blockGrid), dmrsInd(:, 1) + 1, dmrsInd(:, 2) + 1)) = r;
blockGrid(sub2ind(size(blockGrid), dataInd(:, 1) + 1, dataInd(:, 2) + 1)) = d;

info = struct('E', E, 'nDataRE', nDataRE, 'dataInd', dataInd, 'dmrsInd', dmrsInd, ...
    'spssInd', spssInd, 'sssInd', sssInd);
end
