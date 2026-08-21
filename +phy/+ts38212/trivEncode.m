function [triv, bits] = trivEncode(N, t1, t2, maxReserve)
%trivEncode Fold a set of PSSCH resource time offsets into the TRIV field value.
%Spec:   TS 38.214 V16.17.0, clause 8.1.5
%Inputs: N           integer, 1, 2, or 3 -- number of actual resources, N<=maxReserve
%        t1          integer -- resource-2 time offset in logical slots from the first
%                    (SCI-1A-carrying) resource; 1..31 when N=2, 1..30 when N=3; ignored
%                    (any value accepted) when N=1
%        t2          integer -- resource-3 time offset, t1<t2<=31; ignored unless N=3
%        maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: triv  nonnegative integer, the packed TRIV value
%         bits  bit width of the field, from trivBitWidth(maxReserve)
bits = phy.ts38212.trivBitWidth(maxReserve);
if ~(N == 1 || N == 2 || N == 3) || N > maxReserve
    error('ts38212:trivEncode:badN', 'trivEncode: N must be an integer in 1..maxReserve (maxReserve=%d), got %s', maxReserve, num2str(N));
end
if N == 1
    triv = 0;
elseif N == 2
    if ~(t1 >= 1 && t1 <= 31 && mod(t1, 1) == 0)
        error('ts38212:trivEncode:badT1', 'trivEncode: N=2 requires 1<=t1<=31, got %s', num2str(t1));
    end
    triv = t1;
else
    if ~(t1 >= 1 && t1 <= 30 && mod(t1, 1) == 0)
        error('ts38212:trivEncode:badT1', 'trivEncode: N=3 requires 1<=t1<=30, got %s', num2str(t1));
    end
    if ~(t2 > t1 && t2 <= 31 && mod(t2, 1) == 0)
        error('ts38212:trivEncode:badT2', 'trivEncode: N=3 requires t1<t2<=31, got t1=%s t2=%s', num2str(t1), num2str(t2));
    end
    gap = t2 - t1 - 1;
    if gap <= 15
        triv = 30 * gap + t1 + 31;
    else
        triv = 30 * (31 - t2 + t1) + 62 - t1;
    end
end
end
