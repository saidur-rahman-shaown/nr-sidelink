function [tx, discarded] = umTxDiscard(tx, tag)
%umTxDiscard Discard a queued SDU on upper-layer (PDCP) indication.
%Spec:   TS 38.322 V16.3.0, clause 5.4: "When indicated from upper layer (i.e. PDCP) to discard
%        a particular RLC SDU, the transmitting side of an AM RLC entity or the transmitting UM
%        RLC entity shall discard the indicated RLC SDU, if neither the RLC SDU nor a segment
%        thereof has been submitted to the lower layers."
%Inputs: tx   entity from umTxInit
%        tag  integer -- the tag the SDU was enqueued with
%Outputs: tx         updated entity
%         discarded  logical -- false when no such SDU is queued, or when part of it has
%                    already gone to MAC. The second case is not an error: PDCP's discard
%                    timer fires on its own schedule, and a partly sent SDU is finished rather
%                    than truncated, since a truncated SDU can never be reassembled
%
%UM holds no SN for an unsent SDU, so unlike AM there is no gap to close.

discarded = false;
k = find(tx.sduTag == tag, 1);
if isempty(k) || tx.sduOffset(k) > 0
    return;
end
start = 1 + sum(tx.sduLen(1:k - 1));
tx.buf(start : start + tx.sduLen(k) - 1) = [];
tx.sduLen(k) = [];
tx.sduTag(k) = [];
tx.sduOffset(k) = [];
tx.sduSn(k) = [];
discarded = true;
end
