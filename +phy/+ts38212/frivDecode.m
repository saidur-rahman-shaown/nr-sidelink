function [nStart1, nStart2] = frivDecode(friv, LsubCH, Nsub, maxReserve)
%frivDecode Recover the resource starting sub-channel indexes folded into an FRIV value.
%Spec:   TS 38.214 V16.17.0, clause 8.1.5 (inverse of frivEncode)
%Inputs: friv        nonnegative integer, < 2^frivBitWidth(Nsub,maxReserve)
%        LsubCH      integer, >=1, <=Nsub -- number of contiguously allocated sub-channels;
%                    must be known externally, the same value frivEncode was called with (not
%                    recoverable from friv alone -- see frivEncode's header)
%        Nsub        integer, 1..27 -- higher-layer parameter sl-NumSubchannel
%        maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: nStart1  integer, 0..(Nsub-LsubCH) -- starting sub-channel index of resource 2
%         nStart2  integer -- starting sub-channel index of resource 3; 0 when
%                  maxReserve==2 (not applicable)
%
%maxReserve==3's summation term is SQUARED, matching frivEncode -- see that file's header for
%why this is easy to get wrong and how it was caught.
if maxReserve == 2
    triSum = sum(Nsub + 1 - (1:(LsubCH - 1)));
    remainder = friv - triSum;
    nStart1 = remainder;
    nStart2 = 0;
elseif maxReserve == 3
    triSum = sum((Nsub + 1 - (1:(LsubCH - 1))).^2);
    remainder = friv - triSum;
    divisor = Nsub + 1 - LsubCH;
    nStart2 = floor(remainder / divisor);
    nStart1 = remainder - nStart2 * divisor;
else
    error('ts38212:frivDecode:badMaxReserve', 'frivDecode: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
if nStart1 < 0 || nStart1 > Nsub - LsubCH || (maxReserve == 3 && (nStart2 < 0 || nStart2 > Nsub - LsubCH))
    error('ts38212:frivDecode:badFriv', 'frivDecode: friv=%d does not correspond to a legal allocation for LsubCH=%d, Nsub=%d, maxReserve=%d', friv, LsubCH, Nsub, maxReserve);
end
end
