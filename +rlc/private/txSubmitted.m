function [any_, highest] = txSubmitted(tx)
%txSubmitted Whether any not-yet-acknowledged SN has been submitted, and the highest one.
%Spec:   TS 38.322 V16.3.0, clause 5.3.2 ("TX_Next_Ack <= SN <= the highest SN of the AMD PDU
%        among the AMD PDUs submitted to lower layer") and clause 5.3.3.2 (POLL_SN), compared
%        against the modulus base TX_Next_Ack (clause 7.1).
%Inputs: tx  AM transmit entity
%Outputs: any_     logical -- highestSubmittedSn lies in [TX_Next_Ack, TX_Next)
%         highest  integer -- highestSubmittedSn (meaningful only when any_)
%
%Once every submitted SDU is acknowledged, TX_Next_Ack has moved past highestSubmittedSn and
%the stored value is below the window. It must then count as "nothing outstanding" rather than
%be compared as a raw number, or after a wrap it reads as the highest SN in the space.

snLen = tx.cfg.snFieldLength;
highest = tx.highestSubmittedSn;
any_ = highest >= 0 && ...
    rlc.snDiff(highest, tx.TX_Next_Ack, snLen) < rlc.snDiff(tx.TX_Next, tx.TX_Next_Ack, snLen);
end
