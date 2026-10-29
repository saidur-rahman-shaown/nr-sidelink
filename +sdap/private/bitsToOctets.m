function octets = bitsToOctets(bits)
%bitsToOctets Pack a byte-aligned bit string into octets, first bit = MSB of the first octet.
%Spec:   TS 37.324 V19.0.0, clause 6.2.1 / 6.3.1 (byte-aligned bit strings, MSB first).
%Inputs: bits    1 x 8k row vector of 0/1 -- every header is byte aligned (6.2.2.3/6.2.2.4)
%Outputs: octets 1 x k row vector, each 0..255

OCTET_BITS = 8;
if mod(numel(bits), OCTET_BITS) ~= 0
    error('sdap:bitsToOctets:notAligned', 'bitsToOctets: %d bits is not byte aligned', numel(bits));
end
n = numel(bits) / OCTET_BITS;
octets = zeros(1, n);
for k = 1:n
    v = 0;
    for b = 1:OCTET_BITS
        v = v * 2 + bits((k - 1) * OCTET_BITS + b);
    end
    octets(k) = v;
end
end
