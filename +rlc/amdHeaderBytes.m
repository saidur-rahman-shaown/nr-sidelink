function n = amdHeaderBytes(hasSo, snFieldLength)
%amdHeaderBytes Size of an AMD PDU header.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.4, Figures 6.2.2.4-1..-4: "An AM RLC entity is
%        configured by RRC to use either a 12 bit SN or a 18 bit SN. The length of the AMD PDU
%        header is two and three bytes respectively. ... An AMD PDU header contains the SO field
%        only when the Data field consists of an RLC SDU segment which is not the first segment,
%        in which case a 16 bit SO is present."
%Inputs: hasSo          logical -- the Data field does not start at byte 0 of the SDU
%        snFieldLength  integer, 12 or 18
%Outputs: n  integer, bytes: 2/3 without SO, 4/5 with SO

DC_BITS = 1; P_BITS = 1; SI_BITS = 2;   % clauses 6.2.3.6, 6.2.3.7, 6.2.3.4
SO_BITS = 16;                           % clause 6.2.3.5
OCTET_BITS = 8;

assert(any(snFieldLength == [12 18]), 'rlc:amdHeaderBytes:badLength', ...
    'amdHeaderBytes: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
n = ceil((DC_BITS + P_BITS + SI_BITS + snFieldLength) / OCTET_BITS);
if hasSo
    n = n + SO_BITS / OCTET_BITS;
end
end
