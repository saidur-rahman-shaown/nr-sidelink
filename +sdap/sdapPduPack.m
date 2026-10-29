function pdu = sdapPduPack(headerPresent, qfi, sdu)
%sdapPduPack Build an SDAP Data PDU for a sidelink radio bearer.
%Spec:   TS 37.324 V19.0.0 (local; sidelink content unchanged since V16.3.0), clause 5.2.3
%        ("if the SL-DRB ... is configured ... with the presence of SDAP header: construct the SL
%        SDAP data PDU as specified in the clause 6.2.2.4; else ... clause 6.2.2.1"), Figure
%        6.2.2.4-1 (SL Data PDU with SDAP header for UNICAST: Oct 1 = D/C | R | PQFI), clauses
%        6.3.3 (D/C: 1 = Data PDU), 6.3.5 (R = 0), 6.3.8 (PQFI, 6 bits: "the ID of the PC5 QoS flow
%        (as specified in TS 24.587)"), and 6.2.1: "For groupcast and broadcast of NR sidelink
%        communication, only SDAP data PDU without SDAP header is supported." Header presence is
%        per SLRB, TS 38.331 sl-SDAP-Header-r16.
%Inputs: headerPresent  logical -- sl-SDAP-Header == present for the SLRB
%        qfi            integer, 0..63 -- the PQFI of the packet (6-bit field, clause 6.3.8). Ignored
%                       when headerPresent is false
%        sdu            1 x n octets -- the SDAP SDU (the application packet)
%Outputs: pdu  1 x (n or n+1) octets
%
%RANGE CAVEAT (pending-human): TS 38.331 defines SL-PQFI-r16 as INTEGER (1..64), but clause 6.3.8's
%field is 6 bits (0..63) and 37.324 says nothing about an offset. This function encodes the value
%and rejects 64.
%
%The caller must not ask for a header on a groupcast/broadcast SLRB (clause 6.2.1); the stored
%config is validated for that (cfgValidate check 16c) and stack.ueInit asserts it.

DC_BITS = 1; R_BITS = 1; QFI_BITS = 6;
DC_DATA = 1;
checkOctets(sdu, 'sdapPduPack', 'sdu');
if ~headerPresent
    pdu = sdu;
    return;
end
if ~(qfi >= 0 && qfi < 2^QFI_BITS && mod(qfi, 1) == 0)
    error('sdap:sdapPduPack:badQfi', 'sdapPduPack: QFI must fit the 6-bit field (0..63), got %s', num2str(qfi));
end
bits = putBits([], DC_DATA, DC_BITS);
bits = putBits(bits, 0, R_BITS);
bits = putBits(bits, qfi, QFI_BITS);
pdu = [bitsToOctets(bits), sdu];
end
