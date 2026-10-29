function [valid, qfi, sdu] = sdapPduParse(pdu, headerPresent)
%sdapPduParse Strip the SDAP header from a received sidelink SDAP Data PDU.
%Spec:   TS 37.324 V19.0.0 (local), clause 5.2.4 SL reception: "if the SL-DRB from which this
%        SDAP data PDU is received is configured ... with the presence of SDAP header: retrieve the
%        SDAP SDU ... as specified in the clause 6.2.2.4; else ... clause 6.2.2.1; deliver the
%        retrieved SDAP SDU to the upper layer." Formats: see sdapPduPack.
%Inputs: pdu            1 x n octets -- a PDCP SDU
%        headerPresent  logical -- whether this SLRB carries an SDAP header
%Outputs: valid  logical -- false for an empty PDU with a header expected, or D/C = 0: an
%                End-Marker Control PDU (clause 6.2.3), which a unicast transmitter sends only
%                when a flow is REMAPPED to another SL-DRB (clause 5.5.1). Preconfiguration never
%                remaps, so none is sent here; one received is not data and is not delivered
%         qfi    integer, 0..63, or -1 when there is no header
%         sdu    1 x m octets
%
%Like the PDCP SN length, header presence is a property of the receiving bearer, never of the
%PDU: a byte that happens to start with 1 is indistinguishable from a header. A groupcast/broadcast
%receiver knows from the spec itself -- clause 6.2.1 allows no header there -- and a unicast one
%from the PC5-RRC-agreed SLRB.

DC_BITS = 1; R_BITS = 1; QFI_BITS = 6;
DC_DATA = 1;
checkOctets(pdu, 'sdapPduParse', 'pdu');
valid = false; qfi = -1; sdu = zeros(1, 0);
if ~headerPresent
    valid = true;
    sdu = pdu;
    return;
end
if isempty(pdu)
    return;
end
bits = octetsToBits(pdu(1));
[dc, pos] = getBits(bits, 1, DC_BITS);
if dc ~= DC_DATA
    return;
end
pos = pos + R_BITS;                       % R: ignored on receipt
[qfi, ~] = getBits(bits, pos, QFI_BITS);
sdu = pdu(2:end);
valid = true;
end
