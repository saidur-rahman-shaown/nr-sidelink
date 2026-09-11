function out = slBchEncode(mibBits, cyclicPrefix)
%slBchEncode SL-BCH transport channel processing: CRC, polar encode, rate match.
%Spec:   TS 38.212 V16.15.0, clause 8.1 (follows clause 7.1.3-7.1.5, PBCH's chain, with the
%        rate-matching output length and the omission of clause 7.1.1 payload generation and
%        clause 7.1.2 scrambling -- both out of scope for this function: mibSlPack already IS
%        the payload generation step for SL-BCH, and scrambling is TS 38.211 clause 8.3.3.1's
%        job, not this package's)
%Inputs: mibBits       32-by-1 column vector (logical or 0/1) -- MIB-SL information bits, the
%                      output of mibSlPack
%        cyclicPrefix  char, 'normal' or 'extended' -- higher-layer parameter cyclicPrefix for
%                      the sidelink BWP; selects the clause 8.1 rate-matching output length
%Outputs: out  column vector, length 1782 (normal) or 1386 (extended), logical -- the
%              rate-matched coded bit sequence f(0)..f(E-1), ready for TS 38.211 clause
%              8.3.3.1 scrambling (not performed here)
%
%WHICH LABEL GETS WHICH LENGTH, AND HOW IT WAS ONCE INVERTED
%------------------------------------------------------------
%Clause 8.1 states the rule in terms of the RRC field rather than the CP name: "the rate
%matching output sequence length E = 1386 when higher layer parameter cyclicPrefix is
%CONFIGURED, otherwise, E = 1782". TS 38.331's BWP IE defines that field as
%`cyclicPrefix ENUMERATED { extended } OPTIONAL`, with "If not set, the UE uses the normal
%cyclic prefix" -- so its only value is `extended` and its absence means normal. Configured
%therefore means EXTENDED, giving extended = 1386 and normal = 1782.
%
%This function had the two the other way round until 2026-09-11. Three independent sources say
%otherwise and agree with each other: the clause plus the RRC field definition above; TS 38.211
%clause 8.4.3.1, where N_symb^S-SSB is 13 for normal and 11 for extended, and Table 8.4.3.1-1
%puts PSBCH on (N_symb - 4) symbols x (132 - 33 DM-RS) = 99 subcarriers, giving 9 x 99 = 891 REs
%= 1782 QPSK bits for normal and 7 x 99 = 693 REs = 1386 for extended; and
%+phy/+ts38211/slPSBCHIndices, which returns exactly those RE counts.
%
%It survived verification because its own unit test asserted the same inversion, so code and
%test agreed with each other. +test/CLAUDE.md names that failure mode exactly: a round trip
%"proves self-consistency, never correctness". The error could only become visible once a
%codeword had to FIT A RESOURCE ALLOCATION, which needs 38.212 and 38.211 composed -- and that
%composition did not exist until +phy/+chan/psbchTx was written. At normal CP the old mapping
%left 198 of 891 REs unwritten, 22% of the PSBCH, and nothing decoded at any SNR.
switch cyclicPrefix
    case 'normal'
        E = 1782;
    case 'extended'
        E = 1386;
    otherwise
        error('ts38212:slBchEncode:badCyclicPrefix', 'slBchEncode: cyclicPrefix must be ''normal'' or ''extended'', got ''%s''', cyclicPrefix);
end
if numel(mibBits) ~= 32
    error('ts38212:slBchEncode:badMibBits', 'slBchEncode: mibBits must have 32 elements, got %d', numel(mibBits));
end
withCrc = phy.lib.ts38212.crcEncode(mibBits, '24C');
K = numel(withCrc);
encoded = phy.lib.ts38212.polarEncode(withCrc, E, 9, true);
out = phy.lib.ts38212.polarRateMatch(encoded, K, E, false);
end
