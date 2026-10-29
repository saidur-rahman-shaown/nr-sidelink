function tf = rxBufComplete(b, sn)
%rxBufComplete Whether every byte of SDU sn is held ("all byte segments with SN = x").
%Spec:   TS 38.322 V16.3.0, clause 5.2.2.2.3: "if all byte segments with SN = x are received";
%        clause 5.2.3.2.3: "if all bytes of the RLC SDU with SN = x are received".
%Inputs: b   reception buffer
%        sn  integer
%Outputs: tf  logical
%
%Completeness needs the SDU's LENGTH, and the only source of it is a Data field marked as
%holding the last byte (SI 00 or 10). Until one arrives, no amount of contiguous bytes from 0
%is complete -- a receiver that treats "no gap so far" as complete delivers truncated SDUs
%whenever the last segment is the one that was lost.

total = -1;
have = 0;
for k = 1:numel(b.sn)
    if b.sn(k) ~= sn
        continue;
    end
    have = have + b.len(k);
    if b.last(k)
        total = b.so(k) + b.len(k);
    end
end
tf = total > 0 && have == total;
end
