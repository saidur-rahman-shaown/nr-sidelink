function [valid, p, si, sn, so, data] = amdPduParse(pdu, snFieldLength)
%amdPduParse Split an AMD PDU into its header fields and Data field.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.4 (formats), 6.2.3.6 (D/C), 6.2.3.8 (R ignored on
%        receipt), 5.6.1 (invalid PDUs are discarded, reported as valid = false).
%Inputs: pdu            1 x n row vector of octets
%        snFieldLength  integer, 12 or 18
%Outputs: valid  logical -- false when D/C = 0 (a control PDU, route it to statusPduParse
%                instead) or the PDU is too short for its header plus one data byte
%         p      logical -- poll bit
%         si     integer, 0..3
%         sn     integer, 0..2^snFieldLength-1
%         so     integer, 0..65535; 0 for SI = 00/01
%         data   1 x m row vector of octets

DC_BITS = 1; P_BITS = 1; SI_BITS = 2;
SO_BITS = 16;
OCTET_BITS = 8;
DC_DATA = 1;
SI_COMPLETE = 0;
SI_FIRST = 1;

assert(any(snFieldLength == [12 18]), 'rlc:amdPduParse:badLength', ...
    'amdPduParse: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
checkOctets(pdu, 'amdPduParse', 'pdu');

valid = false; p = false; si = 0; sn = 0; so = 0; data = zeros(1, 0);
if isempty(pdu)
    return;
end
bits = octetsToBits(pdu(1));
[dc, pos] = getBits(bits, 1, DC_BITS);
if dc ~= DC_DATA
    return;
end
[pBit, pos] = getBits(bits, pos, P_BITS);
[si, ~] = getBits(bits, pos, SI_BITS);
hasSo = ~(si == SI_COMPLETE || si == SI_FIRST);
hdrBytes = rlc.amdHeaderBytes(hasSo, snFieldLength);
if numel(pdu) < hdrBytes + 1
    return;
end
bits = octetsToBits(pdu(1:hdrBytes));
hdrBits = ceil((DC_BITS + P_BITS + SI_BITS + snFieldLength) / OCTET_BITS) * OCTET_BITS;
pos = 1 + hdrBits - snFieldLength;
[sn, pos] = getBits(bits, pos, snFieldLength);
if hasSo
    [so, ~] = getBits(bits, pos, SO_BITS);
end
p = logical(pBit);
data = pdu(hdrBytes + 1:end);
valid = true;
end
