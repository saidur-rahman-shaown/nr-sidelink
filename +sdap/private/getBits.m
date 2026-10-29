function [value, pos, ok] = getBits(bits, pos, width)
%getBits Read an unsigned integer from a bit string, most significant bit first.
%Spec:   TS 37.324 V19.0.0, clause 6.2.1 / 6.3.1 (byte-aligned bit strings, MSB first).
%Inputs: bits   1 x n row vector of 0/1
%        pos    integer, >=1 -- index of the first bit to read
%        width  integer, 1..18
%Outputs: value  integer, 0..2^width-1 (0 when ok is false)
%         pos    index of the bit after the field
%         ok     logical -- false when the string is too short, so a truncated PDU is reported
%                as invalid (clause 5.6.1) instead of raising

value = 0;
ok = pos + width - 1 <= numel(bits);
if ~ok
    return;
end
for k = 0:width-1
    value = value * 2 + bits(pos + k);
end
pos = pos + width;
end
