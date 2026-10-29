function [g, tbsBits] = applySci(g, sci1a, LsubCH)
%applySci Re-derive the PSSCH geometry from what an SCI-1A actually signalled.
%Spec:   TS 38.212 V16.15.0 clause 8.3.1.1 -- the SCI-1A fields 'DMRS pattern', 'Beta_offset
%        indicator', 'Modulation and coding scheme' and 'Additional MCS table indicator' select,
%        respectively, the entry of sl-PSSCH-DMRS-TimePatternList, of sl-BetaOffsets2ndSCI (Table
%        8.3.1.1-2), and the MCS. TS 38.214 8.1.3.1/8.1.3.2 for modulation, rate and TBS.
%Inputs: g        struct from stack.poolGeometry
%        sci1a    struct from phy.ts38212.sci1aUnpack
%        LsubCH   integer -- the allocation width, from phy.ts38212.frivLsubch
%Outputs: g        g with .mcs .modScheme .Qm .R .nDmrs .dmrsSymbols .beta replaced by the SCI's
%         tbsBits  integer -- the transport block size in bits this SCI implies
%
%A receiver must size everything from the SCI, never from its own transmit choices. Using the
%local defaults works only while every UE happens to pick the same MCS and DM-RS pattern, and
%fails the first time two configurations differ -- with a TB CRC failure that looks like noise.

SUBCARRIERS_PER_RB = 12;
g.mcs = sci1a.mcs;
[g.modScheme, g.Qm, g.R] = phy.ts38214.mcsTableSelect(sci1a.mcs, g.pool.sl_Additional_MCS_Table_r16, sci1a.additionalMcsTableIndex);
g.dmrsPatternIndex = sci1a.dmrsPatternIndex;
g.nDmrs = g.dmrsPatternList(sci1a.dmrsPatternIndex + 1);
g.dmrsSymbols = phy.ts38211.slPSSCHDMRSTimePattern(g.ld, g.pscchSymbols, g.nDmrs);
g.betaOffsetIndex = sci1a.betaOffsetIndex;
g.beta = phy.ts38213.betaOffsetSci2(g.betaList, sci1a.betaOffsetIndex);
m = stack.psschMapping(g, 0, LsubCH, 0);
nReSci1 = g.pscchSymbols * g.pscchPrb * SUBCARRIERS_PER_RB;
tbsBits = phy.ts38214.tbsDetermine(g.Qm, g.R, 1, LsubCH * g.subchSizeRb, g.slLengthSymbols, ...
    g.psfchPeriod, false, 0, g.dmrsPatternList, nReSci1, m.Gsci2 / 2);
end
