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
%!! A DEFECT IN slBchEncode's CYCLIC-PREFIX MAPPING, WORKED AROUND HERE !!
%-------------------------------------------------------------------------
%TS 38.212 clause 8.1 reads: "the rate matching output sequence length E = 1386 when higher
%layer parameter cyclicPrefix is configured, otherwise, E = 1782." The RRC field `cyclicPrefix`
%is present only for EXTENDED cyclic prefix, so the clause means extended -> 1386, normal ->
%1782. `phy.ts38212.slBchEncode` has the two labels the other way round: it returns 1386 for
%'normal' and 1782 for 'extended'.
%
%The resource grid confirms the clause independently. PSBCH occupies 99 subcarriers in
%N_symb^S-SSB - 4 symbols, so normal CP (13 symbols) gives 891 REs = **1782** QPSK bits and
%extended (11 symbols) gives 693 REs = **1386**. `phy.ts38211.slPSBCHIndices` returns exactly
%those counts. Two frozen modules therefore contradict each other, and the spec text and the RE
%arithmetic both point the same way.
%
%slBchEncode is not modified here (it is one of the verified TS 38.212 modules). Instead this
%function sizes the codeword from the RE count -- which is authoritative, since the bits must
%fill exactly those REs -- and calls slBchEncode with whichever label currently produces that
%length. The assertion below then checks the result, so if slBchEncode is ever corrected this
%call site fails loudly instead of silently emitting a codeword of the wrong length.

dataInd = phy.ts38211.slPSBCHIndices(cfg.Nsymb);
dmrsInd = phy.ts38211.slPSBCHDMRSIndices(cfg.Nsymb);
spssInd = phy.ts38211.slSPSSIndices();
sssInd  = phy.ts38211.slSSSSIndices();

nDataRE = size(dataInd, 1);
E       = 2 * nDataRE;                       % PSBCH is QPSK, clause 8.4.1

% See the header. The label is chosen by the length it yields, not by its name.
if E == 1782
    cpLabelForE = 'extended';
elseif E == 1386
    cpLabelForE = 'normal';
else
    error('chan:psbchTx:unexpectedE', 'psbchTx: %d PSBCH data REs imply E=%d, which clause 8.1 does not define', nDataRE, E);
end
coded = phy.ts38212.slBchEncode(mibBits, cpLabelForE);
assert(numel(coded) == E, ...
    'chan:psbchTx:codewordLength: slBchEncode returned %d bits for a %d-RE allocation needing %d -- its cyclic-prefix mapping has changed; see this function''s header', ...
    numel(coded), nDataRE, E);

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
