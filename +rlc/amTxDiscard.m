function [tx, discarded] = amTxDiscard(tx, tag)
%amTxDiscard Discard an unsent SDU on upper-layer (PDCP) indication, without an SN gap.
%Spec:   TS 38.322 V16.3.0, clause 5.4: "When indicated from upper layer (i.e. PDCP) to discard
%        a particular RLC SDU, the transmitting side of an AM RLC entity ... shall discard the
%        indicated RLC SDU, if neither the RLC SDU nor a segment thereof has been submitted to
%        the lower layers. The transmitting side of an AM RLC entity shall not introduce an RLC
%        SN gap when discarding an RLC SDU."
%Inputs: tx   entity from amTxInit
%        tag  integer
%Outputs: tx         updated entity
%         discarded  logical -- false if no such SDU, or if any of it was submitted
%
%WHY THE GAP MATTERS, AND HOW IT IS CLOSED
%-----------------------------------------
%The SN was bound at arrival (amTxEnqueue), so simply deleting the SDU leaves its SN unused. The
%peer's receiver would wait for it forever: RX_Next can never pass an SN that is never sent,
%every later STATUS PDU NACKs it, and the transmitter has nothing to retransmit -- a permanent
%stall of the whole bearer from one discard.
%
%It is closed by renumbering: every SDU after the discarded one moves down by one SN and
%TX_Next goes back by one. This is safe exactly because of the clause's precondition. SDUs are
%first submitted in SN order, so if the discarded SDU was never submitted, NO later SDU was
%either, and no SN being renumbered has ever been seen by the peer. The assertion below checks
%that reasoning rather than trusting it.

snLen = tx.cfg.snFieldLength;
M = 2^snLen;
discarded = false;
k = find(tx.sduTag == tag, 1);
if isempty(k) || tx.sduSent(k) > 0 || tx.RETX_COUNT(k) >= 0
    return;
end
later = (k + 1):numel(tx.sduSn);
if any(tx.sduSent(later) > 0)
    error('rlc:amTxDiscard:orderViolated', 'amTxDiscard: an SDU after SN %d was submitted before it', tx.sduSn(k));
end

start = 1 + sum(tx.sduLen(1:k - 1));
tx.buf(start : start + tx.sduLen(k) - 1) = [];
tx.sduSn(later) = mod(tx.sduSn(later) - 1, M);
tx.sduSn(k) = [];
tx.sduLen(k) = [];
tx.sduTag(k) = [];
tx.sduSent(k) = [];
tx.RETX_COUNT(k) = [];
tx.TX_Next = mod(tx.TX_Next - 1, M);
discarded = true;
end
