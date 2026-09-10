function [sci1aBits, crcOk] = sci1aChainDecode(llr, A, listSize)
%sci1aChainDecode SCI-1A channel-coding chain, inverse: de-rate-match, polar decode, CRC check.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 8.3.2-8.3.4, i.e. of sci1aChainEncode. The
%        CODE is normative; the DECODER is not, so the list size below is ours to choose and
%        this function is verified by recovering what sci1aChainEncode produced.
%Inputs: llr       E-by-1 real column vector -- channel LLRs for the PSCCH codeword,
%                  **negative for a probable 1** (phy.lib.demodLLR's convention). E is taken
%                  from numel(llr): it is fixed by the PSCCH resource allocation, which the
%                  receiver knows from where it found the PSCCH
%        A         positive integer -- SCI-1A payload length in bits, from sci1aPack's own
%                  field widths. The receiver knows this from the pool configuration
%        listSize  integer, one of {1,2,4,8} -- SCL list size
%Outputs: sci1aBits  A-by-1 logical column -- the recovered payload, ready for sci1aUnpack
%         crcOk      logical -- whether the CRC verified. **This is the PSCCH block-error
%                    indication**, and it is a return value rather than an exception because a
%                    failed decode is the normal outcome at range, not a fault
%
%iBIL = FALSE HERE, TRUE IN sci2ChainDecode
%-------------------------------------------
%SCI-1A rate-matches through clause 7.3.4, which sets IBIL = 0; SCI-2 goes through clause 5.4.1
%with IBIL = 1. sci1aChainEncode and sci2ChainEncode already differ on exactly this line, and
%the decoders have to differ with them. Getting it wrong does not raise -- the de-interleaver
%simply permutes the LLRs into the wrong order, and the result is a decoder that fails at every
%SNR, which reads as a broken channel rather than a wrong flag.

if ~any(listSize == [1 2 4 8])
    error('ts38212:sci1aChainDecode:badList', 'sci1aChainDecode: listSize must be 1, 2, 4 or 8, got %s', num2str(listSize));
end
E = numel(llr);
K = A + 24;                                    % clause 7.3.2 attaches a 24-bit CRC
N = phy.lib.ts38212.polarMotherLength(K, E, 9);

recovered = phy.lib.ts38212.polarDeRateMatch(llr(:), K, N, false);
withCrc   = phy.lib.ts38212.polarDecode(recovered, K, N, listSize, 9, true, 24);
[sci1aBits, err] = phy.lib.ts38212.dciCrcCheck(withCrc, []);
crcOk = (err == 0);
end
