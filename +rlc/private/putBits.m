function bits = putBits(bits, value, width)
%putBits Append an unsigned integer to a bit string, most significant bit first.
%Spec:   TS 38.322 V16.3.0, clause 6.2.3.1: "the first and most significant bit is the left
%        most bit and the last and least significant bit is the rightmost bit. Unless mentioned
%        otherwise, integers are encoded in standard binary encoding for unsigned integers."
%Inputs: bits   1 x n row vector of 0/1 -- the string so far (may be empty)
%        value  integer, 0..2^width-1
%        width  integer, 1..18 -- the widest RLC field is the 18-bit SN
%Outputs: bits  1 x (n+width) row vector of 0/1

if ~(value >= 0 && value < 2^width && mod(value, 1) == 0)
    error('rlc:putBits:range', 'putBits: value %s does not fit in %d bits', num2str(value), width);
end
field = zeros(1, width);
v = value;
for k = width:-1:1
    field(k) = mod(v, 2);
    v = floor(v / 2);
end
bits = [bits, field];
end
