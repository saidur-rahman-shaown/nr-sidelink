function [tx, discardCount, discardTag] = pdcpTxTimer(tx, nowMs)
%pdcpTxTimer Expire the discardTimers that are due and report the SDUs to discard.
%Spec:   TS 38.323 V16.8.0, clause 5.3: "When the discardTimer expires for a PDCP SDU ... the
%        transmitting PDCP entity shall discard the PDCP SDU along with the corresponding PDCP
%        Data PDU. If the corresponding PDCP Data PDU has already been submitted to lower layers,
%        the discard is indicated to lower layers." NOTE: "Discarding a PDCP SDU already
%        associated with a PDCP SN causes a SN gap in the transmitted PDCP Data PDUs".
%Inputs: tx     entity from pdcpTxInit
%        nowMs  real, ms
%Outputs: tx            updated entity; .nTimerExpired counts every expiry
%         discardCount  1 x d integer -- COUNTs whose discardTimer expired, ascending
%         discardTag    1 x d integer -- the matching caller tags
%
%Every PDU is submitted to RLC the moment it is built (pdcpTxSdu), so EVERY expiry is the
%"already submitted" case: the caller must pass each COUNT to rlc.umTxDiscard / rlc.amTxDiscard.
%RLC then discards only if no byte of it has reached MAC yet (TS 38.322 clause 5.4); otherwise
%the SDU is already on the air and completes. That is the spec working as written, not a leak:
%the timer bounds QUEUEING, and a PDU half-way through segmentation has left the queue.
%
%The SN gap clause 5.3's NOTE warns about is real for gc/bc (the receiver's t-Reordering then
%waits it out) and is avoided for AM by RLC itself (TS 38.322 clause 5.4, no RLC SN gap).

due = tx.discExpiry <= nowMs;
discardCount = tx.discCount(due);
discardTag = tx.discTag(due);
tx.discCount = tx.discCount(~due);
tx.discTag = tx.discTag(~due);
tx.discExpiry = tx.discExpiry(~due);
tx.nTimerExpired = tx.nTimerExpired + numel(discardCount);
end
