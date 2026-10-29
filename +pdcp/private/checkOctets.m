function checkOctets(x, who, what)
%checkOctets Assert that x is a row vector of octets (integers 0..255).
%Spec:   TS 38.323 V16.8.0, clause 6.3.1: "the left most bit string is the first and most
%        significant and the right most bit is the last and least significant bit. Unless
%        otherwise mentioned, integers are encoded in standard binary encoding for unsigned
%        integers. In all cases the bits appear ordered from MSB to LSB when read in the PDU."
%Inputs: x     candidate octet vector (an empty 1x0 or 0x0 is accepted)
%        who   char -- calling function name, for the error identifier
%        what  char -- argument name, for the message
%Outputs: none; raises pdcp:<who>:notOctets

OCTET_MAX = 255;
if isempty(x)
    return;
end
if ~(isrow(x) && all(x >= 0 & x <= OCTET_MAX & mod(x, 1) == 0))
    error(['pdcp:' who ':notOctets'], '%s: %s must be a row vector of octets 0..255', who, what);
end
end
