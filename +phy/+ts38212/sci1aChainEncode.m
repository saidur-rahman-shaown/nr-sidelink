function out = sci1aChainEncode(sci1aBits, E)
%sci1aChainEncode SCI-1A channel-coding chain: CRC, polar encode, rate match.
%Spec:   TS 38.212 V16.15.0, clause 8.3.2-8.3.4 (CRC per clause 7.3.2 except no RNTI masking;
%        channel coding per clause 7.3.3; rate matching per clause 7.3.4)
%Inputs: sci1aBits  column vector (logical or 0/1), length A -- the output of sci1aPack
%        E          nonnegative integer -- rate-matched output length
%Outputs: out  E-by-1 column vector, logical -- the coded bit sequence ready for TS 38.211
%              clause 8.3.2.1 mapping to PSCCH (no scrambling for SCI-1A, per clause 8.3.2)
withCrc = phy.lib.ts38212.dciCrcEncode(sci1aBits, []);
K = numel(withCrc);
encoded = phy.lib.ts38212.polarEncode(withCrc, E, 9, true);
out = phy.lib.ts38212.polarRateMatch(encoded, K, E, false);
end
