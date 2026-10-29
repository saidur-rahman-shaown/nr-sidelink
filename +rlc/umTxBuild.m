function [tx, pduBytes, pduLen, pduTag] = umTxBuild(tx, grantBytes)
%umTxBuild Fill a transmission opportunity with UMD PDUs, segmenting as needed.
%Spec:   TS 38.322 V16.3.0, clause 4.2.1.2.2: "When notified of a transmission opportunity by
%        the lower layer, the transmitting UM RLC entity shall segment the RLC SDUs, if needed,
%        so that the corresponding UMD PDUs, with RLC headers updated as needed, fit within the
%        total size of RLC PDU(s) indicated by lower layer." Clause 5.2.2.1.1: "if the UMD PDU
%        contains a segment of an RLC SDU, set the SN of the UMD PDU to TX_Next; if the UMD PDU
%        contains a segment that maps to the last byte of an RLC SDU, then increment TX_Next by
%        one." Clause 6.2.3.2: one SDU or one segment per Data field. Clause 4.2.1: "RLC PDUs
%        are submitted to lower layer only when a transmission opportunity has been notified".
%Inputs: tx          entity from umTxInit
%        grantBytes  integer, >=0 -- "the total size of RLC PDU(s)" MAC indicated for this
%                    logical channel (clause 4.3.2). RLC headers count against it; MAC
%                    subheaders do not, they are MAC's to account
%Outputs: tx        updated entity
%         pduBytes  1 x sum(pduLen) octets -- every UMD PDU built, concatenated in submission
%                   order. The same flat form +mac/muxSlSch takes as sduBytes
%         pduLen    1 x nPdu integer -- length of each PDU. sum(pduLen) <= grantBytes
%         pduTag    1 x nPdu integer -- tag of the SDU each PDU carries
%
%SDUs are served in arrival order and only the head SDU is ever part-sent: an SDU is taken up
%only when everything before it has gone, so SN order is submission order.
%
%A segment is never formed with an empty Data field. When the space left cannot hold the
%header plus one byte, the opportunity ends and the leftover is MAC's padding -- clause
%6.2.3.2's one-byte granularity makes a zero-byte segment meaningless, and emitting one would
%still advance TX_Next if it happened to be marked last.

SI_COMPLETE = rlc.siValue(true, true);
SI_FIRST    = rlc.siValue(true, false);
SI_LAST     = rlc.siValue(false, true);
snLen = tx.cfg.snFieldLength;

if ~(grantBytes >= 0 && mod(grantBytes, 1) == 0)
    error('rlc:umTxBuild:badGrant', 'umTxBuild: grantBytes must be a non-negative integer');
end

pduBytes = zeros(1, 0);
pduLen = zeros(1, 0);
pduTag = zeros(1, 0);
remaining = grantBytes;

while ~isempty(tx.sduLen)
    L = tx.sduLen(1);
    off = tx.sduOffset(1);

    if off == 0 && remaining >= rlc.umdHeaderBytes(SI_COMPLETE, snLen) + L
        % Whole SDU fits: no segmentation, no SN (Figure 6.2.2.3-1).
        pdu = rlc.umdPduPack(SI_COMPLETE, 0, 0, tx.buf(1:L), snLen);
        [tx, pduBytes, pduLen, pduTag, remaining] = emit(tx, pdu, pduBytes, pduLen, pduTag, remaining);
        tx = popHead(tx);
        continue;
    end

    if off == 0
        si = SI_FIRST;
    else
        si = SI_LAST;           % header size is the same for last and middle (both carry SO)
    end
    hdr = rlc.umdHeaderBytes(si, snLen);
    if remaining < hdr + 1
        break;
    end
    n = min(L - off, remaining - hdr);
    isLast = (off + n == L);
    si = rlc.siValue(off == 0, isLast);

    if tx.sduSn(1) < 0
        tx.sduSn(1) = tx.TX_Next;       % clause 5.2.2.1.1: "set the SN of the UMD PDU to TX_Next"
    end
    pdu = rlc.umdPduPack(si, tx.sduSn(1), off, tx.buf(off + 1 : off + n), snLen);
    [tx, pduBytes, pduLen, pduTag, remaining] = emit(tx, pdu, pduBytes, pduLen, pduTag, remaining);
    tx.sduOffset(1) = off + n;

    if isLast
        % "if the UMD PDU contains a segment that maps to the last byte of an RLC SDU, then
        % increment TX_Next by one" -- modulo 2^[sn-FieldLength], clause 7.1.
        tx.TX_Next = mod(tx.TX_Next + 1, 2^snLen);
        tx = popHead(tx);
    end
end
end

function [tx, pduBytes, pduLen, pduTag, remaining] = emit(tx, pdu, pduBytes, pduLen, pduTag, remaining)
pduBytes = [pduBytes, pdu];
pduLen(end + 1) = numel(pdu);
pduTag(end + 1) = tx.sduTag(1);
remaining = remaining - numel(pdu);
end

function tx = popHead(tx)
L = tx.sduLen(1);
tx.buf(1:L) = [];
tx.sduLen(1) = [];
tx.sduTag(1) = [];
tx.sduOffset(1) = [];
tx.sduSn(1) = [];
end
