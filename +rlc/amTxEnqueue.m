function [tx, sn] = amTxEnqueue(tx, sdu, tag)
%amTxEnqueue Accept an RLC SDU from upper layer and bind its SN.
%Spec:   TS 38.322 V16.3.0, clause 5.2.3.1.1: "For each RLC SDU received from the upper layer,
%        the AM RLC entity shall: associate a SN with the RLC SDU equal to TX_Next and construct
%        an AMD PDU by setting the SN of the AMD PDU to TX_Next; increment TX_Next by one."
%        Clause 4.2.1: "Each RLC SDU is used to construct an RLC PDU without waiting for
%        notification from the lower layer". Clause 7.1 b): TX_Next "is updated whenever the AM
%        RLC entity constructs an AMD PDU with SN = TX_Next and contains an RLC SDU".
%Inputs: tx   entity from amTxInit
%        sdu  1 x L row vector of octets, 1 <= L <= 65536 (16-bit SO, clause 6.2.3.5)
%        tag  integer -- caller's identifier, returned when the SDU is acknowledged
%Outputs: tx  updated entity
%         sn  integer -- the SN bound to this SDU
%
%AM BINDS THE SN AT ARRIVAL; UM BINDS IT AT SUBMISSION
%-----------------------------------------------------
%The two modes differ here and it is easy to copy one into the other. Clause 5.2.3.1.1 binds
%the AM SN "for each RLC SDU received from the upper layer", with no transmission opportunity
%involved; clause 5.2.2.1.1 binds a UM SN only when a UMD PDU "contains a segment". The AM
%choice is what forces clause 5.4's "shall not introduce an RLC SN gap" -- see amTxDiscard.
%
%An SDU whose SN is outside the transmitting window is accepted and simply waits: the window
%gates SUBMISSION (clause 5.2.3.1.1, "shall not submit to lower layer any AMD PDU whose SN falls
%outside of the transmitting window"), not acceptance.

SO_BITS = 16;
checkOctets(sdu, 'amTxEnqueue', 'sdu');
if isempty(sdu) || numel(sdu) > 2^SO_BITS
    error('rlc:amTxEnqueue:badLength', 'amTxEnqueue: SDU length must be 1..%d bytes, got %d', 2^SO_BITS, numel(sdu));
end
snLen = tx.cfg.snFieldLength;
M = 2^snLen;
if rlc.snDiff(tx.TX_Next + 1, tx.TX_Next_Ack, snLen) == 0
    % One more SN would make TX_Next equal TX_Next_Ack again, and every "TX_Next_Ack <= SN <
    % TX_Next" test would read the whole outstanding set as empty.
    error('rlc:amTxEnqueue:snExhausted', 'amTxEnqueue: all %d SNs are outstanding', M - 1);
end
sn = tx.TX_Next;
tx.buf = [tx.buf, sdu];
tx.sduSn(end + 1) = sn;
tx.sduLen(end + 1) = numel(sdu);
tx.sduTag(end + 1) = tag;
tx.sduSent(end + 1) = 0;
tx.RETX_COUNT(end + 1) = -1;
tx.TX_Next = mod(tx.TX_Next + 1, M);
end
