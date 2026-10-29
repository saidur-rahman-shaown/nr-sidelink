function [tx, rx, sduBytes, sduLen, ackedTags, maxRetxTags] = amReceive(tx, rx, pdu, nowMs)
%amReceive Route one RLC PDU received on an AM logical channel to the side that owns it.
%Spec:   TS 38.322 V16.3.0, clause 6.2.3.6, Table 6.2.3.6-1 (D/C: 0 control PDU, 1 data PDU);
%        clause 4.2.1.3.1 (an AM entity "delivers/receives" AMD PDUs and STATUS PDUs); clause
%        6.2.3.9 / 5.6.1 (a control PDU with a reserved CPT is discarded).
%Inputs: tx, rx  the two sides of one AM entity
%        pdu     1 x n octets, n >= 1 -- one RLC PDU as MAC demultiplexed it
%        nowMs   real, ms
%Outputs: tx, rx       updated
%         sduBytes     1 x sum(sduLen) octets -- SDUs delivered by a data PDU
%         sduLen       1 x nSdu integer
%         ackedTags    1 x a integer -- SDUs positively acknowledged by a STATUS PDU
%         maxRetxTags  1 x m integer -- SDUs that reached maxRetxThreshold
%
%A STATUS PDU goes to the TRANSMITTING side: it reports on this UE's own transmissions. A
%receiver that fed STATUS PDUs to its reassembly would parse their octets as an AMD header,
%and with D/C = 0 amdPduParse rejects them -- so the misrouting shows up only as a
%transmitter that never sees an acknowledgement and retransmits until max-retx.

OCTET_BITS = 8;
DC_DATA = 1;
sduBytes = zeros(1, 0);
sduLen = zeros(1, 0);
ackedTags = zeros(1, 0);
maxRetxTags = zeros(1, 0);
if isempty(pdu)
    rx.nPduDiscarded = rx.nPduDiscarded + 1;
    return;
end

dc = floor(pdu(1) / 2^(OCTET_BITS - 1));       % the first bit, clause 6.2.2.1 bit order
if dc == DC_DATA
    [rx, sduBytes, sduLen] = rlc.amRxPdu(rx, pdu, nowMs);
else
    [valid, ackSn, nackSn, soStart, soEnd, nackRange] = rlc.statusPduParse(pdu, tx.cfg.snFieldLength);
    if valid
        [tx, ackedTags, maxRetxTags] = rlc.amTxOnStatus(tx, ackSn, nackSn, soStart, soEnd, nackRange);
    end
end
end
