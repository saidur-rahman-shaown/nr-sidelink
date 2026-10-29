function pdu = pdcpPduPack(sn, data, cfg)
%pdcpPduPack Build a sidelink PDCP Data PDU.
%Spec:   TS 38.323 V16.8.0,
%        clause 6.2.2.4, Figure 6.2.2.4-1 (sidelink DRBs for groupcast and broadcast, 12-bit SN):
%          Oct 1 = SDU Type (3) | R (1) | PDCP SN (4 MSB); Oct 2 = PDCP SN (8 LSB); then Data.
%          NOTE: "There is no control PDU for SLRBs for groupcast and broadcast. Thus, there is no
%          D/C field in the PDCP Data PDU format for SLRBs for groupcast and broadcast."
%        clause 6.2.2.6, Figure 6.2.2.6-1 (sidelink DRBs for unicast, 12-bit SN):
%          Oct 1 = D/C (1) | SDU Type (3) | PDCP SN (4 MSB); Oct 2 = SN; Oct 3-4 = KNRP-sess ID;
%          Data; MAC-I (optional).
%        clause 6.2.2.7, Figure 6.2.2.7-1 (unicast, 18-bit SN):
%          Oct 1 = D/C | SDU Type (3) | R | R | PDCP SN (2 MSB); Oct 2-3 = SN; Oct 4-5 = KNRP-sess
%          ID; Data; MAC-I (optional).
%        Field definitions: 6.3.2 (SN), 6.3.4 (MAC-I present "only when the DRB is configured
%        with integrity protection"), 6.3.6 (R = 0), 6.3.7 (D/C: 1 = Data PDU), 6.3.12 (SDU Type,
%        3 bits), 6.3.13 (KNRP-sess ID, 16 bits; "For the SLRB that does not need integrity and
%        ciphering protection, the UE shall set KNRP-sess ID to 0").
%Inputs: sn    integer, 0..2^cfg.snFieldLength-1 -- TX_NEXT modulo 2^[sl-PDCP-SN-Size] (5.2.3)
%        data  1 x n row vector of octets -- the (already protected) PDCP SDU
%        cfg   struct from pdcp.pdcpConfig
%Outputs: pdu  1 x (header + n) octets. Header: 2 bytes (gc/bc), 4 (unicast 12-bit), 5 (18-bit)
%
%Security is never active in this tree (TS 33.536 is not built), so KNRP-sess ID is always 0
%and MAC-I is always absent -- both are what the clauses require for an unprotected SLRB, not
%shortcuts.

SDU_TYPE_BITS = 3;      % clause 6.3.12
DC_BITS = 1;            % clause 6.3.7
KNRP_BITS = 16;         % clause 6.3.13
OCTET_BITS = 8;
DC_DATA = 1;            % Table 6.3.7-1
KNRP_UNPROTECTED = 0;   % clause 6.3.13

checkOctets(data, 'pdcpPduPack', 'data');
N = cfg.snFieldLength;
if ~(sn >= 0 && sn < 2^N && mod(sn, 1) == 0)
    error('pdcp:pdcpPduPack:badSn', 'pdcpPduPack: SN must be an integer in 0..%d', 2^N - 1);
end
if cfg.securityActive
    error('pdcp:pdcpPduPack:security', 'pdcpPduPack: KNRP-sess ID and MAC-I need TS 33.536, which is not built');
end

switch cfg.format
    case 'sl-gc-bc'
        hdrBits = ceil((SDU_TYPE_BITS + N) / OCTET_BITS) * OCTET_BITS;
        bits = putBits([], cfg.sduType, SDU_TYPE_BITS);
        bits = putBits(bits, 0, hdrBits - SDU_TYPE_BITS - N);          % R
        bits = putBits(bits, sn, N);
    case 'sl-unicast'
        hdrBits = ceil((DC_BITS + SDU_TYPE_BITS + N) / OCTET_BITS) * OCTET_BITS;
        bits = putBits([], DC_DATA, DC_BITS);
        bits = putBits(bits, cfg.sduType, SDU_TYPE_BITS);
        bits = putBits(bits, 0, hdrBits - DC_BITS - SDU_TYPE_BITS - N); % R (none at 12-bit SN)
        bits = putBits(bits, sn, N);
        bits = putBits(bits, KNRP_UNPROTECTED, KNRP_BITS);
    otherwise
        error('pdcp:pdcpPduPack:badFormat', 'pdcpPduPack: unknown format "%s"', cfg.format);
end
pdu = [bitsToOctets(bits), data];
end
