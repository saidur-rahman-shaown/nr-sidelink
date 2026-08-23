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
%Outputs: out  column vector, length 1386 (normal) or 1782 (extended), logical -- the
%              rate-matched coded bit sequence f(0)..f(E-1), ready for TS 38.211 clause
%              8.3.3.1 scrambling (not performed here)
switch cyclicPrefix
    case 'normal'
        E = 1386;
    case 'extended'
        E = 1782;
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
