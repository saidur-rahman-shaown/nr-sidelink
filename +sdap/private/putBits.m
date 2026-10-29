function bits = putBits(bits, value, width)
%putBits Append an unsigned integer to a bit string, most significant bit first.
%Spec:   TS 37.324 V19.0.0, clause 6.2.1 / 6.3.1 (byte-aligned bit strings, MSB first).
%Inputs: bits   1 x n row vector of 0/1 -- the string so far (may be empty)
%        value  integer, 0..2^width-1
%        width  integer, 1..18 -- the widest header field is the widest header field
%Outputs: bits  1 x (n+width) row vector of 0/1

if ~(value >= 0 && value < 2^width && mod(value, 1) == 0)
    error('sdap:putBits:range', 'putBits: value %s does not fit in %d bits', num2str(value), width);
end
field = zeros(1, width);
v = value;
for k = width:-1:1
    field(k) = mod(v, 2);
    v = floor(v / 2);
end
bits = [bits, field];
end
