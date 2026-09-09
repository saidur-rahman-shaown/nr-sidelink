function [pduBits, nPaddingBytes, nSduIncluded] = muxSlSch(srcL2Id, dstL2Id, sduBytes, sduLen, sduLcid, csiPresent, csiRI, csiCQI, pduSizeBytes)
%muxSlSch Assemble an SL-SCH MAC PDU.
%Spec:   TS 38.321 V16.22.0, clause 6.1.6 (MAC PDU (SL-SCH)), clause 6.2.4 (MAC subheader for
%        SL-SCH and Table 6.2.4-1 LCID values), clause 6.1.3.35 (Sidelink CSI Reporting MAC CE),
%        and the subheader figures 6.1.2-1/-2/-3 that clause 6.1.6 refers to. Ordering rules from
%        clause 6.1.6: "SL MAC subPDU(s) with MAC SDU(s) is placed after the SL-SCH subheader and
%        before the MAC subPDU with a MAC CE and the MAC subPDU with padding [...] SL MAC subPDU
%        with a MAC CE is placed after all the MAC subPDU(s) with MAC SDU and before the MAC
%        subPDU with padding [...] The size of padding can be zero."
%Inputs: srcL2Id       integer, 0..2^24-1 -- the 24-bit Source Layer-2 ID from upper layers
%        dstL2Id       integer, 0..2^24-1 -- the 24-bit Destination Layer-2 ID
%        sduBytes      1 x sum(sduLen) row vector of octets (0..255) -- every MAC SDU
%                      concatenated in transmission order. Flat rather than a cell array of
%                      per-SDU vectors, per the normative-packages rule; sduLen carves it up.
%        sduLen        1 x nSdu integer row vector, each >=1 -- byte length of each MAC SDU, in
%                      the order LCP produced them (slLcp emits them in decreasing priority)
%        sduLcid       1 x nSdu integer row vector -- LCID of each SDU, from Table 6.2.4-1:
%                      0..3 are the four SCCH flavours, 4..19 "Identity of the logical channel"
%                      (i.e. STCH), 20..61 reserved, 62 Sidelink CSI Reporting, 63 Padding.
%                      62 and 63 are rejected here: this argument carries SDUs only, and the CE
%                      and padding subPDUs are built by this function, not supplied.
%        csiPresent    logical scalar -- whether a Sidelink CSI Reporting MAC CE is included
%        csiRI         integer, 0 or 1 -- clause 6.1.3.35 RI field, 1 bit. Ignored unless
%                      csiPresent.
%        csiCQI        integer, 0..15 -- clause 6.1.3.35 CQI field, 4 bits. Ignored unless
%                      csiPresent.
%        pduSizeBytes  positive integer -- the transport block size in BYTES, i.e.
%                      +phy/+ts38214/tbsDetermine's tbs divided by 8. The assembled PDU is padded
%                      to exactly this size; if the content does not fit, that is an error rather
%                      than a truncation (LCP sizes the content against the grant, so an overflow
%                      here means LCP and the TBS disagree).
%Outputs: pduBits        (8*pduSizeBytes) x 1 column vector of 0/1, MSB-first within each octet
%                        -- ready to hand straight to +phy/+ts38212/slSchEncode as its tbBits
%         nPaddingBytes  nonnegative integer -- padding octets after the padding subheader; 0
%                        both when the PDU fits exactly and when no padding subPDU was needed
%         nSduIncluded   nonnegative integer -- SDUs actually placed (always numel(sduLen); the
%                        function does not drop SDUs, it errors if they do not fit)
%
%The SL-SCH subheader carries the OTHER HALF of each identity from the one the SCI carries, and
%this is worth stating because neither field alone is the full ID. Clause 6.2.4: SRC is "the 16
%MOST significant bits of the Source Layer-2 ID" and DST is "the 8 MOST significant bits of the
%Destination Layer-2 ID". Clause 5.22.1.3.1 sets the SCI's Source Layer-1 ID to "the 8 LSB of the
%Source Layer-2 ID" and its Destination Layer-1 ID to "the 16 LSB of the Destination Layer-2 ID".
%So SRC(16 MSB) + SCI's 8 LSB reconstitute the 24-bit source, and DST(8 MSB) + SCI's 16 LSB
%reconstitute the 24-bit destination. A receiver needs both layers to identify a peer, which is
%why a MAC PDU alone is not addressable.
%
%Subheader shapes, from clause 6.1.6 and the figures it cites:
%  - SL-SCH subheader, fixed 4 octets: V(4 bits)|R|R|R|R, then SRC over octets 2-3, then DST in
%    octet 4. Clause 6.2.4: "In this version of the specification, the V field is set to 0."
%  - MAC SDU subheader, R|F|LCID|L: 1 octet of R(1)|F(1)|LCID(6) plus an L field of 8 bits
%    (F=0) or 16 bits (F=1). Clause 6.2.4 fixes the choice, it is not free: "If the size of the
%    MAC SDU is less than 256 bytes, the value of the F field is set to 0, otherwise it is set
%    to 1."
%  - Fixed-size MAC CE and padding subheader, R|LCID: 1 octet of R(2)|LCID(6), no F and no L.
%    The Sidelink CSI Reporting MAC CE is fixed-size (clause 6.1.3.35: RI 1 bit + CQI 4 bits,
%    padded to one octet), so it takes this form and NOT the R/F/LCID/L form.
LCID_CSI = 62;       % Table 6.2.4-1
LCID_PADDING = 63;   % Table 6.2.4-1
LCID_MAX_SDU = 19;   % Table 6.2.4-1: 0..3 SCCH, 4..19 identity of the logical channel
SLSCH_SUBHEADER_BYTES = 4;
F_THRESHOLD_BYTES = 256;   % clause 6.2.4: L is 8 bits below this, 16 bits at or above it

if ~isscalar(srcL2Id) || mod(srcL2Id, 1) ~= 0 || srcL2Id < 0 || srcL2Id > 2^24 - 1
    error('mac:muxSlSch:badSrcId', 'muxSlSch: srcL2Id must be an integer in 0..2^24-1 (24-bit Source Layer-2 ID), got %s', num2str(srcL2Id));
end
if ~isscalar(dstL2Id) || mod(dstL2Id, 1) ~= 0 || dstL2Id < 0 || dstL2Id > 2^24 - 1
    error('mac:muxSlSch:badDstId', 'muxSlSch: dstL2Id must be an integer in 0..2^24-1 (24-bit Destination Layer-2 ID), got %s', num2str(dstL2Id));
end
if ~isequal(size(sduLen), size(sduLcid))
    error('mac:muxSlSch:badSduArrays', 'muxSlSch: sduLen and sduLcid must be the same size, got %d and %d', numel(sduLen), numel(sduLcid));
end
if any(sduLen < 1) || any(mod(sduLen, 1) ~= 0)
    error('mac:muxSlSch:badSduLen', 'muxSlSch: every sduLen entry must be a positive integer number of bytes');
end
if numel(sduBytes) ~= sum(sduLen)
    error('mac:muxSlSch:sduLengthMismatch', 'muxSlSch: sduBytes has %d octets but sduLen sums to %d', numel(sduBytes), sum(sduLen));
end
if any(sduBytes < 0) || any(sduBytes > 255) || any(mod(sduBytes, 1) ~= 0)
    error('mac:muxSlSch:badSduBytes', 'muxSlSch: sduBytes entries must be octets in 0..255');
end
if any(mod(sduLcid, 1) ~= 0) || any(sduLcid < 0) || any(sduLcid > LCID_MAX_SDU)
    error('mac:muxSlSch:badLcid', 'muxSlSch: sduLcid entries must be in 0..%d (Table 6.2.4-1); LCID %d is the CSI MAC CE and %d is padding, both of which this function builds itself', LCID_MAX_SDU, LCID_CSI, LCID_PADDING);
end
if pduSizeBytes < 1 || mod(pduSizeBytes, 1) ~= 0
    error('mac:muxSlSch:badPduSize', 'muxSlSch: pduSizeBytes must be a positive integer (tbsDetermine''s tbs / 8), got %s', num2str(pduSizeBytes));
end
csiPresent = logical(csiPresent);
nSdu = numel(sduLen);
if nSdu == 0 && ~csiPresent
    % clause 5.22.1.4.1.3: "The MAC entity shall not generate a MAC PDU for the HARQ entity if
    % [...] there is no Sidelink CSI Reporting MAC CE generated for this PSSCH transmission [...]
    % and the MAC PDU includes zero MAC SDUs."
    error('mac:muxSlSch:emptyPdu', 'muxSlSch: clause 5.22.1.4.1.3 forbids generating a MAC PDU with zero MAC SDUs and no Sidelink CSI Reporting MAC CE');
end
if csiPresent
    if ~isscalar(csiRI) || ~any(csiRI == [0 1])
        error('mac:muxSlSch:badRI', 'muxSlSch: csiRI must be 0 or 1 (clause 6.1.3.35, 1-bit field), got %s', num2str(csiRI));
    end
    if ~isscalar(csiCQI) || mod(csiCQI, 1) ~= 0 || csiCQI < 0 || csiCQI > 15
        error('mac:muxSlSch:badCQI', 'muxSlSch: csiCQI must be an integer in 0..15 (clause 6.1.3.35, 4-bit field), got %s', num2str(csiCQI));
    end
end

% ---- SL-SCH subheader (clause 6.2.4, Figure 6.1.6-1) ----------------------
octets = zeros(1, 0);
V = 0;   % clause 6.2.4: "In this version of the specification, the V field is set to 0"
octets(end+1) = bitshift(V, 4);                        % V(4) | R R R R (4), reserved bits 0
srcHigh16 = bitshift(srcL2Id, -8);                     % 16 MSB of the 24-bit Source Layer-2 ID
octets(end+1) = bitshift(srcHigh16, -8);
octets(end+1) = bitand(srcHigh16, 255);
octets(end+1) = bitshift(dstL2Id, -16);                % 8 MSB of the 24-bit Destination Layer-2 ID

% ---- MAC SDU subPDUs, in LCP order (clause 6.1.6: SDUs first) -------------
sduCursor = 0;
for i = 1:nSdu
    L = sduLen(i);
    if L < F_THRESHOLD_BYTES
        F = 0;   % clause 6.2.4: 8-bit L field
    else
        F = 1;   % clause 6.2.4: 16-bit L field
    end
    octets(end+1) = bitor(bitshift(F, 6), sduLcid(i));  %#ok<AGROW> % R(1)|F(1)|LCID(6)
    if F == 0
        octets(end+1) = L;                              %#ok<AGROW>
    else
        octets(end+1) = bitshift(L, -8);                %#ok<AGROW>
        octets(end+1) = bitand(L, 255);                 %#ok<AGROW>
    end
    octets = [octets, sduBytes(sduCursor + (1:L))];     %#ok<AGROW>
    sduCursor = sduCursor + L;
end

% ---- Sidelink CSI Reporting MAC CE subPDU (clause 6.1.6: after all SDUs) --
if csiPresent
    octets(end+1) = LCID_CSI;                               % R(2)|LCID(6), fixed-size CE form
    octets(end+1) = bitor(bitshift(csiRI, 7), bitshift(csiCQI, 3));   % RI(1)|CQI(4)|R(3)
end

nContentBytes = numel(octets);
if nContentBytes > pduSizeBytes
    error('mac:muxSlSch:overflow', 'muxSlSch: assembled content is %d octets but the transport block is %d; LCP must size the content against the grant before assembly', nContentBytes, pduSizeBytes);
end

% ---- Padding subPDU (clause 6.1.6: last, and "the size of padding can be zero") ----
remaining = pduSizeBytes - nContentBytes;
nPaddingBytes = 0;
if remaining > 0
    octets(end+1) = LCID_PADDING;    % R(2)|LCID(6)
    nPaddingBytes = remaining - 1;   % the subheader itself consumes one octet
    octets = [octets, zeros(1, nPaddingBytes)];
end

pduBits = octetsToBits(octets);
nSduIncluded = nSdu;
end

function bits = octetsToBits(octets)
%octetsToBits Expand octets to an MSB-first bit column, the order clause 6.1.6's figures read in.
n = numel(octets);
bits = zeros(8 * n, 1);
for i = 1:n
    v = octets(i);
    for b = 1:8
        bits((i - 1) * 8 + b) = bitget(v, 9 - b);   % bit 8 (MSB) first
    end
end
end
