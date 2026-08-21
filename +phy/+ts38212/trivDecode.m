function [N, t1, t2] = trivDecode(triv, maxReserve)
%trivDecode Recover the resource time offsets folded into a TRIV field value.
%Spec:   TS 38.214 V16.17.0, clause 8.1.5 (inverse of trivEncode)
%Inputs: triv        nonnegative integer, < 2^trivBitWidth(maxReserve)
%        maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: N   integer, 1, 2, or 3 -- number of actual resources
%         t1  integer -- resource-2 time offset; 0 when N==1 (not applicable)
%         t2  integer -- resource-3 time offset; 0 when N<3 (not applicable)
%
%N=3 is recovered by exhaustive search over the legal (t1,t2) domain (at most 30*31
%combinations) rather than inverting the piecewise TRIV formula directly -- correct by
%construction against trivEncode; the spec only implies the formula is injective over that
%domain (a real field could not otherwise be decoded), it is not independently proven so here.
bits = phy.ts38212.trivBitWidth(maxReserve);
if triv < 0 || triv >= 2^bits || mod(triv, 1) ~= 0
    error('ts38212:trivDecode:badTriv', 'trivDecode: triv must be an integer in 0..%d, got %s', 2^bits - 1, num2str(triv));
end
if triv == 0
    N = 1; t1 = 0; t2 = 0;
    return;
end
if maxReserve == 2
    if triv < 1 || triv > 31
        error('ts38212:trivDecode:badTriv', 'trivDecode: maxReserve=2 requires triv in 0..31, got %d', triv);
    end
    N = 2; t1 = triv; t2 = 0;
    return;
end
if maxReserve ~= 3
    error('ts38212:trivDecode:badMaxReserve', 'trivDecode: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
if triv >= 1 && triv <= 31
    N = 2; t1 = triv; t2 = 0;
    return;
end
for cand1 = 1:30
    for cand2 = (cand1 + 1):31
        if phy.ts38212.trivEncode(3, cand1, cand2, 3) == triv
            N = 3; t1 = cand1; t2 = cand2;
            return;
        end
    end
end
error('ts38212:trivDecode:noMatch', 'trivDecode: triv=%d does not correspond to any legal N=3 (t1,t2) pair', triv);
end
