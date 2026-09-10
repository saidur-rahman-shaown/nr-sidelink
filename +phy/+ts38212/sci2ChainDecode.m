function [sci2Bits, crcOk] = sci2ChainDecode(llr, A, listSize)
%sci2ChainDecode SCI-2 channel-coding chain, inverse: de-rate-match, polar decode, CRC check.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 8.4.2-8.4.4, i.e. of sci2ChainEncode.
%Inputs: llr       G-by-1 real column vector -- channel LLRs for the SCI-2 portion of the
%                  PSSCH, **negative for a probable 1**. G is G^SCI2, which the receiver
%                  computes from sci2OutputLength using fields it read from the SCI-1A it has
%                  already decoded -- which is why SCI-1A must be decoded first
%        A         positive integer -- SCI-2 payload length: 35 for format 2-A, 48 for 2-B.
%                  Which format applies is signalled in SCI-1A's '2nd-stage SCI format' field
%        listSize  integer, one of {1,2,4,8} -- SCL list size
%Outputs: sci2Bits  A-by-1 logical column -- ready for sci2aUnpack or sci2bUnpack
%         crcOk     logical -- the SCI-2 block-error indication
%
%iBIL = TRUE here, against sci1aChainDecode's false -- see that function's header. The two
%chains are otherwise identical, which is exactly why the difference is easy to lose.

if ~any(listSize == [1 2 4 8])
    error('ts38212:sci2ChainDecode:badList', 'sci2ChainDecode: listSize must be 1, 2, 4 or 8, got %s', num2str(listSize));
end
G = numel(llr);
K = A + 24;
N = phy.lib.ts38212.polarMotherLength(K, G, 9);

recovered = phy.lib.ts38212.polarDeRateMatch(llr(:), K, N, true);
withCrc   = phy.lib.ts38212.polarDecode(recovered, K, N, listSize, 9, true, 24);
[sci2Bits, err] = phy.lib.ts38212.dciCrcCheck(withCrc, []);
crcOk = (err == 0);
end
