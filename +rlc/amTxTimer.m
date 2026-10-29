function [tx, expired, maxRetxTags] = amTxTimer(tx, nowMs)
%amTxTimer Run t-PollRetransmit expiry on the transmitting side, if it is due.
%Spec:   TS 38.322 V16.3.0, clause 5.3.3.4: "Upon expiry of t-PollRetransmit, the transmitting
%        side of an AM RLC entity shall: if both the transmission buffer and the retransmission
%        buffer are empty (excluding transmitted RLC SDU or RLC SDU segment awaiting
%        acknowledgements); or if no new RLC SDU or RLC SDU segment can be transmitted (e.g. due
%        to window stalling): consider the RLC SDU with the highest SN among the RLC SDUs
%        submitted to lower layer for retransmission; or consider any RLC SDU which has not
%        been positively acknowledged for retransmission. include a poll in an AMD PDU as
%        described in clause 5.3.3.2." Clause 5.3.2 for what "consider for retransmission"
%        does to RETX_COUNT.
%Inputs: tx     entity from amTxInit
%        nowMs  real, ms
%Outputs: tx           updated entity
%         expired      logical
%         maxRetxTags  1 x m integer -- as amTxOnStatus: RETX_COUNT reached maxRetxThreshold
%
%The clause offers two choices; this takes the first (the highest submitted SN), falling back
%to the lowest unacknowledged submitted SDU only when the highest has since been acknowledged.
%
%THIS IS THE PATH THAT REACHES maxRetxThreshold ON A DEAD LINK
%-------------------------------------------------------------
%When the peer has gone silent no STATUS PDU ever arrives, so no NACK ever drives RETX_COUNT.
%Only this expiry does: each one re-considers the SDU, and since the retransmission was sent
%(so it is no longer pending) each consideration increments. Without it an AM bearer to a peer
%that has driven out of range polls forever and never declares failure.

expired = false;
maxRetxTags = zeros(1, 0);
if tx.tPollRetransmitExpiry < 0 || nowMs < tx.tPollRetransmitExpiry
    return;
end
expired = true;
tx.tPollRetransmitExpiry = -1;

[bothEmpty, stalled] = txBufferState(tx);
if bothEmpty || stalled
    [anySub, highest] = txSubmitted(tx);
    k = [];
    if anySub
        k = find(tx.sduSn == highest & tx.sduSent > 0, 1);
    end
    if isempty(k)
        k = find(tx.sduSent > 0, 1);
    end
    if ~isempty(k)
        [tx, ~, reached] = considerRetx(tx, k, 0, tx.sduSent(k) - 1, true);
        if reached
            maxRetxTags = tx.sduTag(k);
        end
    end
end
tx.pollPending = true;
end
