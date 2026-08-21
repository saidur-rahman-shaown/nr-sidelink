function [friv, bits] = frivEncode(nStart1, nStart2, LsubCH, Nsub, maxReserve)
%frivEncode Fold a set of PSSCH resource starting sub-channel indexes into the FRIV field.
%Spec:   TS 38.214 V16.17.0, clause 8.1.5
%Inputs: nStart1     integer, 0..(Nsub-LsubCH) -- starting sub-channel index of resource 2
%        nStart2     integer, 0..(Nsub-LsubCH) -- starting sub-channel index of resource 3;
%                    ignored (any value accepted) when maxReserve==2.
%
%maxReserve==3's summation term is SQUARED: sum((Nsub+1-i)^2, i=1..LsubCH-1), not linear like
%the maxReserve==2 branch. This is easy to miss -- pdftotext -layout flattens the exponent onto
%a stray line near the summation and it is trivial to drop when transcribing. Independently
%confirmed by an `independent-verifier` pass (glyph-position analysis of the PDF plus a
%bijectivity argument against 38.212 clause 8.3.1.1's ceil(log2(...)) width formula, which only
%tiles the codepoint space with the squared reading). The linear reading round-trips against
%itself perfectly (encode and decode consistently wrong the same way) but does not match the
%spec value -- caught only because independent-verifier derives from clause text, never from
%this file. `nrv2x-matlab/phy/SidelinkResourceIndicator.m` has the identical bug; do not use it
%to "confirm" this formula.
%        LsubCH      integer, >=1, <=Nsub -- number of contiguously allocated sub-channels,
%                    common to all N resources; known from the physical resource allocation
%                    carrying the SCI, not decodable from FRIV itself (same reasoning as the
%                    first resource's own starting sub-channel, which clause 8.1.5 says comes
%                    from clause 8.1.2.2, not from FRIV)
%        Nsub        integer, 1..27 -- higher-layer parameter sl-NumSubchannel
%        maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: friv  nonnegative integer, the packed FRIV value
%         bits  bit width of the field, from frivBitWidth(Nsub, maxReserve)
if ~(LsubCH >= 1 && LsubCH <= Nsub && mod(LsubCH, 1) == 0)
    error('ts38212:frivEncode:badL', 'frivEncode: LsubCH must be an integer in 1..Nsub (Nsub=%d), got %s', Nsub, num2str(LsubCH));
end
if ~(nStart1 >= 0 && nStart1 <= Nsub - LsubCH && mod(nStart1, 1) == 0)
    error('ts38212:frivEncode:badNStart1', 'frivEncode: nStart1 must be an integer in 0..%d, got %s', Nsub - LsubCH, num2str(nStart1));
end
bits = phy.ts38212.frivBitWidth(Nsub, maxReserve);
if maxReserve == 2
    triSum = sum(Nsub + 1 - (1:(LsubCH - 1)));
    friv = nStart1 + triSum;
elseif maxReserve == 3
    if ~(nStart2 >= 0 && nStart2 <= Nsub - LsubCH && mod(nStart2, 1) == 0)
        error('ts38212:frivEncode:badNStart2', 'frivEncode: nStart2 must be an integer in 0..%d, got %s', Nsub - LsubCH, num2str(nStart2));
    end
    triSum = sum((Nsub + 1 - (1:(LsubCH - 1))).^2);
    friv = nStart1 + nStart2 * (Nsub + 1 - LsubCH) + triSum;
else
    error('ts38212:frivEncode:badMaxReserve', 'frivEncode: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
end
