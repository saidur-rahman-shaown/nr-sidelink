function pdu = amdPduPack(p, si, sn, so, data, snFieldLength)
%amdPduPack Build an AMD PDU: header then Data field.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.4, Figures 6.2.2.4-1 (12-bit SN: D/C|P|SI|SN over two
%        octets), 6.2.2.4-2 (18-bit SN: D/C|P|SI|R|R|SN over three octets), 6.2.2.4-3/-4 (the
%        same followed by a 16-bit SO); clause 6.2.3.6 Table 6.2.3.6-1 (D/C = 1 for a data PDU);
%        clause 6.2.3.7 (P); clause 6.2.3.8 (R = 0).
%Inputs: p              logical or 0/1 -- the poll bit, Table 6.2.3.7-1
%        si             integer, 0..3 -- Table 6.2.3.4-1
%        sn             integer, 0..2^snFieldLength-1. Always present in AM, unlike UM
%        so             integer, 0..65535. Present in the header exactly when so > 0, i.e. when
%                       the Data field is a segment that is not the first ("An AMD PDU header
%                       contains the SO field only when the Data field consists of an RLC SDU
%                       segment which is not the first segment"). SI = 00/01 imply so = 0
%        data           1 x n row vector of octets, n >= 1
%        snFieldLength  integer, 12 or 18
%Outputs: pdu  1 x (header + n) row vector of octets

DC_BITS = 1; P_BITS = 1; SI_BITS = 2;
SO_BITS = 16;
OCTET_BITS = 8;
DC_DATA = 1;            % Table 6.2.3.6-1
SI_COMPLETE = 0;
SI_FIRST = 1;

assert(any(snFieldLength == [12 18]), 'rlc:amdPduPack:badLength', ...
    'amdPduPack: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
assert(any(si == 0:3), 'rlc:amdPduPack:badSi', 'amdPduPack: SI must be 0..3');
checkOctets(data, 'amdPduPack', 'data');
if isempty(data)
    error('rlc:amdPduPack:emptyData', 'amdPduPack: the Data field must hold at least one byte');
end
startsAtZero = (si == SI_COMPLETE || si == SI_FIRST);
if startsAtZero ~= (so == 0)
    error('rlc:amdPduPack:badSo', 'amdPduPack: SI=%d is inconsistent with SO=%d', si, so);
end

hdrBits = ceil((DC_BITS + P_BITS + SI_BITS + snFieldLength) / OCTET_BITS) * OCTET_BITS;
bits = putBits([], DC_DATA, DC_BITS);
bits = putBits(bits, double(logical(p)), P_BITS);
bits = putBits(bits, si, SI_BITS);
bits = putBits(bits, 0, hdrBits - DC_BITS - P_BITS - SI_BITS - snFieldLength);   % R fields
bits = putBits(bits, sn, snFieldLength);
if ~startsAtZero
    bits = putBits(bits, so, SO_BITS);
end
pdu = [bitsToOctets(bits), data];
end
