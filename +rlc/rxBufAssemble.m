function sdu = rxBufAssemble(b, sn)
%rxBufAssemble Reassemble SDU sn from its held byte runs.
%Spec:   TS 38.322 V16.3.0, clause 5.2.2.2.3 "reassemble the RLC SDU from all byte segments
%        with SN = x, remove RLC headers and deliver"; clause 5.2.3.2.3 likewise for AM.
%        Clause 6.2.3.5: SO gives "the position within the original RLC SDU to which the first
%        byte of the RLC SDU segment in the Data field corresponds".
%Inputs: b   reception buffer; rxBufComplete(b, sn) must be true
%Outputs: sdu  1 x L row vector of octets
%
%Placed by SO, not by arrival order: a retransmitted middle segment routinely arrives after
%the last one.

if ~rlc.rxBufComplete(b, sn)
    error('rlc:rxBufAssemble:incomplete', 'rxBufAssemble: SDU %d is not completely received', sn);
end
total = 0;
for k = 1:numel(b.sn)
    if b.sn(k) == sn && b.last(k)
        total = b.so(k) + b.len(k);
    end
end
sdu = zeros(1, total);
start = 1;
for k = 1:numel(b.sn)
    if b.sn(k) == sn
        sdu(b.so(k) + 1 : b.so(k) + b.len(k)) = b.data(start : start + b.len(k) - 1);
    end
    start = start + b.len(k);
end
end
