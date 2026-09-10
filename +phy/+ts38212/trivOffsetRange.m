function [t1Max, t2Max] = trivOffsetRange(N)
%trivOffsetRange Largest time offsets TRIV can signal for N reserved resources.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1 via TS 38.214 V16.17.0 clause 8.1.5 -- the ranges
%        trivEncode enforces: "N=2 requires 1<=t1<=31", "N=3 requires 1<=t1<=30" and
%        "t1<t2<=31".
%Inputs: N  integer, 1, 2 or 3 -- number of actual resources
%Outputs: t1Max  integer -- largest legal t1 in logical pool slots; 0 when N=1 (no offset is
%                signalled at all)
%         t2Max  integer -- largest legal t2; 0 unless N=3
%
%WHY THIS EXISTS SEPARATELY FROM trivEncode
%-------------------------------------------
%A resource-selection policy has to know the range BEFORE it picks, not after. Picking freely
%and then discovering the pick cannot be encoded is not a recoverable error -- the selection
%window is routinely hundreds of slots wide while TRIV reaches only 31, so a policy that draws
%uniformly over the window produces an unsignallable grant most of the time. Reading the bound
%out of trivEncode's error messages is the alternative, and it is the kind of coupling that
%survives exactly until someone rewords an error string.
%
%Note the asymmetry: N=3 caps t1 at 30, not 31, because t2 must be strictly greater than t1 and
%is itself capped at 31. Using 31 for both looks harmless and makes the last legal
%three-resource pattern unencodable.

if ~any(N == [1 2 3])
    error('ts38212:trivOffsetRange:badN', 'trivOffsetRange: N must be 1, 2 or 3, got %s', num2str(N));
end

switch N
    case 1
        t1Max = 0;  t2Max = 0;
    case 2
        t1Max = 31; t2Max = 0;
    case 3
        t1Max = 30; t2Max = 31;
end
end
