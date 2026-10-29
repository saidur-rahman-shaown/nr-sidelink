function bits = octetsToBits(octets)
%octetsToBits Unpack octets into a bit string, MSB of each octet first.
%Spec:   TS 37.324 V19.0.0, clause 6.2.1 / 6.3.1 (byte-aligned bit strings, MSB first).
%Inputs: octets  1 x k row vector, each 0..255
%Outputs: bits   1 x 8k row vector of 0/1

OCTET_BITS = 8;
bits = zeros(1, OCTET_BITS * numel(octets));
for k = 1:numel(octets)
    v = octets(k);
    for b = OCTET_BITS:-1:1
        bits((k - 1) * OCTET_BITS + b) = mod(v, 2);
        v = floor(v / 2);
    end
end
end
