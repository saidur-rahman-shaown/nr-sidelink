function [bothEmpty, stalled, kNext] = txBufferState(tx)
%txBufferState The two buffer conditions clauses 5.3.3.2 and 5.3.3.4 poll on.
%Spec:   TS 38.322 V16.3.0, clause 5.3.3.2: "if both the transmission buffer and the
%        retransmission buffer becomes empty (excluding transmitted RLC SDUs or RLC SDU segments
%        awaiting acknowledgements) ...; or if no new RLC SDU can be transmitted ... (e.g. due to
%        window stalling)"; clause 5.2.3.1.1 (the transmitting window, TX_Next_Ack <= SN <
%        TX_Next_Ack + AM_Window_Size).
%Inputs: tx  AM transmit entity
%Outputs: bothEmpty  logical -- no SDU has unsent bytes and nothing is pending retransmission
%         stalled    logical -- there IS unsent data, but the first SDU holding it has an SN
%                    outside the transmitting window
%         kNext      integer -- index of the first SDU with unsent bytes, 0 if none

snLen = tx.cfg.snFieldLength;
kNext = find(tx.sduSent < tx.sduLen, 1);
if isempty(kNext)
    kNext = 0;
end
bothEmpty = (kNext == 0) && isempty(tx.retxSn);
stalled = (kNext > 0) && rlc.snDiff(tx.sduSn(kNext), tx.TX_Next_Ack, snLen) >= tx.cfg.AM_Window_Size;
end
