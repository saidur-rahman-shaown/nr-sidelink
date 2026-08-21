function bits = bitsFromUint(value, width)
%bitsFromUint Pack a nonnegative integer into a fixed-width MSB-first bit column.
%Not itself a spec clause -- implements the "each field's MSB maps to its lowest-order
%information bit, fields concatenated in declaration order" packing rule stated once in TS
%38.212 clause 8.3.1 and clause 8.4.1, shared by every Wave B pack/unpack function here.
%Inputs: value  nonnegative integer, < 2^width (0 when width==0)
%        width  nonnegative integer -- 0 is legal (produces an empty column)
%Outputs: bits  width-by-1 logical column, bits(1) is the MSB of value
if width == 0
    if value ~= 0
        error('ts38212:bitsFromUint:badValue', 'bitsFromUint: width 0 requires value 0, got %s', num2str(value));
    end
    bits = false(0, 1);
    return;
end
if value < 0 || value >= 2^width || mod(value, 1) ~= 0
    error('ts38212:bitsFromUint:badValue', 'bitsFromUint: value %s does not fit in %d unsigned bits', num2str(value), width);
end
bits = logical(dec2bin(value, width) - '0')';
end
