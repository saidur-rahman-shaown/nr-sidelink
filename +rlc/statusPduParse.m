function [valid, ackSn, nackSn, soStart, soEnd, nackRange] = statusPduParse(pdu, snFieldLength)
%statusPduParse Decode a STATUS PDU into ACK_SN and its list of NACK sets.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.5 (format), 6.2.3.9 Table 6.2.3.9-1 ("001-111
%        Reserved (PDUs with this coding will be discarded by the receiving entity for this
%        release of the protocol)"), 6.2.3.11..6.2.3.17 (fields), 5.6.1 (discard on reserved or
%        invalid values).
%Inputs: pdu            1 x n row vector of octets
%        snFieldLength  integer, 12 or 18
%Outputs: valid      logical -- false for D/C = 1, a reserved CPT, a truncated PDU, or a
%                    NACK range of 0 (E3 = 1 announcing zero lost SDUs is not a value
%                    clause 6.2.3.17 can mean)
%         ackSn      integer
%         nackSn     1 x nNack integer row vector
%         soStart    1 x nNack integer, -1 where E2 = 0
%         soEnd      1 x nNack integer (65535 kept raw = "to the last byte"), -1 where E2 = 0
%         nackRange  1 x nNack integer, 0 where E3 = 0
%
%Octets after the set whose E1 = 0 are ignored: the PDU's own extension bits end it, and a
%lower layer that hands up trailing bytes has not changed the report.

DC_BITS = 1; CPT_BITS = 3; E_BITS = 1;
SO_BITS = 16; NACK_RANGE_BITS = 8;
OCTET_BITS = 8;
N_E_PER_NACK = 3;
DC_CONTROL = 0;
CPT_STATUS = 0;

assert(any(snFieldLength == [12 18]), 'rlc:statusPduParse:badLength', ...
    'statusPduParse: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
checkOctets(pdu, 'statusPduParse', 'pdu');

valid = false; ackSn = 0;
nackSn = zeros(1, 0); soStart = zeros(1, 0); soEnd = zeros(1, 0); nackRange = zeros(1, 0);

bits = octetsToBits(pdu);
headerBits = ceil((DC_BITS + CPT_BITS + snFieldLength + E_BITS) / OCTET_BITS) * OCTET_BITS;
entryBits  = ceil((snFieldLength + N_E_PER_NACK * E_BITS) / OCTET_BITS) * OCTET_BITS;

[dc, pos, ok] = getBits(bits, 1, DC_BITS);
if ~ok || dc ~= DC_CONTROL, return; end
[cpt, pos, ok] = getBits(bits, pos, CPT_BITS);
if ~ok || cpt ~= CPT_STATUS, return; end
[ack, pos, ok] = getBits(bits, pos, snFieldLength);
if ~ok, return; end
[e1, pos, ok] = getBits(bits, pos, E_BITS);
if ~ok, return; end
pos = pos + headerBits - DC_BITS - CPT_BITS - snFieldLength - E_BITS;

while e1 == 1
    [sn, pos, ok] = getBits(bits, pos, snFieldLength);   if ~ok, return; end
    [e1, pos, ok] = getBits(bits, pos, E_BITS);          if ~ok, return; end
    [e2, pos, ok] = getBits(bits, pos, E_BITS);          if ~ok, return; end
    [e3, pos, ok] = getBits(bits, pos, E_BITS);          if ~ok, return; end
    pos = pos + entryBits - snFieldLength - N_E_PER_NACK * E_BITS;
    s0 = -1; s1 = -1; r = 0;
    if e2 == 1
        [s0, pos, ok] = getBits(bits, pos, SO_BITS);     if ~ok, return; end
        [s1, pos, ok] = getBits(bits, pos, SO_BITS);     if ~ok, return; end
    end
    if e3 == 1
        [r, pos, ok] = getBits(bits, pos, NACK_RANGE_BITS);   if ~ok, return; end
        if r == 0, return; end
    end
    nackSn(end + 1) = sn;       %#ok<AGROW>
    soStart(end + 1) = s0;      %#ok<AGROW>
    soEnd(end + 1) = s1;        %#ok<AGROW>
    nackRange(end + 1) = r;     %#ok<AGROW>
end
ackSn = ack;
valid = true;
end
