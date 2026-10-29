function checkOctets(x, who, what)
%checkOctets Assert that x is a row vector of octets (integers 0..255).
%Spec:   TS 38.322 V16.3.0, clause 4.2.1: "RLC SDUs of variable sizes which are byte aligned
%        (i.e. multiple of 8 bits) are supported for all RLC entity types".
%Inputs: x     candidate octet vector (an empty 1x0 or 0x0 is accepted)
%        who   char -- calling function name, for the error identifier
%        what  char -- argument name, for the message
%Outputs: none; raises rlc:<who>:notOctets

OCTET_MAX = 255;
if isempty(x)
    return;
end
if ~(isrow(x) && all(x >= 0 & x <= OCTET_MAX & mod(x, 1) == 0))
    error(['rlc:' who ':notOctets'], '%s: %s must be a row vector of octets 0..255', who, what);
end
end
