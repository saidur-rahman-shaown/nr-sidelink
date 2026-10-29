function pdu = statusPduPack(ackSn, nackSn, soStart, soEnd, nackRange, snFieldLength)
%statusPduPack Build a STATUS PDU.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.5, Figures 6.2.2.5-1 / 6.2.2.5-2: "STATUS PDU payload
%        ... consists of one ACK_SN and one E1, zero or more sets of a NACK_SN, an E1, an E2 and
%        an E3, and possibly a pair of a SOstart and a SOend or a NACK range field for each
%        NACK_SN." Field semantics from clauses 6.2.3.9 (CPT = 000 for STATUS PDU), 6.2.3.11
%        (E1 = 1: a NACK set follows), 6.2.3.13 (E2 = 1: SOstart/SOend follow for this
%        NACK_SN), 6.2.3.16 (E3 = 1: NACK range follows for this NACK_SN), 6.2.3.15 (SOend
%        "1111111111111111" means to the last byte of the SDU), 6.2.3.17 (NACK range, 8 bits).
%        Within one NACK set the order of the optional fields is SOstart, SOend, NACK range, as
%        drawn in both figures.
%Inputs: ackSn          integer, 0..2^snFieldLength-1
%        nackSn         1 x nNack integer row vector (may be empty)
%        soStart        1 x nNack integer, 0..65535, or -1 where E2 = 0. soStart and soEnd
%                       are a pair: both present or both -1
%        soEnd          1 x nNack integer, 0..65535 (65535 = "to the last byte"), or -1
%        nackRange      1 x nNack integer, 1..255, or 0 where E3 = 0
%        snFieldLength  integer, 12 or 18
%Outputs: pdu  1 x statusPduBytes(...) row vector of octets
%
%E1 on the ACK_SN group says whether the FIRST NACK set follows; E1 inside each NACK set says
%whether ANOTHER follows. So the last set carries E1 = 0 and an empty list has E1 = 0 on the
%header. Writing E1 = 1 on the last set makes the receiver read R bits and padding as a NACK.

DC_BITS = 1; CPT_BITS = 3; E_BITS = 1;
SO_BITS = 16; NACK_RANGE_BITS = 8;
OCTET_BITS = 8;
N_E_PER_NACK = 3;
DC_CONTROL = 0;         % Table 6.2.3.6-1
CPT_STATUS = 0;         % Table 6.2.3.9-1

assert(any(snFieldLength == [12 18]), 'rlc:statusPduPack:badLength', ...
    'statusPduPack: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
nNack = numel(nackSn);
if numel(soStart) ~= nNack || numel(soEnd) ~= nNack || numel(nackRange) ~= nNack
    error('rlc:statusPduPack:badShape', 'statusPduPack: nackSn, soStart, soEnd and nackRange must be the same length');
end
for k = 1:nNack
    if (soStart(k) < 0) ~= (soEnd(k) < 0)
        error('rlc:statusPduPack:soPair', 'statusPduPack: SOstart and SOend are a pair (E2), entry %d has only one', k);
    end
    if nackRange(k) < 0 || nackRange(k) >= 2^NACK_RANGE_BITS
        error('rlc:statusPduPack:badRange', 'statusPduPack: NACK range must be 1..255 or 0 for absent, entry %d', k);
    end
end

headerBits = ceil((DC_BITS + CPT_BITS + snFieldLength + E_BITS) / OCTET_BITS) * OCTET_BITS;
entryBits  = ceil((snFieldLength + N_E_PER_NACK * E_BITS) / OCTET_BITS) * OCTET_BITS;

bits = putBits([], DC_CONTROL, DC_BITS);
bits = putBits(bits, CPT_STATUS, CPT_BITS);
bits = putBits(bits, ackSn, snFieldLength);
bits = putBits(bits, double(nNack > 0), E_BITS);                          % E1
bits = putBits(bits, 0, headerBits - DC_BITS - CPT_BITS - snFieldLength - E_BITS);   % R
for k = 1:nNack
    hasSo = soStart(k) >= 0;
    hasRange = nackRange(k) > 0;
    bits = putBits(bits, nackSn(k), snFieldLength);
    bits = putBits(bits, double(k < nNack), E_BITS);                       % E1
    bits = putBits(bits, double(hasSo), E_BITS);                           % E2
    bits = putBits(bits, double(hasRange), E_BITS);                        % E3
    bits = putBits(bits, 0, entryBits - snFieldLength - N_E_PER_NACK * E_BITS);   % R
    if hasSo
        bits = putBits(bits, soStart(k), SO_BITS);
        bits = putBits(bits, soEnd(k), SO_BITS);
    end
    if hasRange
        bits = putBits(bits, nackRange(k), NACK_RANGE_BITS);
    end
end
pdu = bitsToOctets(bits);
end
