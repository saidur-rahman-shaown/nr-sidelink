function [tx, ackedTags, maxRetxTags, valid] = amTxOnStatus(tx, ackSn, nackSn, soStart, soEnd, nackRange)
%amTxOnStatus Act on a received STATUS PDU: acknowledge, schedule retransmissions, stop the poll timer.
%Spec:   TS 38.322 V16.3.0,
%        clause 6.2.3.10: "it interprets that all RLC SDUs up to but not including the RLC SDU
%          with SN = ACK_SN have been received by its peer AM RLC entity, excluding those RLC
%          SDUs indicated in the STATUS PDU with NACK_SN, portions of RLC SDUs indicated ... with
%          NACK_SN, SOstart and SOend, RLC SDUs indicated ... with NACK_SN and NACK_range, and
%          portions of RLC SDUs indicated ... with NACK_SN, NACK range, SOstart and SOend."
%        clauses 6.2.3.14/6.2.3.15/6.2.3.17: with E3 = 1, SOstart belongs to NACK_SN and SOend
%          to "NACK_SN + NACK range - 1"; SOend 0xFFFF means "to the last byte".
%        clause 5.2.3.1.1: on a positive acknowledgement for SN = x, "send an indication to the
%          upper layers of successful delivery of the RLC SDU; set TX_Next_Ack equal to the SN
%          of the RLC SDU with the smallest SN, whose SN falls within the range TX_Next_Ack <=
%          SN <= TX_Next and for which a positive acknowledgment has not been received yet."
%        clause 5.3.2: a negative acknowledgement is acted on only "if the SN of the
%          corresponding RLC SDU falls within the range TX_Next_Ack <= SN <= the highest SN of
%          the AMD PDU among the AMD PDUs submitted to lower layer"; then RETX_COUNT rules.
%        clause 5.3.3.3: "if the STATUS report comprises a positive or negative acknowledgement
%          for the RLC SDU with sequence number equal to POLL_SN: if t-PollRetransmit is
%          running: stop and reset t-PollRetransmit."
%        clause 5.6.1: a PDU with invalid values is discarded (valid = false, tx unchanged).
%Inputs: tx         entity from amTxInit
%        ackSn, nackSn, soStart, soEnd, nackRange -- exactly as rlc.statusPduParse returns
%Outputs: tx           updated entity
%         ackedTags    1 x a integer -- tags of SDUs positively acknowledged, in SN order: the
%                      clause-4.3.1 "indication of successful delivery of upper layers PDUs"
%         maxRetxTags  1 x m integer -- SDUs for which "max retransmission has been reached".
%                      Upper layers treat this as a radio link failure (TS 38.331); RLC itself
%                      keeps going
%         valid        logical -- false if the report was discarded as invalid
%
%The report is judged as a whole BEFORE anything is applied. A STATUS PDU claiming an ACK_SN
%beyond anything submitted, or NACKing an SN at or above its own ACK_SN, cannot be a correct
%report of this entity's transmissions, and acting on its valid-looking part would acknowledge
%SDUs the peer never received.

SO_END_TO_LAST = 65535;     % clause 6.2.3.15, "1111111111111111"
snLen = tx.cfg.snFieldLength;
M = 2^snLen;
base = tx.TX_Next_Ack;
ackedTags = zeros(1, 0);
maxRetxTags = zeros(1, 0);

% ---- validity ------------------------------------------------------------------------
valid = false;
[anySub, highest] = txSubmitted(tx);
dAck = rlc.snDiff(ackSn, base, snLen);
if anySub
    if dAck > rlc.snDiff(highest, base, snLen) + 1
        return;
    end
elseif dAck ~= 0
    return;
end

% Expand the NACK sets into per-SN byte ranges; e = -1 means "to the last byte".
pSn = zeros(1, 0); pSo = zeros(1, 0); pEnd = zeros(1, 0);
for i = 1:numel(nackSn)
    R = max(nackRange(i), 1);
    for j = 0:R - 1
        s = mod(nackSn(i) + j, M);
        if rlc.snDiff(s, base, snLen) >= dAck
            return;                                     % a NACK at or above ACK_SN
        end
        so = 0;
        e = -1;
        if soStart(i) >= 0 && j == 0
            so = soStart(i);
        end
        if soEnd(i) >= 0 && j == R - 1 && soEnd(i) ~= SO_END_TO_LAST
            e = soEnd(i);
        end
        if e >= 0 && e < so
            return;                                     % SOend before SOstart
        end
        pSn(end + 1) = s; pSo(end + 1) = so; pEnd(end + 1) = e;     %#ok<AGROW>
    end
end
valid = true;

% ---- clause 5.3.3.3, judged against the TX_Next_Ack the report was written against ----
if tx.tPollRetransmitExpiry >= 0 && rlc.snDiff(tx.POLL_SN, base, snLen) < dAck
    tx.tPollRetransmitExpiry = -1;
end

% ---- negative acknowledgements, clause 5.3.2 -----------------------------------------
incrementedSn = zeros(1, 0);
for q = 1:numel(pSn)
    k = find(tx.sduSn == pSn(q), 1);
    if isempty(k) || ~anySub || rlc.snDiff(pSn(q), base, snLen) > rlc.snDiff(highest, base, snLen)
        continue;
    end
    e = pEnd(q);
    if e < 0
        e = tx.sduLen(k) - 1;
    end
    e = min(e, tx.sduSent(k) - 1);   % only bytes already submitted can be retransmitted
    if e < pSo(q)
        continue;
    end
    [tx, inc, reached] = considerRetx(tx, k, pSo(q), e, ~any(incrementedSn == pSn(q)));
    if inc
        incrementedSn(end + 1) = pSn(q);    %#ok<AGROW>
    end
    if reached && ~any(maxRetxTags == tx.sduTag(k))
        maxRetxTags(end + 1) = tx.sduTag(k);    %#ok<AGROW>
    end
end

% ---- positive acknowledgements: below ACK_SN and not NACKed in any part ----------------
k = 1;
while k <= numel(tx.sduSn)
    s = tx.sduSn(k);
    if rlc.snDiff(s, base, snLen) < dAck && ~any(pSn == s)
        ackedTags(end + 1) = tx.sduTag(k);  %#ok<AGROW>
        start = 1 + sum(tx.sduLen(1:k - 1));
        tx.buf(start : start + tx.sduLen(k) - 1) = [];
        tx.sduSn(k) = []; tx.sduLen(k) = []; tx.sduTag(k) = [];
        tx.sduSent(k) = []; tx.RETX_COUNT(k) = [];
        drop = (tx.retxSn == s);
        tx.retxSn(drop) = []; tx.retxSo(drop) = []; tx.retxEnd(drop) = [];
    else
        k = k + 1;
    end
end

% TX_Next_Ack: smallest SN not yet positively acknowledged. The table is in SN order.
if isempty(tx.sduSn)
    tx.TX_Next_Ack = tx.TX_Next;
else
    tx.TX_Next_Ack = tx.sduSn(1);
end
end
