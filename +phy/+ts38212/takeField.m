function [field, newIdx] = takeField(bits, idx, width)
%takeField Slice the next fixed-width field off a packed bit column, MSB first.
%Not itself a spec clause -- shared by every Wave B unpack function to walk a0..a(A-1) in
%field-declaration order, since fields are packed back-to-back with no delimiters (the width
%of every field must be known from configuration before the next one can be sliced).
%Inputs: bits   column vector (logical or 0/1), the full packed sequence being unpacked
%        idx    positive integer -- 1-based index of the next unconsumed bit
%        width  nonnegative integer -- width of the field to take (0 is legal)
%Outputs: field   width-by-1 logical column
%         newIdx  idx advanced past the field just taken
if idx + width - 1 > numel(bits)
    error('ts38212:takeField:tooShort', 'takeField: input has %d bits, not enough for a %d-bit field starting at position %d', numel(bits), width, idx);
end
field = logical(bits(idx : idx + width - 1));
newIdx = idx + width;
end
