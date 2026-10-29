function tf = rxBufCovered(b, sn, y, z)
%rxBufCovered Whether byte segment numbers y to z of SDU sn have all been received.
%Spec:   TS 38.322 V16.3.0, clause 5.2.3.2.2: "if byte segment numbers y to z of the RLC SDU
%        with SN = x have been received before: discard the received AMD PDU."
%Inputs: b   reception buffer
%        sn  integer
%        y   integer, >=0 -- first byte
%        z   integer, >=y -- last byte
%Outputs: tf  logical -- true only when EVERY byte y..z is held. A partial overlap is not a
%             duplicate: the clause's next bullet keeps the PDU and trims the overlap instead.

need = z - y + 1;
have = 0;
for k = 1:numel(b.sn)
    if b.sn(k) ~= sn
        continue;
    end
    s = max(b.so(k), y);
    e = min(b.so(k) + b.len(k) - 1, z);
    if e >= s
        have = have + (e - s + 1);     % runs never overlap, so the overlaps just add
    end
end
tf = (have == need);
end
