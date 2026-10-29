function n = umdHeaderBytes(si, snFieldLength)
%umdHeaderBytes Size of a UMD PDU header for a given SI and SN length.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.3, Figures 6.2.2.3-1..-5: "The UMD PDU header is byte
%        aligned. When an UMD PDU contains a complete RLC SDU, the UMD PDU header only contains
%        the SI and R fields. ... An UMD PDU header contains the SN field only when the
%        corresponding RLC SDU is segmented. An UMD PDU carrying the first segment of an RLC SDU
%        does not carry the SO field in its header. The length of the SO field is 16 bits."
%Inputs: si             integer, 0..3 -- Table 6.2.3.4-1
%        snFieldLength  integer, 6 or 12
%Outputs: n  integer, bytes: 1 (complete), 1/2 (first segment, 6/12-bit SN),
%            3/4 (middle or last segment, 6/12-bit SN)

SI_BITS = 2;        % clause 6.2.3.4
SO_BITS = 16;       % clause 6.2.3.5
OCTET_BITS = 8;
SI_COMPLETE = 0;
SI_FIRST = 1;

assert(any(snFieldLength == [6 12]), 'rlc:umdHeaderBytes:badLength', ...
    'umdHeaderBytes: UM SN length must be 6 or 12, got %s', num2str(snFieldLength));
assert(any(si == 0:3), 'rlc:umdHeaderBytes:badSi', 'umdHeaderBytes: SI must be 0..3');

if si == SI_COMPLETE
    n = 1;                                   % SI + six R bits, Figure 6.2.2.3-1
    return;
end
n = ceil((SI_BITS + snFieldLength) / OCTET_BITS);   % SI, R padding, SN
if si ~= SI_FIRST
    n = n + SO_BITS / OCTET_BITS;
end
end
