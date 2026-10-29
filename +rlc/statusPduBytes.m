function n = statusPduBytes(hasSo, hasRange, snFieldLength)
%statusPduBytes Size of a STATUS PDU with a given set of NACK entries.
%Spec:   TS 38.322 V16.3.0, clause 6.2.2.5, Figures 6.2.2.5-1 (12-bit SN) and 6.2.2.5-2 (18-bit
%        SN); field lengths from clauses 6.2.3.6 (D/C, 1), 6.2.3.9 (CPT, 3), 6.2.3.10 (ACK_SN),
%        6.2.3.11/13/16 (E1, E2, E3, 1 each), 6.2.3.12 (NACK_SN), 6.2.3.14/15 (SOstart, SOend,
%        16 each), 6.2.3.17 (NACK range, 8).
%Inputs: hasSo          1 x nNack logical -- E2 of each NACK entry (SOstart/SOend follow)
%        hasRange       1 x nNack logical -- E3 of each NACK entry (NACK range follows)
%        snFieldLength  integer, 12 or 18
%Outputs: n  integer, bytes
%
%The figures pad both the ACK_SN/E1 group and each NACK_SN/E1/E2/E3 group with R bits to an
%octet boundary, so the sizes are: header 3 bytes at either SN length; each NACK entry 2 bytes
%(12-bit) or 3 bytes (18-bit); +4 with SOstart/SOend; +1 with NACK range.

DC_BITS = 1; CPT_BITS = 3; E_BITS = 1;
SO_BITS = 16; NACK_RANGE_BITS = 8;
OCTET_BITS = 8;
N_E_PER_NACK = 3;       % E1, E2, E3

assert(any(snFieldLength == [12 18]), 'rlc:statusPduBytes:badLength', ...
    'statusPduBytes: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
assert(numel(hasSo) == numel(hasRange), 'rlc:statusPduBytes:badShape', ...
    'statusPduBytes: hasSo and hasRange must be the same length');

headerBytes = ceil((DC_BITS + CPT_BITS + snFieldLength + E_BITS) / OCTET_BITS);
entryBytes  = ceil((snFieldLength + N_E_PER_NACK * E_BITS) / OCTET_BITS);
n = headerBytes;
for k = 1:numel(hasSo)
    n = n + entryBytes;
    if hasSo(k)
        n = n + 2 * SO_BITS / OCTET_BITS;
    end
    if hasRange(k)
        n = n + NACK_RANGE_BITS / OCTET_BITS;
    end
end
end
