function [srcHigh16, dstHigh8, sduBytes, sduLen, sduLcid, csiPresent, csiRI, csiCQI] = demuxSlSch(pduBits)
%demuxSlSch Disassemble an SL-SCH MAC PDU. The inverse of muxSlSch.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.3 ("The MAC entity shall disassemble and demultiplex
%        a MAC PDU as defined in clause 6.1.6"), clause 6.1.6 (MAC PDU (SL-SCH)), clause 6.2.4
%        (MAC subheader for SL-SCH and Table 6.2.4-1 LCID values), clause 6.1.3.35 (Sidelink
%        CSI Reporting MAC CE).
%Inputs: pduBits  (8*nBytes) x 1 vector of 0/1, MSB-first within each octet -- a decoded
%                 transport block, exactly the shape muxSlSch emits
%Outputs: srcHigh16   integer, 0..65535 -- SRC field: the 16 MOST significant bits of the
%                     Source Layer-2 ID. **Not the full ID** -- see below
%         dstHigh8    integer, 0..255 -- DST field: the 8 MOST significant bits of the
%                     Destination Layer-2 ID. Also not the full ID
%         sduBytes    1 x sum(sduLen) row vector of octets -- every MAC SDU concatenated in the
%                     order they appeared, flat, carved up by sduLen (the same shape muxSlSch
%                     takes, so a round trip is comparable field by field)
%         sduLen      1 x nSdu integer row vector -- byte length of each SDU
%         sduLcid     1 x nSdu integer row vector -- LCID of each SDU
%         csiPresent  logical -- whether a Sidelink CSI Reporting MAC CE was present
%         csiRI       integer, 0 or 1 -- its RI field; 0 when absent
%         csiCQI      integer, 0..15 -- its CQI field; 0 when absent
%
%WHAT THIS RETURNS IS HALF OF EACH IDENTITY, DELIBERATELY
%---------------------------------------------------------
%Clause 6.2.4 puts the 16 MOST significant bits of the Source Layer-2 ID and the 8 MOST
%significant bits of the Destination Layer-2 ID in the subheader; clause 5.22.1.3.1 puts the 8
%LSB of the source and the 16 LSB of the destination in the SCI. Neither layer alone identifies
%a peer. So this function returns the fields as they appear on the wire -- named `srcHigh16`
%and `dstHigh8` rather than `srcL2Id`/`dstL2Id` -- and the cross-check against the SCI's halves
%is mac.pduFilter's job, per clause 5.22.2.2.2. Returning them under the full-identity names
%would invite a caller to compare a 16-bit fragment against a 24-bit ID and find it never
%matches, or worse, to mask and find it always does.
%
%PARSING STOPS AT THE PADDING SUBHEADER
%---------------------------------------
%Clause 6.1.6 places padding last and clause 6.1.5 says "Presence and length of padding is
%implicit based on TB size" -- the padding subPDU carries no length field, so everything after
%its subheader is padding to the end of the transport block. Continuing to parse past it reads
%padding octets as subheaders, which produces plausible-looking SDUs of arbitrary length from
%what is, in this implementation, a run of zeros.

LCID_CSI     = 62;   % Table 6.2.4-1
LCID_PADDING = 63;   % Table 6.2.4-1
LCID_MAX_SDU = 19;   % Table 6.2.4-1: 0..3 SCCH, 4..19 identity of the logical channel
F_THRESHOLD_BYTES = 256;   % clause 6.2.4: L is 8 bits below this, 16 bits at or above

if mod(numel(pduBits), 8) ~= 0
    error('mac:demuxSlSch:notByteAligned', 'demuxSlSch: a MAC PDU is byte aligned (clause 6.1.1); got %d bits', numel(pduBits));
end
octets = bitsToOctets(pduBits(:));
nBytes = numel(octets);
if nBytes < 4
    error('mac:demuxSlSch:tooShort', 'demuxSlSch: the SL-SCH subheader alone is 4 octets; got %d', nBytes);
end

% ---- SL-SCH subheader, 4 octets (clause 6.2.4) ---------------------------
V = bitshift(octets(1), -4);
if V ~= 0
    error('mac:demuxSlSch:badVersion', 'demuxSlSch: clause 6.2.4 fixes the V field at 0 in this version of the specification, got %d', V);
end
srcHigh16 = bitshift(octets(2), 8) + octets(3);
dstHigh8  = octets(4);

% ---- subPDUs ------------------------------------------------------------
sduBytes = zeros(1, 0);
sduLen   = zeros(1, 0);
sduLcid  = zeros(1, 0);
csiPresent = false;
csiRI  = 0;
csiCQI = 0;

k = 5;
while k <= nBytes
    lcid = bitand(octets(k), 63);       % low 6 bits in every subheader form

    if lcid == LCID_PADDING
        break;                          % everything after is padding; see the header
    end

    if lcid == LCID_CSI
        % Fixed-size MAC CE: R(2)|LCID(6) subheader, then one octet of RI(1)|CQI(4)|R(3).
        if k + 1 > nBytes
            error('mac:demuxSlSch:truncatedCsi', 'demuxSlSch: a CSI Reporting MAC CE subheader at octet %d has no payload octet', k);
        end
        csiPresent = true;
        csiRI  = bitshift(octets(k + 1), -7);
        csiCQI = bitand(bitshift(octets(k + 1), -3), 15);
        k = k + 2;
        continue;
    end

    if lcid > LCID_MAX_SDU
        error('mac:demuxSlSch:reservedLcid', 'demuxSlSch: LCID %d at octet %d is reserved in Table 6.2.4-1', lcid, k);
    end

    % MAC SDU subheader: R(1)|F(1)|LCID(6), then an 8- or 16-bit L.
    F = bitand(bitshift(octets(k), -6), 1);
    if F == 0
        if k + 1 > nBytes
            error('mac:demuxSlSch:truncatedLength', 'demuxSlSch: an 8-bit L field at octet %d runs past the PDU', k);
        end
        L = octets(k + 1);
        hdr = 2;
    else
        if k + 2 > nBytes
            error('mac:demuxSlSch:truncatedLength', 'demuxSlSch: a 16-bit L field at octet %d runs past the PDU', k);
        end
        L = bitshift(octets(k + 1), 8) + octets(k + 2);
        hdr = 3;
    end
    % Clause 6.2.4 fixes the F/L pairing, so a PDU whose F disagrees with its own L is
    % malformed rather than merely unusual -- and accepting it would let a 16-bit L carry a
    % short SDU, shifting every subsequent subheader by one octet.
    if (F == 0 && L >= F_THRESHOLD_BYTES) || (F == 1 && L < F_THRESHOLD_BYTES)
        error('mac:demuxSlSch:fieldMismatch', 'demuxSlSch: clause 6.2.4 pairs F=0 with L<256 and F=1 with L>=256; got F=%d L=%d at octet %d', F, L, k);
    end
    if k + hdr + L - 1 > nBytes
        error('mac:demuxSlSch:truncatedSdu', 'demuxSlSch: an SDU of %d octets at octet %d runs past the %d-octet PDU', L, k, nBytes);
    end

    sduBytes = [sduBytes, octets(k + hdr + (0:L - 1))]; %#ok<AGROW>
    sduLen(end + 1)  = L;    %#ok<AGROW>
    sduLcid(end + 1) = lcid; %#ok<AGROW>
    k = k + hdr + L;
end
end

% =========================================================================
function octets = bitsToOctets(bits)
%bitsToOctets Collapse an MSB-first bit column into octets. Inverse of muxSlSch's octetsToBits.
n = numel(bits) / 8;
octets = zeros(1, n);
for i = 1:n
    b = double(bits((i - 1) * 8 + (1:8)));
    octets(i) = b(1) * 128 + b(2) * 64 + b(3) * 32 + b(4) * 16 + b(5) * 8 + b(6) * 4 + b(7) * 2 + b(8);
end
end
