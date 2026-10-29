function [valid, si, sn, so, data] = umdPduParse(pdu, snFieldLength)
%umdPduParse Split a UMD PDU into its header fields and Data field.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.3 (formats), clause 6.2.3.8 ("The receiving entity
%        shall ignore this field" -- R bits are not checked), clause 5.6.1 (a PDU with invalid
%        values is discarded, reported here as valid = false).
%Inputs: pdu            1 x n row vector of octets
%        snFieldLength  integer, 6 or 12 -- the receiving entity's configured SN length
%Outputs: valid  logical -- false for a PDU too short to hold its header plus one data byte
%         si     integer, 0..3
%         sn     integer -- the SN, or -1 when the header carries none (SI = 00)
%         so     integer, 0..65535 -- 0 for SI = 00 and SI = 01, whose headers carry no SO
%         data   1 x m row vector of octets, m >= 1 when valid
%
%The SN length is a property of the receiving ENTITY, not of the PDU: nothing in the header
%says whether it is 6 or 12 bits. A receiver configured for the wrong length parses every
%segmented PDU into garbage SNs and reassembles nothing -- while complete-SDU PDUs, which carry
%no SN, keep getting through, so the link looks merely lossy rather than broken.

SI_BITS = 2;
SO_BITS = 16;
OCTET_BITS = 8;
SI_COMPLETE = 0;
SI_FIRST = 1;

assert(any(snFieldLength == [6 12]), 'rlc:umdPduParse:badLength', ...
    'umdPduParse: UM SN length must be 6 or 12, got %s', num2str(snFieldLength));
checkOctets(pdu, 'umdPduParse', 'pdu');

valid = false; si = 0; sn = -1; so = 0; data = zeros(1, 0);
if isempty(pdu)
    return;
end
bits = octetsToBits(pdu(1));
[si, ~] = getBits(bits, 1, SI_BITS);
hdrBytes = rlc.umdHeaderBytes(si, snFieldLength);
if numel(pdu) < hdrBytes + 1
    return;
end
bits = octetsToBits(pdu(1:hdrBytes));
pos = 1 + SI_BITS;
if si ~= SI_COMPLETE
    hdrBits = ceil((SI_BITS + snFieldLength) / OCTET_BITS) * OCTET_BITS;
    pos = pos + (hdrBits - SI_BITS - snFieldLength);               % skip R
    [sn, pos] = getBits(bits, pos, snFieldLength);
    if si ~= SI_FIRST
        [so, ~] = getBits(bits, pos, SO_BITS);
    end
end
data = pdu(hdrBytes + 1:end);
valid = true;
end
