function pdu = umdPduPack(si, sn, so, data, snFieldLength)
%umdPduPack Build a UMD PDU: header then Data field.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.3, Figures 6.2.2.3-1 (complete SDU: SI|R R R R R R),
%        6.2.2.3-2 (6-bit SN, no SO: SI|SN), 6.2.2.3-3 (12-bit SN, no SO: SI|R|R|SN over two
%        octets), 6.2.2.3-4 (6-bit SN with SO), 6.2.2.3-5 (12-bit SN with SO); clause 6.2.3.8
%        "The transmitting entity shall set the R field to 0"; clause 6.2.2.1 bit order.
%Inputs: si             integer, 0..3 -- Table 6.2.3.4-1
%        sn             integer, 0..2^snFieldLength-1 -- ignored (not encoded) when si = 00
%        so             integer, 0..65535 -- encoded only for SI = 10 or 11 (middle / last
%                       segment). Must be 0 for SI = 01, since the first segment starts at
%                       byte 0 by definition
%        data           1 x n row vector of octets, n >= 1 -- the Data field
%        snFieldLength  integer, 6 or 12
%Outputs: pdu  1 x (header + n) row vector of octets
%
%A complete-SDU UMD PDU carries NO SN. Clause 6.2.3.3: "For RLC UM, the sequence number is
%incremented by one for every segmented RLC SDU" -- unsegmented SDUs never consume one.

SI_BITS = 2;
SO_BITS = 16;
OCTET_BITS = 8;
SI_COMPLETE = 0;
SI_FIRST = 1;

assert(any(snFieldLength == [6 12]), 'rlc:umdPduPack:badLength', ...
    'umdPduPack: UM SN length must be 6 or 12, got %s', num2str(snFieldLength));
assert(any(si == 0:3), 'rlc:umdPduPack:badSi', 'umdPduPack: SI must be 0..3');
checkOctets(data, 'umdPduPack', 'data');
if isempty(data)
    error('rlc:umdPduPack:emptyData', 'umdPduPack: the Data field must hold at least one byte (clause 6.2.3.2 granularity)');
end
if si == SI_FIRST && so ~= 0
    error('rlc:umdPduPack:badSo', 'umdPduPack: a first segment starts at byte 0, got SO=%d', so);
end

bits = putBits([], si, SI_BITS);
if si == SI_COMPLETE
    bits = putBits(bits, 0, OCTET_BITS - SI_BITS);                  % R fields
else
    hdrBits = ceil((SI_BITS + snFieldLength) / OCTET_BITS) * OCTET_BITS;
    bits = putBits(bits, 0, hdrBits - SI_BITS - snFieldLength);     % R fields (none at 6 bits)
    bits = putBits(bits, sn, snFieldLength);
    if si ~= SI_FIRST
        bits = putBits(bits, so, SO_BITS);
    end
end
pdu = [bitsToOctets(bits), data];
end
