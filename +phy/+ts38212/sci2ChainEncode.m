function out = sci2ChainEncode(sci2Bits, outlen)
%sci2ChainEncode SCI-2 (format 2-A or 2-B) channel-coding chain: CRC, polar encode, rate match.
%Spec:   TS 38.212 V16.15.0, clause 8.4.2-8.4.4 (CRC per clause 7.3.2 except no RNTI masking;
%        channel coding per clause 7.3.3; rate matching per clause 5.4.1 with IBIL=1 -- note
%        this differs from SCI-1A's sci1aChainEncode, which uses IBIL=0 via clause 7.3.4)
%Inputs: sci2Bits  column vector (logical or 0/1), length A -- the output of sci2aPack or
%                  sci2bPack
%        outlen    nonnegative integer -- G^SCI2, from sci2OutputLength
%Outputs: out  outlen-by-1 column vector, logical -- g^SCI2(0)..g^SCI2(outlen-1), ready for
%              sci12Multiplex
withCrc = phy.lib.ts38212.dciCrcEncode(sci2Bits, []);
K = numel(withCrc);
encoded = phy.lib.ts38212.polarEncode(withCrc, outlen, 9, true);
out = phy.lib.ts38212.polarRateMatch(encoded, K, outlen, true);
end
