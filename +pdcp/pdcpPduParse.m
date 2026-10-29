function [valid, sn, data] = pdcpPduParse(pdu, cfg)
%pdcpPduParse Split a sidelink PDCP Data PDU into its SN and Data field.
%Spec:   TS 38.323 V16.8.0, clauses 6.2.2.4 / 6.2.2.6 / 6.2.2.7 (formats; see pdcpPduPack),
%        6.3.6 ("Reserved bits shall be ignored by the receiver"), 6.3.12 Table 6.3.12-1
%        (SDU Type 010-111 reserved), 5.10 ("When a PDCP PDU that contains reserved or invalid
%        values is received, the receiving PDCP entity shall: discard the received PDU." NOTE:
%        "For NR sidelink communication for unicast, the invalid values include the invalid
%        value of KNRP-sess ID.").
%Inputs: pdu  1 x n octets
%        cfg  struct from pdcp.pdcpConfig -- the format and SN length are the RECEIVING entity's
%             configuration; nothing in the header says which applies
%Outputs: valid  logical -- false for a too-short PDU, a reserved SDU Type, a unicast D/C = 0
%                (a Control PDU: status reports are not used on sidelink in this tree), or a
%                non-zero KNRP-sess ID on an unprotected SLRB
%         sn     integer -- the PDCP SN
%         data   1 x m octets -- the Data field (m may be 0: clause 6.3.3 does not forbid an
%                empty SDU)
%
%An SDU Type that is legal but differs from the entity's own (IP arriving on a Non-IP bearer)
%is accepted: Table 6.3.12-1 reserves only 010-111, and clause 6.3.12 says the entity "may
%handle the SDU differently per SDU Type", not that it must reject a mismatch.

SDU_TYPE_BITS = 3;
DC_BITS = 1;
KNRP_BITS = 16;
OCTET_BITS = 8;
DC_DATA = 1;
SDU_TYPE_MAX_DEFINED = 1;     % 000 IP, 001 Non-IP; 010-111 reserved

checkOctets(pdu, 'pdcpPduParse', 'pdu');
valid = false; sn = 0; data = zeros(1, 0);
N = cfg.snFieldLength;
switch cfg.format
    case 'sl-gc-bc'
        hdrBytes = ceil((SDU_TYPE_BITS + N) / OCTET_BITS);
        if numel(pdu) < hdrBytes, return; end
        bits = octetsToBits(pdu(1:hdrBytes));
        [sduType, pos] = getBits(bits, 1, SDU_TYPE_BITS);
        pos = pos + hdrBytes * OCTET_BITS - SDU_TYPE_BITS - N;        % skip R
        [sn, ~] = getBits(bits, pos, N);
    case 'sl-unicast'
        hdrBytes = ceil((DC_BITS + SDU_TYPE_BITS + N) / OCTET_BITS) + KNRP_BITS / OCTET_BITS;
        if numel(pdu) < hdrBytes, return; end
        bits = octetsToBits(pdu(1:hdrBytes));
        [dc, pos] = getBits(bits, 1, DC_BITS);
        if dc ~= DC_DATA, return; end
        [sduType, pos] = getBits(bits, pos, SDU_TYPE_BITS);
        pos = pos + (hdrBytes - KNRP_BITS / OCTET_BITS) * OCTET_BITS - DC_BITS - SDU_TYPE_BITS - N;
        [sn, pos] = getBits(bits, pos, N);
        [knrp, ~] = getBits(bits, pos, KNRP_BITS);
        if knrp ~= 0 && ~cfg.securityActive, return; end
    otherwise
        error('pdcp:pdcpPduParse:badFormat', 'pdcpPduParse: unknown format "%s"', cfg.format);
end
if sduType > SDU_TYPE_MAX_DEFINED
    sn = 0;
    return;
end
data = pdu(hdrBytes + 1:end);
valid = true;
end
