function [tx, incremented, reachedMax] = considerRetx(tx, k, so, e, mayIncrement)
%considerRetx Consider byte range [so, e] of SDU k for retransmission.
%Spec:   TS 38.322 V16.3.0, clause 5.3.2: "When an RLC SDU or an RLC SDU segment is considered
%        for retransmission, the transmitting side of the AM RLC entity shall: if the RLC SDU
%        or RLC SDU segment is considered for retransmission for the first time: set the
%        RETX_COUNT associated with the RLC SDU to zero. else, if it ... is not pending for
%        retransmission already and the RETX_COUNT associated with the RLC SDU has not been
%        incremented due to another negative acknowledgment in the same STATUS PDU: increment
%        the RETX_COUNT. if RETX_COUNT = maxRetxThreshold: indicate to upper layers that max
%        retransmission has been reached."
%Inputs: tx            AM transmit entity
%        k             integer -- index of the SDU in tx's SDU table
%        so, e         integers -- inclusive byte range, already clipped to submitted bytes
%        mayIncrement  logical -- false when this SDU's RETX_COUNT was already incremented by
%                      another NACK in the same STATUS PDU (the caller tracks that)
%Outputs: tx           updated entity, with [so, e] merged into the retransmission buffer
%         incremented  logical -- RETX_COUNT was SET TO ZERO or went up by one here. Either
%                      spends this STATUS PDU's one action on the SDU (see below)
%         reachedMax   logical -- RETX_COUNT equals maxRetxThreshold after this consideration
%
%RETX_COUNT is per SDU, and a STATUS PDU often NACKs several segments of one SDU (one NACK set
%per missing byte run). Incrementing once per NACK set would charge one lost TB as several
%retransmissions and reach maxRetxThreshold -- a radio link failure -- several times too early.
%The same-STATUS-PDU guard exists to prevent exactly that.
%
%The first-time zeroing counts as that one action. Read per SDU, the clause would otherwise zero
%RETX_COUNT on the first NACK set of a never-retransmitted SDU and then INCREMENT it on the second
%set of the same STATUS PDU ("not considered for the first time", "not incremented" yet) -- a
%first loss of two segments charged as a retransmission. Read per segment, the second set would
%zero it again. Both readings agree only if the zeroing blocks further change within the same
%STATUS PDU, which is what this does. pending-human, see +rlc/CLAUDE.md.

sn = tx.sduSn(k);
incremented = false;

% "not pending for retransmission already": every byte of [so, e] already in the buffer.
pendingBytes = 0;
for r = 1:numel(tx.retxSn)
    if tx.retxSn(r) == sn
        s = max(tx.retxSo(r), so);
        t = min(tx.retxEnd(r), e);
        if t >= s
            pendingBytes = pendingBytes + (t - s + 1);
        end
    end
end
alreadyPending = (pendingBytes == e - so + 1);

if tx.RETX_COUNT(k) < 0
    tx.RETX_COUNT(k) = 0;
    incremented = true;
elseif ~alreadyPending && mayIncrement
    tx.RETX_COUNT(k) = tx.RETX_COUNT(k) + 1;
    incremented = true;
end
reachedMax = (tx.RETX_COUNT(k) == tx.cfg.maxRetxThreshold);

% Merge [so, e] with this SN's pending ranges (overlapping or adjacent ranges coalesce).
mine = find(tx.retxSn == sn);
starts = [tx.retxSo(mine), so];
ends = [tx.retxEnd(mine), e];
tx.retxSn(mine) = [];
tx.retxSo(mine) = [];
tx.retxEnd(mine) = [];
[starts, order] = sort(starts);
ends = ends(order);
cs = starts(1);
ce = ends(1);
for r = 2:numel(starts)
    if starts(r) <= ce + 1
        ce = max(ce, ends(r));
    else
        tx.retxSn(end + 1) = sn; tx.retxSo(end + 1) = cs; tx.retxEnd(end + 1) = ce;
        cs = starts(r);
        ce = ends(r);
    end
end
tx.retxSn(end + 1) = sn; tx.retxSo(end + 1) = cs; tx.retxEnd(end + 1) = ce;
end
